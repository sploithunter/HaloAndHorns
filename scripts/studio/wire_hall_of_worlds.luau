--[[
    Idempotently binds the baked Workspace.Maps.FuturePath geometry to the Hall of Worlds
    gameplay contract. Run in Studio Edit mode after importing or moving the Hall map.

    This script authors markers, translucent progression walls, two-way travel gates, and
    physically placed Hall egg stands. Preview-only eggs sit on those stands until a route
    egg_id makes the bay live. It does not generate structural tiles.
]]

local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local hallConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("hall_of_worlds"))
local HallEggStand = require(
    ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("HallEggStand")
)
local HallPlayAreas = require(
    ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("HallPlayAreas")
)

local maps = workspace:FindFirstChild("Maps")
assert(maps, "Workspace.Maps is required")
local hall = maps:FindFirstChild("FuturePath")
local home = maps:FindFirstChild("Home")
assert(hall, "Workspace.Maps.FuturePath is required")
assert(home, "Workspace.Maps.Home is required")

local tiles = hall:FindFirstChild("Tiles")
local tile01 = tiles and tiles:FindFirstChild("Tile01_cap")
assert(tile01, "Workspace.Maps.FuturePath.Tiles.Tile01_cap is required")

local function ensureFolder(parent, name)
    local existing = parent:FindFirstChild(name)
    if existing and not existing:IsA("Folder") then
        existing:Destroy()
        existing = nil
    end
    if not existing then
        existing = Instance.new("Folder")
        existing.Name = name
        existing.Parent = parent
    end
    return existing
end

local function resetTags(instance, tags)
    for _, tag in ipairs(CollectionService:GetTags(instance)) do
        CollectionService:RemoveTag(instance, tag)
    end
    for _, tag in ipairs(tags) do
        CollectionService:AddTag(instance, tag)
    end
end

local function ensurePart(parent, name, size, cframe)
    local part = parent:FindFirstChild(name)
    if part and not part:IsA("Part") then
        part:Destroy()
        part = nil
    end
    if not part then
        part = Instance.new("Part")
        part.Name = name
        part.Parent = parent
    end
    part.Anchored = true
    part.Size = size
    part.CFrame = cframe
    return part
end

local function setAttributes(instance, attributes)
    for key, value in pairs(attributes) do
        instance:SetAttribute(key, value)
    end
end

local function anchorTree(root)
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
        end
    end
end

-- The barn and its fence were authored directly in the place. Adopt them into the first baked tile
-- so subsequent Hall moves/exports keep the encounter geometry together. Only root-level Hall
-- fence pieces in the authored coordinate envelope are adopted; realm fences are untouched.
local barn = hall:FindFirstChild("Barn") or tile01:FindFirstChild("Barn")
assert(barn, "The authored Hall Barn is required")
barn.Parent = tile01
barn:SetAttribute("HallEncounterId", "barn")
anchorTree(barn)

local barnFence = tile01:FindFirstChild("BarnFence") or Instance.new("Folder")
barnFence.Name = "BarnFence"
barnFence.Parent = tile01
for _, candidate in ipairs(workspace:GetChildren()) do
    if candidate:IsA("BasePart") and candidate.Name == "Fence" then
        local position = candidate.Position
        if
            position.X >= 1900
            and position.X <= 2300
            and position.Z >= -350
            and position.Z <= 50
        then
            candidate.Anchored = true
            candidate.Parent = barnFence
        end
    end
end
barnFence:SetAttribute("HallEncounterId", "barn")

local HALL_STAND = {
    modelAssetId = 124799395948890,
    textureId = "rbxassetid://81791717345802",
    targetMaxDimension = 12,
    eggHoverHeight = 1.25,
    eggTargetMaxDimension = (
        hallConfig.egg_stand and hallConfig.egg_stand.egg_target_max_dimension
    ) or 8,
}

local DORMANT_EGGS = {
    [2] = {
        displayName = "Gilded Gallery Egg",
        assetKey = "hall_gilded_egg",
        modelAssetId = 114164077732209,
        textureId = "rbxassetid://76870312052027",
        iconImageId = "92154990657326",
    },
    [3] = {
        displayName = "Vanguard Egg",
        assetKey = "vanguard_egg",
        modelAssetId = 84073314782695,
        textureId = "rbxassetid://106498438354720",
        iconImageId = "133582624829203",
    },
    [4] = {
        displayName = "Worldheart Egg",
        assetKey = "worldheart_egg",
        modelAssetId = 107303501881003,
        textureId = "rbxassetid://103667752364907",
        iconImageId = "75792210741748",
    },
}

