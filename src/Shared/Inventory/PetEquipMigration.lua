--[[
    PetEquipMigration — pure v6 -> v7 transform: lift equip state OFF the inventory records
    into a separate Equipped table, so `Inventory.pets.items` becomes pure ownership and
    `Equipped.pets` becomes the authoritative (validated-at-read) restore/preference layer.

    v6 records carried equip inline:
      common stack  items["id:variant"] = { ..., equipped_slots = {3,7} }
      special       items[uid]          = { ..., equipped_slot = 2 }

    v7 lifts those into Equipped.pets:
      Equipped.pets["slot_3"] = "stack|id:variant"
      Equipped.pets["slot_2"] = "<uid>"
    and the caller then normalizes the records (which strips the inline equip fields).

    PURE: no Roblox APIs. A common stack is keyed by "id:variant" (contains ':'); a special by
    its uid (no ':'). Slot collisions keep the first claimant (ownership is untouched either
    way — at worst one equip preference is dropped, never a pet).

    extractToEquipped(items) -> equippedTable, report{ refsOnRecords, refsExtracted }
]]

local PetEquipMigration = {}

local function slotArray(slots)
    local seen, out = {}, {}
    if type(slots) == "table" then
        for key, value in pairs(slots) do
            local n
            if value == true then
                n = tonumber(key)
            else
                n = tonumber(value)
            end
            if n and n >= 1 and n == math.floor(n) and not seen[n] then
                seen[n] = true
                out[#out + 1] = n
            end
        end
    end
    table.sort(out)
    return out
end

function PetEquipMigration.extractToEquipped(items)
    items = items or {}
    local equipped = {}
    local claimed = {}
    local refsOnRecords, refsExtracted = 0, 0

    -- Deterministic order (specials before commons would be arbitrary; sort by key).
    local keys = {}
    for key, entry in pairs(items) do
        if type(entry) == "table" then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)

    local function claim(slot, ref)
        refsOnRecords += 1
        if slot >= 1 and not claimed[slot] then
            claimed[slot] = true
            equipped["slot_" .. slot] = ref
            refsExtracted += 1
        end
    end

    for _, key in ipairs(keys) do
        local entry = items[key]
        local isStack = string.find(key, ":") ~= nil
        if isStack then
            for _, slot in ipairs(slotArray(entry.equipped_slots)) do
                claim(slot, "stack|" .. key)
            end
        else
            local slot = tonumber(entry.equipped_slot)
            if slot and slot >= 1 and slot == math.floor(slot) then
                claim(slot, key) -- bare uid for a special
            end
        end
    end

    return equipped, { refsOnRecords = refsOnRecords, refsExtracted = refsExtracted }
end

return PetEquipMigration
