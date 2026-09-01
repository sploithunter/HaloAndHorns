-- Pure progression policy for the Merge Defense bulwarks. The server owns payment and
-- persistence; this module keeps unlock, family ownership, slot install, and tier advancement
-- deterministic. Buying a family keeps that tier forever; switching onto a slot is free.
-- Lane = gold BulwarkLine. Egg = red BreachLine. Wardstone is egg-only.

local MergeBulwarkSlots = require(script.Parent.MergeBulwarkSlots)
local MergeTierArt = require(script.Parent.MergeTierArt)

local MergeBulwarkProgression = {}

local FAMILIES = {
    {
        id = "impaler_palisade",
        name = "Impaler Palisade",
        role = "Stop",
        description = "Stakes the strip. Marchers that hit the line get shoved back toward the gate. No damage — after enough hits they walk through.",
        upgradeNotes = {
            {
                "+ Timber stakes on the strip",
                "+ Shove back toward the gate",
                "+ One bounce, then they breach",
            },
            { "+ Iron-capped stakes", "+ Harder shove", "+ Two bounces before they breach" },
            { "+ Venom-coated tips", "+ Permanent venom", "+ Three bounces before they breach" },
            { "+ Soulforged pylons", "+ Permanent plague", "+ Four bounces before they breach" },
        },
    },
    {
        id = "concertina_line",
        name = "Concertina Line",
        role = "Bleed",
        description = "Razor wire across the lane. Marchers on the strip bleed and slow. Higher tiers linger after they leave; the top rank stacks and does not wear off.",
        upgradeNotes = {
            {
                "+ Razor wire on the strip",
                "+ Bleed and slow on the wire",
                "+ Stops when they leave",
            },
            { "+ Steel razor coils", "+ Heavier bleed", "+ Short linger" },
            { "+ Electrified wire", "+ Faster tick", "+ Longer linger" },
            { "+ Plasma coils", "+ Bleed stacks", "+ Permanent linger" },
        },
    },
    {
        id = "land_shark",
        name = "Land Sharks",
        role = "Hunt",
        description = "Sharks leave the strip to chase a marcher, bite it, and drag it under. When it dies, it sinks.",
        upgradeNotes = {
            {
                "+ Four sharks on the strip",
                "+ Bite and drag under",
                "+ Dead marchers sink",
            },
            { "+ Five sharks", "+ Ironjaw bite", "+ Faster cadence" },
            { "+ Six sharks", "+ Venom near the shark", "+ Keeps the hunt" },
            { "+ Seven sharks", "+ Heavier bite", "+ Prefers bosses first" },
        },
    },
    {
        id = "saw_blade",
        name = "Saw Blades",
        role = "Shred",
        description = "Spinning blades chew anything on the line. Highest raw damage, no control.",
        upgradeNotes = {
            {
                "+ One saw on the line",
                "+ Rapid chew, no control",
                "+ Chips spray off the target",
            },
            { "+ Twin hardened blades", "+ Higher shred", "+ More chips" },
            { "+ Triple heated saws", "+ Faster chew", "+ Hotter cut" },
            { "+ Quad void blades", "+ Fastest shred", "+ Most chips" },
        },
    },
    {
        id = "grasping_hedge",
        name = "Grasping Hedge",
        role = "Hold",
        description = "Thorns root the front of the wave and slow the pile so your pets can finish it. Hands stay free. The root wears off so they can break through; walking back in roots them again.",
        upgradeNotes = {
            {
                "+ Thorn hedge on the strip",
                "+ Roots the front of the wave",
                "+ Then they break through",
            },
            { "+ Ironwood roots", "+ Longer root", "+ Two at the front" },
            { "+ Venom briar", "+ Poisoned grab", "+ Longer slow" },
            { "+ Worldroot wall", "+ Roots more of the wave", "+ Still wears off" },
        },
    },
    {
        id = "wardstone_barrier",
        name = "Wardstone Barrier",
        role = "Ward",
        description = "Wards the hatcher eggs, not the lane. Cuts damage that gets past the fight and hits an installed egg.",
        upgradeNotes = {
            { "+ Two ward stones", "+ Cuts hatcher-egg damage", "+ Not a lane trap" },
            { "+ Fortified obelisks", "+ Stronger ward", "+ Crystal cores" },
            { "+ Polarity pylons", "+ Broader egg cover", "+ Faster absorb" },
            { "+ Null wall", "+ Deepest ward", "+ Soul lattice" },
        },
    },
}