local function configureDisplayTree(root, textureId)
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = true
            if descendant:IsA("MeshPart") and textureId ~= "" then
                descendant.TextureID = textureId
            end
        elseif descendant:IsA("ProximityPrompt") or descendant:IsA("BaseScript") then
            descendant:Destroy()
        end
    end
end

local function loadDisplayAsset(assetId, name, textureId)
    local asset
    local folder = ReplicatedStorage:FindFirstChild("PlaceAssets")
    local cached = folder and folder:FindFirstChild(tostring(assetId))
    if cached then
        asset = cached:Clone()
    else
        local ok, loaded = pcall(function()
            return InsertService:LoadAsset(assetId)
        end)
        assert(
            ok and loaded,
            ("Could not load Hall display asset %d: %s"):format(assetId, tostring(loaded))
        )
        asset = loaded
    end
    asset.Name = name
    configureDisplayTree(asset, textureId)
    return asset
end

local function scaleToMaxDimension(model, targetDimension)
    local _, size = model:GetBoundingBox()
    local largestDimension = math.max(size.X, size.Y, size.Z)
    if targetDimension > 0 and largestDimension > 0 then
        model:ScaleTo(model:GetScale() * targetDimension / largestDimension)
    end
end

local function sitOnFloor(model, x, z, floorY)
    local pivot = model:GetPivot()
    local _, yaw = pivot:ToEulerAnglesYXZ()
    model:PivotTo(CFrame.new(x, floorY, z) * CFrame.Angles(0, yaw, 0))
    local bounds, size = model:GetBoundingBox()
    local deltaY = HallEggStand.deltaYToSit(bounds.Position.Y, size.Y, floorY)
    model:PivotTo(model:GetPivot() + Vector3.new(0, deltaY, 0))
    return model:GetBoundingBox()
end

local function hallStandMesh(stand)
    local mesh = stand:FindFirstChild("hall_egg_stand", true)
    if mesh and mesh:IsA("BasePart") then
        return mesh
    end
    return nil
end

local function standMeshTopY(stand)
    local mesh = hallStandMesh(stand)
    if mesh then
        return mesh.Position.Y + mesh.Size.Y * 0.5
    end
    local maxY = -math.huge
    for _, descendant in ipairs(stand:GetDescendants()) do
        if
            descendant:IsA("BasePart")
            and descendant.Name ~= "UIanchor"
            and not descendant:FindFirstAncestor("DisplayEgg")
            and not descendant:FindFirstAncestor("PlacedEgg")
        then
            maxY = math.max(maxY, descendant.Position.Y + descendant.Size.Y * 0.5)
        end
    end
    if maxY == -math.huge then
        local bounds, size = stand:GetBoundingBox()
        return bounds.Position.Y + size.Y * 0.5
    end
    return maxY
end

local function alignHallStandToMesh(stand)
    local mesh = hallStandMesh(stand)
    if not mesh then
        return stand:GetPivot()
    end
    local _, yaw = mesh.CFrame:ToEulerAnglesYXZ()
    stand.WorldPivot = CFrame.new(mesh.Position.X, mesh.Position.Y, mesh.Position.Z)
        * CFrame.Angles(0, yaw, 0)
    return stand:GetPivot()
end

local function ensureUIanchor(stand, x, z)
    local anchor = stand:FindFirstChild("UIanchor")
    if anchor and not anchor:IsA("BasePart") then
        anchor:Destroy()
        anchor = nil
    end
    if not anchor then
        anchor = Instance.new("Part")
        anchor.Name = "UIanchor"
        anchor.Size = Vector3.new(1, 1, 1)
        anchor.Transparency = 1
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanTouch = false
        anchor.CanQuery = false
        anchor.Parent = stand
    end
    local pivot = alignHallStandToMesh(stand)
    local mesh = hallStandMesh(stand)
    local sourceX, sourceZ = HallEggStand.visualXZ(
        mesh and mesh.Position.X,
        mesh and mesh.Position.Z,
        tonumber(x) or pivot.Position.X,
        tonumber(z) or pivot.Position.Z
    )
    local cupX, cupY, cupZ =
        HallEggStand.cupPosition(sourceX, sourceZ, standMeshTopY(stand), HALL_STAND.eggHoverHeight)
    if cupX then
        local _, yaw = pivot:ToEulerAnglesYXZ()
        anchor.CFrame = CFrame.new(cupX, cupY, cupZ) * CFrame.Angles(0, yaw, 0)
    end
    return anchor
