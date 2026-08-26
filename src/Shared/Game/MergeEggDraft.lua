--[[
    MergeEggDraft — pure composition-aware best-of-N selection for the Merge an Egg prototype.

    Egg tier controls how many ordinary hatch outcomes are offered. Selection first tries to fill
    one tank, then one support slot, then takes the candidate with the highest configured combat
    power. The hatch simulator remains the only source of species, variant, and Huge outcomes.
]]

local MergeEggDraft = {}

local function roleCounts(roster)
    local counts = {}
    for _, member in ipairs(roster or {}) do
        local role = tostring(member.role or "melee")
        counts[role] = (counts[role] or 0) + 1
    end
    return counts
end

local function priority(candidate, counts)
    local role = tostring(candidate.role or "melee")
    if (counts.tank or 0) == 0 then
        if role == "tank" then
            return 3
        end
        if (counts.support or 0) == 0 and role == "support" then
            return 2
        end
    elseif (counts.support or 0) == 0 and role == "support" then
        return 2
    end
    return 1
end

function MergeEggDraft.select(candidates, roster)
    if type(candidates) ~= "table" or #candidates == 0 then
        return nil, nil
    end
    local counts = roleCounts(roster)
    local bestIndex = 1
    local best = candidates[1]
    local bestPriority = priority(best, counts)
    local bestPower = math.max(0, tonumber(best.combatPower) or 0)
    for index = 2, #candidates do
        local candidate = candidates[index]
        local candidatePriority = priority(candidate, counts)
        local candidatePower = math.max(0, tonumber(candidate.combatPower) or 0)
        if
            candidatePriority > bestPriority
            or (candidatePriority == bestPriority and candidatePower > bestPower)
        then
            bestIndex = index
            best = candidate
            bestPriority = candidatePriority
            bestPower = candidatePower
        end
    end
    return best, bestIndex
end

return MergeEggDraft
