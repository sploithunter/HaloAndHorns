--[[
    ShopService — Phase 7 (the cost-gated reward gate).

    A shop offer is a Claim whose gate is a *cost* (an inverse reward bundle) plus an
    optional purchase limit. ShopLogic decides affordability/limit; on success the
    cost is spent through EconomyService and the reward bundle is granted via
    RewardService. Purchase counts live in profile.ShopPurchases (offerId -> count)
    so limited offers don't repeat.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopLogic = require(ReplicatedStorage.Shared.Game.ShopLogic)
local ShopPurchaseTransaction = require(ReplicatedStorage.Shared.Game.ShopPurchaseTransaction)

local ShopService = {}
ShopService.__index = ShopService

function ShopService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._economyService = self._modules and self._modules.EconomyService
    self._rewardService = self._modules and self._modules.RewardService
    self._config = self._configLoader:LoadConfig("shop")
end

function ShopService:_balances(player)
    local out = {}
    local data = self._dataService and self._dataService:GetData(player)
    if data and type(data.Currencies) == "table" then
        for k, v in pairs(data.Currencies) do
            out[k] = v
        end
    end
    return out
end

local function purchases(data)
    if type(data.ShopPurchases) ~= "table" then
        data.ShopPurchases = {}
    end
    return data.ShopPurchases
end

function ShopService:List(player)
    local balances = self:_balances(player)
    local data = self._dataService:GetData(player)
    local counts = purchases(data)
    local out = {}
    for id, offer in pairs(self._config.offers or {}) do
        local count = counts[id] or 0
        local verdict = ShopLogic.canPurchase(offer, balances, count)
        table.insert(out, {
            id = id,
            name = offer.name,
            cost = offer.cost,
            reward = offer.reward,
            discountPercent = offer.discount_percent,
            limit = offer.limit,
            purchasedCount = count,
            purchasable = verdict.ok,
            reason = verdict.reason,
        })
    end
    return { ok = true, offers = out }
end

function ShopService:Purchase(player, offerId)
    local offer = (self._config.offers or {})[offerId]
    if not offer then
        return { ok = false, reason = "unknown_offer" }
    end
    local data = self._dataService:GetData(player)
    local counts = purchases(data)
    local balances = self:_balances(player)
    local verdict = ShopLogic.canPurchase(offer, balances, counts[offerId] or 0)
    if not verdict.ok then
        return verdict
    end

    -- SPEND → GRANT → REFUND-ON-FAILURE (2026-07-07 transaction audit: this spent the
    -- currency then ran an un-pcalled Grant — and even reported ok=true with NO reward when
    -- RewardService wasn't resolvable — leaving the buyer currency-poor with nothing. Same
    -- contract as EnhancementShopService:Buy now: the grant must land or the spend comes back.)
    local economy = self._economyService
    local rewards = self._rewardService
    if not economy or not rewards then
        return { ok = false, reason = "service_unavailable" }
    end
    local source = "shop:" .. offerId
    local transaction = ShopPurchaseTransaction.execute({
        costs = offer.cost and offer.cost.currencies,
        debit = function(currency, amount)
            return economy:RemoveCurrency(player, currency, amount, source)
        end,
        grant = function()
            return rewards:Grant(player, offer.reward, source)
        end,
        refund = function(currency, amount)
            return economy:AddCurrency(player, currency, amount, source .. ":refund")
        end,
    })
    if not transaction.ok then
        return transaction
    end
    counts[offerId] = (counts[offerId] or 0) + 1
    self._dataService:RequestSave(player, "shop_purchase", { critical = true })
    return { ok = true, offer = offerId, reward = transaction.granted.granted }
end

return ShopService