end

local function ensureDormantEggOnStand(stand, definition)
    local old = stand:FindFirstChild("DisplayEgg")
    if old then
        old:Destroy()
    end

    local egg = loadDisplayAsset(definition.modelAssetId, "DisplayEgg", definition.textureId)
    egg.Parent = stand
    scaleToMaxDimension(egg, HALL_STAND.eggTargetMaxDimension)
    local anchor = stand:FindFirstChild("UIanchor")
    local pos = anchor and anchor.Position or stand:GetPivot().Position
    local eggPivot = egg:GetPivot()
    egg:PivotTo(CFrame.new(pos) * (eggPivot - eggPivot.Position))
    setAttributes(egg, {
        PreviewOnly = true,
        Dormant = true,
        AwaitingConfiguration = true,
        BayIndex = stand:GetAttribute("BayIndex"),
        EggAssetKey = definition.assetKey,
        DisplayName = definition.displayName,
        IconImageId = definition.iconImageId,
        IdleFloatAmplitude = 0.3,
        IdleFloatPeriod = 3.4,
    })
    resetTags(egg, { "EggDisplay" })
end

local function ensureArea(parent, areaId, size, center, spawnPosition)
    local zone = ensurePart(parent, areaId .. "_AreaZone", size, CFrame.new(center))
    zone.Transparency = 1
    zone.CanCollide = false
    zone.CanTouch = true
    zone.CanQuery = false
    zone.CastShadow = false
    resetTags(zone, { "AreaZone" })
    setAttributes(zone, { AreaId = areaId })

    if spawnPosition ~= false then
        local spawnCFrame = typeof(spawnPosition) == "CFrame" and spawnPosition
            or CFrame.new(spawnPosition)
        local spawn =
            ensurePart(parent, areaId .. "_PlayerSpawn", Vector3.new(8, 1, 8), spawnCFrame)
        spawn.Transparency = 1
        spawn.CanCollide = false
        spawn.CanTouch = false
        spawn.CanQuery = false
        spawn.CastShadow = false
        resetTags(spawn, { "PlayerSpawn" })
        setAttributes(spawn, { AreaId = areaId, ZoneId = areaId })
    end
end

local function adoptHallSpawn()
    local spawnCfg = type(hallConfig.player_spawn) == "table" and hallConfig.player_spawn or {}
    local partName = spawnCfg.part_name or "HallSpawn"
    local areaId = spawnCfg.area_id or "Hall_1"
    local spawn = hall:FindFirstChild(partName)
    if spawn and not spawn:IsA("BasePart") then
        spawn:Destroy()
        spawn = nil
    end
    if not spawn then
        spawn = Instance.new("Part")
        spawn.Name = partName
        spawn.Size = Vector3.new(8, 1, 8)
        spawn.CFrame =
            CFrame.lookAt(Vector3.new(1897.8, 2.8, -314.7), Vector3.new(1818.9, 2.8, -317.9))
        spawn.Parent = hall
    end
    spawn.Transparency = 1
    spawn.Color = Color3.fromRGB(255, 214, 90)
    spawn.Material = Enum.Material.SmoothPlastic
    spawn.Anchored = true
    spawn.CanCollide = false
    spawn.CanTouch = false
    spawn.CanQuery = false
    spawn.CastShadow = false
    resetTags(spawn, { "PlayerSpawn" })
    setAttributes(spawn, { AreaId = areaId, ZoneId = areaId })
    local leftover = runtime:FindFirstChild(areaId .. "_PlayerSpawn")
    if leftover then
        leftover:Destroy()
    end
    return spawn
end

