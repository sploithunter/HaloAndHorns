-- Physical install slots versus the two combat planes.
--
-- Combat planes are unique named parts and keep their meanings:
--   BulwarkLine — pets change behavior after they cross (combat opens).
--   BreachLine  — marchers may attack hatcher eggs / count overrun.
-- Do not add a third combat-plane meaning. Extra walls are install slots only.
--
-- Install slots are repeatable placement lines. Lane sits on the yellow
-- BulwarkLine and egg sits on the red BreachLine. Mid is the orange line
-- exactly halfway between them; front is the green line one equal interval
-- beyond yellow toward the gate. Later walls can keep that spacing outward
-- without touching the two combat planes.
-- Towers should grow the same way: own catalog, same per-slot loop.

local MergeBulwarkSlots = {}

local DEFAULT_ID = "lane"

local COMBAT_PLANES = {
    {
        id = "bulwark",
        lineConfigKey = "bulwark_line",
        lineDefault = "BulwarkLine",
        distanceAttr = "MergeEggBulwarkLeadingDistance",
        opensCombat = true,
        countsAsPastBulwark = true,
        writeApproachDebug = true,
    },
    {
        id = "breach",
        lineConfigKey = "breach_line",
        lineDefault = "BreachLine",
        distanceAttr = "MergeEggBreachLineDistance",
        opensCombat = false,
        countsAsPastBulwark = false,
        countsBreach = true,
        writeApproachDebug = false,
    },
}

local SLOTS = {
    {
        id = "lane",
        persistFamily = "bulwark_family",
        persistTier = "bulwark_tier",
        recordFamily = "bulwarkFamily",
        recordTier = "bulwarkTier",
        aliasFamily = "family",
        aliasTier = "tier",
        stationsFolder = "BulwarkStations",
        anchorsSuffix = "BulwarkAnchors",
        anchorNamePattern = "^BulwarkAnchor_%d+$",
        anchorNameFormat = "BulwarkAnchor_%02d",
        bayFolderFormat = "%s_%02d_BulwarkAnchors",
        modelPrefix = "",
        promptPrefix = "",
        promptObject = "Bulwark",
        restrictedHint = nil,
        -- Sits on the yellow combat plane. Strip ticks use that part; they do
        -- not replace the plane's pet-combat meaning.
        combatPlane = "bulwark",
        required = true,
    },
    {
        id = "egg",
        persistFamily = "egg_bulwark_family",
        persistTier = "egg_bulwark_tier",
        recordFamily = "eggBulwarkFamily",
        recordTier = "eggBulwarkTier",
        aliasFamily = "eggFamily",
        aliasTier = "eggTier",
        stationsFolder = "EggBulwarkStations",
        anchorsSuffix = "EggBulwarkAnchors",
        anchorNamePattern = "^EggBulwarkAnchor_%d+$",
        anchorNameFormat = "EggBulwarkAnchor_%02d",
        bayFolderFormat = "%s_%02d_EggBulwarkAnchors",
        modelPrefix = "Egg",
        promptPrefix = "Egg",
        promptObject = "Egg Bulwark",
        restrictedHint = "ONLY AT THE EGGS",
        combatPlane = "breach",
        required = false,
    },
    {
        id = "mid",
        persistFamily = "mid_bulwark_family",
        persistTier = "mid_bulwark_tier",
        recordFamily = "midBulwarkFamily",
        recordTier = "midBulwarkTier",
        aliasFamily = "midFamily",
        aliasTier = "midTier",
        stationsFolder = "MidBulwarkStations",
        anchorsSuffix = "MidBulwarkAnchors",
        anchorNamePattern = "^MidBulwarkAnchor_%d+$",
        anchorNameFormat = "MidBulwarkAnchor_%02d",
        bayFolderFormat = "%s_%02d_MidBulwarkAnchors",
        modelPrefix = "Mid",
        promptPrefix = "Mid",
        promptObject = "Orange Bulwark",
        -- Halfway between the two combat planes. Placement hook only.
        lineConfigKey = "mid_bulwark_line",
        lineDefault = "MidBulwarkLine",
        distanceAttr = "MergeEggMidBulwarkDistance",
        combatPlane = nil,
        required = false,
    },
    {
        id = "front",
        persistFamily = "front_bulwark_family",
        persistTier = "front_bulwark_tier",
        recordFamily = "frontBulwarkFamily",
        recordTier = "frontBulwarkTier",
        aliasFamily = "frontFamily",
        aliasTier = "frontTier",
        stationsFolder = "FrontBulwarkStations",
        anchorsSuffix = "FrontBulwarkAnchors",
        anchorNamePattern = "^FrontBulwarkAnchor_%d+$",
        anchorNameFormat = "FrontBulwarkAnchor_%02d",
        bayFolderFormat = "%s_%02d_FrontBulwarkAnchors",
        modelPrefix = "Front",
        promptPrefix = "Front",
        promptObject = "Green Bulwark",
        -- Same spacing out past BulwarkLine toward the gate. Placement hook only.
        lineConfigKey = "front_bulwark_line",
        lineDefault = "FrontBulwarkLine",
        distanceAttr = "MergeEggFrontBulwarkDistance",
        combatPlane = nil,
        required = false,
    },
}

