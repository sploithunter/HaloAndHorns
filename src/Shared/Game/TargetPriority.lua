--[[
    TargetPriority (pure) — choose which enemy a pet attacks from a candidate list.

    The squad's combat targeting (EnemyService) already honours a player-directed ASSIST target
    above all else; when there's none, it falls back to this priority. Each pet can be set to a
    different mode (per-pet override), defaulting to the squad/config default.

    Modes:
      aggro       — the enemy most angry at THIS pet (current default); if nobody is, the closest
      closest     — the nearest enemy
      furthest    — the farthest enemy
      strongest   — the highest-strength enemy (level/power), tie-break by HP
      weakest      — the lowest-strength enemy, tie-break by HP
      team_threat — the enemy that has dealt the most damage to the squad

    Candidates are { id, distance, strength, hp, aggro, teamDamage }. Pure + Roblox-free; the
    service supplies the per-enemy numbers. Returns the chosen id (or nil if there are none).
]]

local TargetPriority = {}

TargetPriority.MODES = { "aggro", "closest", "furthest", "strongest", "weakest", "team_threat" }
TargetPriority.DEFAULT = "aggro"

local function isMode(mode)
    for _, m in ipairs(TargetPriority.MODES) do
        if m == mode then
            return true
        end
    end
    return false
end
TargetPriority.isMode = isMode

-- Pick the best candidate by `scoreFn`; preferHigh = keep the highest score, else the lowest.
-- Stable: ties keep the earlier candidate (deterministic given a stable candidate order).
local function best(candidates, scoreFn, preferHigh)
    local bestC, bestS
    for _, c in ipairs(candidates) do
        local s = scoreFn(c)
        if bestS == nil or (preferHigh and s > bestS) or (not preferHigh and s < bestS) then
            bestS, bestC = s, c
        end
    end
    return bestC
end

local SCORERS = {
    closest = {
        fn = function(c)
            return c.distance or math.huge
        end,
        high = false,
    },
    furthest = {
        fn = function(c)
            return c.distance or 0
        end,
        high = true,
    },
    strongest = {
        fn = function(c)
            return c.strength or 0
        end,
        high = true,
    },
    weakest = {
        fn = function(c)
            return c.strength or math.huge
        end,
        high = false,
    },
    team_threat = {
        fn = function(c)
            return c.teamDamage or 0
        end,
        high = true,
    },
}

-- Choose a candidate's id for `mode`. Unknown mode -> the default (aggro).
function TargetPriority.pick(candidates, mode)
    if type(candidates) ~= "table" or #candidates == 0 then
        return nil
    end
    if not isMode(mode) then
        mode = TargetPriority.DEFAULT
    end

    if mode == "aggro" then
        -- most angry at this pet; if nobody has any aggro, engage the closest instead.
        local chosen = best(candidates, function(c)
            return c.aggro or 0
        end, true)
        if chosen and (chosen.aggro or 0) <= 0 then
            chosen = best(candidates, function(c)
                return c.distance or math.huge
            end, false)
        end
        return chosen and chosen.id
    end

    local s = SCORERS[mode]
    local chosen = best(candidates, s.fn, s.high)
    return chosen and chosen.id
end

return TargetPriority