local function bindPlayArea(definition)
    local tileName = assert(definition.tile_name, "Hall play area requires tile_name")
    local zone = HallPlayAreas.bind(tiles, definition)
    assert(zone, "Missing Hall play-area tile or field " .. tostring(tileName))
end

local function ensureProgressionGate(parent, definition)
    local look = hallConfig.gate_appearance or {}
    local color = look.color or { 226, 236, 242 }
    local gate = ensurePart(parent, definition.name, definition.size, definition.cframe)
    gate.Material = Enum.Material[look.material or "Ice"] or Enum.Material.Ice
    gate.Color = Color3.fromRGB(color[1] or 226, color[2] or 236, color[3] or 242)
    gate.Transparency = look.transparency or 0.28
    gate.Reflectance = look.reflectance or 0.04
    gate.CanCollide = true
    gate.CanTouch = true
    gate.CanQuery = true
    gate.CastShadow = false
    resetTags(gate, { "HallGate", "Portal" })
    setAttributes(gate, {
        ZoneId = definition.source,
        AreaId = definition.source,
        TargetZoneId = definition.target,
        TargetAreaId = definition.target,
        ForcePrompt = true,
        -- Physical world-space height above the barrier floor. ZoneService converts this
        -- authored measurement into an Attachment, avoiding screen-size-dependent UI offsets.
        PromptHeightFromBottom = definition.promptHeightFromBottom or 4.5,
    })
    local staleLabel = gate:FindFirstChild("HallGateLabel")
    if staleLabel then
        staleLabel:Destroy()
    end
end

local function ensureComingSoonWall(parent, definition)
    local look = hallConfig.gate_appearance or {}
    local color = look.color or { 226, 236, 242 }
    local pos = definition.position or {}
    local size = definition.size or { 100, 28, 5 }
    local wall = ensurePart(
        parent,
        definition.name,
        Vector3.new(size[1], size[2], size[3]),
        CFrame.new(pos[1] or 0, pos[2] or 0, pos[3] or 0)
    )
    wall.Material = Enum.Material[look.material or "Ice"] or Enum.Material.Ice
    wall.Color = Color3.fromRGB(color[1] or 226, color[2] or 236, color[3] or 242)
    wall.Transparency = look.transparency or 0.28
    wall.Reflectance = look.reflectance or 0.04
    wall.CanCollide = true
    wall.CanTouch = false
    wall.CanQuery = true
    wall.CastShadow = false
    resetTags(wall, { "HallComingSoon" })
    setAttributes(wall, { ComingSoon = true })
end

local function ensurePortalTrigger(parent, name, cframe, source, target, hallExit, returnDoor)
    local trigger = ensurePart(parent, name, Vector3.new(12, 14, 8), cframe)
    trigger.Transparency = 1
    trigger.CanCollide = false
    trigger.CanTouch = true
    trigger.CanQuery = false
    trigger.CastShadow = false
    resetTags(trigger, { "Portal" })
    setAttributes(trigger, {
        ZoneId = source,
        AreaId = source,
        TargetZoneId = target,
        TargetAreaId = target,
        ForcePrompt = true,
        RequiresTutorialComplete = hallExit == true,
        HallExitToCrystalWorld = hallExit == true,
        CrystalWorldReturn = returnDoor == true,
    })
end

local function findLargestGate(root, excludedRoot)
    local best, bestVolume = nil, 0
    for _, candidate in ipairs(root:GetDescendants()) do
        if
            candidate:IsA("Model")
            and candidate.Name == "Gate"
            and not (excludedRoot and candidate:IsDescendantOf(excludedRoot))
        then
            local size = candidate:GetExtentsSize()
            local volume = size.X * size.Y * size.Z
            if volume > bestVolume then
                best, bestVolume = candidate, volume
            end
        end
    end
    return best
end

