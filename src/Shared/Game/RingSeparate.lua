--[[
    RingSeparate — "don't pile up, fan out" positioning for melee attackers.

    Multiple attackers (enemies on one pet, or pets on one enemy) used to chase the SAME point and
    stack on top of each other. This relaxes that: each attacker wants to stand at a fixed `radius`
    from its target (its attack distance), and when another attacker is too close it gets nudged
    TANGENTIALLY — sideways around the target ring — so the crowd fans into an arc and then settles.

    Crucially the nudge is re-projected back onto the ring, so the distance to the target (and
    therefore proximity / threat / damage) NEVER changes — this is purely where they stand. It is
    NOT a constant orbit: with no crowding the attacker holds its current angle (push = 0 → no
    motion); it only slides to de-overlap, then stops.

    point(self, target, others, radius, minGap) -> { x, z }
        self    — this attacker's position           { x, z }
        target  — the thing it's attacking            { x, z }
        others  — other attackers on the SAME target  { {x,z}, ... }
        radius  — desired distance from target (studs)
        minGap  — how close two attackers may sit before they push apart (studs)

    Pure 2D (XZ plane) — no Roblox types, headless-tested. Callers convert Vector3 <-> {x,z}.
]]

local RingSeparate = {}

local EPS = 1e-4

local function norm(x, z)
    local d = math.sqrt(x * x + z * z)
    if d < EPS then
        return 0, 0, 0
    end
    return x / d, z / d, d
end

function RingSeparate.point(self, target, others, radius, minGap)
    radius = radius or 8
    minGap = minGap or 6

    -- Direction target -> self = the angle this attacker currently holds. Degenerate (sitting on
    -- the target) falls back to a fixed axis so the result is deterministic, never NaN.
    local ux, uz = norm(self.x - target.x, self.z - target.z)
    if ux == 0 and uz == 0 then
        ux, uz = 1, 0
    end

    -- The on-ring point in that direction — where it would stand with no crowding.
    local bx = target.x + ux * radius
    local bz = target.z + uz * radius

    -- Accumulate sideways pushes off any co-attacker whose ring-point is within minGap. Strength
    -- ramps 0..1 as they get closer (relaxation: it fades to 0 once spread, so the system settles).
    local px, pz = 0, 0
    for _, o in ipairs(others or {}) do
        local ox, oz, od = norm(bx - o.x, bz - o.z)
        if od > EPS and od < minGap then
            local strength = (minGap - od) / minGap
            px = px + ox * strength
            pz = pz + oz * strength
        elseif od <= EPS then
            -- exactly coincident → push along the tangent (deterministic) so they peel apart
            px = px - uz
            pz = pz + ux
        end
    end

    -- Apply the push, then RE-PROJECT onto the ring: only the angular component survives, so the
    -- distance to the target is preserved exactly. The attacker slides around the ring, never in/out.
    local nx = bx + px * minGap
    local nz = bz + pz * minGap
    local ndx, ndz, nd = norm(nx - target.x, nz - target.z)
    if nd < EPS then
        ndx, ndz = ux, uz
    end
    return { x = target.x + ndx * radius, z = target.z + ndz * radius }
end

return RingSeparate
