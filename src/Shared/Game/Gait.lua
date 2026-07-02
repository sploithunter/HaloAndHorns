--[[
    Gait — pure procedural walk-cycle math (Halo & Horns).

    Rig-less mesh creatures (enemies AND pets) animate by layering a procedural motion
    on their smoothed base CFrame, driven by distance travelled (so it scales with speed
    and rests when still). This module is the shared, Roblox-free core: it produces the
    bob / roll / yaw OFFSETS as plain numbers; the caller composes them into a CFrame
    (CFrame.new(0, bob, 0) * base * CFrame.Angles(0, yaw, roll)).

    Used by EnemyMotion (enemies) and PetFollowController (pets) — pets and enemies share
    the same movement feel, configured per-type.

      bob  — world-up bounce (studs)
      roll — bank about the facing axis (radians) — left/right lean
      yaw  — heading wiggle about up (radians) — snake-like sway
]]

local Gait = {}

local TWO_PI = math.pi * 2

-- style(phase) -> normalised (bob, roll, yaw) in [-1, 1]. The resolved gait scales bob
-- by bob_height and roll/yaw by tilt (radians). phase advances 0..2π per stride.
Gait.STYLES = {
    -- bob 2x/stride (down at phase 0), bank 1x/stride: down->L->up->down->R->up.
    waddle = function(p)
        return -math.cos(2 * p), math.sin(p), 0
    end,
    -- stiff vertical stomp, no tilt.
    march = function(p)
        return -math.cos(2 * p), 0, 0
    end,
    -- one big bounce per stride, no tilt.
    hop = function(p)
        return -math.cos(p), 0, 0
    end,
    -- no bob; heading wiggles left/right like a snake.
    slither = function(p)
        return 0, 0, math.sin(p)
    end,
    -- flyer hover: a smooth sine bounce centred on the hover line, with a gentle wing-bank.
    -- Pair with hover=true (below) so it keeps bobbing while the creature floats in place.
    flap = function(p)
        return math.sin(p), 0.35 * math.sin(p), 0
    end,
}

local function clamp01(n)
    if n < 0 then
        return 0
    elseif n > 1 then
        return 1
    end
    return n
end

-- Merge an `override` config over `default` into a resolved gait (numeric fields +
-- the style fn). degrees are converted to radians. Either arg may be nil.
function Gait.resolve(default, override)
    default = default or {}
    local g = {
        enabled = default.enabled ~= false,
        style = default.style or "waddle",
        bobHeight = default.bob_height or 0.6,
        tiltRad = math.rad(default.tilt_degrees or 12),
        stride = default.stride_length or 5,
        refSpeed = default.ref_speed or 8,
        easeRate = default.ease_rate or 8,
        -- HOVER (flyers): keep bobbing while floating in place. hover=true advances the phase by
        -- time (flapHz cycles/sec) on top of distance, and floors the amplitude at idleAmp so the
        -- bounce never fully decays when the creature is still.
        hover = default.hover == true,
        idleAmp = clamp01(default.idle_amp or 0),
        flapHz = default.flap_hz or 1.2,
    }
    if type(override) == "table" then
        if override.enabled ~= nil then
            g.enabled = override.enabled
        end
        g.style = override.style or g.style
        g.bobHeight = override.bob_height or g.bobHeight
        g.tiltRad = override.tilt_degrees and math.rad(override.tilt_degrees) or g.tiltRad
        g.stride = override.stride_length or g.stride
        g.refSpeed = override.ref_speed or g.refSpeed
        g.easeRate = override.ease_rate or g.easeRate
        if override.hover ~= nil then
            g.hover = override.hover == true
        end
        g.idleAmp = override.idle_amp and clamp01(override.idle_amp) or g.idleAmp
        g.flapHz = override.flap_hz or g.flapHz
    end
    g.fn = Gait.STYLES[g.style] or Gait.STYLES.waddle
    return g
end

-- Advance a gait `state` ({ phase, amp }, mutated) by one frame and return the offsets
-- (bob, roll, yaw) to apply. `stepDist` = studs the base moved this frame; `dt` seconds.
-- Amplitude eases toward (speed / ref_speed) so the gait fades in/out with movement.
function Gait.advance(state, gait, stepDist, dt)
    state.phase = state.phase or 0
    state.amp = state.amp or 0
    if not gait.enabled or gait.stride <= 0 then
        state.amp = 0
        return 0, 0, 0
    end
    local phaseStep = (stepDist / gait.stride) * TWO_PI
    if gait.hover then
        -- time-driven flap so a hovering (stationary) flyer keeps bouncing
        phaseStep = phaseStep + gait.flapHz * TWO_PI * dt
    end
    state.phase = (state.phase + phaseStep) % TWO_PI
    local speed = stepDist / math.max(dt, 1e-3)
    local targetAmp = clamp01(speed / gait.refSpeed)
    if gait.hover then
        targetAmp = math.max(targetAmp, gait.idleAmp) -- never fully rest: keep the hover bob alive
    end
    state.amp = state.amp + (targetAmp - state.amp) * (1 - math.exp(-gait.easeRate * dt))
    local bobN, rollN, yawN = gait.fn(state.phase)
    return gait.bobHeight * state.amp * bobN,
        gait.tiltRad * state.amp * rollN,
        gait.tiltRad * state.amp * yawN
end

return Gait
