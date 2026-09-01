-- Pure air-fling path for the Repulsor cannon. Same parabola as tower
-- shot loft: height peaks at mid-flight, then the chassis lands and
-- recovers. Tumble is a full-spin angle the client layers on.

local MergeCannonFling = {}

function MergeCannonFling.point(startX, startY, startZ, destX, destY, destZ, height, alpha)
    alpha = tonumber(alpha) or 0
    if alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end
    height = math.max(0, tonumber(height) or 0)
    startX, startY, startZ = tonumber(startX) or 0, tonumber(startY) or 0, tonumber(startZ) or 0
    destX, destY, destZ = tonumber(destX) or 0, tonumber(destY) or 0, tonumber(destZ) or 0
    local x = startX + (destX - startX) * alpha
    local z = startZ + (destZ - startZ) * alpha
    local y = startY + (destY - startY) * alpha + 4 * height * alpha * (1 - alpha)
    return x, y, z
end

function MergeCannonFling.tumble(alpha, spins, sign)
    alpha = tonumber(alpha) or 0
    if alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end
    spins = tonumber(spins) or 1
    sign = (tonumber(sign) or 1) >= 0 and 1 or -1
    return spins * sign * alpha * math.pi * 2
end

-- Knockback/fling may climb a short step or drop a short step. A cliff
-- (off the playfield onto the stock baseplate) is not a legal landing.
function MergeCannonFling.keepStep(fromY, toY, climbMax, dropMax)
    fromY = tonumber(fromY) or 0
    toY = tonumber(toY) or 0
    climbMax = math.max(0, tonumber(climbMax) or 10)
    dropMax = math.max(0, tonumber(dropMax) or 10)
    local rise = toY - fromY
    return rise <= climbMax and rise >= -dropMax
end

function MergeCannonFling.hitRoll(chance, sample)
    chance = tonumber(chance)
    if chance == nil then
        return true
    end
    chance = math.clamp(chance, 0, 1)
    sample = tonumber(sample)
    if sample == nil then
        return true
    end
    return sample < chance
end

return MergeCannonFling
