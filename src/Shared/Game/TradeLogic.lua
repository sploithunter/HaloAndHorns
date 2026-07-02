--[[
    TradeLogic — pure functional core for trading (Feature 19).

    No Roblox APIs. The service supplies item descriptors; these rules decide what
    can be offered and whether a trade may execute.

      canAddItem(category, item, config)        -> { ok, reason? }
      canExecute(offerA, offerB)                -> { ok, reason? }
      auditRecord(playerA, playerB, offerA, offerB, timestamp) -> table

    An `offer` is { items = {...}, confirmed = boolean }. An `item` is
    { category = "pets"|"currencies"|"cosmetics", id, locked? }.
]]

local TradeLogic = {}

function TradeLogic.canAddItem(category, item, config)
    local tradeable = config and config.tradeable or {}
    -- Currencies are non-tradeable EXCEPT an explicit per-currency allowlist
    -- (config.tradeable_currencies = { gems = true }). Pet Realm design: the four
    -- biome coins are soulbound; gems are the only trade currency.
    if category == "currencies" then
        local allow = config and config.tradeable_currencies or {}
        local id = item and item.id
        if id and allow[id] == true then
            return { ok = true }
        end
        return { ok = false, reason = "currencies_not_tradeable" }
    end
    if tradeable[category] == false then
        return { ok = false, reason = "not_tradeable" }
    end
    if tradeable[category] ~= true then
        return { ok = false, reason = "not_tradeable" }
    end
    if category == "pets" and item and item.locked == true then
        return { ok = false, reason = "pet_locked" }
    end
    return { ok = true }
end

-- A trade executes only when BOTH sides have confirmed.
function TradeLogic.canExecute(offerA, offerB)
    if not (offerA and offerB) then
        return { ok = false, reason = "incomplete_trade" }
    end
    if offerA.confirmed ~= true or offerB.confirmed ~= true then
        return { ok = false, reason = "not_both_confirmed" }
    end
    return { ok = true }
end

-- Build a trade-history audit record (both players, items, timestamp).
function TradeLogic.auditRecord(playerA, playerB, offerA, offerB, timestamp)
    return {
        a = playerA,
        b = playerB,
        a_items = (offerA and offerA.items) or {},
        b_items = (offerB and offerB.items) or {},
        timestamp = timestamp,
    }
end

return TradeLogic
