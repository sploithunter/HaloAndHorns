--[[
    RoundedOutline — arc-length path around a rounded convex play field.

    Port of RobloxGenerateMap/playground/scenes/petsim/_walk.js `roundedRectPath`
    plus the FieldCorner-center walk used for corner-tile pentagons. Dashes are
    placed by distance travelled so a corner earns exactly as many dashes as its
    arc length, instead of a rectangle that cuts across the curve.

    Zone-local XZ. The client transforms through the SpawnZone CFrame.
]]

local RoundedOutline = {}

local EPS = 1e-4
-- Kit SAMPLE: one polyline vertex every ~3 studs.
RoundedOutline.SAMPLE = 3

local function clamp(value, lo, hi)
    if value < lo then
        return lo
    elseif value > hi then
        return hi
    end
    return value
end

local function hypot(x, z)
    return math.sqrt(x * x + z * z)
end

local function normalize(x, z)
    local length = hypot(x, z)
    if length <= EPS then
        return 0, 0, 0
    end
    return x / length, z / length, length
end

local function sweepCcw(a0, a1)
    local sweep = a1 - a0
    while sweep < 0 do
        sweep += math.pi * 2
    end
    while sweep >= math.pi * 2 do
        sweep -= math.pi * 2
    end
    return sweep
end

