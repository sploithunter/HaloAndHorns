--[[
    PetAttackMotion — real-hit procedural pet attack choreography.

    AttackAnim is the continuous, engagement-time flourish used while a pet is assigned to a
    target. This module is deliberately different: its clock starts from Combat_PetHit, the
    server-authoritative swing that actually landed (or missed). The owner and nearby observers
    therefore render the same role-readable contact/recovery motion without moving damage
    authority to the client.

    Roblox-free: profiles and samples are plain tables/numbers so the motion curves are covered by
    the headless suite. `forward` is studs along the pet's faced -Z axis; `height` is world-up;
    pitch/yaw/roll are radians.
]]

local PetAttackMotion = {}

local PI = math.pi
local TWO_PI = PI * 2

local DEFAULTS = {
    duration = 0.36,
    depth = 0,
    recoil = 0,
    height = 0,
    drop = 0,
    pitch = 0,
    yaw = 0,
    roll = 0,
}

local function copyInto(out, source)
    if type(source) ~= "table" then
        return
    end
    for key, value in pairs(source) do
        out[key] = value
    end
end

-- The server event marks contact. Each curve therefore opens on (or very near) its strongest
-- contact pose, then supplies the readable recovery/settle that was missing from static pets.
PetAttackMotion.STYLES = {
    none = function(_, _)
        return 0, 0, 0, 0, 0
    end,

    -- Agile close-range hit: snap into the target, rebound slightly, then settle.
    lunge = function(t, p)
        local decay = (1 - t) * (1 - t)
        local rebound = math.sin(PI * t) * (1 - t)
        return p.depth * decay - p.recoil * rebound,
            p.height * math.sin(PI * t),
            p.pitch * decay,
            p.yaw * math.sin(TWO_PI * t) * (1 - t),
            p.roll * math.sin(TWO_PI * t) * (1 - t)
    end,

    -- Heavy tank contact: arrive low and forward, rise through the recovery, then plant.
    slam = function(t, p)
        local decay = (1 - t) * (1 - t)
        local recovery = math.sin(PI * t) * (1 - t)
        return p.depth * decay - p.recoil * recovery,
            -p.drop * decay + p.height * recovery,
            p.pitch * decay,
            p.yaw * math.sin(PI * t) * (1 - t),
            p.roll * math.sin(TWO_PI * t) * (1 - t)
    end,

    -- Ranged shot: the projectile is still rendered by CombatHitFX; this sells weapon recoil.
    recoil = function(t, p)
        local decay = (1 - t) * (1 - t)
        local settle = math.sin(TWO_PI * t) * (1 - t)
        return -p.recoil * decay,
            p.height * math.sin(PI * t) * (1 - t),
            -p.pitch * decay,
            p.yaw * settle,
            p.roll * settle
    end,

    -- Support/caster hit: a buoyant hop with a readable side-to-side magical flourish.
    cast = function(t, p)
        local decay = 1 - t
        return p.depth * math.sin(PI * t) * decay,
            p.height * math.sin(PI * t),
            p.pitch * math.sin(PI * t) * decay,
            p.yaw * math.sin(TWO_PI * t) * decay,
            p.roll * math.sin(TWO_PI * t) * decay
    end,
}

-- Resolution order: defaults -> role profile -> species override. This gives every current and
-- future pet a role animation immediately, while allowing the starter quartet to be hand-tuned.
function PetAttackMotion.resolve(cfg, roleId, petType)
    cfg = cfg or {}
    local profile = {}
    copyInto(profile, DEFAULTS)
    copyInto(profile, cfg.default)
    copyInto(profile, cfg.roles and cfg.roles[roleId])
    copyInto(profile, cfg.by_type and cfg.by_type[petType])

    profile.style = profile.style or "none"
    profile.duration = math.max(0, tonumber(profile.duration) or DEFAULTS.duration)
    profile.enabled = cfg.enabled ~= false
        and profile.style ~= "none"
        and PetAttackMotion.STYLES[profile.style] ~= nil
        and profile.duration > 0
    profile.fn = PetAttackMotion.STYLES[profile.style] or PetAttackMotion.STYLES.none

    for key, fallback in pairs(DEFAULTS) do
        profile[key] = tonumber(profile[key]) or fallback
    end
    return profile
end

-- Returns (motion, active). At/after duration, motion is exactly zero so a rendered pet always
-- returns to its clean formation CFrame and never accumulates cosmetic drift.
function PetAttackMotion.sample(profile, elapsed)
    local zero = { forward = 0, height = 0, pitch = 0, yaw = 0, roll = 0 }
    if not profile or not profile.enabled then
        return zero, false
    end

    local duration = profile.duration
    local age = math.max(0, tonumber(elapsed) or 0)
    if duration <= 0 or age >= duration then
        return zero, false
    end

    local t = math.min(1, age / duration)
    local forward, height, pitch, yaw, roll = profile.fn(t, profile)
    return {
        forward = forward,
        height = height,
        pitch = pitch,
        yaw = yaw,
        roll = roll,
    },
        true
end

return PetAttackMotion
