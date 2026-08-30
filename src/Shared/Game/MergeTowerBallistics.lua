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

return MergeTowerBallistics
