--[[
    HallPlayAreas — adopt every configured Hall green field as a play area.

    Corridor tiles (Tile02 / Tile05 / Tile08) have authored Field pads but no
    baked SpawnZone. Bind creates that marker from the field AABB and tags it
    the same way the cap/playfield/corner markers already are. Existing
    markers are adopted in place and never snapped.
]]

local CollectionService = game:GetService("CollectionService")

local HallFieldOutline = require(script.Parent.HallFieldOutline)

local HallPlayAreas = {}

local function applyZone(zone, definition)
    zone.Transparency = 1
    zone.CanCollide = false
    zone.CanTouch = false
    zone.CanQuery = false
    zone.CastShadow = false
    if not CollectionService:HasTag(zone, "SpawnZone") then
        CollectionService:AddTag(zone, "SpawnZone")
    end
    if not CollectionService:HasTag(zone, "HallPlayArea") then
        CollectionService:AddTag(zone, "HallPlayArea")
    end

    local marquee = type(definition.marquee) == "table" and definition.marquee or {}
    zone:SetAttribute("AreaId", definition.area_id)
    zone:SetAttribute("SpawnerId", definition.spawner_id or "spawn_crystals")
    zone:SetAttribute("OutlinePath", HallFieldOutline.encode(zone))
    zone:SetAttribute("SlotLayout", definition.slot_layout or "random")
    zone:SetAttribute("DashLength", marquee.dash_length or 4.5)
    zone:SetAttribute("DashWidth", marquee.dash_width or 1.3)
    zone:SetAttribute("DashHeight", marquee.dash_height or 0.4)
    zone:SetAttribute("DashSpacing", marquee.dash_spacing or 8)
    zone:SetAttribute("MarqueeSpeed", marquee.speed or 14)
    return zone
end

function HallPlayAreas.bind(tiles, definition)
    if typeof(tiles) ~= "Instance" or type(definition) ~= "table" then
        return nil
    end
    local tileName = definition.tile_name
    local areaId = definition.area_id
    if type(tileName) ~= "string" or type(areaId) ~= "string" then
        return nil
    end
    local tile = tiles:FindFirstChild(tileName)
    if not tile then
        return nil
    end

    local markerName = definition.marker_name or "SpawnZone"
    local zone = tile:FindFirstChild(markerName)
    if not (zone and zone:IsA("BasePart")) then
        local bounds = HallFieldOutline.worldBounds(tile)
        if not bounds then
            return nil
        end
        zone = Instance.new("Part")
        zone.Name = markerName
        zone.Anchored = true
        zone.Size = Vector3.new(math.max(1, bounds.width), 0.5, math.max(1, bounds.depth))
        zone.CFrame = CFrame.new(bounds.x, bounds.y, bounds.z)
        zone.Parent = tile
    end

    return applyZone(zone, definition)
end

function HallPlayAreas.bindAll(tiles, playAreas)
    local bound = 0
    if type(playAreas) ~= "table" then
        return bound
    end
    for _, definition in pairs(playAreas) do
        if HallPlayAreas.bind(tiles, definition) then
            bound += 1
        end
    end
    return bound
end

return HallPlayAreas
