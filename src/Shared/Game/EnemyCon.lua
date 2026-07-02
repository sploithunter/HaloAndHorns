--[[
    EnemyCon — the City-of-Heroes "con" (consideration) colour for an enemy, by its level RELATIVE
    to the viewing player. One shared resolver so every per-viewer enemy display (HUD name, future
    over-head tint, target panel) reads danger identically at a glance.

    Diff = enemyLevel - playerLevel. The enemy's published Level already bakes in its rank_offset
    (minion +0 / lieutenant +1 / boss +2 — see configs/combat.lua), so a boss naturally cons higher
    with no extra term here — "one up their level for their rank" is done at publish.

        ≤ -3  gray    (trivial)
          -2  green
          -1  blue
           0  white   (even)
          +1  yellow
          +2  orange
          +3  red
        ≥ +4  purple  (deadly)

    tier(diff) is pure (testable); color(diff)/colorForLevels(...) map to Color3.
]]

local EnemyCon = {}

-- diff -> tier name (pure). Clamped at the ends.
function EnemyCon.tier(diff)
    diff = tonumber(diff) or 0
    if diff <= -3 then
        return "gray"
    elseif diff == -2 then
        return "green"
    elseif diff == -1 then
        return "blue"
    elseif diff == 0 then
        return "white"
    elseif diff == 1 then
        return "yellow"
    elseif diff == 2 then
        return "orange"
    elseif diff == 3 then
        return "red"
    end
    return "purple" -- diff >= 4
end

local TIER_RGB = {
    gray = { 150, 150, 155 },
    green = { 90, 210, 110 },
    blue = { 90, 165, 235 },
    white = { 240, 240, 245 },
    yellow = { 240, 225, 90 },
    orange = { 240, 160, 70 },
    red = { 235, 80, 70 },
    purple = { 190, 110, 230 },
}

-- diff -> {r,g,b} (pure; no Color3 dependency, for tests/non-UI callers).
function EnemyCon.rgb(diff)
    return TIER_RGB[EnemyCon.tier(diff)]
end

-- diff -> Color3.
function EnemyCon.color(diff)
    local c = EnemyCon.rgb(diff)
    return Color3.fromRGB(c[1], c[2], c[3])
end

-- Convenience: enemy + player levels -> Color3 (diff = enemyLevel - playerLevel).
function EnemyCon.colorForLevels(enemyLevel, playerLevel)
    return EnemyCon.color((tonumber(enemyLevel) or 1) - (tonumber(playerLevel) or 1))
end

return EnemyCon
