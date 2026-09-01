-- Pure progression policy for Merge Defense pad cannons. The server owns
-- payment and persistence; this module keeps unlock, role ownership, pad
-- install, and tier advancement deterministic. Buying a role keeps that
-- tier forever; switching onto a pad is free. Each pad is an independent
-- install slot with its own Artillery Commander.

local MergeTowerSlots = require(script.Parent.MergeTowerSlots)

local MergeTowerProgression = {}

local FAMILIES = {
    {
        id = "heal",
        name = "Heal Cannon",
        role = "Mend",
        description = "A support piece on the pad. Landing casts a Healing Field at the impact. Tiers are size-only until distinct meshes land.",
        previewAssetIds = {
            "139934426250291",
            "139934426250291",
            "139934426250291",
            "139934426250291",
        },
        upgradeNotes = {
            { "+ Starter Heal chassis", "+ Sits on this pad", "+ Lands a Healing Field" },
            { "+ Larger Heal chassis", "+ Same current-art mesh", "+ Same Healing Field" },
            { "+ Held at the playtest size", "+ Distinct art later", "+ Same Healing Field" },
            { "+ Top playtest rank", "+ Distinct art later", "+ Same Healing Field" },
        },
    },
    {
        id = "rage",
        name = "Rage Cannon",
        role = "Fury",
        description = "A fury piece on the pad. Shot effects stay visual this pass; the chassis and tier are what you are buying.",
        previewAssetIds = {
            "100102545353592",
            "100102545353592",
            "100102545353592",
            "100102545353592",
        },
        upgradeNotes = {
            { "+ Starter Rage chassis", "+ Sits on this pad", "+ Shots stay visual" },
            { "+ Larger Rage chassis", "+ Same current-art mesh", "+ Still visual shots" },
            { "+ Held at the playtest size", "+ Distinct art later", "+ Still visual shots" },
            { "+ Top playtest rank", "+ Distinct art later", "+ Still visual shots" },
        },
    },
    {
        id = "debuff",
        name = "Debuff Cannon",
        role = "Hex",
        description = "A hex piece on the pad. Shot effects stay visual this pass; the chassis and tier are what you are buying.",
        previewAssetIds = {
            "98058587937305",
            "98058587937305",
            "98058587937305",
            "98058587937305",
        },
        upgradeNotes = {
            { "+ Starter Debuff chassis", "+ Sits on this pad", "+ Shots stay visual" },
            { "+ Larger Debuff chassis", "+ Same current-art mesh", "+ Still visual shots" },
            { "+ Held at the playtest size", "+ Distinct art later", "+ Still visual shots" },
            { "+ Top playtest rank", "+ Distinct art later", "+ Still visual shots" },
        },
    },
    {
        id = "gravity",
        name = "Gravity Cannon",
        role = "Pull",
        description = "A pull piece on the pad. Shot effects stay visual this pass; the chassis and tier are what you are buying.",
        previewAssetIds = {
            "117227343235730",
            "117227343235730",
            "117227343235730",
            "117227343235730",
        },
        upgradeNotes = {
            { "+ Starter Gravity chassis", "+ Sits on this pad", "+ Shots stay visual" },
            { "+ Larger Gravity chassis", "+ Same current-art mesh", "+ Still visual shots" },
            { "+ Held at the playtest size", "+ Distinct art later", "+ Still visual shots" },
            { "+ Top playtest rank", "+ Distinct art later", "+ Still visual shots" },
        },
    },
    {
        id = "repulsor",
        name = "Repulsor Cannon",
        role = "Push",
        description = "The playtest starter. Knocks the look of a shove down the lane; shot damage is still later.",
        previewAssetIds = {
            "121632029834795",
            "121632029834795",
            "121632029834795",
            "121632029834795",
        },
        upgradeNotes = {
            { "+ Starter Repulsor chassis", "+ Sits on this pad", "+ Shots stay visual" },
            { "+ Larger Repulsor chassis", "+ Same current-art mesh", "+ Still visual shots" },
            { "+ Held at the playtest size", "+ Distinct art later", "+ Still visual shots" },
            { "+ Top playtest rank", "+ Distinct art later", "+ Still visual shots" },
        },
    },
    {
        id = "nullifier",
        name = "Nullifier Cannon",
        role = "Silence",
        description = "A silence piece on the pad. Shot effects stay visual this pass; the chassis and tier are what you are buying.",
        previewAssetIds = {
            "97270924486976",
            "97270924486976",
            "97270924486976",
            "97270924486976",
        },
        upgradeNotes = {
            { "+ Starter Nullifier chassis", "+ Sits on this pad", "+ Shots stay visual" },
            { "+ Larger Nullifier chassis", "+ Same current-art mesh", "+ Still visual shots" },
            { "+ Held at the playtest size", "+ Distinct art later", "+ Still visual shots" },
            { "+ Top playtest rank", "+ Distinct art later", "+ Still visual shots" },
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
MergeTowerProgression.slots = MergeTowerSlots

function MergeTowerProgression.families()
    local result = {}
    for index, family in ipairs(FAMILIES) do
        result[index] = table.clone(family)
        result[index].previewAssetIds = table.clone(family.previewAssetIds)
        result[index].upgradeNotes = {}
        for step, lines in ipairs(family.upgradeNotes) do
            result[index].upgradeNotes[step] = table.clone(lines)
        end
    end
    return result
end

function MergeTowerProgression.familiesForSlot(slot)
    slot = normalizeSlot(slot)
    local result = MergeTowerProgression.families()
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

local function decorateState(owned, installs)
    local state = {
        slots = {},
        owned = owned,
    }
    for _, def in ipairs(MergeTowerSlots.all()) do
        local family = installs[def.id]
        local tier = family and owned[family] or 0
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
        if FAMILY_SET[family] and owned[family] == nil then
            owned[family] = math.clamp(whole(rawTier, 1), 1, cap)
        end
        if FAMILY_SET[family] and owned[family] ~= nil then
            installs[def.id] = family
        end
    end
    return decorateState(owned, installs)
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

function MergeTowerProgression.actionCost(config)
    config = type(config) == "table" and config or {}
    return {
        currency = tostring(config.currency or "hall_coins"),
        amount = whole(config.action_cost, 1),
    }
end

local function withInstalls(owned, installs, extra)
    extra = type(extra) == "table" and extra or {}
    local state = decorateState(owned, installs)
    for key, value in pairs(extra) do
        state[key] = value
    end
    return state
end

local function cloneInstalls(state)
    local installs = {}
    for _, slotId in ipairs(MergeTowerSlots.ids()) do
        local family = MergeTowerProgression.slotFamily(state, slotId)
        installs[slotId] = family
    end
    return installs
end

-- Visual-pass helper: own every listed role at starter tier so Install does
-- not require a Buy. Does not place a chassis on a pad.
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
    return decorateState(owned, cloneInstalls(state))
end

function MergeTowerProgression.apply(raw, action, family, currentWave, config, slot)
    config = type(config) == "table" and config or {}
    local maximumTier = math.max(1, whole(config.maximum_tier, 4))
    local state = MergeTowerProgression.normalize(raw, maximumTier)
    if not MergeTowerProgression.isUnlocked(currentWave, config) then
        return nil, "cannon_locked"
    end
    slot = normalizeSlot(slot)

    if action == "select" then
        local requested = string.lower(tostring(family or ""))
        if not FAMILY_SET[requested] then
            return nil, "invalid_cannon_family"
        end
        if not MergeTowerProgression.canInstall(requested, slot) then
            return nil, "cannon_slot_forbidden"
        end
        local owned = cloneOwned(state.owned)
        local installs = cloneInstalls(state)
        local current = installs[slot]
        if owned[requested] == nil then
            owned[requested] = 1
            installs[slot] = requested
            return withInstalls(owned, installs, {
                operation = "installed",
                charged = true,
                slot = slot,
            })
        end
        if requested == current then
            return nil, "cannon_already_selected"
        end
        installs[slot] = requested
        return withInstalls(owned, installs, {
            operation = "equipped",
            charged = false,
            slot = slot,
        })
    end

    if action == "upgrade" then
        local fallback = MergeTowerProgression.slotFamily(state, slot)
        if not fallback then
            for _, slotId in ipairs(MergeTowerSlots.ids()) do
                fallback = MergeTowerProgression.slotFamily(state, slotId)
                if fallback then
                    break
                end
            end
        end
        local requested = string.lower(tostring(family or fallback or ""))
        if not FAMILY_SET[requested] then
            return nil, "cannon_not_owned"
        end
        local owned = cloneOwned(state.owned)
        if owned[requested] == nil then
            return nil, "cannon_not_owned"
        end
        if owned[requested] >= maximumTier then
            return nil, "cannon_maxed"
        end
        owned[requested] = owned[requested] + 1
        return withInstalls(owned, cloneInstalls(state), {
            upgradedFamily = requested,
            operation = "upgraded",
            charged = true,
            slot = slot,
        })
    end

    return nil, "invalid_cannon_action"
end

return MergeTowerProgression
