-- Pure parabolic flight for Merge edge-tower projectiles.
--
-- XZ lerp plus a 4 * h * t * (1-t) apex so t=0 and t=1 sit on the endpoints and t=0.5 is the
-- peak. Numbers only so headless tests can load this without Vector3.

local MergeTowerBallistics = {}

local function clamp01(alpha)
    alpha = tonumber(alpha) or 0
    if alpha < 0 then
        return 0
    end
    if alpha > 1 then
        return 1
    end
    return alpha
end

function MergeTowerBallistics.point(ox, oy, oz, tx, ty, tz, apexHeight, alpha)
    alpha = clamp01(alpha)
    local height = math.max(0, tonumber(apexHeight) or 0)
    local x = ox + (tx - ox) * alpha
    local z = oz + (tz - oz) * alpha
    local y = oy + (ty - oy) * alpha + 4 * height * alpha * (1 - alpha)
    return x, y, z
end

function MergeTowerBallistics.launchDelta(ox, oy, oz, tx, ty, tz, apexHeight)
    local height = math.max(0, tonumber(apexHeight) or 0)
    return (tx - ox), (ty - oy) + 4 * height, (tz - oz)
end

local function unitOrNil(x, y, z)
    local magnitude = math.sqrt(x * x + y * y + z * z)
    if magnitude < 1e-6 then
        return nil
    end
    return x / magnitude, y / magnitude, z / magnitude
end

-- Flatten a world delta onto the pad so yaw-only aim never pitches the chassis.
function MergeTowerBallistics.planarYaw(dx, _dy, dz)
    local x, _, z = unitOrNil(dx, 0, dz)
    if not x then
        return 1, 0, 0
    end
    return x, 0, z
end

-- The authored cannon mesh is longest on local +X, so the barrel is RightVector,
-- not LookVector. Returns right, up, look as nine numbers for a CFrame.fromMatrix.
-- Callers that want a flat turret pass a planar yaw; the fireball arc carries loft.
function MergeTowerBallistics.barrelBasis(dx, dy, dz)
    local rx, ry, rz = unitOrNil(dx, dy, dz)
    if not rx then
        rx, ry, rz = 1, 0, 0
    end
    -- look = world-up × right so the chassis stays upright while +X follows the shot.
    local lx, ly, lz = unitOrNil(rz, 0, -rx)
    if not lx then
        lx, ly, lz = 0, 0, -1
    end
    local ux = ry * lz - rz * ly
    local uy = rz * lx - rx * lz
    local uz = rx * ly - ry * lx
    return rx, ry, rz, ux, uy, uz, lx, ly, lz
end

return MergeTowerBallistics
