--[[
    XpReward — pure XP-from-activity math (no Roblox APIs).

    "Everything you do grants XP": mining a node, defeating an enemy, etc. all feed the level bar
    (quests/daily/achievements add bigger chunks via RewardService bundles). Each activity converts
    a reward magnitude (ore value, loot total) into XP through a simple, config-driven rate so every
    number stays a dev knob.

      XpReward.fromValue(value, { per_value = number, min = number }) -> integer XP (>= 0)
      XpReward.fromEnemyLevel(effLevel, xpPerLevel, rankMult) -> integer XP (>= 1)  [combat]
]]

local XpReward = {}

function XpReward.fromValue(value, cfg)
    cfg = cfg or {}
    value = tonumber(value) or 0
    if value <= 0 then
        return 0
    end
    local perValue = tonumber(cfg.per_value) or 0
    local minXp = tonumber(cfg.min) or 0
    return math.max(minXp, math.floor(value * perValue))
end

-- COMBAT XP: scale off the enemy's EFFECTIVE level (base + elite rank + the player's ±difficulty
-- offset — all baked into the Level attribute) × the rank multiplier, NOT its coin drop. So reward
-- tracks challenge, and a lieutenant/boss pays extra on top of its level. Floored at 1 so any kill
-- ticks the bar. The caller then applies LevelDiffYield.xp (diminish over-leveled targets).
function XpReward.fromEnemyLevel(effLevel, xpPerLevel, rankMult)
    effLevel = tonumber(effLevel) or 1
    xpPerLevel = tonumber(xpPerLevel) or 0
    rankMult = tonumber(rankMult) or 1
    return math.max(1, math.floor(xpPerLevel * effLevel * rankMult))
end

return XpReward
