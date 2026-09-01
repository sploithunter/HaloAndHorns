-- Pure progression policy for the Merge Defense bulwarks. The server owns payment and
-- persistence; this module keeps unlock, family ownership, slot install, and tier advancement
-- deterministic. Buying a family keeps that tier forever; switching onto a slot is free.
-- Lane = gold BulwarkLine. Egg = red BreachLine. Wardstone is egg-only.

local MergeBulwarkSlots = require(script.Parent.MergeBulwarkSlots)

local MergeBulwarkProgression = {}

local FAMILIES = {
    {
        id = "impaler_palisade",
        name = "Impaler Palisade",
        role = "Stop",
        description = "Stakes the strip. Marchers that hit the line get shoved back toward the gate. No damage — after enough hits they walk through.",
        previewAssetIds = {
            "116860085128235",
            "97859864666503",
            "129822630921173",
            "74198495305059",
        },
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
        previewAssetIds = {
            "113357672010171",
            "105913949349922",
            "72955017349938",
            "90245489274928",
        },
        upgradeNotes = {
            { "+ Razor wire on the strip", "+ Bleed and slow on the wire", "+ Stops when they leave" },
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
        previewAssetIds = {
            "113908496978867",
            "88409379844802",
            "111766652323283",
            "108251207551720",
        },
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
        previewAssetIds = {
            "121529052464390",
            "77664713466251",
            "72827689088718",
            "112838270832676",
        },
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
        previewAssetIds = {
            "85025651891171",
            "80372327819409",
            "90028794177150",
            "87259173917660",
        },
        upgradeNotes = {
            { "+ Thorn hedge on the strip", "+ Roots the front of the wave", "+ Then they break through" },
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
        previewAssetIds = {
            "135466894164464",
            "115291422790551",
            "138858336514150",
            "100267714245380",
        },
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

function MergeBulwarkProgression.families()
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

function MergeBulwarkProgression.familiesForSlot(slot)
    slot = normalizeSlot(slot)
    local result = MergeBulwarkProgression.families()
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

-- Impaler Palisade is a stop wall, not a damage trap. Each marcher gets a small shove budget,
-- then walks through. Five bounces on Tier 1 would farm-lock the wave; T1 is one bounce.
local STOP_SHOVE = {
    charges = { 1, 2, 3, 4 },
    shove_studs = { 16, 20, 24, 28 },
    root_seconds = { 0.4, 0.45, 0.55, 0.7 },
    -- T3 coats the bounce with a permanent DoT. T4 adds contagion hops; those stay on too.
    -- Wave fights end, so a lasting burn does not leak into later content.
    venom_damage = { 0, 0, 12, 18 },
    venom_period = { 1, 1, 0.7, 0.55 },
    venom_permanent = { false, false, true, true },
    contagion_radius = { 0, 0, 0, 12 },
    contagion_interval = { 1, 1, 1, 1.0 },
    contagion_hops = { 0, 0, 0, 4 },
}

-- Concertina Line is a lane DoT plus a graded slow. T1 only while on the wire; later tiers
-- linger after they walk off. T4 stacks and does not wear off for the rest of the wave.
local BLEED_SLOW = {
    bleed_damage = { 8, 14, 20, 16 },
    bleed_period = { 0.9, 0.75, 0.55, 0.4 },
    slow_factor = { 0.8, 0.7, 0.58, 0.45 },
    linger_seconds = { 0, 1.5, 3.5, 0 },
    bleed_permanent = { false, false, false, true },
    bleed_stacks = { false, false, false, true },
    stack_cap = { 1, 1, 1, 4 },
    strip_depth_studs = { 8, 8, 10, 12 },
}

-- Land Sharks leave the patrol to bite and drag a marcher under. Damage is pet-like ticks,
-- not a lane DoT: one shark, one target. Periods are 2x the original cadence so DPS doubles.
local HUNT_DRAG = {
    shark_count = { 4, 5, 6, 7 },
    bite_damage = { 36, 90, 130, 190 },
    bite_period = { 0.575, 0.25, 0.21, 0.175 },
    hunt_range_studs = { 16, 18, 20, 22 },
    grab_range_studs = { 7, 7, 8, 8 },
    sink_studs = { 8, 9, 10, 12 },
    -- T3 venom is a proximity aura, not a second bite. One cloud per marcher so a pack
    -- swimming past does not stack per-shark ticks. T4 prefers an unclaimed boss, then trash.
    venom_damage = { 0, 0, 10, 14 },
    venom_period = { 0.5, 0.5, 0.35, 0.275 },
    venom_range_studs = { 0, 0, 8, 9 },
    prefer_bosses = { false, false, false, true },
}

-- Saw Blade is the shred line: high raw damage, no control, on the blades only. Ticks stay
-- faster than Concertina so a marcher crossing the six-stud deck actually gets chewed.
local SHRED_LINE = {
    shred_damage = { 16, 24, 30, 42 },
    shred_period = { 0.16, 0.13, 0.10, 0.08 },
    strip_depth_studs = { 6, 6, 6, 6 },
    chunk_count = { 6, 7, 8, 10 },
}

-- Grasping Hedge roots the front of the wave (feet stuck, hands free) and slows the pile.
-- The root is timed and not refreshed, so they can walk off. Leaving and walking back in
-- is a new grab — not a lifetime counter.
local GRAB_ROOT = {
    grab_count = { 1, 2, 3, 4 },
    root_seconds = { 0.9, 1.2, 1.6, 2.2 },
    slow_factor = { 0.7, 0.6, 0.5, 0.42 },
    slow_seconds = { 0.8, 1.1, 1.6, 2.0 },
    venom_damage = { 0, 0, 10, 14 },
    venom_period = { 1, 1, 0.7, 0.55 },
    venom_duration = { 0, 0, 4, 5 },
    strip_depth_studs = { 8, 8, 8, 10 },
    -- Must travel this far past the strip on the march axis before a new grab.
    -- Lateral shuffle and a one-stud flicker do not count as leaving.
    exit_buffer_studs = { 6, 6, 6, 6 },
}

local function tierPick(source, defaults, tier)
    local list = type(source) == "table" and source or defaults
    local value = list[tier]
    if value == nil then
        value = defaults[tier]
    end
    return value
end

function MergeBulwarkProgression.combatEffect(family, tier, config)
    local id = string.lower(tostring(family or ""))
    config = type(config) == "table" and config or {}
    local combat = type(config.combat) == "table" and config.combat[id] or {}
    local step = math.clamp(whole(tier, 1), 1, 4)
    if id == "impaler_palisade" then
        return {
            kind = "stop_shove",
            charges = math.max(1, whole(tierPick(combat.charges, STOP_SHOVE.charges, step), 1)),
            shoveStuds = math.max(
                4,
                tonumber(tierPick(combat.shove_studs, STOP_SHOVE.shove_studs, step)) or 16
            ),
            rootSeconds = math.max(
                0,
                tonumber(tierPick(combat.root_seconds, STOP_SHOVE.root_seconds, step)) or 0.4
            ),
            venomDamage = math.max(
                0,
                whole(tierPick(combat.venom_damage, STOP_SHOVE.venom_damage, step), 0)
            ),
            venomPeriod = math.max(
                0.35,
                tonumber(tierPick(combat.venom_period, STOP_SHOVE.venom_period, step)) or 0.7
            ),
            venomPermanent = tierPick(
                combat.venom_permanent,
                STOP_SHOVE.venom_permanent,
                step
            ) == true,
            contagionRadius = math.max(
                0,
                tonumber(tierPick(combat.contagion_radius, STOP_SHOVE.contagion_radius, step))
                    or 0
            ),
            contagionInterval = math.max(
                0.2,
                tonumber(tierPick(combat.contagion_interval, STOP_SHOVE.contagion_interval, step))
                    or 1.2
            ),
            contagionHops = math.max(
                0,
                whole(tierPick(combat.contagion_hops, STOP_SHOVE.contagion_hops, step), 0)
            ),
        }
    end
    if id == "concertina_line" then
        return {
            kind = "bleed_slow",
            bleedDamage = math.max(
                1,
                whole(tierPick(combat.bleed_damage, BLEED_SLOW.bleed_damage, step), 1)
            ),
            bleedPeriod = math.max(
                0.25,
                tonumber(tierPick(combat.bleed_period, BLEED_SLOW.bleed_period, step)) or 0.9
            ),
            slowFactor = math.clamp(
                tonumber(tierPick(combat.slow_factor, BLEED_SLOW.slow_factor, step)) or 0.8,
                0.2,
                1
            ),
            lingerSeconds = math.max(
                0,
                tonumber(tierPick(combat.linger_seconds, BLEED_SLOW.linger_seconds, step)) or 0
            ),
            bleedPermanent = tierPick(
                combat.bleed_permanent,
                BLEED_SLOW.bleed_permanent,
                step
            ) == true,
            bleedStacks = tierPick(combat.bleed_stacks, BLEED_SLOW.bleed_stacks, step) == true,
            stackCap = math.max(
                1,
                whole(tierPick(combat.stack_cap, BLEED_SLOW.stack_cap, step), 1)
            ),
            stripDepthStuds = math.max(
                4,
                tonumber(tierPick(combat.strip_depth_studs, BLEED_SLOW.strip_depth_studs, step))
                    or 8
            ),
        }
    end
    if id == "land_shark" then
        return {
            kind = "hunt_drag",
            sharkCount = math.clamp(
                whole(tierPick(combat.shark_count, HUNT_DRAG.shark_count, step), 4),
                1,
                10
            ),
            biteDamage = math.max(
                1,
                whole(tierPick(combat.bite_damage, HUNT_DRAG.bite_damage, step), 1)
            ),
            bitePeriod = math.max(
                0.15,
                tonumber(tierPick(combat.bite_period, HUNT_DRAG.bite_period, step)) or 0.575
            ),
            huntRangeStuds = math.max(
                8,
                tonumber(tierPick(combat.hunt_range_studs, HUNT_DRAG.hunt_range_studs, step)) or 16
            ),
            grabRangeStuds = math.max(
                4,
                tonumber(tierPick(combat.grab_range_studs, HUNT_DRAG.grab_range_studs, step)) or 7
            ),
            sinkStuds = math.max(
                4,
                tonumber(tierPick(combat.sink_studs, HUNT_DRAG.sink_studs, step)) or 8
            ),
            venomDamage = math.max(
                0,
                whole(tierPick(combat.venom_damage, HUNT_DRAG.venom_damage, step), 0)
            ),
            venomPeriod = math.max(
                0.15,
                tonumber(tierPick(combat.venom_period, HUNT_DRAG.venom_period, step)) or 0.5
            ),
            venomRangeStuds = math.max(
                0,
                tonumber(tierPick(combat.venom_range_studs, HUNT_DRAG.venom_range_studs, step))
                    or 0
            ),
            preferBosses = tierPick(combat.prefer_bosses, HUNT_DRAG.prefer_bosses, step) == true,
        }
    end
    if id == "saw_blade" then
        return {
            kind = "shred_line",
            shredDamage = math.max(
                1,
                whole(tierPick(combat.shred_damage, SHRED_LINE.shred_damage, step), 1)
            ),
            shredPeriod = math.max(
                0.06,
                tonumber(tierPick(combat.shred_period, SHRED_LINE.shred_period, step)) or 0.16
            ),
            stripDepthStuds = math.max(
                4,
                tonumber(tierPick(combat.strip_depth_studs, SHRED_LINE.strip_depth_studs, step))
                    or 6
            ),
            chunkCount = math.clamp(
                whole(tierPick(combat.chunk_count, SHRED_LINE.chunk_count, step), 6),
                4,
                14
            ),
        }
    end
    if id == "grasping_hedge" then
        return {
            kind = "grab_root",
            grabCount = math.max(
                1,
                whole(tierPick(combat.grab_count, GRAB_ROOT.grab_count, step), 1)
            ),
            rootSeconds = math.max(
                0.25,
                tonumber(tierPick(combat.root_seconds, GRAB_ROOT.root_seconds, step)) or 0.9
            ),
            slowFactor = math.clamp(
                tonumber(tierPick(combat.slow_factor, GRAB_ROOT.slow_factor, step)) or 0.7,
                0.2,
                1
            ),
            slowSeconds = math.max(
                0.25,
                tonumber(tierPick(combat.slow_seconds, GRAB_ROOT.slow_seconds, step)) or 0.8
            ),
            venomDamage = math.max(
                0,
                whole(tierPick(combat.venom_damage, GRAB_ROOT.venom_damage, step), 0)
            ),
            venomPeriod = math.max(
                0.35,
                tonumber(tierPick(combat.venom_period, GRAB_ROOT.venom_period, step)) or 0.7
            ),
            venomDuration = math.max(
                0,
                tonumber(tierPick(combat.venom_duration, GRAB_ROOT.venom_duration, step)) or 0
            ),
            stripDepthStuds = math.max(
                4,
                tonumber(tierPick(combat.strip_depth_studs, GRAB_ROOT.strip_depth_studs, step))
                    or 8
            ),
            exitBufferStuds = math.max(
                2,
                tonumber(tierPick(combat.exit_buffer_studs, GRAB_ROOT.exit_buffer_studs, step))
                    or 6
            ),
        }
    end
    return nil
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
