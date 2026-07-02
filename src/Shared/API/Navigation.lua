--[[
    Navigation (pure)

    The functional core of the automation movement driver. These helpers do the
    waypoint-following arithmetic with plain numbers — no Vector3, no Roblox API
    — so the tricky part (arrival thresholds, advancing through a path, stuck
    detection) is unit-tested headlessly while AutomationService handles the
    Roblox-side I/O (PathfindingService, Humanoid:MoveTo).

    Purity contract: standard Lua only. Tested via `mise run test-headless`.
]]

local Navigation = {}

-- Horizontal (XZ-plane) distance between two points. Y is ignored because
-- arrival is judged on the ground plane — a character standing under/over a
-- waypoint has still "arrived" horizontally.
function Navigation.planarDistance(ax, az, bx, bz)
    local dx = ax - bx
    local dz = az - bz
    return math.sqrt((dx * dx) + (dz * dz))
end

-- Full 3D distance, for callers that need it (e.g. vertical traversal checks).
function Navigation.distance3(ax, ay, az, bx, by, bz)
    local dx = ax - bx
    local dy = ay - by
    local dz = az - bz
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

-- True once the character is within `threshold` studs of the current waypoint.
function Navigation.hasArrived(distance, threshold)
    return distance <= threshold
end

--[[
    Decide the next waypoint index given the character's distance to the current
    one. Returns (nextIndex, done):
      • not yet within threshold        → (index, false)   keep walking
      • arrived and more waypoints left → (index + 1, false) advance
      • arrived and on the last one     → (index, true)    path complete

    `total` is the number of waypoints (1-based indices).
]]
function Navigation.advanceWaypoint(index, distance, threshold, total)
    if not Navigation.hasArrived(distance, threshold) then
        return index, false
    end
    if index >= total then
        return index, true
    end
    return index + 1, false
end

--[[
    Stuck detection: given the distance moved since the last sample, report
    whether the character has made meaningful progress. `epsilon` is the minimum
    distance considered progress. Used to bail out (or re-issue a MoveTo) when
    the control module fights the movement and the character stalls.
]]
function Navigation.madeProgress(distanceMovedSinceLastSample, epsilon)
    return distanceMovedSinceLastSample > epsilon
end

return Navigation
