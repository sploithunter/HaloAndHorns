--[[
    MergeEggEnemyRoster — pure roster selection for the Merge an Egg defense prototype.

    Enemy identity follows the egg installed at the hatcher receiving a front. Home eggs use the
    authored Home/Lava enemy pool. Realm eggs perform an independent weighted hatch from the
    configured opposing egg for every authored wave position. Combat rank remains a separate
    overlay applied after species (and therefore its inherent powers) have been selected.
]]

local MergeEggEnemyRoster = {}

local function normalizedRoll(value)
    return math.clamp(tonumber(value) or 0, 0, 0.999999)
end

local function pick(values, roll)
    if type(values) ~= "table" or #values == 0 then
        return nil
    end
    return values[math.floor(normalizedRoll(roll) * #values) + 1]
end

function MergeEggEnemyRoster.defenderEgg(progression, teamTier, baseTier)
    local eggs = type(progression) == "table" and progression or {}
    if #eggs == 0 then
        return nil, 0
    end
    local tier = math.max(1, math.floor(math.max(tonumber(teamTier) or 0, tonumber(baseTier) or 1)))
    tier = math.clamp(tier, 1, #eggs)
    return eggs[tier], tier
end

function MergeEggEnemyRoster.opposingEgg(rosters, defenderEggId)
    local mapping = type(rosters) == "table" and rosters.opposition_egg_by_defender_egg or nil
    local eggId = type(mapping) == "table" and mapping[tostring(defenderEggId or "")] or nil
    return type(eggId) == "string" and eggId ~= "" and eggId or nil
end

function MergeEggEnemyRoster.homeEnemyId(rosters, archetype, roll)
    local home = type(rosters) == "table" and rosters.home or nil
    local byArchetype = type(home) == "table" and home.by_archetype or nil
    return pick(
        type(byArchetype) == "table" and byArchetype[tostring(archetype or "")] or nil,
        roll
    )
end

function MergeEggEnemyRoster.eggPetCandidates(petsConfig, rolesConfig, rosters, eggId, archetype)
    local sources = type(petsConfig) == "table" and petsConfig.egg_sources or nil
    local source = type(sources) == "table" and sources[tostring(eggId or "")] or nil
    local weights = type(source) == "table" and source.pet_weights or nil
    if type(weights) ~= "table" then
        return {}
    end
    local pets = type(petsConfig.pets) == "table" and petsConfig.pets or {}
    local byType = type(rolesConfig) == "table" and rolesConfig.by_type or nil
    byType = type(byType) == "table" and byType or {}
    local defaultRole = tostring(type(rolesConfig) == "table" and rolesConfig.default or "melee")
    local result = {}
    for petId, weight in pairs(weights) do
        if type(pets[petId]) == "table" and (tonumber(weight) or 0) > 0 then
            result[#result + 1] = {
                id = tostring(petId),
                role = tostring(byType[petId] or defaultRole),
                weight = tonumber(weight),
            }
        end
    end
    table.sort(result, function(a, b)
        return a.id < b.id
    end)
    return result
end

function MergeEggEnemyRoster.eggPet(petsConfig, rolesConfig, rosters, eggId, archetype, roll)
    local candidates =
        MergeEggEnemyRoster.eggPetCandidates(petsConfig, rolesConfig, rosters, eggId, archetype)
    local total = 0
    for _, candidate in ipairs(candidates) do
        total += math.max(0, tonumber(candidate.weight) or 0)
    end
    if total <= 0 then
        return nil
    end
    local threshold = normalizedRoll(roll) * total
    local cumulative = 0
    for _, candidate in ipairs(candidates) do
        cumulative += math.max(0, tonumber(candidate.weight) or 0)
        if threshold < cumulative then
            return candidate
        end
    end
    return candidates[#candidates]
end

return MergeEggEnemyRoster
