--[[
    HatchTiming — pure functional core for "how long does a hatch take".

    No Roblox APIs. Single source of truth for the egg-hatch animation/lock
    duration, consumed by BOTH sides so the server cooldown tracks the client
    animation instead of guessing:

      - Client (EggHatchingService) uses it to size the hatch-lock watchdog.
      - Server (EggService) uses it to set the post-success cooldown to
        max(purchase_cooldown floor, expectedSeconds) — so an injected client
        that bypasses the client-side lock still can't out-pace the animation.

    The math mirrors the real client sequence (resolveAnimationTiming +
    ExecuteHatchingSequence + StartHatchingAnimation's deferred cleanup):

        total = shakeWait
              + (count-1) * staggerDelay         (when staggered)
              + max(completionWait, revealDuration)
              + resultEnjoyment + cleanupPause

    Animation-phase durations are scaled by preset * fastHatch speedScale; the
    post-animation holds (enjoyment/cleanup) are preset-scaled only — exactly as
    the client applies them. skipHatch bypasses the whole sequence -> 0.

    Inputs:
      resolve(timingConfig, options, extra)
        timingConfig : the egg_hatching config { timing, speed_presets,
                       current_preset, advanced }
        options      : hatch options { fastHatch, showHatch, skipHatch, silentHatch }
        extra        : { fastHatchSpeedScale = number }  (lives in egg_system
                       config, supplied by the caller; defaults to 0.5)
      expectedSeconds(count, timing)            -> number (>= 0)
      watchdogSeconds(count, timing, opts)      -> number (failsafe upper bound)
]]

local HatchTiming = {}

-- Normalize the egg_hatching config + per-hatch options into the durations the
-- duration math needs. Pure: plain tables in, plain table out.
function HatchTiming.resolve(timingConfig, options, extra)
    timingConfig = type(timingConfig) == "table" and timingConfig or {}
    options = type(options) == "table" and options or {}
    extra = type(extra) == "table" and extra or {}

    local timing = type(timingConfig.timing) == "table" and timingConfig.timing or {}
    local advanced = type(timingConfig.advanced) == "table" and timingConfig.advanced or {}

    -- Active preset speed multiplier (e.g. very_fast = 0.5).
    local presetMult = 1.0
    local presets = timingConfig.speed_presets
    local current = timingConfig.current_preset
    if type(presets) == "table" and current ~= nil and type(presets[current]) == "table" then
        presetMult = tonumber(presets[current].speed_multiplier) or 1.0
    end

    local fastHatch = options.fastHatch == true
    local showHatch = options.showHatch ~= false
    -- showHatch == false is treated as skip (matches resolveAnimationTiming).
    local skipHatch = options.skipHatch == true or showHatch == false

    local fastScale = tonumber(extra.fastHatchSpeedScale)
    if not (fastScale and fastScale > 0) then
        fastScale = 0.5
    end
    local speedScale = fastHatch and fastScale or 1.0

    -- Staggered reveal unless the config explicitly asks for simultaneous.
    local doStagger = advanced.batch_reveal_mode ~= "simultaneous"

    local function base(key)
        return tonumber(timing[key]) or 0
    end

    return {
        skipHatch = skipHatch,
        fastHatch = fastHatch,
        silentHatch = options.silentHatch == true,
        doStagger = doStagger,
        presetMultiplier = presetMult,
        speedScale = speedScale,
        -- Animation-phase durations: preset * speedScale (as resolveAnimationTiming).
        shakeWaitDuration = base("shake_wait_duration") * presetMult * speedScale,
        staggerDelay = base("stagger_delay") * presetMult * speedScale,
        revealDuration = base("reveal_duration") * presetMult * speedScale,
        completionWait = base("reveal_completion_wait") * presetMult * speedScale,
        -- Post-animation holds: preset only (StartHatchingAnimation does NOT apply speedScale).
        resultEnjoymentTime = base("result_enjoyment_time") * presetMult,
        cleanupPauseTime = base("cleanup_pause_time") * presetMult,
    }
end

-- Expected wall-clock duration of a hatch of `count` eggs with the given resolved timing.
function HatchTiming.expectedSeconds(count, timing)
    timing = type(timing) == "table" and timing or {}
    count = math.max(1, math.floor(tonumber(count) or 1))

    if timing.skipHatch == true then
        return 0
    end

    local shake = timing.shakeWaitDuration or 0
    local stagger = 0
    if timing.doStagger ~= false then
        stagger = math.max(0, count - 1) * (timing.staggerDelay or 0)
    end
    -- The post-loop completion wait overlaps the last (concurrent) reveal; take whichever
    -- bounds the reveal's end.
    local revealTail = math.max(timing.completionWait or 0, timing.revealDuration or 0)
    local post = (timing.resultEnjoymentTime or 0) + (timing.cleanupPauseTime or 0)

    return shake + stagger + revealTail + post
end

-- Backup watchdog duration for the client hatch lock: comfortably longer than the expected
-- animation (so it never trips a legitimate hatch) but bounded (so a UI glitch can't lock a
-- player out forever). Returns expected*factor + margin, clamped to [minSeconds, maxSeconds].
function HatchTiming.watchdogSeconds(count, timing, opts)
    opts = type(opts) == "table" and opts or {}
    local expected = HatchTiming.expectedSeconds(count, timing)
    local factor = tonumber(opts.safetyFactor) or 3
    local margin = tonumber(opts.marginSeconds) or 5
    local minSeconds = tonumber(opts.minSeconds) or 8
    local maxSeconds = tonumber(opts.maxSeconds) or 120

    local seconds = expected * factor + margin
    if seconds < minSeconds then
        seconds = minSeconds
    end
    if seconds > maxSeconds then
        seconds = maxSeconds
    end
    return seconds
end

return HatchTiming
