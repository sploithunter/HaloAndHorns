-- Pure assignment policy for Merge Defense reinforcements.
--
-- CombatTargetGroup owns each team's opening matchup. This module decides how many otherwise-idle
-- teams may remain in reserve and which live enemy should receive duplicate coverage once the
-- opening has had time to settle.

local MergeEggDefenseAssignment = {}

local RANK_PRIORITY = {
    trash = 1,
    minion = 1,
    tank = 2,
    lieutenant = 3,
    villain = 3,
    boss = 4,
    archvillain = 4,
}

local ROLE_PRIORITY = {
    melee = 1,
    ranged = 1,
    support = 2,
    healer = 2,
    tank = 3,
}

local function finiteNumber(value)
    value = tonumber(value) or 0
    if value ~= value or value == math.huge or value == -math.huge then
        return 0
    end
    return value
end

local function priority(map, value)
    return map[string.lower(tostring(value or ""))] or 0
end

local function harder(left, right)
    local comparisons = {
        { priority(RANK_PRIORITY, left.rank), priority(RANK_PRIORITY, right.rank) },
        { finiteNumber(left.maxHealth), finiteNumber(right.maxHealth) },
        { finiteNumber(left.currentHealth), finiteNumber(right.currentHealth) },
        { priority(ROLE_PRIORITY, left.role), priority(ROLE_PRIORITY, right.role) },
        { finiteNumber(left.damage), finiteNumber(right.damage) },
    }
    for _, comparison in ipairs(comparisons) do
        if comparison[1] ~= comparison[2] then
            return comparison[1] > comparison[2]
        end
    end
    return finiteNumber(left.spawnIndex) < finiteNumber(right.spawnIndex)
end

function MergeEggDefenseAssignment.pickHardest(candidates)
    local best
    for _, candidate in ipairs(type(candidates) == "table" and candidates or {}) do
        if type(candidate) == "table" and (best == nil or harder(candidate, best)) then
            best = candidate
        end
    end
    return best
end

function MergeEggDefenseAssignment.reserveCount(
    activeTeamCount,
    activeAttackGroupCount,
    reserveReleased,
    maximumReserveTeams
)
    activeTeamCount = math.max(0, math.floor(finiteNumber(activeTeamCount)))
    activeAttackGroupCount = math.max(0, math.floor(finiteNumber(activeAttackGroupCount)))
    maximumReserveTeams = math.max(0, math.floor(finiteNumber(maximumReserveTeams)))
    if
        reserveReleased == true
        or activeTeamCount <= 1
        or activeAttackGroupCount >= activeTeamCount
    then
        return 0
    end
    return math.min(maximumReserveTeams, math.max(0, activeTeamCount - activeAttackGroupCount))
end

return MergeEggDefenseAssignment
