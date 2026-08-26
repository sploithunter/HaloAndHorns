--[[
    EnemyPatrolRoute — pure directed-waypoint movement for authored enemy routes.

    The route advances only while EnemyService considers the enemy idle. Combat may interrupt it;
    the same state then resumes from the enemy's authoritative position after disengagement.
]]

local EnemyPatrolRoute = {}

local function coordinate(point, upper, lower)
    if point == nil then
        return nil
    end
    local okUpper, value = pcall(function()
        return point[upper]
    end)
    if okUpper and type(value) == "number" then
        return value
    end
    local okLower, fallback = pcall(function()
        return point[lower]
    end)
    if okLower and type(fallback) == "number" then
        return fallback
    end
    return nil
end

function EnemyPatrolRoute.new(config)
    if type(config) ~= "table" or type(config.waypoints) ~= "table" then
        return nil
    end

    local points = {}
    for _, waypoint in ipairs(config.waypoints) do
        local x = coordinate(waypoint, "X", "x")
        local y = coordinate(waypoint, "Y", "y")
        local z = coordinate(waypoint, "Z", "z")
        if not (x and z) then
            return nil
        end
        points[#points + 1] = { x = x, y = y or 0, z = z }
    end
    if #points == 0 then
        return nil
    end

    local speed = tonumber(config.speed) or 8
    local arriveDistance = tonumber(config.arriveDistance) or 2
    if speed <= 0 or arriveDistance < 0 then
        return nil
    end
    return {
        points = points,
        index = 1,
        speed = speed,
        arriveDistance = arriveDistance,
    }
end

-- Advance across as many waypoint segments as this tick's movement budget permits.
-- Returns x, z, nextIndex, completed. The input route is not mutated.
function EnemyPatrolRoute.step(route, currentX, currentZ, dt)
    if type(route) ~= "table" or type(route.points) ~= "table" or #route.points == 0 then
        return currentX, currentZ, 1, true
    end

    local x = tonumber(currentX) or 0
    local z = tonumber(currentZ) or 0
    local index = math.max(1, math.floor(tonumber(route.index) or 1))
    local remaining = math.max(0, tonumber(route.speed) or 0) * math.max(0, tonumber(dt) or 0)
    local arriveDistance = math.max(0, tonumber(route.arriveDistance) or 0)

    while index <= #route.points do
        local point = route.points[index]
        local dx = point.x - x
        local dz = point.z - z
        local distance = math.sqrt(dx * dx + dz * dz)
        if distance <= arriveDistance then
            if index == #route.points then
                return x, z, index, true
            end
            index += 1
        elseif remaining <= 0 then
            return x, z, index, false
        else
            local travel = math.min(distance, remaining)
            x += dx / distance * travel
            z += dz / distance * travel
            remaining -= travel
        end
    end

    return x, z, #route.points, true
end

return EnemyPatrolRoute
