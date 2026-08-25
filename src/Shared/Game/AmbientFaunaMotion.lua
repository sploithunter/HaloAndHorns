--!strict

-- Pure motion sampler for non-combat ambient fauna. The server owns the
-- visual Models, while this module keeps their tiny loops deterministic and
-- headless-testable.

local AmbientFaunaMotion = {}

export type Spec = {
    radius: number?,
    hover_height: number?,
    bob_height: number?,
    speed: number?,
    phase: number?,
}

export type Sample = {
    x: number,
    y: number,
    z: number,
    yaw: number,
}

function AmbientFaunaMotion.sample(motion: string, time: number, spec: Spec?): Sample
    local data = spec or {}
    local radius = math.max(0, tonumber(data.radius) or 0)
    local speed = math.max(0, tonumber(data.speed) or 0)
    local phase = tonumber(data.phase) or 0
    local angle = time * speed + phase
    local bob = math.max(0, tonumber(data.bob_height) or 0)
    local hover = motion == "hover" and math.max(0, tonumber(data.hover_height) or 0) or 0

    return {
        x = math.cos(angle) * radius,
        y = hover + math.sin(angle * 2) * bob,
        z = math.sin(angle) * radius,
        -- Models face Roblox -Z. This yaw follows the tangent around the
        -- circular loop instead of spinning in place.
        yaw = -angle,
    }
end

return AmbientFaunaMotion
