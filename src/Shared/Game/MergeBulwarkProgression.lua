-- Pure progression policy for the Merge Defense bulwark strip. The server owns payment and
-- persistence; this module keeps unlock, family ownership, strip install, and tier advancement
-- deterministic. Buying a family keeps that tier forever; switching onto the strip is free.

local MergeBulwarkProgression = {}

local FAMILIES = {
    {
        id = "impaler_palisade",
        name = "Impaler Palisade",
        role = "Stop",
        description = "Stakes the strip. Marchers that hit the line take a burst and get shoved back toward the gate.",
        previewAssetIds = {
            "129803988118337",
            "98392384350392",
            "102201870134911",
            "125827629437462",
        },
        upgradeNotes = {
            { "+ Timber stakes on the strip", "+ Burst on contact", "+ Shove back toward the gate" },
            { "+ Iron-capped stakes", "+ Harder shove", "+ Forged braces" },
            { "+ Venom-coated tips", "+ Burst hits more of the wave", "+ Stronger knockback" },
            { "+ Soulforged pylons", "+ Holds the shove", "+ Void burst" },
        },
    },
    {
        id = "concertina_line",
        name = "Concertina Line",
        role = "Bleed",
        description = "Razor wire across the lane. Anything that keeps walking the strip takes damage for as long as it stays on it.",
        previewAssetIds = {
            "136599170104983",
            "114115802025357",
            "97116236163143",
            "127236634177361",
        },
        upgradeNotes = {
            { "+ Razor wire on the strip", "+ Bleed while they walk it", "+ Posts hold the lane" },
            { "+ Steel razor coils", "+ Heavier bleed", "+ Armored posts" },
            { "+ Electrified wire", "+ Faster tick", "+ Stronger linger" },
            { "+ Plasma coils", "+ Bleed stacks", "+ Runic cut" },
        },
    },
    {
        id = "land_shark",
        name = "Land Sharks",
        role = "Hunt",
        description = "Sharks travel the strip and bite the nearest marcher. They chase instead of sitting still.",
        previewAssetIds = {
            "93689656194809",
            "75537065187935",
            "104209939997210",
            "75511812682521",
        },
        upgradeNotes = {
            { "+ One shark on the strip", "+ Bites the nearest marcher", "+ Chases instead of sitting still" },
            { "+ Ironjaw armor", "+ Harder bite", "+ Faster chase" },
            { "+ Venom fins", "+ Poisoned bite", "+ Keeps the hunt" },
            { "+ Apex void shark", "+ Heavier bite", "+ Boss of the strip" },
        },
    },
    {
        id = "saw_blade",
        name = "Saw Blades",
        role = "Shred",
        description = "Spinning blades chew anything on the line. Highest raw damage, no control.",
        previewAssetIds = {
            "135106892647800",
            "127121637387172",
            "95208080901306",
            "75817556345709",
        },
        upgradeNotes = {
            { "+ One saw on the line", "+ Chews anything that crosses", "+ Highest raw damage, no control" },
            { "+ Twin hardened blades", "+ Higher shred", "+ Riveted track" },
            { "+ Triple heated saws", "+ Faster chew", "+ Hotter cut" },
            { "+ Quad void blades", "+ Highest shred", "+ Runic hubs" },
        },
    },
    {
        id = "grasping_hedge",
        name = "Grasping Hedge",
        role = "Hold",
        description = "Thorns grab the front of the wave and slow it so your pets can finish the pile.",
        previewAssetIds = {
            "124036242227752",
            "88689523917752",
            "105129779394582",
            "95382045660111",
        },
        upgradeNotes = {
            { "+ Thorn hedge on the strip", "+ Grabs the front of the wave", "+ Slows the pile" },
            { "+ Ironwood roots", "+ Stronger hold", "+ Ivory thorns" },
            { "+ Venom briar", "+ Poisoned grab", "+ Longer slow" },
            { "+ Worldroot wall", "+ Holds the wave", "+ Crystal thorns" },
        },
    },
    {
        id = "wardstone_barrier",
        name = "Wardstone Barrier",
        role = "Ward",
        description = "Wards the hatcher eggs, not the lane. Cuts damage that gets past the fight and hits an installed egg.",
        previewAssetIds = {
            "78858133707824",
            "130243428103758",
            "111395473839332",
            "82814362109464",
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
    local parts = {
        tostring(state.family or ""),
        tostring(state.tier or 0),
    }
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

function MergeBulwarkProgression.isFamily(family)
    return FAMILY_SET[string.lower(tostring(family or ""))] == true
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
    local family = string.lower(tostring(raw.family or raw.bulwark_family or ""))
    if FAMILY_SET[family] and owned[family] == nil then
        owned[family] = math.clamp(whole(raw.tier or raw.bulwark_tier, 1), 1, cap)
    end
    if not FAMILY_SET[family] or owned[family] == nil then
        family = nil
    end
    return {
        family = family,
        tier = family and owned[family] or 0,
        owned = owned,
    }
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

function MergeBulwarkProgression.apply(raw, action, family, currentWave, config)
    config = type(config) == "table" and config or {}
    local maximumTier = math.max(1, whole(config.maximum_tier, 4))
    local state = MergeBulwarkProgression.normalize(raw, maximumTier)
    if not MergeBulwarkProgression.isUnlocked(currentWave, config) then
        return nil, "bulwark_locked"
    end

    if action == "select" then
        local requested = string.lower(tostring(family or ""))
        if not FAMILY_SET[requested] then
            return nil, "invalid_bulwark_family"
        end
        local owned = cloneOwned(state.owned)
        if owned[requested] == nil then
            owned[requested] = 1
            return {
                family = requested,
                tier = 1,
                owned = owned,
                operation = "installed",
                charged = true,
            }
        end
        if requested == state.family then
            return nil, "bulwark_already_selected"
        end
        return {
            family = requested,
            tier = owned[requested],
            owned = owned,
            operation = "equipped",
            charged = false,
        }
    end

    if action == "upgrade" then
        local requested = string.lower(tostring(family or state.family or ""))
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
        local equipped = state.family
        return {
            family = equipped,
            tier = equipped and owned[equipped] or 0,
            owned = owned,
            upgradedFamily = requested,
            operation = "upgraded",
            charged = true,
        }
    end

    return nil, "invalid_bulwark_action"
end

return MergeBulwarkProgression
