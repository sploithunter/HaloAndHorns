-- Pure progression policy for Merge Defense pad cannons. The server owns
-- payment and persistence; this module keeps unlock, role ownership, pad
-- install, and tier advancement deterministic. Buying a role unlocks
-- Install on every pad. Each pad keeps its own family and tier; Upgrade
-- only advances the pad whose commander you talked to.

local MergeTowerSlots = require(script.Parent.MergeTowerSlots)
local MergeTierArt = require(script.Parent.MergeTierArt)

local MergeTowerProgression = {}

local FAMILIES = {
    {
        id = "heal",
        name = "Heal Cannon",
        role = "Mend",
        description = "A support piece on the pad. Landing casts a Healing Field at the impact. Every tier has its own chassis.",
        upgradeNotes = {
            { "+ Starter Heal chassis", "+ Sits on this pad", "+ Lands a Healing Field" },
            { "+ Reinforced Heal chassis", "+ Distinct Tier 2 model", "+ Healing Field" },
            { "+ Advanced Heal chassis", "+ Distinct Tier 3 model", "+ Healing Field" },
            { "+ Mythic Heal chassis", "+ Distinct Tier 4 model", "+ Healing Field" },
        },
    },
    {
        id = "rage",
        name = "Rage Cannon",
        role = "Fury",
        description = "A fury piece on the pad. Landing drops a Berserk circle at the impact. Every tier has its own chassis.",
        upgradeNotes = {
            { "+ Starter Rage chassis", "+ Sits on this pad", "+ Lands a Berserk circle" },
            { "+ Reinforced Rage chassis", "+ Distinct Tier 2 model", "+ Berserk circle" },
            { "+ Advanced Rage chassis", "+ Distinct Tier 3 model", "+ Berserk circle" },
            { "+ Mythic Rage chassis", "+ Distinct Tier 4 model", "+ Berserk circle" },
        },
    },
    {
        id = "debuff",
        name = "Debuff Cannon",
        role = "Hex",
        description = "A hex piece on the pad. Landing sips a Weakening Vial on enemies in the circle. Every tier has its own chassis.",
        upgradeNotes = {
            { "+ Starter Debuff chassis", "+ Sits on this pad", "+ Lands a Weakening Vial" },
            { "+ Reinforced Debuff chassis", "+ Distinct Tier 2 model", "+ Weakening Vial" },
            { "+ Advanced Debuff chassis", "+ Distinct Tier 3 model", "+ Weakening Vial" },
            { "+ Mythic Debuff chassis", "+ Distinct Tier 4 model", "+ Weakening Vial" },
        },
    },
    {
        id = "gravity",
        name = "Gravity Cannon",
        role = "Pull",
        description = "A pull piece on the pad. Landing opens a black hole and shoves enemies into the impact. Every tier has its own chassis.",
        upgradeNotes = {
            { "+ Starter Gravity chassis", "+ Sits on this pad", "+ Black hole pull" },
            { "+ Reinforced Gravity chassis", "+ Distinct Tier 2 model", "+ Black hole pull" },
            { "+ Advanced Gravity chassis", "+ Distinct Tier 3 model", "+ Black hole pull" },
            { "+ Mythic Gravity chassis", "+ Distinct Tier 4 model", "+ Black hole pull" },
        },
    },
    {
        id = "repulsor",
        name = "Repulsor Cannon",
        role = "Push",
        description = "The playtest starter. Landing is a concussion blast: enemies in the radius can be flung outward. Every tier has its own chassis.",
        upgradeNotes = {
            { "+ Starter Repulsor chassis", "+ Sits on this pad", "+ Blast (50% hit)" },
            { "+ Reinforced Repulsor chassis", "+ Distinct Tier 2 model", "+ Blast (50% hit)" },
            { "+ Advanced Repulsor chassis", "+ Distinct Tier 3 model", "+ Blast (45% hit)" },
            { "+ Mythic Repulsor chassis", "+ Distinct Tier 4 model", "+ Blast (40% hit)" },
        },
    },
    {
        id = "nullifier",
        name = "Nullifier Cannon",
        role = "Silence",
        description = "A silence piece on the pad. Landing rolls Frost Bind on each enemy in the circle. Every tier has its own chassis.",
        upgradeNotes = {
            { "+ Starter Nullifier chassis", "+ Sits on this pad", "+ Frost Bind (40% hit)" },
            {
                "+ Reinforced Nullifier chassis",
                "+ Distinct Tier 2 model",
                "+ Frost Bind (50% hit)",
            },
            { "+ Advanced Nullifier chassis", "+ Distinct Tier 3 model", "+ Frost Bind (60% hit)" },
            { "+ Mythic Nullifier chassis", "+ Distinct Tier 4 model", "+ Frost Bind (70% hit)" },
        },
    },
}

