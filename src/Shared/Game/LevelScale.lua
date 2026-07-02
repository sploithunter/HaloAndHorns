--[[
    LevelScale — pure level-difference math (Halo & Horns combat).

    Keeps every combat number in a tight ~100 band: instead of inflating HP/damage into
    the thousands as you level, the LEVEL DIFFERENCE between attacker and defender scales
    damage. Level up (pet) -> you out-level enemies -> effectively tougher, while the
    displayed stats stay readable. Also classifies an enemy's difficulty (vs the viewer's
    level) into a colour tier for its name label.

    Roblox-free + deterministic.
]]

local LevelScale = {}

local function clamp(n, lo, hi)
    if n < lo then
        return lo
    elseif n > hi then
        return hi
    end
    return n
end

-- Damage multiplier from a level gap: attacker above defender hits harder, below softer.
-- mult = clamp(1 + per_level*(attacker - defender), min, max).
function LevelScale.factor(attackerLevel, defenderLevel, cfg)
    cfg = cfg or {}
    local per = cfg.per_level or 0.08
    local diff = (attackerLevel or 1) - (defenderLevel or 1)
    return clamp(1 + per * diff, cfg.min or 0.3, cfg.max or 2.5)
end

-- An enemy's effective level = its base level + an elite rank offset (lieutenant/boss
-- read as higher level than a standard mob of the same base).
function LevelScale.effectiveLevel(baseLevel, rankOffset)
    return (baseLevel or 1) + (rankOffset or 0)
end

-- Difficulty tier KEY from (enemy effective level - viewer level). The client maps the
-- key to a colour. Caps at purple (>=+3) and gray (<=-3).
function LevelScale.tier(relative)
    relative = relative or 0
    if relative >= 3 then
        return "purple"
    elseif relative == 2 then
        return "red"
    elseif relative == 1 then
        return "yellow"
    elseif relative == 0 then
        return "white"
    elseif relative == -1 then
        return "blue"
    elseif relative == -2 then
        return "green"
    end
    return "gray"
end

return LevelScale