local function cloneGateVisual(template, parent, name, pivot)
    local old = parent:FindFirstChild(name)
    local savedLightning = old and old:FindFirstChild("ArchLightning")
    if savedLightning then
        savedLightning = savedLightning:Clone()
    end
    if old then
        old:Destroy()
    end
    local clone = template:Clone()
    clone.Name = name
    for _, descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = true
        elseif descendant:IsA("ProximityPrompt") or descendant:IsA("BaseScript") then
            descendant:Destroy()
        end
    end
    clone.Parent = parent
    -- Home Gate clones inherit a stale WorldPivot. PivotTo would park that
    -- pivot at `pivot` while the visible arch sits tens of studs away from
    -- the travel trigger. Center the pivot on the mesh first.
    local boxCf = clone:GetBoundingBox()
    clone.WorldPivot = CFrame.new(boxCf.Position)
    clone:PivotTo(pivot)
    if savedLightning then
        savedLightning.Parent = clone
    end
    return clone
end

local function ensureBillboard(parent, name, text, adornee, color)
    local gui = parent:FindFirstChild(name)
    if gui then
        gui:Destroy()
    end
    gui = Instance.new("BillboardGui")
    gui.Name = name
    if adornee:IsA("Model") then
        adornee = adornee.PrimaryPart or adornee:FindFirstChildWhichIsA("BasePart", true)
    end
    assert(adornee and adornee:IsA("BasePart"), "A gate label requires a BasePart adornee")
    gui.Adornee = adornee
    gui.AlwaysOnTop = true
    gui.Size = UDim2.fromScale(10, 2)
    gui.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
    gui.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBlack
    label.Text = text
    label.TextColor3 = color
    label.TextScaled = true
    label.TextStrokeTransparency = 0
    label.Parent = gui
end

local runtime = ensureFolder(hall, "HallRuntimeBindings")
local homeRuntime = ensureFolder(home, "HallRuntimeBindings")

local barnEncounter = assert(hallConfig.encounters.barn, "Hall barn encounter config is missing")
local barnCenter = barnEncounter.center
local barnSize = barnEncounter.size
local barnSpawner = ensurePart(
    tile01,
    barnEncounter.spawner_name,
    Vector3.new(barnSize.x, barnSize.y, barnSize.z),
    CFrame.new(barnCenter.x, barnCenter.y, barnCenter.z)
)
barnSpawner.Transparency = 1
barnSpawner.CanCollide = false
barnSpawner.CanTouch = false
barnSpawner.CanQuery = false
barnSpawner.CastShadow = false
setAttributes(barnSpawner, {
    AreaId = barnEncounter.area_id,
    ZoneId = barnEncounter.area_id,
    HallEncounterId = "barn",
    UseAreaCurrencyLoot = barnEncounter.use_area_currency_loot == true,
})

adoptHallSpawn()
ensureArea(runtime, "Hall_1", Vector3.new(570, 48, 690), Vector3.new(2000, 24, -223), false)
for _, child in ipairs(runtime:GetChildren()) do
    if child:IsA("BasePart") and string.match(child.Name, "^Hall_%d+_PlayArea$") then
        child:Destroy()
    end
end
for _, definition in pairs(assert(hallConfig.play_areas, "Hall play-area config is missing")) do
    bindPlayArea(definition)
end
ensureArea(
    runtime,
    "Hall_2",
    Vector3.new(350, 48, 394),
    Vector3.new(1950, 24, 323),
    Vector3.new(2000, 5, 208)
)
ensureArea(
    runtime,
    "Hall_3",
    Vector3.new(438, 48, 250),
    Vector3.new(2348, 24, 431),
    Vector3.new(2348, 5, 428)
)
ensureArea(
    runtime,
    "Hall_4",
    Vector3.new(564, 48, 700),
    Vector3.new(2568, 24, 914),
    Vector3.new(2568, 5, 982)
)

for _, definition in ipairs(hallConfig.progression_gates or {}) do
    local pos = definition.position or {}
    local size = definition.size or { 100, 28, 5 }
    ensureProgressionGate(runtime, {
        name = definition.name,
        source = definition.source,
        target = definition.target,
        size = Vector3.new(size[1], size[2], size[3]),
        cframe = CFrame.new(pos[1] or 0, pos[2] or 0, pos[3] or 0),
    })
end
for _, definition in ipairs((hallConfig.coming_soon and hallConfig.coming_soon.walls) or {}) do
    ensureComingSoonWall(runtime, definition)
end

local eggBayPositions = {
    -- Wayfinder was moved off Tile01 Archpad; do not snap it back onto the return door.
    Vector3.new(1818.9, 1, -317.9),
    -- Gilded stand mesh lives on the Tile03 play-field nook, not the old ShoulderDeck pivot.
    Vector3.new(2099.2, 1, 212.4),
    Vector3.new(2348, 1, 380),
    Vector3.new(2734.4, 1, 1190),
}

