--[[
    AttackAnim — pure procedural ATTACK-motion math (Halo & Horns).

    The companion to Gait (src/Shared/Game/Gait.lua). Gait is the WALK cycle, driven by
    distance travelled; AttackAnim is the ATTACK flourish, driven by elapsed time, layered
    on the same smoothed base CFrame while a pet (or enemy) is engaging a target. Like Gait
    it is Roblox-free and returns plain numbers; the caller composes them onto the pivot:

        local lunged = base * CFrame.new(0, 0, -lunge)            -- jab forward toward target
        model:PivotTo(CFrame.new(0, bob, 0) * lunged * CFrame.Angles(0, yaw, 0))

      yaw   — extra heading rotation about up (radians) — the spin
      lunge — forward translation toward the faced target (studs) — the pounce/jab
      bob   — world-up bounce (studs)

    Styles (extend freely — pounce / spin_attack / etc. are just new entries):
      none   — no flourish; the pet simply faces its target (combat default for now)
      spin   — continuous whirl about up + a gentle bounce (the mining "spin attack")
      pounce — periodic jab toward the target and back (a melee lunge)
]]

local AttackAnim = {}

local TWO_PI = math.pi * 2

-- style(t, anim) -> yaw (rad), lunge (studs forward), bobN (-1..1, scaled by bobHeight).
-- t = seconds the pet has been attacking (accumulates while engaged, resets when it stops).
AttackAnim.STYLES = {
    none = function(_, _)
        return 0, 0, 0
    end,
    -- Mining whirl: heading spins about up at spin_speed; a small |sin| bounce sells it.
    spin = function(t, a)
        local yaw = (a.spinSpeed * t) % TWO_PI
        local bobN = math.abs(math.sin(a.spinSpeed * t * 0.5))
        return yaw, 0, bobN
    end,
    -- Melee pounce: one jab toward the target and back per pounce_period (0 -> depth -> 0).
    pounce = function(t, a)
        local period = (a.pouncePeriod > 0) and a.pouncePeriod or 1
        local phase = (t % period) / period
        local lunge = a.pounceDepth * math.max(0, math.sin(phase * math.pi))
        return 0, lunge, 0
    end,
    -- Peck: repeated downward dip toward the target (headbutt/pickaxe), no yaw or lunge.
    -- bobN rides in [-1, 0] so the pivot dips DOWN by bob_height; peck_speed = dips/sec-ish.
    peck = function(t, a)
        return 0, 0, -math.abs(math.sin(a.peckSpeed * t))
    end,
}

-- Resolve a raw config block ({ style, spin_speed, pounce_depth, pounce_period, bob_height })
-- into a ready-to-advance table with its style fn bound. nil / "none" => disabled (no-op).
function AttackAnim.resolve(cfg)
    cfg = cfg or {}
    local a = {
        style = cfg.style or "none",
        spinSpeed = cfg.spin_speed or 7,
        pounceDepth = cfg.pounce_depth or 3,
        pouncePeriod = cfg.pounce_period or 0.8,
        peckSpeed = cfg.peck_speed or 6,
        bobHeight = cfg.bob_height or 0.6,
    }
    a.enabled = a.style ~= "none" and AttackAnim.STYLES[a.style] ~= nil
    a.fn = AttackAnim.STYLES[a.style] or AttackAnim.STYLES.none
    return a
end

-- Advance a per-pet `state` ({ t }, mutated) by dt and return composed offsets
-- (yaw, lunge, bob). Disabled anims return zeros (and still accrue t harmlessly).
function AttackAnim.advance(state, anim, dt)
    state.t = (state.t or 0) + (dt or 0)
    if not anim or not anim.enabled then
        return 0, 0, 0
    end
    local yaw, lunge, bobN = anim.fn(state.t, anim)
    return yaw, lunge, anim.bobHeight * bobN
end

return AttackAnim