local FAMILY_SET = {}
for _, family in ipairs(FAMILIES) do
    FAMILY_SET[family.id] = true
end

local function normalizeSlot(slot)
    return MergeTowerSlots.normalizeId(slot)
end

local function whole(value, minimum)
    return math.max(minimum or 0, math.floor(tonumber(value) or 0))
end

local function cloneOwned(owned)
    local result = {}
    for family, tier in pairs(type(owned) == "table" and owned or {}) do
        result[family] = tier
    end
    return result
end

local function snapshot(state)
    local parts = {}
    local installs = type(state.slots) == "table" and state.slots or {}
    for _, slotId in ipairs(MergeTowerSlots.ids()) do
        local install = installs[slotId]
        parts[#parts + 1] = slotId .. ":" .. tostring(install and install.family or "")
        parts[#parts + 1] = tostring(install and install.tier or 0)
    end
    local keys = {}
    for family in pairs(type(state.owned) == "table" and state.owned or {}) do
        keys[#keys + 1] = family
    end
    table.sort(keys)
    for _, family in ipairs(keys) do
        parts[#parts + 1] = family .. "=" .. tostring(state.owned[family])
    end
    return table.concat(parts, "|")
end

MergeTowerProgression.SLOT_LEFT = "left"
MergeTowerProgression.SLOT_RIGHT = "right"
MergeTowerProgression.SLOT_REAR_LEFT = "rear_left"
MergeTowerProgression.SLOT_REAR_RIGHT = "rear_right"
MergeTowerProgression.slots = MergeTowerSlots

function MergeTowerProgression.families(tierArt)
    local result = {}
    for index, family in ipairs(FAMILIES) do
        result[index] = table.clone(family)
        result[index].previewAssetIds = MergeTierArt.previewAssetIds(tierArt, "cannon", family.id)
        result[index].upgradeNotes = {}
        for step, lines in ipairs(family.upgradeNotes) do
            result[index].upgradeNotes[step] = table.clone(lines)
        end
    end
    return result
end

function MergeTowerProgression.familiesForSlot(slot, tierArt)
    slot = normalizeSlot(slot)
    local result = MergeTowerProgression.families(tierArt)
    for _, family in ipairs(result) do
        family.canInstall = MergeTowerProgression.canInstall(family.id, slot)
        family.slotFor = "any"
        family.installHint = nil
    end
    return result
end

function MergeTowerProgression.isFamily(family)
    return FAMILY_SET[string.lower(tostring(family or ""))] == true
end

function MergeTowerProgression.normalizeSlot(slot)
    return normalizeSlot(slot)
end

function MergeTowerProgression.requiredRebirthRank(slot, config)
    return MergeTowerSlots.requiredRebirthRank(normalizeSlot(slot), config)
end

function MergeTowerProgression.isSlotUnlocked(slot, rebirthRank, config)
    return MergeTowerSlots.isUnlockedAtRank(normalizeSlot(slot), rebirthRank, config)
end

function MergeTowerProgression.canInstall(family, slot)
    local id = string.lower(tostring(family or ""))
    if not FAMILY_SET[id] then
        return false
    end
    return MergeTowerSlots.canInstall(id, slot)
end

local function readRawFamily(raw, def, nested)
    local install = type(nested) == "table" and nested[def.id] or nil
    if type(install) == "table" and install.family then
        return install.family, install.tier
    end
    return raw[def.aliasFamily] or raw[def.persistFamily],
        raw[def.aliasTier] or raw[def.persistTier]
end

local function installEntry(entry)
    if type(entry) == "table" then
        return entry.family, whole(entry.tier, 0)
    end
    return entry, 0
end

local function decorateState(owned, installs, cap)
    cap = math.max(1, whole(cap, 4))
    local state = {
        slots = {},
        owned = owned,
    }
    for _, def in ipairs(MergeTowerSlots.all()) do
        local family, rawTier = installEntry(installs[def.id])
        local tier = 0
        if family then
            if rawTier > 0 then
                tier = math.clamp(rawTier, 1, cap)
            else
                tier = math.clamp(whole(owned[family], 1), 1, cap)
            end
        end
        state.slots[def.id] = {
            family = family,
            tier = tier,
        }
        state[def.aliasFamily] = family
        state[def.aliasTier] = tier
    end
    return state
end

function MergeTowerProgression.normalize(raw, maximumTier)
    raw = type(raw) == "table" and raw or {}
    local cap = math.max(1, whole(maximumTier, 4))
    local owned = {}
    local sourceOwned = type(raw.owned) == "table" and raw.owned
        or type(raw.tower_owned) == "table" and raw.tower_owned
        or {}
    for family, tier in pairs(sourceOwned) do
        local id = string.lower(tostring(family or ""))
        if FAMILY_SET[id] then
            owned[id] = math.clamp(whole(tier, 1), 1, cap)
        end
    end
    local nested = type(raw.slots) == "table" and raw.slots
        or type(raw.tower_slots) == "table" and raw.tower_slots
        or {}
    local installs = {}
    for _, def in ipairs(MergeTowerSlots.all()) do
        local rawFamily, rawTier = readRawFamily(raw, def, nested)
        local family = string.lower(tostring(rawFamily or ""))
        local tier = math.clamp(whole(rawTier, 0), 0, cap)
        if FAMILY_SET[family] and owned[family] == nil then
            owned[family] = math.clamp(math.max(tier, 1), 1, cap)
        end
        if FAMILY_SET[family] and owned[family] ~= nil then
            installs[def.id] = {
                family = family,
                tier = tier > 0 and tier or owned[family],
            }
        end
    end
    return decorateState(owned, installs, cap)
end

function MergeTowerProgression.slotFamily(state, slot)
    state = type(state) == "table" and state or {}
    slot = normalizeSlot(slot)
    local install = type(state.slots) == "table" and state.slots[slot] or nil
    if install then
        return install.family, install.tier or 0
    end
    local def = MergeTowerSlots.get(slot)
    if def then
        return state[def.aliasFamily], state[def.aliasTier] or 0
    end
    return nil, 0
end

function MergeTowerProgression.persistFields(state)
    state = MergeTowerProgression.normalize(state)
    local fields = {
        tower_owned = cloneOwned(state.owned),
        tower_slots = {},
    }
    for _, def in ipairs(MergeTowerSlots.all()) do
        local family, tier = MergeTowerProgression.slotFamily(state, def.id)
        fields[def.persistFamily] = family
        fields[def.persistTier] = tier
        fields.tower_slots[def.id] = {
            family = family,
            tier = tier,
        }
    end
    return fields
end

function MergeTowerProgression.ownedTier(state, family)
    state = type(state) == "table" and state or {}
    local id = string.lower(tostring(family or ""))
    return whole((type(state.owned) == "table" and state.owned or {})[id], 0)
end

-- Per-pad view for the workshop: owned families show as T1 (installable).
-- The family on this pad shows that pad's live tier.
function MergeTowerProgression.menuOwned(state, slot)
    state = MergeTowerProgression.normalize(state)
    local owned = {}
    for family in pairs(type(state.owned) == "table" and state.owned or {}) do
        owned[family] = 1
    end
    local family, tier = MergeTowerProgression.slotFamily(state, slot)
    if family then
        owned[family] = math.max(1, whole(tier, 1))
    end
    return owned
end

function MergeTowerProgression.signature(state)
    return snapshot(MergeTowerProgression.normalize(state))
end

function MergeTowerProgression.unlockWave(config)
    config = type(config) == "table" and config or {}
    if config.playtest_unlock_enabled == true then
        return math.max(1, whole(config.playtest_unlock_wave, 1))
    end
    return math.max(1, whole(config.unlock_wave, 10))
end

function MergeTowerProgression.isUnlocked(currentWave, config)
    local reachedWave = math.max(1, whole(currentWave, 0))
    return reachedWave >= MergeTowerProgression.unlockWave(config)
end

function MergeTowerProgression.actionCost(config, action, family, targetTier)
    config = type(config) == "table" and config or {}
    local id = string.lower(tostring(family or ""))
    assert(FAMILY_SET[id] == true, "Unknown cannon price family: " .. tostring(family))
    if tostring(action or "") == "unlock" then
        local costs = type(config.unlock_costs) == "table" and config.unlock_costs or {}
        local row = costs[id]
        assert(type(row) == "table", "Missing edge_towers.unlock_costs." .. id)
        assert(tonumber(row.amount) ~= nil, "Invalid edge_towers.unlock_costs." .. id .. ".amount")
        return {
            currency = tostring(row.currency or "gems"),
            amount = whole(row.amount, 1),
        }
    end

    local tier = whole(targetTier, 1)
    local costs = type(config.tier_costs) == "table" and config.tier_costs or {}
    local row = costs[id]
    assert(type(row) == "table", "Missing edge_towers.tier_costs." .. id)
    local amount = tonumber(row[tier])
    assert(amount ~= nil, string.format("Missing edge_towers.tier_costs.%s[%d]", id, tier))
    return {
        currency = tostring(config.currency or "hall_coins"),
        amount = whole(amount, 1),
    }
end

local function withInstalls(owned, installs, extra, cap)
    extra = type(extra) == "table" and extra or {}
    local state = decorateState(owned, installs, cap)
    for key, value in pairs(extra) do
        state[key] = value
    end
    return state
end

local function cloneInstalls(state)
    local installs = {}
    for _, slotId in ipairs(MergeTowerSlots.ids()) do
        local family, tier = MergeTowerProgression.slotFamily(state, slotId)
        if family then
            installs[slotId] = {
                family = family,
                tier = tier,
            }
        end
    end
    return installs
end

-- Test helper: grant unlock flags without placing a chassis. Playtest no
-- longer uses this; the workshop must show LOCKED until a real unlock.
function MergeTowerProgression.withCatalogOwned(raw, roles, starterTier, maximumTier)
    local cap = math.max(1, whole(maximumTier, 4))
    local state = MergeTowerProgression.normalize(raw, cap)
    local owned = cloneOwned(state.owned)
    local starter = math.clamp(whole(starterTier, 1), 1, cap)
    for _, role in ipairs(type(roles) == "table" and roles or {}) do
        local id = string.lower(tostring(role or ""))
        if FAMILY_SET[id] and owned[id] == nil then
            owned[id] = starter
        end
    end
    return decorateState(owned, cloneInstalls(state), cap)
end

-- Rebirth keeps unlock flags. Robux/game-pass grants are permanent
-- entitlements and must never be cleared here. Only placements empty.
function MergeTowerProgression.clearInstalls(raw, maximumTier)
    local cap = math.max(1, whole(maximumTier, 4))
    local state = MergeTowerProgression.normalize(raw, cap)
    return decorateState(cloneOwned(state.owned), {}, cap)
end

function MergeTowerProgression.apply(raw, action, family, currentWave, config, slot, rebirthRank)
    config = type(config) == "table" and config or {}
    local maximumTier = math.max(1, whole(config.maximum_tier, 4))
    local state = MergeTowerProgression.normalize(raw, maximumTier)
    if not MergeTowerProgression.isUnlocked(currentWave, config) then
        return nil, "cannon_locked"
    end
    slot = normalizeSlot(slot)
    if not MergeTowerProgression.isSlotUnlocked(slot, rebirthRank, config) then
        return nil, "cannon_slot_rebirth_locked"
    end

    if action == "select" then
        local requested = string.lower(tostring(family or ""))
        if not FAMILY_SET[requested] then
            return nil, "invalid_cannon_family"
        end
        if not MergeTowerProgression.canInstall(requested, slot) then
            return nil, "cannon_slot_forbidden"
        end
        local owned = cloneOwned(state.owned)
        if owned[requested] == nil then
            return nil, "cannon_not_owned"
        end
        local installs = cloneInstalls(state)
        local current = installs[slot] and installs[slot].family
        if requested == current then
            return nil, "cannon_already_selected"
        end
        installs[slot] = {
            family = requested,
            tier = 1,
        }
        return withInstalls(owned, installs, {
            operation = current and "replaced" or "installed",
            charged = true,
            slot = slot,
        }, maximumTier)
    end

    if action == "upgrade" then
        local currentFamily, currentTier = MergeTowerProgression.slotFamily(state, slot)
        local requested = string.lower(tostring(family or currentFamily or ""))
        if requested ~= currentFamily then
            return nil, "cannon_not_installed"
        end
        if not FAMILY_SET[requested] then
            return nil, "cannon_not_owned"
        end
        local owned = cloneOwned(state.owned)
        if owned[requested] == nil then
            return nil, "cannon_not_owned"
        end
        if currentTier >= maximumTier then
            return nil, "cannon_maxed"
        end
        local installs = cloneInstalls(state)
        local nextTier = currentTier + 1
        installs[slot] = {
            family = currentFamily,
            tier = nextTier,
        }
        return withInstalls(owned, installs, {
            upgradedFamily = requested,
            operation = "upgraded",
            charged = true,
            slot = slot,
        }, maximumTier)
    end

    if action == "unlock" then
        local requested = string.lower(tostring(family or ""))
        if not FAMILY_SET[requested] then
            return nil, "invalid_cannon_family"
        end
        local owned = cloneOwned(state.owned)
        if owned[requested] ~= nil then
            return nil, "cannon_already_unlocked"
        end
        owned[requested] = 1
        return withInstalls(owned, cloneInstalls(state), {
            operation = "unlocked",
            charged = true,
            slot = slot,
        }, maximumTier)
    end

    return nil, "invalid_cannon_action"
end

return MergeTowerProgression
