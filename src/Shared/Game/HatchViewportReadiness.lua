--!strict

-- A newly-parented ScreenGui can report an intermediate AbsoluteSize for its first rendered
-- frame. Hatch cards use offset geometry, so accepting that transient width permanently shifts
-- the first presentation even though later hatches reuse the correctly-sized container.

local HatchViewportReadiness = {}

export type Policy = {
    stableFrames: number,
    maxWaitFrames: number,
    minWidth: number,
    minHeight: number,
    sizeTolerance: number,
}

export type State = {
    observedFrames: number,
    stableFrames: number,
    lastWidth: number?,
    lastHeight: number?,
}

local function number(value: unknown, fallback: number): number
    local parsed = tonumber(value)
    return parsed or fallback
end

function HatchViewportReadiness.resolvePolicy(config): Policy
    config = type(config) == "table" and config or {}
    local stableFrames = math.max(1, math.floor(number(config.stable_frames, 3)))
    local maxWaitFrames = math.max(stableFrames, math.floor(number(config.max_wait_frames, 30)))
    return {
        stableFrames = stableFrames,
        maxWaitFrames = maxWaitFrames,
        minWidth = math.max(1, number(config.min_width, 320)),
        minHeight = math.max(1, number(config.min_height, 240)),
        sizeTolerance = math.max(0, number(config.size_tolerance, 1)),
    }
end

function HatchViewportReadiness.newState(): State
    return {
        observedFrames = 0,
        stableFrames = 0,
        lastWidth = nil,
        lastHeight = nil,
    }
end

function HatchViewportReadiness.observe(
    state: State,
    width: number,
    height: number,
    policy: Policy
): boolean
    state.observedFrames += 1

    local usable = width >= policy.minWidth and height >= policy.minHeight
    local unchanged = state.lastWidth ~= nil
        and state.lastHeight ~= nil
        and math.abs(width - state.lastWidth) <= policy.sizeTolerance
        and math.abs(height - state.lastHeight) <= policy.sizeTolerance

    if not usable then
        state.stableFrames = 0
    elseif unchanged then
        state.stableFrames += 1
    else
        state.stableFrames = 1
    end

    state.lastWidth = width
    state.lastHeight = height
    return usable and state.stableFrames >= policy.stableFrames
end

return HatchViewportReadiness
