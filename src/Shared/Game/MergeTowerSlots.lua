-- Physical cannon pads. Each bay has a Left and Right mount; each mount has
-- its own Artillery Commander. Ownership is global; install is per pad.
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
        if id == 2 then
            return "right"
        end
        return "left"
    end
    local key = string.lower(tostring(id or DEFAULT_ID))
    if key == "2" or key == "right" or key == "slot2" then
        return "right"
    end
    if SLOT_BY_ID[key] then
        return key
    end
    return DEFAULT_ID
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
