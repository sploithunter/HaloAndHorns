-- Pure endpoint selection and proximity policy for authored Hell-gate ambient lightning.
local HellGateLightning = {}

function HellGateLightning.roles(markers, contract)
    local result = { sky = {}, inner = {}, crown = {}, left = {}, right = {}, targets = {} }
    local seen = {}
    for _, role in ipairs({ "sky", "inner", "crown", "left", "right" }) do
        for _, name in ipairs(contract[role] or {}) do
            local point = markers[name]
            if point and not seen[point] then
                seen[point] = true
                table.insert(result[role], point)
                if role ~= "sky" then
                    table.insert(result.targets, point)
                end
            end
        end
    end
    return result
end

-- The sky marker is hundreds of studs overhead: proximity is to the lower gate,
-- never the sky point or a bounding box expanded by that point.
function HellGateLightning.distanceSquared(points, here)
    local nearest = math.huge
    for _, point in ipairs(points) do
        local dx, dy, dz = point.x - here.x, point.y - here.y, point.z - here.z
        nearest = math.min(nearest, dx * dx + dy * dy + dz * dz)
    end
    return nearest
end

function HellGateLightning.nearest(gates, here, radius, limit)
    local candidates = {}
    for _, gate in ipairs(gates) do
        local distance = HellGateLightning.distanceSquared(gate.roles.targets, here)
        if distance <= radius * radius then
            table.insert(candidates, { gate = gate, distance = distance })
        end
    end
    table.sort(candidates, function(a, b)
        if a.distance == b.distance then
            return a.gate.id < b.gate.id
        end
        return a.distance < b.distance
    end)
    local result = {}
    for index = 1, math.min(limit, #candidates) do
        table.insert(result, candidates[index].gate)
    end
    return result
end

function HellGateLightning.pick(roles, kind, side, randomIndex)
    local origins = kind == "sky" and roles.sky or roles.inner
    local targets = kind == "sky" and roles.targets or roles[side]
    if not origins or not targets or #origins == 0 or #targets == 0 then
        return nil, nil
    end
    return origins[randomIndex(#origins)], targets[randomIndex(#targets)]
end

-- One due pulse per channel; a long suspended frame never queues catch-up bursts.
function HellGateLightning.nextAt(now, interval, roll)
    return now + interval[1] + (interval[2] - interval[1]) * roll
end

return HellGateLightning
