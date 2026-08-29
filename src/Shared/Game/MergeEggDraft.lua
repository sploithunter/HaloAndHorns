--[[
    MergeEggDraft — pure composition helpers for the Merge an Egg prototype.

    Hatcher drafts still prefer a missing tank/support before raw power. The player-reserve
    experiment also needs two deterministic operations over those same ordinary hatch results:
    remove the weakest cast-off, then build the strongest available tank/ranged/melee lineup (plus
    support in a four-slot squad). Nothing here creates or persists a pet.
]]

local MergeEggDraft = {}

local function power(candidate)
    return math.max(0, tonumber(candidate and candidate.combatPower) or 0)
end

local function role(candidate)
    return tostring(candidate and candidate.role or "melee")
end

local function roleCounts(roster)
    local counts = {}
    for _, member in ipairs(roster or {}) do
        local memberRole = role(member)
        counts[memberRole] = (counts[memberRole] or 0) + 1
    end
    return counts
end

local function priority(candidate, counts)
    local candidateRole = role(candidate)
    if (counts.tank or 0) == 0 then
        if candidateRole == "tank" then
            return 3
        end
        if (counts.support or 0) == 0 and candidateRole == "support" then
            return 2
        end
    elseif (counts.support or 0) == 0 and candidateRole == "support" then
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
    local bestPower = power(best)
    for index = 2, #candidates do
        local candidate = candidates[index]
        local candidatePriority = priority(candidate, counts)
        local candidatePower = power(candidate)
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

function MergeEggDraft.weakest(candidates, excludedIndex)
    local weakest
    local weakestIndex
    local weakestPower
    for index, candidate in ipairs(candidates or {}) do
        if index ~= excludedIndex then
            local candidatePower = power(candidate)
            if weakest == nil or candidatePower < weakestPower then
                weakest = candidate
                weakestIndex = index
                weakestPower = candidatePower
            end
        end
    end
    return weakest, weakestIndex
end

local function strongestIndex(candidates, used, desiredRole, excludedRole)
    local bestIndex
    local bestPower
    for index, candidate in ipairs(candidates or {}) do
        if
            not used[index]
            and (desiredRole == nil or role(candidate) == desiredRole)
            and (excludedRole == nil or role(candidate) ~= excludedRole)
        then
            local candidatePower = power(candidate)
            if bestIndex == nil or candidatePower > bestPower then
                bestIndex = index
                bestPower = candidatePower
            end
        end
    end
    return bestIndex
end

function MergeEggDraft.composePlayerRoster(candidates, slotCount)
    local capacity = math.clamp(math.floor(tonumber(slotCount) or 3), 1, 4)
    local desiredRoles = { "tank", "ranged", "melee" }
    if capacity >= 4 then
        desiredRoles[#desiredRoles + 1] = "support"
    end

    local squad = {}
    local used = {}
    for slot, desiredRole in ipairs(desiredRoles) do
        local index = strongestIndex(candidates, used, desiredRole)
        if index then
            used[index] = true
            squad[slot] = candidates[index]
        end
    end
    -- Core seats may use another combat pet while waiting for their exact role. Support never
    -- occupies a three-slot lineup or displaces tank/ranged/melee on a four-slot account.
    for slot = 1, math.min(3, capacity) do
        if squad[slot] == nil then
            local index = strongestIndex(candidates, used, nil, "support")
            if index then
                used[index] = true
                squad[slot] = candidates[index]
            end
        end
    end

    local reserve = {}
    while true do
        local index = strongestIndex(candidates, used, nil)
        if not index then
            break
        end
        used[index] = true
        reserve[#reserve + 1] = candidates[index]
    end
    return squad, reserve
end

function MergeEggDraft.selectPlayerReplacement(candidates, desiredRole, fallbackMode)
    if type(candidates) ~= "table" or #candidates == 0 then
        return nil, nil
    end
    local used = {}
    local index = strongestIndex(candidates, used, desiredRole)
    if not index and fallbackMode ~= "none" then
        index = strongestIndex(
            candidates,
            used,
            nil,
            fallbackMode == "non_support" and "support" or nil
        )
    end
    return index and candidates[index] or nil, index
end

return MergeEggDraft
