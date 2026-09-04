--!strict
-- Pure policy: no instance mutation, persistence, or clocks.
local ShadowPolicy = {}

function ShadowPolicy.normalize(mode, config)
    for _, candidate in ipairs(config.modes) do
        if mode == candidate then
            return mode
        end
    end
    return config.default_mode
end

function ShadowPolicy.new(config)
    return { enabled = true, slow = 0, healthy = 0, hold = config.warmup_seconds }
end

function ShadowPolicy.resetObservation(state, config)
    state.slow = 0
    state.healthy = 0
    state.hold = math.max(state.hold, config.warmup_seconds)
end

function ShadowPolicy.frameSeconds(dt, config)
    -- A lone loading stall contributes at most one capped frame. Repeated long
    -- frames still count as sustained poor performance instead of resetting forever.
    return math.clamp(dt, 0, config.max_sample_frame_seconds)
end

function ShadowPolicy.sample(state, fps, seconds, config)
    if state.hold > 0 then
        state.hold = math.max(0, state.hold - seconds)
        state.slow = 0
        state.healthy = 0
        return state.enabled
    end
    if state.enabled then
        state.slow = if fps < config.disable_below_fps then state.slow + seconds else 0
        if state.slow >= config.slow_seconds then
            state.enabled = false
            state.slow = 0
            state.hold = config.cooldown_seconds
        end
    else
        state.healthy = if fps >= config.recover_above_fps then state.healthy + seconds else 0
        if state.healthy >= config.recovery_seconds then
            state.enabled = true
            state.healthy = 0
            -- Observe a restoration immediately after startup grace; if it
            -- cannot sustain the frame rate, disable again and wait a full cooldown.
            state.hold = config.warmup_seconds
        end
    end
    return state.enabled
end

function ShadowPolicy.enabled(mode, state)
    return mode == "on" or (mode == "auto" and state.enabled)
end

function ShadowPolicy.nearby(distanceSquared, wasNear, config)
    local radius = if wasNear then config.far_studs else config.near_studs
    return distanceSquared <= radius * radius
end

function ShadowPolicy.distanceSquared(x, y, z, halfX, halfY, halfZ)
    local dx = math.max(0, math.abs(x) - halfX)
    local dy = math.max(0, math.abs(y) - halfY)
    local dz = math.max(0, math.abs(z) - halfZ)
    return dx * dx + dy * dy + dz * dz
end

return ShadowPolicy