local function addLine(segs, x0, z0, x1, z1)
    local len = hypot(x1 - x0, z1 - z0)
    if len > EPS then
        segs[#segs + 1] = { kind = "line", x0 = x0, z0 = z0, x1 = x1, z1 = z1, len = len }
    end
end

local function addArc(segs, ox, oz, radius, a0, sweep)
    if radius > EPS and sweep > EPS then
        segs[#segs + 1] = {
            kind = "arc",
            ox = ox,
            oz = oz,
            r = radius,
            a0 = a0,
            sweep = sweep,
            len = radius * sweep,
        }
    end
end

local function finalize(segs)
    local total = 0
    for _, seg in ipairs(segs) do
        seg.s0 = total
        total += seg.len
    end
    return { segs = segs, total = total }
end

-- Counter-clockwise rounded rect in (x, z), starting on the +x edge heading +z.
-- radii is a number or { fl, fr, bl, br }.
function RoundedOutline.roundedRectPath(cx, cz, hx, hz, radii)
    cx = tonumber(cx) or 0
    cz = tonumber(cz) or 0
    hx = tonumber(hx) or 0
    hz = tonumber(hz) or 0
    local uniform = tonumber(radii)
    local r = {
        fl = clamp(uniform or (radii and radii.fl) or 0, 0, math.min(hx, hz)),
        fr = clamp(uniform or (radii and radii.fr) or 0, 0, math.min(hx, hz)),
        bl = clamp(uniform or (radii and radii.bl) or 0, 0, math.min(hx, hz)),
        br = clamp(uniform or (radii and radii.br) or 0, 0, math.min(hx, hz)),
    }
    local function X(sign)
        return cx + sign * hx
    end
    local function Z(sign)
        return cz + sign * hz
    end
    local segs = {}
    addLine(segs, X(1), Z(-1) + r.fr, X(1), Z(1) - r.br)
    addArc(segs, X(1) - r.br, Z(1) - r.br, r.br, 0, math.pi * 0.5)
    addLine(segs, X(1) - r.br, Z(1), X(-1) + r.bl, Z(1))
    addArc(segs, X(-1) + r.bl, Z(1) - r.bl, r.bl, math.pi * 0.5, math.pi * 0.5)
    addLine(segs, X(-1), Z(1) - r.bl, X(-1), Z(-1) + r.fl)
    addArc(segs, X(-1) + r.fl, Z(-1) + r.fl, r.fl, math.pi, math.pi * 0.5)
    addLine(segs, X(-1) + r.fl, Z(-1), X(1) - r.fr, Z(-1))
    addArc(segs, X(1) - r.fr, Z(-1) + r.fr, r.fr, math.pi * 1.5, math.pi * 0.5)
    return finalize(segs)
end

-- Convex loop from authored FieldCorner centers (zone-local). Equal dash radius.
function RoundedOutline.pathFromCenters(centers, radius)
    radius = tonumber(radius) or 0
    if type(centers) ~= "table" or #centers < 3 or radius <= EPS then
        return finalize({})
    end

    local ordered = table.create(#centers)
    local cx, cz = 0, 0
    for index, center in ipairs(centers) do
        local x = tonumber(center.x) or 0
        local z = tonumber(center.z) or 0
        ordered[index] = { x = x, z = z }
        cx += x
        cz += z
    end
    cx /= #ordered
    cz /= #ordered
    table.sort(ordered, function(a, b)
        return math.atan2(a.z - cz, a.x - cx) < math.atan2(b.z - cz, b.x - cx)
    end)

    local segs = {}
    local count = #ordered
    for index = 1, count do
        local prev = ordered[(index - 2) % count + 1]
        local current = ordered[index]
        local nextCenter = ordered[index % count + 1]
        local inX, inZ = normalize(current.x - prev.x, current.z - prev.z)
        local outX, outZ = normalize(nextCenter.x - current.x, nextCenter.z - current.z)
        local inOutX, inOutZ = inZ, -inX
        local outOutX, outOutZ = outZ, -outX
        local a0 = math.atan2(inOutZ, inOutX)
        local a1 = math.atan2(outOutZ, outOutX)
        addArc(segs, current.x, current.z, radius, a0, sweepCcw(a0, a1))
        addLine(
            segs,
            current.x + outOutX * radius,
            current.z + outOutZ * radius,
            nextCenter.x + outOutX * radius,
            nextCenter.z + outOutZ * radius
        )
    end
    return finalize(segs)
end

function RoundedOutline.at(path, distance)
    if not path or (path.total or 0) <= EPS then
        return { x = 0, z = 0, yaw = 0 }
    end
    local u = distance % path.total
    if u < 0 then
        u += path.total
    end
    local segs = path.segs
    for _, seg in ipairs(segs) do
        if u <= seg.s0 + seg.len + EPS then
            local t = (u - seg.s0) / seg.len
            if seg.kind == "line" then
                local tx = (seg.x1 - seg.x0) / seg.len
                local tz = (seg.z1 - seg.z0) / seg.len
                return {
                    x = seg.x0 + (seg.x1 - seg.x0) * t,
                    z = seg.z0 + (seg.z1 - seg.z0) * t,
                    yaw = math.atan2(tx, tz),
                }
            end
            local angle = seg.a0 + seg.sweep * t
            return {
                x = seg.ox + seg.r * math.cos(angle),
                z = seg.oz + seg.r * math.sin(angle),
                yaw = math.atan2(-math.sin(angle), math.cos(angle)),
            }
        end
    end
    return RoundedOutline.at(path, path.total - EPS)
end

function RoundedOutline.sample(path, spacing)
    spacing = math.max(0.5, tonumber(spacing) or RoundedOutline.SAMPLE)
    if not path or (path.total or 0) <= EPS then
        return {}
    end
    local count = math.max(24, math.floor(path.total / spacing))
    local points = table.create(count)
    for index = 0, count - 1 do
        local point = RoundedOutline.at(path, (index / count) * path.total)
        points[index + 1] = { x = point.x, z = point.z }
    end
    return points
end

function RoundedOutline.encode(points)
    if type(points) ~= "table" or #points < 3 then
        return nil
    end
    local parts = table.create(#points)
    for index, point in ipairs(points) do
        parts[index] = string.format("%.1f,%.1f", point.x, point.z)
    end
    return table.concat(parts, ";")
end

function RoundedOutline.encodePath(path, spacing)
    return RoundedOutline.encode(RoundedOutline.sample(path, spacing))
end

-- Build the marquee polyline on the authored field/kerb outline. `corners` are
-- FieldKerbCorner (preferred) or FieldCorner centers in zone-local XZ; their
-- radius IS the outline. Without cylinders, `width`/`depth` are the field or
-- kerb AABB — never the smaller SpawnZone.
function RoundedOutline.forPlayArea(opts)
    opts = opts or {}
    local sample = tonumber(opts.sample) or RoundedOutline.SAMPLE
    local corners = opts.corners
    local fieldRadius = tonumber(opts.field_radius)

    if type(corners) == "table" and #corners >= 3 then
        if not fieldRadius then
            fieldRadius = tonumber(corners[1].r)
        end
        return RoundedOutline.encodePath(
            RoundedOutline.pathFromCenters(corners, math.max(0, fieldRadius or 0)),
            sample
        )
    end

    local halfX = math.max(0, (tonumber(opts.width) or 0) * 0.5)
    local halfZ = math.max(0, (tonumber(opts.depth) or 0) * 0.5)
    if halfX <= EPS or halfZ <= EPS then
        return nil
    end
    return RoundedOutline.encodePath(
        RoundedOutline.roundedRectPath(
            tonumber(opts.center_x) or 0,
            tonumber(opts.center_z) or 0,
            halfX,
            halfZ,
            math.max(0, fieldRadius or 0)
        ),
        sample
    )
end

return RoundedOutline
