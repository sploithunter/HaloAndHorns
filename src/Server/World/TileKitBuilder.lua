--[[
    TileKitBuilder — turns a pure tile-kit (definition + part specs) into a
    folder of tile Models the MissionStamper can clone.

    Consumes the GrayBoxKit shape (docs/MISSION_WORLDGEN.md §2):
        kit.definition() → TileCatalog kit def (ids, classes, bounds, doors)
        kit.parts(tile)  → primitive part specs (see GrayBoxKit header)

    build(kit, parent) → Folder named <kitId> with one Model per tile:
        Model.PrimaryPart = TileRoot (pivot at floor-center, per contract)
        Model attributes: TileClass, Weight, MaxPerMap
        Parts: anchored; tags via CollectionService; attributes verbatim
        (hook attrs keep their $MISSION placeholders — the stamper rewrites)

    NOTE parent: at runtime the canonical store is
    ReplicatedStorage.Assets.Models.MissionTiles (AssetPreloadService-style
    augmentation). In EDIT mode that subtree is Rojo-owned (Models.rbxm) —
    build into a scratch parent instead so Rojo never fights the kit.
]]

local CollectionService = game:GetService("CollectionService")

local TileKitBuilder = {}

local DIR_LOOK = {
    px = Vector3.new(1, 0, 0),
    nx = Vector3.new(-1, 0, 0),
    pz = Vector3.new(0, 0, 1),
    nz = Vector3.new(0, 0, -1),
}

local function buildPart(spec)
    local part = Instance.new("Part")
    part.Name = spec.name
    if spec.shape == "Ball" then
        part.Shape = Enum.PartType.Ball
    elseif spec.shape == "Cylinder" then
        part.Shape = Enum.PartType.Cylinder
    end
    part.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
    local pos = Vector3.new(spec.pos[1], spec.pos[2], spec.pos[3])
    if spec.face then
        part.CFrame = CFrame.lookAt(pos, pos + DIR_LOOK[spec.face])
    else
        part.CFrame = CFrame.new(pos)
    end
    if spec.tilt then
        -- in-plane roll (boarded-up cap planks etc.)
        part.CFrame = part.CFrame * CFrame.Angles(0, 0, math.rad(spec.tilt))
    end
    if spec.pitch then
        -- slope about X (mezzanine ramps)
        part.CFrame = part.CFrame * CFrame.Angles(math.rad(spec.pitch), 0, 0)
    end
    part.Anchored = true
    part.CanCollide = spec.canCollide ~= false
    part.CanTouch = false
    part.CanQuery = spec.canQuery ~= false
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Material = Enum.Material[spec.material or "SmoothPlastic"]
    part.Transparency = spec.transparency or 0
    if spec.color then
        part.Color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
    end
    for _, tag in ipairs(spec.tags or {}) do
        CollectionService:AddTag(part, tag)
    end
    for name, value in pairs(spec.attrs or {}) do
        part:SetAttribute(name, value)
    end
    -- M5a dressing: specs may carry a light (doorway torches etc.)
    if spec.light then
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(spec.light.color[1], spec.light.color[2], spec.light.color[3])
        light.Brightness = spec.light.brightness or 1
        light.Range = spec.light.range or 16
        light.Shadows = spec.light.shadows == true
        light.Parent = part
    end
    return part
end

function TileKitBuilder.build(kit, parent)
    local def = kit.definition()
    local folder = Instance.new("Folder")
    folder.Name = def.kitId

    for _, tile in ipairs(def.tiles) do
        local model = Instance.new("Model")
        model.Name = tile.id
        model:SetAttribute("TileClass", tile.class)
        model:SetAttribute("Weight", tile.weight or 1)
        model:SetAttribute("MaxPerMap", tile.maxPerMap or 0)

        local root
        for _, spec in ipairs(kit.parts(tile)) do
            local part = buildPart(spec)
            part.Parent = model
            if spec.name == "TileRoot" then
                root = part
            end
        end
        assert(root, ("TileKitBuilder: tile %q emitted no TileRoot"):format(tile.id))
        model.PrimaryPart = root
        model.Parent = folder
    end

    folder.Parent = parent
    return folder
end

return TileKitBuilder
