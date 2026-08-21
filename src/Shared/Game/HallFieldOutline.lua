--[[
    HallFieldOutline — the authored green-field / white-kerb loop.

    The visible outline is FieldKerb + FieldKerbCorner (fallback Field / FieldCorner).
    SpawnZone is only the inscribed spawn marker; it does not match corner pentagons.
    Marquee and breakable slots both resolve through this helper so they stay aligned.
]]

local RoundedOutline = require(script.Parent.RoundedOutline)
local SpawnSlots = require(script.Parent.SpawnSlots)

local HallFieldOutline = {}

local function cylinderCorners(zone, name)
    local parent = zone.Parent
    if not parent then
        return {}
    end

    local corners = {}
    for _, inst in ipairs(parent:GetDescendants()) do
        if inst.Name == name and inst:IsA("BasePart") then
            local localPos = zone.CFrame:PointToObjectSpace(inst.Position)
            corners[#corners + 1] = {
                x = localPos.X,
                z = localPos.Z,
                r = math.max(inst.Size.X, inst.Size.Z) * 0.5,
            }
        end
    end
    return corners
end

function HallFieldOutline.corners(zone)
    if not zone then
        return {}
    end
    local kerb = cylinderCorners(zone, "FieldKerbCorner")
    if #kerb >= 3 then
        return kerb
    end
    return cylinderCorners(zone, "FieldCorner")
end

function HallFieldOutline.bounds(zone)
    local parent = zone and zone.Parent
    if not parent then
        return nil
    end

    local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
    local found = false
    for _, inst in ipairs(parent:GetDescendants()) do
        if (inst.Name == "FieldKerb" or inst.Name == "Field") and inst:IsA("BasePart") then
            found = true
            local localCf = zone.CFrame:ToObjectSpace(inst.CFrame)
            local halfX, halfZ = inst.Size.X * 0.5, inst.Size.Z * 0.5
            for _, offsetX in ipairs({ -halfX, halfX }) do
                for _, offsetZ in ipairs({ -halfZ, halfZ }) do
                    local point = localCf * Vector3.new(offsetX, 0, offsetZ)
                    minX = math.min(minX, point.X)
                    maxX = math.max(maxX, point.X)
                    minZ = math.min(minZ, point.Z)
                    maxZ = math.max(maxZ, point.Z)
                end
            end
        end
    end
    if not found then
        return nil
    end
    return {
        width = maxX - minX,
        depth = maxZ - minZ,
        center_x = (minX + maxX) * 0.5,
        center_z = (minZ + maxZ) * 0.5,
    }
end

function HallFieldOutline.encode(zone, inset)
    inset = math.max(0, tonumber(inset) or 0)
    local corners = HallFieldOutline.corners(zone)
    if #corners >= 3 then
        local radius = math.max(0, (tonumber(corners[1].r) or 0) - inset)
        return RoundedOutline.forPlayArea({
            corners = corners,
            field_radius = radius,
        })
    end

    local bounds = HallFieldOutline.bounds(zone)
    if not bounds then
        return nil
    end
    return RoundedOutline.forPlayArea({
        width = math.max(0, bounds.width - inset * 2),
        depth = math.max(0, bounds.depth - inset * 2),
        center_x = bounds.center_x,
        center_z = bounds.center_z,
    })
end

function HallFieldOutline.area(zone, inset)
    local outline = SpawnSlots.parseOutline(HallFieldOutline.encode(zone, inset))
    local polyArea = SpawnSlots.polygonArea(outline)
    if polyArea > 0 then
        return polyArea
    end
    local bounds = HallFieldOutline.bounds(zone)
    if bounds then
        return bounds.width * bounds.depth
    end
    if zone then
        return math.max(0, tonumber(zone.Size.X) or 0) * math.max(0, tonumber(zone.Size.Z) or 0)
    end
    return 0
end

function HallFieldOutline.ensureAttribute(zone, inset)
    local encoded = HallFieldOutline.encode(zone, inset)
    if encoded then
        zone:SetAttribute("OutlinePath", encoded)
    end
    return encoded
end

return HallFieldOutline
