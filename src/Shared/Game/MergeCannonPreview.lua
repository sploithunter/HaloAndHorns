-- Pure framing for the two artillery-workshop preview panes. Each window
-- frames its own chassis: eye-level (no pitch), 90° to the long silhouette,
-- filled to the authored fraction of that pane. No Roblox types so headless
-- tests can lock the camera math.

local MergeCannonPreview = {}

local function number3(values, name)
    assert(type(values) == "table", "workshop_preview." .. name .. " must be { r, g, b } or { x, y, z }")
    local a = tonumber(values[1])
    local b = tonumber(values[2])
    local c = tonumber(values[3])
    assert(a ~= nil and b ~= nil and c ~= nil, "workshop_preview." .. name .. " needs three numbers")
    return { a, b, c }
end

function MergeCannonPreview.settings(raw)
    assert(type(raw) == "table", "team.edge_towers.workshop_preview is required")
    local fill = tonumber(raw.fill)
    local fov = tonumber(raw.fov_degrees)
    assert(fill ~= nil and fill > 0.2 and fill < 1, "workshop_preview.fill must be a fraction")
    assert(fov ~= nil and fov > 10 and fov < 90, "workshop_preview.fov_degrees is out of range")
    return {
        fill = fill,
        fovDegrees = fov,
        ambient = number3(raw.ambient, "ambient"),
        lightColor = number3(raw.light_color, "light_color"),
        lightDirection = number3(raw.light_direction, "light_direction"),
    }
end

-- Look along the shorter horizontal box axis so the long silhouette faces the camera.
function MergeCannonPreview.lookAxis(sizeX, sizeZ)
    sizeX = tonumber(sizeX) or 0
    sizeZ = tonumber(sizeZ) or 0
    if sizeX >= sizeZ then
        return "z"
    end
    return "x"
end

function MergeCannonPreview.visibleWidth(sizeX, sizeZ)
    if MergeCannonPreview.lookAxis(sizeX, sizeZ) == "z" then
        return math.max(tonumber(sizeX) or 0, 0)
    end
    return math.max(tonumber(sizeZ) or 0, 0)
end

function MergeCannonPreview.flatLook(lookX, lookZ)
    lookX = tonumber(lookX) or 0
    lookZ = tonumber(lookZ) or 0
    local mag = math.sqrt(lookX * lookX + lookZ * lookZ)
    if mag < 1e-4 then
        return 0, 1
    end
    return lookX / mag, lookZ / mag
end

function MergeCannonPreview.sideLook(rightX, rightZ, lookX, lookZ, sizeX, sizeZ)
    if MergeCannonPreview.lookAxis(sizeX, sizeZ) == "z" then
        return MergeCannonPreview.flatLook(lookX, lookZ)
    end
    return MergeCannonPreview.flatLook(rightX, rightZ)
end

-- World AABB of an oriented box, then the silhouette seen by an eye-level camera.
function MergeCannonPreview.worldAabbSize(cx, cy, cz, rx, ry, rz, ux, uy, uz, lx, ly, lz, sx, sy, sz)
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    cx, cy, cz = tonumber(cx) or 0, tonumber(cy) or 0, tonumber(cz) or 0
    rx, ry, rz = tonumber(rx) or 1, tonumber(ry) or 0, tonumber(rz) or 0
    ux, uy, uz = tonumber(ux) or 0, tonumber(uy) or 1, tonumber(uz) or 0
    lx, ly, lz = tonumber(lx) or 0, tonumber(ly) or 0, tonumber(lz) or -1
    sx, sy, sz = tonumber(sx) or 0, tonumber(sy) or 0, tonumber(sz) or 0
    for ix = -0.5, 0.5, 1 do
        for iy = -0.5, 0.5, 1 do
            for iz = -0.5, 0.5, 1 do
                local x = cx + rx * sx * ix + ux * sy * iy + lx * sz * iz
                local y = cy + ry * sx * ix + uy * sy * iy + ly * sz * iz
                local z = cz + rz * sx * ix + uz * sy * iy + lz * sz * iz
                minX, maxX = math.min(minX, x), math.max(maxX, x)
                minY, maxY = math.min(minY, y), math.max(maxY, y)
                minZ, maxZ = math.min(minZ, z), math.max(maxZ, z)
            end
        end
    end
    return maxX - minX, maxY - minY, maxZ - minZ, (minX + maxX) * 0.5, (minY + maxY) * 0.5, (minZ + maxZ) * 0.5
end

function MergeCannonPreview.projectedViewSize(aabbX, aabbY, aabbZ, lookX, lookZ)
    lookX, lookZ = MergeCannonPreview.flatLook(lookX, lookZ)
    local rightX, rightZ = -lookZ, lookX
    local visibleWidth = math.abs((tonumber(aabbX) or 0) * rightX) + math.abs((tonumber(aabbZ) or 0) * rightZ)
    local visibleHeight = math.abs(tonumber(aabbY) or 0)
    return visibleWidth, visibleHeight
end

function MergeCannonPreview.fitDistance(visibleWidth, visibleHeight, aspect, fovDegrees, fill)
    aspect = math.max(tonumber(aspect) or 1, 1e-3)
    fovDegrees = tonumber(fovDegrees) or 35
    fill = tonumber(fill) or 0.86
    if fill < 0.2 then
        fill = 0.2
    elseif fill > 0.98 then
        fill = 0.98
    end
    local tanHalf = math.tan(math.rad(fovDegrees) * 0.5)
    if tanHalf < 1e-6 then
        tanHalf = 1e-6
    end
    visibleWidth = math.max(tonumber(visibleWidth) or 0, 1e-3)
    visibleHeight = math.max(tonumber(visibleHeight) or 0, 1e-3)
    local distHeight = (visibleHeight * 0.5 / fill) / tanHalf
    local distWidth = (visibleWidth * 0.5 / fill) / (tanHalf * aspect)
    return math.max(distHeight, distWidth)
end

-- Camera sits at the bbox center height: eye-level, no downward pitch.
function MergeCannonPreview.cameraOffset(lookX, lookZ, distance)
    lookX, lookZ = MergeCannonPreview.flatLook(lookX, lookZ)
    distance = math.max(tonumber(distance) or 1, 0.1)
    return lookX * distance, 0, lookZ * distance
end

return MergeCannonPreview
