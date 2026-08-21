--[[
    EggHatchFront — hatch ViewportFrame camera sits in front of the authored
    egg. World clones keep their stand yaw; a fixed +Z camera would show the
    side of a +X-facing Hall egg.
]]

local EggHatchFront = {}

function EggHatchFront.flatLook(lookX, lookZ)
    lookX = tonumber(lookX) or 0
    lookZ = tonumber(lookZ) or 0
    local mag = math.sqrt(lookX * lookX + lookZ * lookZ)
    if mag < 1e-4 then
        return 0, -1
    end
    return lookX / mag, lookZ / mag
end

function EggHatchFront.cameraPose(lookX, lookZ, focusY, distance)
    local lx, lz = EggHatchFront.flatLook(lookX, lookZ)
    focusY = tonumber(focusY) or 0
    distance = tonumber(distance) or 1
    if distance < 0.1 then
        distance = 0.1
    end
    return {
        x = lx * distance,
        y = focusY,
        z = lz * distance,
        lookX = -lx,
        lookY = 0,
        lookZ = -lz,
    }
end

function EggHatchFront.cameraCFrame(lookX, lookZ, focusY, distance)
    local pose = EggHatchFront.cameraPose(lookX, lookZ, focusY, distance)
    return CFrame.lookAt(Vector3.new(pose.x, pose.y, pose.z), Vector3.new(0, pose.y, 0))
end

return EggHatchFront
