--[[
    HitReact — a tiny decaying "got hit" flinch (pure, client-render juice).

    Jason: "when a pet or enemy gets hit, turn/move them slightly — they shouldn't
    just stay frozen." On impact a model gets a quick recoil (a small world-space
    shove away from the attacker) plus a yaw twist, both springing back to zero
    over DURATION. The render loop samples it each frame and layers the offset on
    top of its normal pivot — same way the gait bob/tilt layers on.

    Pure: state in, math out. No Roblox APIs, headless-testable. The caller owns
    the per-model state table (weak-keyed) and the os.clock() now.

    Used by EnemyMotion (enemies, on Combat_PetHit) and PetFollowController (pets,
    on a CombatDamageTaken increase). Spec: tests/headless/specs/hit_react.spec.luau.
]]

local HitReact = {}

HitReact.DURATION = 0.22 -- seconds for the flinch to fully spring back
HitReact.RECOIL = 1.1 -- studs of shove at the instant of impact
HitReact.YAW = 0.22 -- radians of twist at impact

-- Arm a flinch on `state`: recoil along (dirX, dirZ) (any scale; normalized here),
-- twisting in `yawSign` (>=0 = +, else -). `now` is os.clock().
function HitReact.start(state, now, dirX, dirZ, yawSign)
    state.untilT = (tonumber(now) or 0) + HitReact.DURATION
    local m = math.sqrt((dirX or 0) ^ 2 + (dirZ or 0) ^ 2)
    if m > 1e-4 then
        state.dx, state.dz = dirX / m, dirZ / m
    else
        state.dx, state.dz = 0, 0
    end
    state.yaw = HitReact.YAW * ((tonumber(yawSign) or 1) >= 0 and 1 or -1)
end

-- Sample the current flinch -> (offsetX, offsetZ, yaw). Decays linearly to zero
-- (max shove at impact, recover) and returns 0,0,0 once spent.
function HitReact.sample(state, now)
    if not state or not state.untilT then
        return 0, 0, 0
    end
    now = tonumber(now) or 0
    if now >= state.untilT then
        return 0, 0, 0
    end
    local k = (state.untilT - now) / HitReact.DURATION -- 1 at impact -> 0
    return (state.dx or 0) * HitReact.RECOIL * k,
        (state.dz or 0) * HitReact.RECOIL * k,
        (state.yaw or 0) * k
end

return HitReact
