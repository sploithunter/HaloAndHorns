-- Pure local minigame math. No server timestamps, round trips or latency adjustment.
local Timing = {}
function Timing.newProfile(cfg, rng)
    return {
        cap = rng:NextNumber(cfg.cap_min, cfg.cap_max),
        period = rng:NextNumber(cfg.period_min, cfg.period_max),
        phase = rng:NextNumber(0, math.pi * 2),
        surge = rng:NextNumber() < cfg.surge_chance,
        surgeAt = rng:NextNumber(cfg.surge_earliest, cfg.surge_latest),
    }
end
function Timing.score(cfg, profile, elapsed)
    local wave = (math.sin(elapsed * math.pi * 2 / profile.period + profile.phase) + 1) / 2
    local value = cfg.floor
        + (profile.cap - cfg.floor) * wave
        + math.sin(elapsed * math.pi * 2 * cfg.wobble_hz) * cfg.wobble
    value = math.clamp(value, 0, profile.cap)
    if profile.surge then
        local delta = math.abs(elapsed - profile.surgeAt)
        if delta <= cfg.surge_plateau / 2 then
            return 100
        elseif delta < cfg.surge_duration / 2 then
            local blend = 1
                - (delta - cfg.surge_plateau / 2)
                    / ((cfg.surge_duration - cfg.surge_plateau) / 2)
            value += (100 - value) * blend
        end
    end
    return math.floor(value)
end
function Timing.escapeChance(cfg, score)
    return cfg.escape_at_zero
        + (cfg.escape_at_full - cfg.escape_at_zero) * math.clamp(score / 100, 0, 1)
end
function Timing.tier(cfg, score)
    local index = 1
    for i, tier in ipairs(cfg.tiers) do
        if score >= tier.minimum then
            index = i
        end
    end
    return index, cfg.tiers[index]
end
function Timing.reward(cfg, score, roll)
    local index, tier = Timing.tier(cfg, score)
    local sum = 0
    for _, row in ipairs(tier.rewards) do
        sum += row.weight
    end
    local target = math.clamp(roll, 0, 1) * sum
    for _, row in ipairs(tier.rewards) do
        target -= row.weight
        if target <= 0 then
            return row, index
        end
    end
    return tier.rewards[#tier.rewards], index
end
return Timing
