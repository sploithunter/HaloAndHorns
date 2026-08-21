--[[
    ArchLightning — grouping and pair-picking for Hall gate ambient bolts.

    Markers are Parts named lightning1, lightning2, … Client ArchLightning
    fires EnchantLightning between a pair on opposite gate jambs.
]]

local ArchLightning = {}

local MIN_SPAN = 2

function ArchLightning.isMarkerName(name, prefix)
    if type(name) ~= "string" or type(prefix) ~= "string" or prefix == "" then
        return false
    end
    return string.match(name, "^" .. prefix .. "%d+$") ~= nil
end

-- Greedy clusters: a point joins the first seed within radius.
function ArchLightning.clusterLoose(points, radius)
    local groups = {}
    if type(points) ~= "table" then
        return groups
    end
    local r = tonumber(radius) or 48
    for _, point in ipairs(points) do
        local px = tonumber(point.x)
        local py = tonumber(point.y)
        local pz = tonumber(point.z)
        if px and py and pz then
            local placed = false
            for _, group in ipairs(groups) do
                local seed = group[1]
                local dx = px - seed.x
                local dy = py - seed.y
                local dz = pz - seed.z
                if math.sqrt(dx * dx + dy * dy + dz * dz) <= r then
                    table.insert(group, point)
                    placed = true
                    break
                end
            end
            if not placed then
                table.insert(groups, { point })
            end
        end
    end
    return groups
end

local function span(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Opposite jambs when both columns exist. minCross rejects same-pillar pairs.
function ArchLightning.pickPair(points, preferCross, _roll, minCross)
    if type(points) ~= "table" or #points < 2 then
        return nil, nil
    end

    local needCross = tonumber(minCross) or 0
    local minX, maxX = points[1].x, points[1].x
    local minZ, maxZ = points[1].z, points[1].z
    for _, point in ipairs(points) do
        minX = math.min(minX, point.x)
        maxX = math.max(maxX, point.x)
        minZ = math.min(minZ, point.z)
        maxZ = math.max(maxZ, point.z)
    end
    local useX = (maxX - minX) > (maxZ - minZ)
    local function axis(point)
        return useX and point.x or point.z
    end

    local low, high = {}, {}
    local sum = 0
    for _, point in ipairs(points) do
        sum += axis(point)
    end
    local mid = sum / #points
    for index, point in ipairs(points) do
        if axis(point) < mid then
            table.insert(low, index)
        else
            table.insert(high, index)
        end
    end

    local function tryPair(i, j)
        if not i or not j or i == j then
            return nil, nil
        end
        if span(points[i], points[j]) < MIN_SPAN then
            return nil, nil
        end
        if needCross > 0 and math.abs(axis(points[i]) - axis(points[j])) < needCross then
            return nil, nil
        end
        return i, j
    end

    if preferCross ~= false and #low > 0 and #high > 0 then
        local i, j = tryPair(low[math.random(#low)], high[math.random(#high)])
        if i then
            return i, j
        end
    end

    for _ = 1, 12 do
        local i = math.random(#points)
        local j = math.random(#points)
        local a, b = tryPair(i, j)
        if a then
            return a, b
        end
    end

    for i = 1, #points do
        for j = i + 1, #points do
            local a, b = tryPair(i, j)
            if a then
                return a, b
            end
        end
    end

    return nil, nil
end

-- Local-space points: two jamb columns only. No mid-arch apex.
function ArchLightning.sampleArchPoints(width, height, rows)
    local w = tonumber(width) or 26
    local h = tonumber(height) or 36
    local n = math.max(2, math.floor(tonumber(rows) or 9))
    local halfW = (w * 0.58) / 2
    local y0 = -h / 2 + 2.2
    local y1 = h / 2 - 2.8
    local points = {}
    for row = 0, n - 1 do
        local alpha = (n == 1) and 0.5 or row / (n - 1)
        local y = y0 + (y1 - y0) * alpha
        table.insert(points, { x = 0, y = y, z = -halfW })
        table.insert(points, { x = 0, y = y, z = halfW })
    end
    return points
end

function ArchLightning.openingWidth(size)
    return math.max(size.X, size.Z)
end

-- sampleArchPoints uses Z as the opening. Swap X/Z when the box is wider on X.
function ArchLightning.worldFromLocal(boxCf, size, localPoint)
    local lx = localPoint.x
    local ly = localPoint.y
    local lz = localPoint.z
    if size.X > size.Z then
        return boxCf * Vector3.new(lz, ly, lx)
    end
    return boxCf * Vector3.new(lx, ly, lz)
end

ArchLightning.GROUP_NAME = "ArchLightning"

return ArchLightning