local function findNookFloorY(position)
    local bestAnchor, bestDist
    for _, inst in ipairs(hall:GetDescendants()) do
        if inst.Name == "Anchor_egg" and inst:IsA("BasePart") then
            local dist = (
                Vector3.new(inst.Position.X - position.X, 0, inst.Position.Z - position.Z)
            ).Magnitude
            if dist < 8 and (not bestDist or dist < bestDist) then
                bestAnchor, bestDist = inst, dist
            end
        end
    end
    if not bestAnchor then
        return nil
    end

    local padTop
    local parent = bestAnchor.Parent
    if parent then
        for _, sibling in ipairs(parent:GetChildren()) do
            if sibling.Name == "NookPad" and sibling:IsA("BasePart") then
                local dist = (Vector3.new(
                    sibling.Position.X - bestAnchor.Position.X,
                    0,
                    sibling.Position.Z - bestAnchor.Position.Z
                )).Magnitude
                if dist < 2 then
                    padTop = sibling.Position.Y + sibling.Size.Y * 0.5
                    break
                end
            end
        end
    end
    return HallEggStand.floorYFromNook(padTop, bestAnchor.Position.Y - bestAnchor.Size.Y * 0.5)
end

local function raycastFloorY(position)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { runtime }
    local result =
        workspace:Raycast(Vector3.new(position.X, 50, position.Z), Vector3.new(0, -120, 0), params)
    return result and result.Position.Y or nil
end

local function nearestSurfaceFloorY(position)
    local bestY, bestDist
    for _, inst in ipairs(hall:GetDescendants()) do
        if
            inst:IsA("BasePart")
            and inst.Transparency < 0.8
            and inst.Size.X >= 8
            and inst.Size.Z >= 8
            and inst.Size.Y <= 4
            and not inst:IsDescendantOf(runtime)
        then
            local localPos =
                inst.CFrame:PointToObjectSpace(Vector3.new(position.X, inst.Position.Y, position.Z))
            local onSurface = math.abs(localPos.X) <= inst.Size.X * 0.5
                and math.abs(localPos.Z) <= inst.Size.Z * 0.5
            local dist = (
                Vector3.new(inst.Position.X - position.X, 0, inst.Position.Z - position.Z)
            ).Magnitude
            if onSurface and (not bestDist or dist < bestDist) then
                bestDist = dist
                bestY = inst.Position.Y + inst.Size.Y * 0.5
            end
        end
    end
    return bestY
end

local function resolveStandFloorY(position)
    return findNookFloorY(position)
        or raycastFloorY(position)
        or nearestSurfaceFloorY(position)
        or -2.1
end

local function ensureAuthoredHallStand(parent, bayIndex, position, floorY, eggId)
    local name = "HallEggStand" .. tostring(bayIndex)
    local stand = parent:FindFirstChild(name) or hall:FindFirstChild(name, true)
    if stand and not stand:IsA("Model") then
        stand:Destroy()
        stand = nil
    end
    local created = false
    if not stand then
        stand = loadDisplayAsset(HALL_STAND.modelAssetId, name, HALL_STAND.textureId)
        stand.Parent = parent
        scaleToMaxDimension(stand, HALL_STAND.targetMaxDimension)
        created = true
    end

    local placed = stand:FindFirstChild("PlacedEgg")
    if placed then
        placed:Destroy()
    end
    local display = stand:FindFirstChild("DisplayEgg")
    if display then
        display:Destroy()
    end

    -- Do not snap a stand the user already placed. New stands still sit on the authored floor.
    if created then
        sitOnFloor(stand, position.X, position.Z, floorY)
        ensureUIanchor(stand, position.X, position.Z)
    else
        local pivot = stand:GetPivot()
        ensureUIanchor(stand, pivot.Position.X, pivot.Position.Z)
    end
    setAttributes(stand, {
        BayIndex = bayIndex,
        AreaId = "Hall_" .. bayIndex,
        EggId = eggId,
        AuthoredVisual = true,
    })
    return stand
end

