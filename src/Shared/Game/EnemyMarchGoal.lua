--[[
    EnemyMarchGoal — pure forward movement toward one authored destination.

    EnemyService advances the goal only while the enemy is idle. Combat may pull it off course;
    after disengagement, movement resumes from the enemy's latest authoritative position.
]]

local EnemyMarchGoal = {}

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

function EnemyMarchGoal.new(config)
    if type(config) ~= "table" then
        return nil
    end
    local destination = config.destination
    local x = coordinate(destination, "X", "x")
    local y = coordinate(destination, "Y", "y")
    local z = coordinate(destination, "Z", "z")
    if not (x and z) then
        return nil
    end

    local speed = tonumber(config.speed) or 8
    local arriveDistance = tonumber(config.arriveDistance) or 2
    if speed <= 0 or arriveDistance < 0 then
        return nil
    end
    return {
        destination = { x = x, y = y or 0, z = z },
        speed = speed,
        arriveDistance = arriveDistance,
    }
end

-- Returns x, z, reached. The input goal is not mutated.
function EnemyMarchGoal.step(goal, currentX, currentZ, dt)
    if type(goal) ~= "table" or type(goal.destination) ~= "table" then
        return currentX, currentZ, true
    end

    local x = tonumber(currentX) or 0
    local z = tonumber(currentZ) or 0
    local dx = goal.destination.x - x
    local dz = goal.destination.z - z
    local distance = math.sqrt(dx * dx + dz * dz)
    local arriveDistance = math.max(0, tonumber(goal.arriveDistance) or 0)
    if distance <= arriveDistance then
        return x, z, true
    end

    local travel =
        math.min(distance, math.max(0, tonumber(goal.speed) or 0) * math.max(0, tonumber(dt) or 0))
    if travel > 0 then
        x += dx / distance * travel
        z += dz / distance * travel
    end
    local remainingX = goal.destination.x - x
    local remainingZ = goal.destination.z - z
    local reached = math.sqrt(remainingX * remainingX + remainingZ * remainingZ) <= arriveDistance
    return x, z, reached
end

return EnemyMarchGoal