local SLOT_BY_ID = {}
for _, slot in ipairs(SLOTS) do
    SLOT_BY_ID[slot.id] = slot
end

local PLANE_BY_ID = {}
for _, plane in ipairs(COMBAT_PLANES) do
    PLANE_BY_ID[plane.id] = plane
end

-- Families omitted here may sit on every cataloged line.
local FAMILY_ONLY_SLOTS = {
    wardstone_barrier = { egg = true },
}

local function cloneRow(row)
    return table.clone(row)
end

function MergeBulwarkSlots.defaultId()
    return DEFAULT_ID
end

function MergeBulwarkSlots.combatPlanes()
    local result = {}
    for index, plane in ipairs(COMBAT_PLANES) do
        result[index] = cloneRow(plane)
    end
    return result
end

function MergeBulwarkSlots.combatPlane(id)
    local plane = PLANE_BY_ID[tostring(id or "")]
    return plane and cloneRow(plane) or nil
end

function MergeBulwarkSlots.all()
    local result = {}
    for index, slot in ipairs(SLOTS) do
        result[index] = cloneRow(slot)
    end
    return result
end

function MergeBulwarkSlots.ids()
    local result = {}
    for index, slot in ipairs(SLOTS) do
        result[index] = slot.id
    end
    return result
end

function MergeBulwarkSlots.get(id)
    local slot = SLOT_BY_ID[string.lower(tostring(id or ""))]
    return slot and cloneRow(slot) or nil
end

function MergeBulwarkSlots.normalizeId(id)
    local key = string.lower(tostring(id or DEFAULT_ID))
    if SLOT_BY_ID[key] then
        return key
    end
    return DEFAULT_ID
end

function MergeBulwarkSlots.attrSuffix(id)
    return "_" .. MergeBulwarkSlots.normalizeId(id)
end

function MergeBulwarkSlots.requiredRebirthRank(slot, config)
    config = type(config) == "table" and config or {}
    local def = type(slot) == "table" and slot or MergeBulwarkSlots.get(slot)
    if not def then
        return math.huge
    end
    local gates = config.slot_unlock_rebirth_ranks
    assert(type(gates) == "table", "edge_bulwarks.slot_unlock_rebirth_ranks is required")
    local required = tonumber(gates[def.id])
    assert(required ~= nil, "Missing bulwark Rebirth gate for " .. def.id)
    return math.max(1, math.floor(required))
end

function MergeBulwarkSlots.isUnlockedAtRank(slot, rebirthRank, config)
    local rank = math.max(1, math.floor(tonumber(rebirthRank) or 1))
    return rank >= MergeBulwarkSlots.requiredRebirthRank(slot, config)
end

function MergeBulwarkSlots.stripLineName(slot, worldConfig)
    worldConfig = type(worldConfig) == "table" and worldConfig or {}
    local def = type(slot) == "table" and slot or MergeBulwarkSlots.get(slot)
    if not def then
        return nil
    end
    if def.combatPlane then
        local plane = PLANE_BY_ID[def.combatPlane]
        if plane then
            return worldConfig[plane.lineConfigKey] or plane.lineDefault
        end
    end
    return worldConfig[def.lineConfigKey] or def.lineDefault
end

function MergeBulwarkSlots.stripDistanceAttr(slot)
    local def = type(slot) == "table" and slot or MergeBulwarkSlots.get(slot)
    if not def then
        return nil
    end
    if def.combatPlane then
        local plane = PLANE_BY_ID[def.combatPlane]
        return plane and plane.distanceAttr or nil
    end
    return def.distanceAttr
end

function MergeBulwarkSlots.allowedSlotsForFamily(family)
    local id = string.lower(tostring(family or ""))
    local only = FAMILY_ONLY_SLOTS[id]
    if only == nil then
        return nil
    end
    local result = {}
    for slotId in pairs(only) do
        result[#result + 1] = slotId
    end
    table.sort(result)
    return result
end

function MergeBulwarkSlots.canInstall(family, slotId)
    local key = string.lower(tostring(slotId or ""))
    if SLOT_BY_ID[key] == nil then
        return false
    end
    local only = FAMILY_ONLY_SLOTS[string.lower(tostring(family or ""))]
    if only == nil then
        return true
    end
    return only[key] == true
end

function MergeBulwarkSlots.restrictedHint(family, slotId)
    if MergeBulwarkSlots.canInstall(family, slotId) then
        return nil
    end
    local allowed = MergeBulwarkSlots.allowedSlotsForFamily(family)
    local first = allowed and allowed[1]
    local slot = first and SLOT_BY_ID[first]
    return slot and slot.restrictedHint or "LOCKED LINE"
end

return MergeBulwarkSlots
