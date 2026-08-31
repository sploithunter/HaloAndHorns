-- Pure progression policy for the Merge Defense bulwark strip. The server owns payment and
-- persistence; this module keeps unlock, family replacement, and tier advancement deterministic.

local MergeBulwarkProgression = {}

local FAMILIES = {
    { id = "impaler_palisade", name = "Impaler Palisade" },
    { id = "concertina_line", name = "Concertina Line" },
    { id = "land_shark", name = "Land Sharks" },
    { id = "saw_blade", name = "Saw Blades" },
    { id = "grasping_hedge", name = "Grasping Hedge" },
    { id = "wardstone_barrier", name = "Wardstone Barrier" },
}

local FAMILY_SET = {}
for _, family in ipairs(FAMILIES) do
    FAMILY_SET[family.id] = true
end

local function whole(value, minimum)
    return math.max(minimum or 0, math.floor(tonumber(value) or 0))
end

function MergeBulwarkProgression.families()
    local result = {}
    for index, family in ipairs(FAMILIES) do
        result[index] = table.clone(family)
    end
    return result
end

function MergeBulwarkProgression.isFamily(family)
    return FAMILY_SET[string.lower(tostring(family or ""))] == true
end

function MergeBulwarkProgression.normalize(raw, maximumTier)
    raw = type(raw) == "table" and raw or {}
    local family = string.lower(tostring(raw.family or raw.bulwark_family or ""))
    if not FAMILY_SET[family] then
        return { family = nil, tier = 0 }
    end
    return {
        family = family,
        tier = math.clamp(
            whole(raw.tier or raw.bulwark_tier, 1),
            1,
            math.max(1, whole(maximumTier, 4))
        ),
    }
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
        if requested == state.family then
            return nil, "bulwark_already_selected"
        end
        return {
            family = requested,
            tier = 1,
            operation = state.family and "replaced" or "installed",
        }
    end

    if action == "upgrade" then
        if not state.family then
            return nil, "bulwark_not_installed"
        end
        if state.tier >= maximumTier then
            return nil, "bulwark_maxed"
        end
        return {
            family = state.family,
            tier = state.tier + 1,
            operation = "upgraded",
        }
    end

    return nil, "invalid_bulwark_action"
end

return MergeBulwarkProgression
