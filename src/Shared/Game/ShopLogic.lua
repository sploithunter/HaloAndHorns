--[[
    ShopLogic — pure purchase gate for the reward spine (Phase 7).

    A shop offer is a Claim whose gate is a *cost* (an inverse reward bundle) plus
    an optional purchase limit, instead of a Condition. No Roblox APIs.

      affordable(cost, balances)                       -> bool
      canPurchase(offer, balances, purchaseCount)      -> { ok, reason?, currency? }

    offer.cost   = { currencies = { coins = 1000 } }   -- only currencies for now
    offer.limit  = N | nil                             -- nil = repeatable

    reasons: "insufficient_funds" (with currency) | "out_of_stock"
]]

local ShopLogic = {}

function ShopLogic.affordable(cost, balances)
    balances = balances or {}
    local currencies = (cost and cost.currencies) or {}
    for currency, amount in pairs(currencies) do
        if (balances[currency] or 0) < amount then
            return false
        end
    end
    return true
end

function ShopLogic.canPurchase(offer, balances, purchaseCount)
    offer = offer or {}
    purchaseCount = purchaseCount or 0

    if offer.limit ~= nil and purchaseCount >= offer.limit then
        return { ok = false, reason = "out_of_stock" }
    end

    local currencies = (offer.cost and offer.cost.currencies) or {}
    for currency, amount in pairs(currencies) do
        if ((balances or {})[currency] or 0) < amount then
            return { ok = false, reason = "insufficient_funds", currency = currency }
        end
    end

    return { ok = true }
end

return ShopLogic