local FAMILY_SET = {}
for _, family in ipairs(FAMILIES) do
    FAMILY_SET[family.id] = true
end

local function normalizeSlot(slot)
    return MergeBulwarkSlots.normalizeId(slot)
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
    for _, slotId in ipairs(MergeBulwarkSlots.ids()) do
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

MergeBulwarkProgression.SLOT_LANE = "lane"
MergeBulwarkProgression.SLOT_EGG = "egg"
MergeBulwarkProgression.slots = MergeBulwarkSlots

function MergeBulwarkProgression.families(tierArt)
    local result = {}
    for index, family in ipairs(FAMILIES) do
        result[index] = table.clone(family)
        result[index].previewAssetIds = MergeTierArt.previewAssetIds(tierArt, "bulwark", family.id)
        result[index].upgradeNotes = {}
        for step, lines in ipairs(family.upgradeNotes) do
            result[index].upgradeNotes[step] = table.clone(lines)
        end
    end
    return result
end

function MergeBulwarkProgression.familiesForSlot(slot, tierArt)
    slot = normalizeSlot(slot)
    local result = MergeBulwarkProgression.families(tierArt)
    for _, family in ipairs(result) do
        family.canInstall = MergeBulwarkProgression.canInstall(family.id, slot)
        family.slotFor = MergeBulwarkProgression.slotForFamily(family.id)
        family.installHint = MergeBulwarkSlots.restrictedHint(family.id, slot)
    end
    return result
end

function MergeBulwarkProgression.isFamily(family)
    return FAMILY_SET[string.lower(tostring(family or ""))] == true
end

function MergeBulwarkProgression.normalizeSlot(slot)
    return normalizeSlot(slot)
end

function MergeBulwarkProgression.slotForFamily(family)
    local id = string.lower(tostring(family or ""))
    if not FAMILY_SET[id] then
        return nil
    end
    local only = MergeBulwarkSlots.allowedSlotsForFamily(id)
    if only == nil then
        return "any"
    end
    if #only == 1 then
        return only[1]
    end
    return only
end

function MergeBulwarkProgression.canInstall(family, slot)
    local id = string.lower(tostring(family or ""))
    if not FAMILY_SET[id] then
        return false
    end
    return MergeBulwarkSlots.canInstall(id, slot)
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
    for _, def in ipairs(MergeBulwarkSlots.all()) do
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

function MergeBulwarkProgression.normalize(raw, maximumTier)
    raw = type(raw) == "table" and raw or {}
    local cap = math.max(1, whole(maximumTier, 4))
    local owned = {}
    local sourceOwned = type(raw.owned) == "table" and raw.owned
        or type(raw.bulwark_owned) == "table" and raw.bulwark_owned
        or {}
    for family, tier in pairs(sourceOwned) do
        local id = string.lower(tostring(family or ""))
        if FAMILY_SET[id] then
            owned[id] = math.clamp(whole(tier, 1), 1, cap)
        end
    end
    local nested = type(raw.slots) == "table" and raw.slots
        or type(raw.bulwark_slots) == "table" and raw.bulwark_slots
        or {}
    local installs = {}
    for _, def in ipairs(MergeBulwarkSlots.all()) do
        local rawFamily, rawTier = readRawFamily(raw, def, nested)
        local family = string.lower(tostring(rawFamily or ""))
        if FAMILY_SET[family] and owned[family] == nil then
            owned[family] = math.clamp(whole(rawTier, 1), 1, cap)
        end
        if FAMILY_SET[family] and owned[family] ~= nil then
            installs[def.id] = family
        end
    end
    -- Legacy saves could put Wardstone on the gold line. Move it to the first
    -- slot that still accepts it.
    for _, def in ipairs(MergeBulwarkSlots.all()) do
        local family = installs[def.id]
        if family and not MergeBulwarkProgression.canInstall(family, def.id) then
            installs[def.id] = nil
            for _, other in ipairs(MergeBulwarkSlots.all()) do
                if
                    installs[other.id] == nil
                    and MergeBulwarkProgression.canInstall(family, other.id)
                then
                    installs[other.id] = family
                    break
                end
            end
        end
    end
    return decorateState(owned, installs)
