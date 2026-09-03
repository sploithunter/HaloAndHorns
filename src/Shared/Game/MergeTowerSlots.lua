-- Physical cannon pads. Each bay has a front Left/Right pair and a second
-- RearLeft/RearRight pair at the same depth interval behind them. Each mount
-- has its own Artillery Commander. Ownership is global; install is per pad.
-- Towers do not create combat planes.

local MergeTowerSlots = {}

local DEFAULT_ID = "left"

local SLOTS = {
    {
        id = "left",
        persistFamily = "left_tower_family",
        persistTier = "left_tower_tier",
        recordFamily = "leftTowerFamily",
        recordTier = "leftTowerTier",
        aliasFamily = "leftFamily",
        aliasTier = "leftTier",
        padRole = "Left",
        padSlot = 1,
        promptObject = "Artillery",
    },
    {
        id = "right",
        persistFamily = "right_tower_family",
        persistTier = "right_tower_tier",
        recordFamily = "rightTowerFamily",
        recordTier = "rightTowerTier",
        aliasFamily = "rightFamily",
        aliasTier = "rightTier",
        padRole = "Right",
        padSlot = 2,
        promptObject = "Artillery",
    },
    {
        id = "rear_left",
        persistFamily = "rear_left_tower_family",
        persistTier = "rear_left_tower_tier",
        recordFamily = "rearLeftTowerFamily",
        recordTier = "rearLeftTowerTier",
        aliasFamily = "rearLeftFamily",
        aliasTier = "rearLeftTier",
        padRole = "RearLeft",
        padSlot = 3,
        promptObject = "Rear Artillery",
    },
    {
        id = "rear_right",
        persistFamily = "rear_right_tower_family",
        persistTier = "rear_right_tower_tier",
        recordFamily = "rearRightTowerFamily",
        recordTier = "rearRightTowerTier",
        aliasFamily = "rearRightFamily",
        aliasTier = "rearRightTier",
        padRole = "RearRight",
        padSlot = 4,
        promptObject = "Rear Artillery",
    },
}

local SLOT_BY_ID = {}
for _, slot in ipairs(SLOTS) do
    SLOT_BY_ID[slot.id] = slot
end

local function cloneRow(row)
    return table.clone(row)
end

function MergeTowerSlots.defaultId()
    return DEFAULT_ID
end

function MergeTowerSlots.all()
    local result = {}
    for index, slot in ipairs(SLOTS) do
        result[index] = cloneRow(slot)
    end
    return result
end

function MergeTowerSlots.ids()
    local result = {}
    for index, slot in ipairs(SLOTS) do
        result[index] = slot.id
    end
    return result
end

function MergeTowerSlots.get(id)
    local slot = SLOT_BY_ID[MergeTowerSlots.normalizeId(id)]
    return slot and cloneRow(slot) or nil
end

function MergeTowerSlots.normalizeId(id)
    if type(id) == "number" then
        local def = SLOTS[math.floor(id)]
        return def and def.id or DEFAULT_ID
    end
    local key = string.lower(tostring(id or DEFAULT_ID))
    local compact = string.gsub(key, "[^%w]", "")
    local aliases = {
        ["1"] = "left",
        slot1 = "left",
        initialtowerpadleft = "left",
        ["2"] = "right",
        slot2 = "right",
        initialtowerpadright = "right",
        ["3"] = "rear_left",
        slot3 = "rear_left",
        rearleft = "rear_left",
        initialtowerpadrearleft = "rear_left",
        ["4"] = "rear_right",
        slot4 = "rear_right",
        rearright = "rear_right",
        initialtowerpadrearright = "rear_right",
    }
    if aliases[compact] then
        return aliases[compact]
    end
    if SLOT_BY_ID[key] then
        return key
    end
    return DEFAULT_ID
end

function MergeTowerSlots.requiredRebirthRank(slot, config)
    config = type(config) == "table" and config or {}
    local def = type(slot) == "table" and slot or MergeTowerSlots.get(slot)
    if not def then
        return math.huge
    end
    local gates = config.slot_unlock_rebirth_ranks
    assert(type(gates) == "table", "edge_towers.slot_unlock_rebirth_ranks is required")
    local required = tonumber(gates[def.id])
    assert(required ~= nil, "Missing cannon Rebirth gate for " .. def.id)
    return math.max(1, math.floor(required))
end

function MergeTowerSlots.isUnlockedAtRank(slot, rebirthRank, config)
    local rank = math.max(1, math.floor(tonumber(rebirthRank) or 1))
    return rank >= MergeTowerSlots.requiredRebirthRank(slot, config)
end

function MergeTowerSlots.fromPad(pad)
    if not pad then
        return DEFAULT_ID
    end
    local function attr(key)
        if type(pad.GetAttribute) == "function" then
            return pad:GetAttribute(key)
        end
        return nil
    end
    local tagged = attr("MergeTowerSlot")
    if type(tagged) == "string" and tagged ~= "" then
        return MergeTowerSlots.normalizeId(tagged)
    end
    local role = attr("MergeTowerPadRole")
    if type(role) == "string" and role ~= "" then
        return MergeTowerSlots.normalizeId(role)
    end
    local slot = attr("MergeTowerPadSlot")
    if slot ~= nil then
        return MergeTowerSlots.normalizeId(slot)
    end
    return MergeTowerSlots.normalizeId(pad.Name)
end

function MergeTowerSlots.canInstall(_family, slotId)
    return SLOT_BY_ID[MergeTowerSlots.normalizeId(slotId)] ~= nil
end

return MergeTowerSlots
