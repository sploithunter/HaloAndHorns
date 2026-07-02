--[[
    VeteranTrack — pure math for the post-cap XP track (docs/VETERAN_LEVELS.md).

    Level 50 is the build cap; total XP keeps counting past it. Every cfg.xp_per_level of
    overflow = one VETERAN level (flat curve — a metronome, not an escalating wall). Rewards
    are enhancement rolls + status milestones, resolved per reached level by the service.

    Pure + Roblox-free: (totalXp, capXp, cfg) in, numbers out. capXp = the total XP at which
    the cap level was EARNED (LevelCurve.xpForLevel(max_level)) — the service supplies it.
]]

local VeteranTrack = {}

local function step(cfg)
    local s = tonumber(cfg and cfg.xp_per_level) or 0
    return (s > 0) and s or nil
end

-- Veteran level for a lifetime XP total. 0 below the cap, when disabled, or with no step.
function VeteranTrack.level(totalXp, capXp, cfg)
    if not (cfg and cfg.enabled) then
        return 0
    end
    local s = step(cfg)
    if not s then
        return 0
    end
    local over = (tonumber(totalXp) or 0) - (tonumber(capXp) or 0)
    if over <= 0 then
        return 0
    end
    return math.floor(over / s)
end

-- Bar-facing progress: { level, into, step } — `into` = XP into the NEXT vet level.
function VeteranTrack.progress(totalXp, capXp, cfg)
    local s = step(cfg)
    if not (cfg and cfg.enabled) or not s then
        return { level = 0, into = 0, step = 0 }
    end
    local over = math.max(0, (tonumber(totalXp) or 0) - (tonumber(capXp) or 0))
    return {
        level = math.floor(over / s),
        into = over % s,
        step = s,
    }
end

-- Enhancement rolls paid for REACHING a given vet level (base + the premium beat).
function VeteranTrack.rollsFor(vetLevel, cfg)
    local r = (cfg and cfg.rewards) or {}
    local rolls = tonumber(r.rolls_per_level) or 1
    local every = tonumber(r.premium_every) or 0
    if every > 0 and vetLevel > 0 and vetLevel % every == 0 then
        rolls += tonumber(r.premium_bonus_rolls) or 1
    end
    return rolls
end

-- Is this vet level a STATUS milestone (world announce / title beat)?
function VeteranTrack.isMilestone(vetLevel, cfg)
    local every = tonumber(cfg and cfg.rewards and cfg.rewards.announce_every) or 0
    return every > 0 and vetLevel > 0 and vetLevel % every == 0
end

return VeteranTrack
