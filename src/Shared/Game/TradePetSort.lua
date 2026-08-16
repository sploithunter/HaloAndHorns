--[[
    TradePetSort

    Deterministic ordering for pet-only trade lists:
      1. Huge pets first (regardless of ordinary power)
      2. Effective/display power, strongest first
      3. Stack quantity, largest first
      4. Stable identity fields for deterministic ties

    The caller supplies the power resolver because live display power depends on
    the local player's current zone/realm. Keeping the hierarchy pure makes it
    headless-testable while allowing TradePanel to use inventory-equivalent power.
]]

local TradePetSort = {}

local function recordOf(item)
    return type(item and item.record) == "table" and item.record or item or {}
end

local function isHuge(item)
    local record = recordOf(item)
    return item and item.huge == true or record.huge == true
end

local function stableText(item, field)
    local record = recordOf(item)
    return tostring((item and item[field]) or record[field] or "")
end

function TradePetSort.compare(a, b, powerFor)
    local ah, bh = isHuge(a), isHuge(b)
    if ah ~= bh then
        return ah
    end

    local ap = tonumber(powerFor and powerFor(a)) or tonumber(a and a.sortPower) or 0
    local bp = tonumber(powerFor and powerFor(b)) or tonumber(b and b.sortPower) or 0
    if ap ~= bp then
        return ap > bp
    end

    local aq = tonumber(a and (a.quantity or a.count)) or 1
    local bq = tonumber(b and (b.quantity or b.count)) or 1
    if aq ~= bq then
        return aq > bq
    end

    for _, field in ipairs({ "id", "variant", "uid", "recordKey" }) do
        local av, bv = stableText(a, field), stableText(b, field)
        if av ~= bv then
            return av < bv
        end
    end
    return false
end

function TradePetSort.sort(items, powerFor)
    table.sort(items, function(a, b)
        return TradePetSort.compare(a, b, powerFor)
    end)
    return items
end

return TradePetSort
