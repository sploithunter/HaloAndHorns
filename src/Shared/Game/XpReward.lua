--[[
    XpReward — pure XP-from-activity math (no Roblox APIs).

    "Everything you do grants XP": mining a node, defeating an enemy, etc. all feed the level bar
    (quests/daily/achievements add bigger chunks via RewardService bundles). Each activity converts
    a reward magnitude (ore value, loot total) into XP through a simple, config-driven rate so every
    number stays a dev knob.

      XpReward.fromValue(value, { per_value = number, min = number }) -> integer XP (>= 0)
      XpReward.fromEnemyLevel(effLevel, xpPerLevel, rankMult) -> integer XP (>= 1)  [combat]
      XpReward.applyOnramp(amount, playerLevel, cfg, source) -> integer XP (>= 0)
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

-- Apply the below-threshold XP tune at the ONE progression choke point. Activity sources may
-- override the fallback multiplier without teaching mining/combat services about balance values.
-- Unknown or omitted sources intentionally retain cfg.xp_mult for backwards compatibility.
function XpReward.applyOnramp(amount, playerLevel, cfg, source)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount == 0 or type(cfg) ~= "table" then
        return amount
    end

    local belowLevel = tonumber(cfg.below_level) or 5
    if (tonumber(playerLevel) or 1) >= belowLevel then
        return amount
    end

    local multiplier = tonumber(cfg.xp_mult) or 1
    local bySource = cfg.xp_mult_by_source
    if type(source) == "string" and type(bySource) == "table" then
        multiplier = tonumber(bySource[source]) or multiplier
    end

    return math.max(0, math.floor(amount * multiplier + 0.5))
end

return XpReward
