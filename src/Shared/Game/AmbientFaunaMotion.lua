--!strict

-- Pure motion sampler for non-combat ambient fauna. The server owns the
-- visual Models, while this module keeps their tiny loops deterministic and
-- headless-testable.

local AmbientFaunaMotion = {}

export type Spec = {
    radius: number?,
    radius_x: number?,
    radius_z: number?,
    hover_height: number?,
    speed: number?,
    phase: number?,
}

export type Sample = {
    x: number,
    y: number,
    z: number,
    facing_x: number,
    facing_z: number,
}

function AmbientFaunaMotion.sample(motion: string, time: number, spec: Spec?): Sample
    local data = spec or {}
    local radius = math.max(0, tonumber(data.radius) or 0)
    local radiusX = math.max(0, tonumber(data.radius_x) or radius)
    local radiusZ = math.max(0, tonumber(data.radius_z) or radius)
    local speed = math.max(0, tonumber(data.speed) or 0)
    local phase = tonumber(data.phase) or 0
    local angle = time * speed + phase
    local hover = motion == "hover" and math.max(0, tonumber(data.hover_height) or 0) or 0
    local tangentX = -math.sin(angle) * radiusX
    local tangentZ = math.cos(angle) * radiusZ
    local tangentLength = math.sqrt(tangentX * tangentX + tangentZ * tangentZ)
    if tangentLength < 0.0001 then
        tangentX, tangentZ, tangentLength = 0, -1, 1
    end

    return {
        x = math.cos(angle) * radiusX,
        y = hover,
        z = math.sin(angle) * radiusZ,
        -- The service uses this tangent to face along the route. Orientation
        -- therefore follows actual travel instead of spinning around the anchor.
        facing_x = tangentX / tangentLength,
        facing_z = tangentZ / tangentLength,
    }
end

return AmbientFaunaMotion
