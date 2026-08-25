--[[
    CombatDeath — pick and sample a dramatic enemy death (pure).

    Styles live in configs/combat_deaths.lua. sample() returns pose offsets
    the client layers on the last walk CFrame: pitch/yaw/roll, lift, scale, fade.
]]

local CombatDeath = {}

local function clamp01(t)
    t = tonumber(t) or 0
    if t < 0 then
        return 0
    end
    if t > 1 then
        return 1
    end
    return t
end

local function easeOut(t)
    t = clamp01(t)
    return 1 - (1 - t) * (1 - t)
end

local function easeIn(t)
    t = clamp01(t)
    return t * t
end

local POSES = {
    flop = function(t)
        local e = easeIn(t)
        return {
            pitch = e * (math.pi * 0.52),
            yaw = 0,
            roll = e * 0.35,
            y = -0.55 * e,
            scale = 1,
            fade = e * 0.15,
        }
    end,
    pop = function(t)
        local squash = t < 0.35 and (1 + t * 1.4) or (1.5 * (1 - (t - 0.35) / 0.65))
        return {
            pitch = 0,
            yaw = 0,
            roll = 0,
            y = t < 0.35 and t * 1.2 or 0.4 * (1 - (t - 0.35) / 0.65),
            scale = math.max(0.05, squash),
            fade = easeIn(t) * 0.4,
        }
    end,
    shatter = function(t)
        local e = easeOut(t)
        return {
            pitch = e * 0.4,
            yaw = e * 1.2,
            roll = e * 0.8,
            y = 0.6 * e,
            scale = math.max(0.08, 1 - e),
            fade = e * 0.75,
        }
    end,
    whirl = function(t)
        local e = easeOut(t)
        return {
            pitch = e * 0.5,
            yaw = e * math.pi * 4,
            roll = e * 0.4,
            y = 3.2 * math.sin(clamp01(t) * math.pi),
            scale = math.max(0.12, 1 - e * 0.7),
            fade = e * 0.35,
        }
    end,
    sink = function(t)
        local e = easeIn(t)
        return {
            pitch = e * 0.2,
            yaw = 0,
            roll = 0,
            y = -2.4 * e,
            scale = math.max(0.2, 1 - e * 0.4),
            fade = e * 0.85,
        }
    end,
    launch = function(t)
        local e = easeOut(t)
        return {
            pitch = e * math.pi * 1.6,
            yaw = e * math.pi * 1.2,
            roll = e * 0.6,
            y = 7 * math.sin(clamp01(t) * math.pi),
            scale = math.max(0.15, 1 - e * 0.55),
            fade = e * 0.45,
        }
    end,
    -- Body empties as Robux cubes pop out one by one (client owns the cubes).
    robux = function(t)
        local e = easeIn(t)
        local squash = t < 0.28 and (1 + t * 0.9) or math.max(0.08, 1.25 * (1 - (t - 0.28) / 0.72))
        return {
            pitch = e * 0.15,
            yaw = e * 0.35,
            roll = e * 0.2,
            y = t < 0.28 and t * 0.7 or 0.2 * (1 - (t - 0.28) / 0.72),
            scale = squash,
            fade = easeOut(t) * 0.7,
        }
    end,
}

function CombatDeath.ids(config)
    local out = {}
    for _, style in ipairs((config and config.styles) or {}) do
        if type(style.id) == "string" then
            out[#out + 1] = style.id
        end
    end
    return out
end

function CombatDeath.styleById(config, id)
    for _, style in ipairs((config and config.styles) or {}) do
        if style.id == id then
            return style
        end
    end
    return nil
end

function CombatDeath.pick(config, rng, opts)
    opts = type(opts) == "table" and opts or {}
    local styles = (config and config.styles) or {}
    local total = 0
    local weights = {}
    local rank = tostring(opts.rank or "")
    local isBoss = rank == "boss" or rank == "lieutenant"
    for i, style in ipairs(styles) do
        local w = tonumber(style.weight) or 1
        if isBoss then
            w = tonumber(style.boss_weight) or w
        end
        w = math.max(0, w)
        weights[i] = w
        total += w
    end
    if total <= 0 then
        return styles[1]
    end
    local roll = (type(rng) == "function" and rng() or math.random()) * total
    local acc = 0
    for i, style in ipairs(styles) do
        acc += weights[i]
        if roll <= acc then
            return style
        end
    end
    return styles[#styles]
end

function CombatDeath.sample(styleId, t)
    local fn = POSES[styleId] or POSES.flop
    return fn(clamp01(t))
end

function CombatDeath.applyPose(baseCf, pose)
    pose = type(pose) == "table" and pose or {}
    local cf = baseCf * CFrame.Angles(pose.pitch or 0, pose.yaw or 0, pose.roll or 0)
        + Vector3.new(0, pose.y or 0, 0)
    return cf, tonumber(pose.scale) or 1, tonumber(pose.fade) or 0
end

-- Staggered scatter plan for a cube-burst style. rng() -> [0,1).
function CombatDeath.cubePlan(style, rng)
    local cubes = (type(style) == "table" and style.cubes) or {}
    local count = math.max(1, math.floor(tonumber(cubes.count) or 12))
    local stagger = math.max(0, tonumber(cubes.stagger) or 0.05)
    local lifetime = math.max(0.4, tonumber(cubes.lifetime) or 2)
    local scatter = math.max(1, tonumber(cubes.scatter) or 6)
    local peak = math.max(0.3, tonumber(cubes.peak) or 2)
    local roll = type(rng) == "function" and rng or math.random
    local plan = {}
    for i = 1, count do
        local jitter = (roll() - 0.5) * 0.55
        local ang = ((i - 1) / count) * math.pi * 2 + jitter
        local dist = scatter * (0.4 + 0.6 * roll())
        plan[i] = {
            delay = (i - 1) * stagger,
            x = math.cos(ang) * dist,
            z = math.sin(ang) * dist,
            peak = peak * (0.7 + 0.5 * roll()),
            lifetime = lifetime,
        }
    end
    return plan
end

return CombatDeath
