--[[
    LevelDiffYield — XP and payout multipliers vs the level gap between the player
    and the thing they broke/defeated (Jason, 2026-06-11: "somebody could passively
    mine in the same level forever and wake up the next morning 30 levels ahead.
    We can't allow that... three levels below you should get some XP, but it
    should be almost not worth it").

    Pure — no Roblox APIs. Consumed by BreakableSpawner (mining) and CombatService
    (enemy loot/XP). Target levels: crystals carry MiningLevel (zone_level +
    size-tier offset, small/medium/large = minion/lieutenant/boss = +0/+1/+2);
    enemies carry the Level attribute (rank already baked in).

    XP   — diminishing returns ONLY downward: a target at/above your level pays
           full XP (no punch-up bonus; the to-hit/damage penalty already taxes
           that). Below you it decays per level to a floor.
    PAY  — a symmetric clamped linear seam, shipped NEUTRAL (x1 at any diff):
           coins behave exactly as today, but the tuning lever exists in config.
]]

local LevelDiffYield = {}

local function num(v, d)
    local n = tonumber(v)
    return n ~= nil and n or d
end

-- XP multiplier. cfg = { per_level_down, floor } (configs/leveling.lua xp_level_scale).
-- target >= player -> 1. Below: max(floor, 1 - per_level_down * levelsBelow).
function LevelDiffYield.xp(playerLevel, targetLevel, cfg)
    if type(cfg) ~= "table" then
        return 1
    end
    local below = num(playerLevel, 1) - num(targetLevel, num(playerLevel, 1))
    if below <= 0 then
        return 1
    end
    local per = num(cfg.per_level_down, 0)
    local floor = num(cfg.floor, 0)
    return math.max(floor, 1 - per * below)
end

-- Payout multiplier. cfg = { per_level, min, max } (configs/leveling.lua
-- payout_level_scale). multiplier = clamp(1 + per_level * (target - player), min, max).
-- Shipped { per_level = 0, min = 1, max = 1 } -> always exactly 1.
function LevelDiffYield.payout(playerLevel, targetLevel, cfg)
    if type(cfg) ~= "table" then
        return 1
    end
    local diff = num(targetLevel, num(playerLevel, 1)) - num(playerLevel, 1)
    local raw = 1 + num(cfg.per_level, 0) * diff
    return math.clamp(raw, num(cfg.min, 1), num(cfg.max, 1))
end

return LevelDiffYield
