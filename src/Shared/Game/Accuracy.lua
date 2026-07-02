--[[
    Accuracy — pure level-diff to-hit math (Halo & Horns combat). No Roblox APIs.

    Brings ACCURACY to parity with DAMAGE: both now scale with the gap between the attacker's
    EFFECTIVE level and the defender's level (the enemy's published Level already bakes in its
    rank_offset, so a boss reads +2 and is naturally harder to hit). MINING is exempt — crystals
    are inert (no level, no rank), so they never dodge.

      toHit(attackerLevel, defenderLevel, cfg) -> hit chance in [floor, cap]
        = clamp(base_to_hit + per_level_step * (attacker - defender), floor, cap)
      miningHitChance(cfg) -> cfg.mining_hit_chance (default 1.0)

    cfg = configs/combat.lua `accuracy`. The service feeds the resulting hit_chance into
    CombatRoll (which still owns the crit roll), so a miss still deals nothing and a crit still
    multiplies.
]]

local Accuracy = {}

function Accuracy.toHit(attackerLevel, defenderLevel, cfg)
    cfg = cfg or {}
    local base = tonumber(cfg.base_to_hit) or 0.92
    local step = tonumber(cfg.per_level_step) or 0.04
    local floor = tonumber(cfg.floor) or 0.05
    local cap = tonumber(cfg.cap) or 0.95
    local diff = (tonumber(attackerLevel) or 1) - (tonumber(defenderLevel) or 1)
    return math.clamp(base + step * diff, floor, cap)
end

-- Alias for clarity at call sites (enemy combat).
Accuracy.combatToHit = Accuracy.toHit

function Accuracy.miningHitChance(cfg)
    return tonumber(cfg and cfg.mining_hit_chance) or 1
end

return Accuracy
