--[[
    MissionRankScale — pure, config-driven Trial rank level interpolation.

    A rank's ordinary fields are its max-level tuning. Optional `level_scaling`
    declares the minimum content level and the fields' values there; this module
    resolves the one effective overlay used by every pet-model mission enemy.
    It always deep-clones so callers can safely attach per-instance data.
]]

local MissionRankScale = {}

local SCALAR_FIELDS = { "hp_mult", "dmg_mult", "armor" }

local function deepClone(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, child in pairs(value) do
        copy[deepClone(key)] = deepClone(child)
    end
    return copy
end

local function lerp(a, b, alpha)
    return a + (b - a) * alpha
end

function MissionRankScale.resolve(rankDef, contentLevel)
    if type(rankDef) ~= "table" then
        return rankDef
    end

    local resolved = deepClone(rankDef)
    local scaling = rankDef.level_scaling
    if type(scaling) ~= "table" then
        return resolved
    end

    local minLevel = tonumber(scaling.min_level)
    local maxLevel = tonumber(scaling.max_level)
    local atMin = scaling.at_min
    if not minLevel or not maxLevel or maxLevel <= minLevel or type(atMin) ~= "table" then
        return resolved
    end

    local level = tonumber(contentLevel) or maxLevel
    local alpha = math.max(0, math.min(1, (level - minLevel) / (maxLevel - minLevel)))
    for _, field in ipairs(SCALAR_FIELDS) do
        local low = tonumber(atMin[field])
        local high = tonumber(rankDef[field])
        if low and high then
            resolved[field] = lerp(low, high, alpha)
        end
    end

    local abilityLow = tonumber(atMin.ability_damage_mult)
    if abilityLow and type(resolved.abilities) == "table" then
        local damageMult = lerp(abilityLow, 1, alpha)
        for _, ability in pairs(resolved.abilities) do
            if type(ability) == "table" and type(ability.damage) == "number" then
                ability.damage = ability.damage * damageMult
            end
        end
    end

    resolved.level_scaling = nil
    return resolved
end

return MissionRankScale