end

function MergeBulwarkProgression.slotFamily(state, slot)
    state = type(state) == "table" and state or {}
    slot = normalizeSlot(slot)
    local install = type(state.slots) == "table" and state.slots[slot] or nil
    if install then
        return install.family, install.tier or 0
    end
    local def = MergeBulwarkSlots.get(slot)
    if def then
        return state[def.aliasFamily], state[def.aliasTier] or 0
    end
    return nil, 0
end

function MergeBulwarkProgression.persistFields(state)
    state = MergeBulwarkProgression.normalize(state)
    local fields = {
        bulwark_owned = cloneOwned(state.owned),
        bulwark_slots = {},
    }
    for _, def in ipairs(MergeBulwarkSlots.all()) do
        local family, tier = MergeBulwarkProgression.slotFamily(state, def.id)
        fields[def.persistFamily] = family
        fields[def.persistTier] = tier
        fields.bulwark_slots[def.id] = {
            family = family,
            tier = tier,
        }
    end
    return fields
end

function MergeBulwarkProgression.ownedTier(state, family)
    state = type(state) == "table" and state or {}
    local id = string.lower(tostring(family or ""))
    return whole((type(state.owned) == "table" and state.owned or {})[id], 0)
end

function MergeBulwarkProgression.signature(state)
    return snapshot(MergeBulwarkProgression.normalize(state))
end

function MergeBulwarkProgression.unlockWave(config)
    config = type(config) == "table" and config or {}
    if config.playtest_unlock_enabled == true then
        return math.max(1, whole(config.playtest_unlock_wave, 1))
    end
    return math.max(1, whole(config.unlock_wave, 20))
end

function MergeBulwarkProgression.isUnlocked(currentWave, config)
    -- Before combat starts the pending wave is Wave 1, so the Wave-1 playtest override is usable
    -- immediately. Later unlocks become available during the intermission leading into that wave.
    local reachedWave = math.max(1, whole(currentWave, 0))
    return reachedWave >= MergeBulwarkProgression.unlockWave(config)
end

function MergeBulwarkProgression.actionCost(config)
    config = type(config) == "table" and config or {}
    return {
        currency = tostring(config.currency or "hall_coins"),
        amount = whole(config.action_cost, 1),
    }
end

local function tierValue(combat, family, key, tier)
    local list = type(combat) == "table" and combat[key] or nil
    local value = nil
    if type(list) == "table" then
        value = list[tier]
    end
    assert(value ~= nil, string.format("Missing edge_bulwarks.combat.%s.%s[%d]", family, key, tier))
    return value
end

local function tierNumber(combat, family, key, tier)
    local value = tonumber(tierValue(combat, family, key, tier))
    assert(value ~= nil, string.format("Invalid edge_bulwarks.combat.%s.%s[%d]", family, key, tier))
    return value
end

local function tierWhole(combat, family, key, tier)
    return math.floor(tierNumber(combat, family, key, tier))
end

