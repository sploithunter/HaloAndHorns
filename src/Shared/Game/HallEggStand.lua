--[[
    HallEggStand — placement math for authored Hall hatcher pedestals.

    Crystal World stands are physically placed in the map. Hall stands follow the
    same contract: the Studio wiring pass authors the pedestal on the real floor,
    and runtime only places the egg on UIanchor. Invisible marker tops are not floors.
]]

local HallEggStand = {}

-- Vertical shift that seats an AABB on floorY. Positive moves the model up.
function HallEggStand.deltaYToSit(bboxCenterY, bboxHeight, floorY)
    bboxCenterY = tonumber(bboxCenterY)
    bboxHeight = tonumber(bboxHeight)
    floorY = tonumber(floorY)
    if not bboxCenterY or not bboxHeight or not floorY then
        return 0
    end
    return floorY - (bboxCenterY - bboxHeight * 0.5)
end

-- Prefer the visible pedestal mesh. A dragged MeshPart leaves GetPivot() behind.
function HallEggStand.visualXZ(meshX, meshZ, pivotX, pivotZ)
    if tonumber(meshX) and tonumber(meshZ) then
        return meshX, meshZ
    end
    return tonumber(pivotX), tonumber(pivotZ)
end

-- Egg sits on the stand cup: stand XZ and mesh-top Y plus a small hover.
function HallEggStand.cupPosition(standX, standZ, meshTopY, hoverHeight)
    standX = tonumber(standX)
    standZ = tonumber(standZ)
    meshTopY = tonumber(meshTopY)
    if not (standX and standZ and meshTopY) then
        return nil
    end
    return standX, meshTopY + (tonumber(hoverHeight) or 0), standZ
end

-- Authored egg nooks use a NookPad with an Anchor_egg cube sitting on it.
-- Prefer the pad top; the cube bottom is the same plane when the pad is missing.
function HallEggStand.floorYFromNook(nookPadTopY, anchorBottomY)
    local pad = tonumber(nookPadTopY)
    if pad then
        return pad
    end
    return tonumber(anchorBottomY)
end

-- Distance from a point to an axis-aligned box. Zero when the point is inside.
function HallEggStand.distanceToAabb(px, py, pz, cx, cy, cz, sx, sy, sz)
    px, py, pz = tonumber(px), tonumber(py), tonumber(pz)
    cx, cy, cz = tonumber(cx), tonumber(cy), tonumber(cz)
    sx, sy, sz = tonumber(sx), tonumber(sy), tonumber(sz)
    if not (px and py and pz and cx and cy and cz and sx and sy and sz) then
        return math.huge
    end
    local dx = math.max(math.abs(px - cx) - sx * 0.5, 0)
    local dy = math.max(math.abs(py - cy) - sy * 0.5, 0)
    local dz = math.max(math.abs(pz - cz) - sz * 0.5, 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function HallEggStand.hatcherDistance(rootX, rootY, rootZ, anchorX, anchorY, anchorZ, box)
    local best = math.huge
    if tonumber(anchorX) and tonumber(anchorY) and tonumber(anchorZ) then
        local dx = anchorX - rootX
        local dy = anchorY - rootY
        local dz = anchorZ - rootZ
        best = math.min(best, math.sqrt(dx * dx + dy * dy + dz * dz), math.sqrt(dx * dx + dz * dz))
    end
    if type(box) == "table" then
        best = math.min(
            best,
            HallEggStand.distanceToAabb(
                rootX,
                rootY,
                rootZ,
                box.x,
                box.y,
                box.z,
                box.sx,
                box.sy,
                box.sz
            )
        )
    end
    return best
end

return HallEggStand