for index, position in ipairs(eggBayPositions) do
    local routeEntry = hallConfig.route and hallConfig.route[index]
    local eggSpec = routeEntry and routeEntry.egg
    local eggId = eggSpec and eggSpec.egg_id
    local isConfigured = type(eggId) == "string" and eggId ~= ""
    local floorY = resolveStandFloorY(position)
    local bayName = "HallEggBay" .. index
    local marker = hall:FindFirstChild(bayName, true)
    if marker and not marker:IsA("Part") then
        marker:Destroy()
        marker = nil
    end
    if not marker then
        marker = ensurePart(
            runtime,
            bayName,
            Vector3.new(8, 1, 8),
            CFrame.new(position.X, floorY + 0.5, position.Z)
        )
    else
        marker.Size = Vector3.new(8, 1, 8)
        marker.Anchored = true
    end
    marker.Transparency = 1
    marker.CanCollide = false
    marker.CanTouch = false
    marker.CanQuery = false
    resetTags(marker, { "HallEggBay" })
    setAttributes(marker, {
        BayIndex = index,
        AreaId = "Hall_" .. index,
        PetChoiceCount = 5,
        EggId = eggId,
        AwaitingRoster = false,
        AwaitingConfiguration = not isConfigured,
    })

    local stand = ensureAuthoredHallStand(runtime, index, position, floorY, eggId)
    marker.CFrame = stand:GetPivot()
    marker.Parent = stand
    local definition = DORMANT_EGGS[index]
    if isConfigured then
        local preview = stand:FindFirstChild("DisplayEgg")
        if preview then
            preview:Destroy()
        end
    elseif definition then
        ensureDormantEggOnStand(stand, definition)
    end
end

local stalePreviews = runtime:FindFirstChild("DormantEggDisplays")
if stalePreviews then
    stalePreviews:Destroy()
end

local function homeFootprintFromHeavenPortal()
    local heaven = maps:FindFirstChild("Heaven_1")
    local portalHome = heaven and heaven:FindFirstChild("Portal_Home")
    assert(portalHome, "Heaven_1.Portal_Home is the Home-footprint source")
    local boxCf = portalHome:GetBoundingBox()
    -- Heaven_1 sits +2000Y. Drop the same XZ onto Home.
    local pos = boxCf.Position - Vector3.new(0, 2000, 0)
    local _, yaw = boxCf:ToEulerAnglesYXZ()
    return pos, yaw
end

local gateTemplate = findLargestGate(home, homeRuntime)
assert(gateTemplate, "A reusable Home Gate model is required")
local homeGatePos, homeGateYaw = homeFootprintFromHeavenPortal()

local crystalVisual = runtime:FindFirstChild("CrystalWorldGateVisual")
if not (crystalVisual and crystalVisual:IsA("Model")) then
    crystalVisual = cloneGateVisual(
        gateTemplate,
        runtime,
        "CrystalWorldGateVisual",
        CFrame.new(2770, 17, 970) * CFrame.Angles(0, math.rad(90), 0)
    )
end
ensureBillboard(
    runtime,
    "CrystalWorldGateTitle",
    "CRYSTAL WORLD",
    crystalVisual,
    Color3.fromRGB(90, 238, 255)
)
local crystalBox = crystalVisual:GetBoundingBox()
ensurePortalTrigger(
    runtime,
    "CrystalWorldPortal",
    CFrame.new(crystalBox.Position.X, 7, crystalBox.Position.Z),
    "Hall_4",
    "Spawn",
    true
)

local returnCfg = hallConfig.crystal_world_return or {}
local returnTile = tiles and tiles:FindFirstChild(returnCfg.tile_name or "Tile01_cap")
local archpad = returnTile and returnTile:FindFirstChild(returnCfg.pad_name or "Archpad")
assert(archpad and archpad:IsA("BasePart"), "Tile01_cap.Archpad is the Crystal World return pad")
local returnLook = archpad.CFrame.LookVector
local returnYaw = math.atan2(-returnLook.X, -returnLook.Z)
local returnPos = archpad.Position
local returnSource = returnCfg.source_area or "Hall_1"
local returnTarget = returnCfg.target_area or "Spawn"
local returnVisual = cloneGateVisual(
    gateTemplate,
    runtime,
    "CrystalWorldReturnGateVisual",
    CFrame.new(returnPos.X, returnPos.Y + 19.5, returnPos.Z) * CFrame.Angles(0, returnYaw, 0)
)
ensureBillboard(
    runtime,
    "CrystalWorldReturnGateTitle",
    returnCfg.title or "CRYSTAL WORLD",
    returnVisual,
    Color3.fromRGB(90, 238, 255)
)
ensurePortalTrigger(
    runtime,
    "CrystalWorldReturnPortal",
    CFrame.new(returnPos.X, returnPos.Y + 9.5, returnPos.Z) * CFrame.Angles(0, returnYaw, 0),
    returnSource,
    returnTarget,
    false,
    true
)