function MergeBulwarkProgression.combatEffect(family, tier, config)
    local id = string.lower(tostring(family or ""))
    config = type(config) == "table" and config or {}
    local combat = type(config.combat) == "table" and config.combat[id] or {}
    local step = math.clamp(whole(tier, 1), 1, 4)
    if id == "impaler_palisade" then
        return {
            kind = "stop_shove",
            charges = tierWhole(combat, id, "charges", step),
            shoveStuds = tierNumber(combat, id, "shove_studs", step),
            rootSeconds = tierNumber(combat, id, "root_seconds", step),
            venomDamage = tierWhole(combat, id, "venom_damage", step),
            venomPeriod = tierNumber(combat, id, "venom_period", step),
            venomPermanent = tierValue(combat, id, "venom_permanent", step) == true,
            contagionRadius = tierNumber(combat, id, "contagion_radius", step),
            contagionInterval = tierNumber(combat, id, "contagion_interval", step),
            contagionHops = tierWhole(combat, id, "contagion_hops", step),
        }
    end
    if id == "concertina_line" then
        return {
            kind = "bleed_slow",
            bleedDamage = tierWhole(combat, id, "bleed_damage", step),
            bleedPeriod = tierNumber(combat, id, "bleed_period", step),
            slowFactor = tierNumber(combat, id, "slow_factor", step),
            lingerSeconds = tierNumber(combat, id, "linger_seconds", step),
            bleedPermanent = tierValue(combat, id, "bleed_permanent", step) == true,
            bleedStacks = tierValue(combat, id, "bleed_stacks", step) == true,
            stackCap = tierWhole(combat, id, "stack_cap", step),
            stripDepthStuds = tierNumber(combat, id, "strip_depth_studs", step),
        }
    end
    if id == "land_shark" then
        return {
            kind = "hunt_drag",
            sharkCount = tierWhole(combat, id, "shark_count", step),
            biteDamage = tierWhole(combat, id, "bite_damage", step),
            bitePeriod = tierNumber(combat, id, "bite_period", step),
            huntRangeStuds = tierNumber(combat, id, "hunt_range_studs", step),
            grabRangeStuds = tierNumber(combat, id, "grab_range_studs", step),
            sinkStuds = tierNumber(combat, id, "sink_studs", step),
            venomDamage = tierWhole(combat, id, "venom_damage", step),
            venomPeriod = tierNumber(combat, id, "venom_period", step),
            venomRangeStuds = tierNumber(combat, id, "venom_range_studs", step),
            preferBosses = tierValue(combat, id, "prefer_bosses", step) == true,
        }
    end
    if id == "saw_blade" then
        return {
            kind = "shred_line",
            shredDamage = tierWhole(combat, id, "shred_damage", step),
            shredPeriod = tierNumber(combat, id, "shred_period", step),
            stripDepthStuds = tierNumber(combat, id, "strip_depth_studs", step),
            chunkCount = tierWhole(combat, id, "chunk_count", step),
        }
    end
    if id == "grasping_hedge" then
        return {
            kind = "grab_root",
            grabCount = tierWhole(combat, id, "grab_count", step),
            rootSeconds = tierNumber(combat, id, "root_seconds", step),
            slowFactor = tierNumber(combat, id, "slow_factor", step),
            slowSeconds = tierNumber(combat, id, "slow_seconds", step),
            venomDamage = tierWhole(combat, id, "venom_damage", step),
            venomPeriod = tierNumber(combat, id, "venom_period", step),
            venomDuration = tierNumber(combat, id, "venom_duration", step),
            stripDepthStuds = tierNumber(combat, id, "strip_depth_studs", step),
            exitBufferStuds = tierNumber(combat, id, "exit_buffer_studs", step),
        }
    end
    return nil
end

local POWER_FIELDS = { "venomDamage", "bleedDamage", "biteDamage", "shredDamage" }
local RADIUS_FIELDS = {
    "contagionRadius",
    "stripDepthStuds",
    "huntRangeStuds",
    "grabRangeStuds",
    "venomRangeStuds",
    "exitBufferStuds",
}
local CADENCE_FIELDS = {
    "venomPeriod",
    "contagionInterval",
    "bleedPeriod",
    "bitePeriod",
    "shredPeriod",
}
local DURATION_FIELDS = { "rootSeconds", "lingerSeconds", "slowSeconds", "venomDuration" }
local CAPACITY_FIELDS = {
    "charges",
    "contagionHops",
    "stackCap",
    "sharkCount",
    "chunkCount",
    "grabCount",
}
local CONTROL_FIELDS = { "shoveStuds", "sinkStuds" }

