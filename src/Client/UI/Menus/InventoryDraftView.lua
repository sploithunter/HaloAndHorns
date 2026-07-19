--[[
    Pure count reconciliation for the InventoryPanel squad draft.

    Replicated stack Quantity is the number of UNEQUIPPED pets, while the squad
    editor renders a working draft that may differ from the live deployed squad:

        owned = unequipped + deployed
        available in the working grid = owned - drafted
]]

local InventoryDraftView = {}

function InventoryDraftView.normalizeRef(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    if string.sub(value, 1, 6) == "stack|" then
        return (string.gsub(value, "|%d+$", ""))
    end
    return value
end

function InventoryDraftView.stackPrefix(ref)
    if type(ref) ~= "string" or string.sub(ref, 1, 6) ~= "stack|" then
        return nil
    end
    local key = string.sub(ref, 7)
    local petId, variant = string.match(key, "^([^:]*):([^:]*)")
    if petId and petId ~= "" and variant then
        return petId .. ":" .. variant
    end
    return nil
end

function InventoryDraftView.refsMatch(a, b)
    local left = InventoryDraftView.normalizeRef(a)
    local right = InventoryDraftView.normalizeRef(b)
    if not left or not right then
        return false
    end
    if left == right then
        return true
    end
    local leftPrefix = InventoryDraftView.stackPrefix(left)
    return leftPrefix ~= nil and leftPrefix == InventoryDraftView.stackPrefix(right)
end

function InventoryDraftView.countMatching(ref, refs)
    local count = 0
    for _, candidate in ipairs(refs or {}) do
        if InventoryDraftView.refsMatch(ref, candidate) then
            count += 1
        end
    end
    return count
end

-- A card cache can be built while the server's equip projection is still settling. The Quantity
-- IntValue itself is stable and authoritative, so a present live value (including zero) must win
-- over the cached snapshot.
function InventoryDraftView.unequippedCount(cachedCount, liveCount)
    local live = tonumber(liveCount)
    if live ~= nil then
        return math.max(0, math.floor(live))
    end
    return math.max(0, math.floor(tonumber(cachedCount) or 0))
end

function InventoryDraftView.stackCounts(unequipped, ref, deployedRefs, draftRefs)
    local availableOnServer = InventoryDraftView.unequippedCount(unequipped, nil)
    local deployed = InventoryDraftView.countMatching(ref, deployedRefs)
    local drafted = InventoryDraftView.countMatching(ref, draftRefs)
    local owned = availableOnServer + deployed
    return {
        owned = owned,
        available = math.max(0, owned - drafted),
        deployed = deployed,
        drafted = drafted,
    }
end

return InventoryDraftView