local hallVisual = cloneGateVisual(
    gateTemplate,
    homeRuntime,
    "HallOfWorldsGateVisual",
    CFrame.new(homeGatePos.X, 17, homeGatePos.Z) * CFrame.Angles(0, homeGateYaw, 0)
)
ensureBillboard(
    homeRuntime,
    "HallOfWorldsGateTitle",
    "HALL OF WORLDS",
    hallVisual,
    Color3.fromRGB(255, 218, 75)
)
ensurePortalTrigger(
    homeRuntime,
    "HallOfWorldsPortal",
    CFrame.new(homeGatePos.X, 7, homeGatePos.Z) * CFrame.Angles(0, homeGateYaw, 0),
    "Spawn",
    "Hall_1",
    false
)

local function adoptChallengeDoor(partName, missionId, title, fallbackCFrame)
    local pad = hall:FindFirstChild(partName, true)
    if pad and not pad:IsA("BasePart") then
        pad:Destroy()
        pad = nil
    end
    if not pad then
        pad = Instance.new("Part")
        pad.Name = partName
        pad.Size = Vector3.new(12, 1, 12)
        pad.CFrame = fallbackCFrame
        pad.Parent = hall
    end
    pad.Anchored = true
    pad.Transparency = 1
    pad.CanCollide = false
    pad.CanTouch = false
    pad.CanQuery = true
    pad.CastShadow = false
    resetTags(pad, { "MissionDoor" })
    setAttributes(pad, { MissionId = missionId })

    local visualName = partName .. "GateVisual"
    local visual = runtime:FindFirstChild(visualName)
    if not visual then
        local look = pad.CFrame.LookVector
        local pivot = CFrame.lookAt(
            pad.Position + Vector3.new(0, 19.5, 0),
            pad.Position + Vector3.new(0, 19.5, 0) + Vector3.new(look.X, 0, look.Z)
        )
        visual = cloneGateVisual(gateTemplate, runtime, visualName, pivot)
    end
    ensureBillboard(runtime, partName .. "Title", title, visual, Color3.fromRGB(255, 180, 70))
    return pad
end

-- Pads sit at the gate visual's XZ (prompt parents to the pad). After a
-- gate rotate, move the pad to the arch — do not leave it on the old
-- approach. Adopt in place; do not snap a user-moved pad back to these
-- fallbacks if the part already exists.
local homeChallenges = home:FindFirstChild("ChallengeBindings")
local challengesRelocated = homeChallenges
    and homeChallenges:FindFirstChild("RangePad")
    and homeChallenges:FindFirstChild("TrainingGroundPad")
if not challengesRelocated then
    adoptChallengeDoor(
        "RangePad",
        "range",
        "THE RANGE",
        CFrame.lookAt(Vector3.new(1945.1, 0.8, 400), Vector3.new(1945.1, 0.8, 399))
    )
    adoptChallengeDoor(
        "TrainingGroundPad",
        "training_ground",
        "TRAINING GROUND",
        CFrame.lookAt(Vector3.new(2623.6, 0.8, 465.1), Vector3.new(2623.6, 0.8, 464.1))
    )
else
    print("[HallOfWorlds] preserving relocated Home.ChallengeBindings challenge fixtures")
end

print(
    string.format(
        "[HallOfWorlds] adopted the barn/fence, wired its encounter, 4 areas, Hall play-area marquee/spawner bounds, 3 progression walls, 4 egg bays, 3 dormant egg displays, and 3 travel gates under %s",
        hall:GetFullName()
    )
)