local function scaleFields(result, keys, multiplier, inverse, wholeNumbers)
    multiplier = tonumber(multiplier) or 1
    multiplier = inverse and math.max(0.001, multiplier) or math.max(0, multiplier)
    for _, key in ipairs(keys) do
        local value = tonumber(result[key])
        if value ~= nil then
            local scaled = inverse and value / multiplier or value * multiplier
            result[key] = wholeNumbers and math.max(0, math.floor(scaled + 0.5)) or scaled
        end
    end
end

-- Apply rebirth axes after tier tuning. Every numeric combat output belongs to an explicit axis;
-- callers can grow damage without accidentally widening fields or accelerating control loops.
function MergeBulwarkProgression.scaleCombatEffect(effect, multipliers)
    if type(effect) ~= "table" then
        return effect
    end
    multipliers = type(multipliers) == "table" and multipliers or {}
    local result = table.clone(effect)
    scaleFields(result, POWER_FIELDS, multipliers.power, false, false)
    scaleFields(result, RADIUS_FIELDS, multipliers.radius, false, false)
    scaleFields(result, CADENCE_FIELDS, multipliers.cadence, true, false)
    scaleFields(result, DURATION_FIELDS, multipliers.duration, false, false)
    scaleFields(result, CAPACITY_FIELDS, multipliers.capacity, false, true)
    scaleFields(result, CONTROL_FIELDS, multipliers.control, false, false)
    if tonumber(result.slowFactor) ~= nil then
        local control = math.max(0, tonumber(multipliers.control) or 1)
        result.slowFactor = math.clamp(1 - (1 - result.slowFactor) * control, 0, 1)
    end
    return result
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
    for _, slotId in ipairs(MergeBulwarkSlots.ids()) do
        local family = MergeBulwarkProgression.slotFamily(state, slotId)
        installs[slotId] = family
    end
    return installs
end

function MergeBulwarkProgression.apply(raw, action, family, currentWave, config, slot)
    config = type(config) == "table" and config or {}
    local maximumTier = math.max(1, whole(config.maximum_tier, 4))
    local state = MergeBulwarkProgression.normalize(raw, maximumTier)
    if not MergeBulwarkProgression.isUnlocked(currentWave, config) then
        return nil, "bulwark_locked"
    end
    slot = normalizeSlot(slot)

    if action == "select" then
        local requested = string.lower(tostring(family or ""))
        if not FAMILY_SET[requested] then
            return nil, "invalid_bulwark_family"
        end
        if not MergeBulwarkProgression.canInstall(requested, slot) then
            return nil, "bulwark_slot_forbidden"
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
            return nil, "bulwark_already_selected"
        end
        installs[slot] = requested
        return withInstalls(owned, installs, {
            operation = "equipped",
            charged = false,
            slot = slot,
        })
    end

    if action == "upgrade" then
        local fallback = MergeBulwarkProgression.slotFamily(state, slot)
        if not fallback then
            for _, slotId in ipairs(MergeBulwarkSlots.ids()) do
                fallback = MergeBulwarkProgression.slotFamily(state, slotId)
                if fallback then
                    break
                end
            end
        end
        local requested = string.lower(tostring(family or fallback or ""))
        if not FAMILY_SET[requested] then
            return nil, "bulwark_not_owned"
        end
        local owned = cloneOwned(state.owned)
        if owned[requested] == nil then
            return nil, "bulwark_not_owned"
        end
        if owned[requested] >= maximumTier then
            return nil, "bulwark_maxed"
        end
        owned[requested] = owned[requested] + 1
        return withInstalls(owned, cloneInstalls(state), {
            upgradedFamily = requested,
            operation = "upgraded",
            charged = true,
            slot = slot,
        })
    end

    return nil, "invalid_bulwark_action"
end

return MergeBulwarkProgression
