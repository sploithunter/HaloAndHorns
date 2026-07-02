--[[
    EnemyLeash — pure point-in-region containment + clamp for the enemy movement leash (no Roblox
    APIs). A leash REGION is a union of simple footprint shapes on the X/Z plane:

        box    = { kind = "box",    cx, cz, halfX, halfZ }
        circle = { kind = "circle", cx, cz, r }

    An enemy spawned inside a region is confined to that region's UNION: it may roam anywhere
    inside ANY shape, but a step that leaves every shape is clamped back to the nearest boundary.
    This lets the grass starter area be (Grass mesh ∪ Spawn circle) — one connected pen spanning
    two differently-shaped parts. Shapes are built from live map parts by EnemyService at boot.

    Pure + deterministic so it is exercised headlessly (tests/headless/specs/enemy_leash).
]]

local EnemyLeash = {}

-- Is (x,z) inside this single shape (optionally inset by `margin` so the usable area stops just
-- inside the edge)? Box uses the rectangle; circle uses radius.
local function insideShape(x, z, shape, margin)
    margin = margin or 0
    if shape.kind == "circle" then
        local r = math.max(0, (shape.r or 0) - margin)
        local dx, dz = x - shape.cx, z - shape.cz
        return (dx * dx + dz * dz) <= r * r
    end
    local hx = math.max(0, (shape.halfX or 0) - margin)
    local hz = math.max(0, (shape.halfZ or 0) - margin)
    return math.abs(x - shape.cx) <= hx and math.abs(z - shape.cz) <= hz
end

-- Nearest point ON/INSIDE this shape to (x,z), inset by `margin`. Returns x, z plus the squared
-- distance from the input to that point (0 when already inside) for picking the closest shape.
local function clampToShape(x, z, shape, margin)
    margin = margin or 0
    if shape.kind == "circle" then
        local r = math.max(0, (shape.r or 0) - margin)
        local dx, dz = x - shape.cx, z - shape.cz
        local d2 = dx * dx + dz * dz
        if d2 <= r * r then
            return x, z, 0
        end
        local d = math.sqrt(d2)
        local nx = shape.cx + (dx / d) * r
        local nz = shape.cz + (dz / d) * r
        local ex, ez = x - nx, z - nz
        return nx, nz, ex * ex + ez * ez
    end
    local hx = math.max(0, (shape.halfX or 0) - margin)
    local hz = math.max(0, (shape.halfZ or 0) - margin)
    local nx = math.clamp(x, shape.cx - hx, shape.cx + hx)
    local nz = math.clamp(z, shape.cz - hz, shape.cz + hz)
    local ex, ez = x - nx, z - nz
    return nx, nz, ex * ex + ez * ez
end

-- True if (x,z) lies inside the union of `shapes` (inset by margin).
function EnemyLeash.inside(x, z, shapes, margin)
    for _, shape in ipairs(shapes) do
        if insideShape(x, z, shape, margin) then
            return true
        end
    end
    return false
end

-- Clamp (x,z) into the union of `shapes`. Inside any shape -> unchanged. Otherwise snap to the
-- nearest shape's boundary (the shape whose clamped point is closest to the input). Empty set or
-- no shapes -> unchanged. Returns x, z.
function EnemyLeash.clamp(x, z, shapes, margin)
    if not shapes or #shapes == 0 then
        return x, z
    end
    if EnemyLeash.inside(x, z, shapes, margin) then
        return x, z
    end
    local bestX, bestZ, bestD2
    for _, shape in ipairs(shapes) do
        local nx, nz, d2 = clampToShape(x, z, shape, margin)
        if not bestD2 or d2 < bestD2 then
            bestX, bestZ, bestD2 = nx, nz, d2
        end
    end
    return bestX, bestZ
end

return EnemyLeash
