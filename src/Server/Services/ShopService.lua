--[[
    ShopService — Phase 7 (the cost-gated reward gate).

    A shop offer is a Claim whose gate is a *cost* (an inverse reward bundle) plus an
    optional purchase limit. ShopLogic decides affordability/limit; on success the
    cost is spent (DataService:RemoveCurrency) and the reward bundle is granted via
    RewardService. Purchase counts live in profile.ShopPurchases (offerId -> count)
    so limited offers don't repeat.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopLogic = require(ReplicatedStorage.Shared.Game.ShopLogic)

local ShopService = {}
ShopService.__index = ShopService

function ShopService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._config = self._configLoader:LoadConfig("shop")
end

function ShopService:_service(name)
    local locator = _G.RBXTemplateServices
    if not locator then
        return nil
    end
    local ok, service = pcall(function()
        return locator:Get(name)
    end)
    return ok and service or nil
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

    -- Spend the cost (server-authoritative), then grant the reward.
    for currency, amount in pairs((offer.cost and offer.cost.currencies) or {}) do
        self._dataService:RemoveCurrency(player, currency, amount, "shop:" .. offerId)
    end
    local rewards = self:_service("RewardService")
    local granted
    if rewards then
        granted = rewards:Grant(player, offer.reward, "shop:" .. offerId)
    end
    counts[offerId] = (counts[offerId] or 0) + 1
    self._dataService:RequestSave(player, "shop_purchase", { critical = true })
    return { ok = true, offer = offerId, reward = granted and granted.granted }
end

return ShopService
