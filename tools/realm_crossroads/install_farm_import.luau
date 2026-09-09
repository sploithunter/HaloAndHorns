-- Additive Edit-only import. No spawn/travel/gameplay activation and no global atmosphere changes.
return function(package, cfg)
    assert(not game:GetService("RunService"):IsRunning(), "Stop destination Play")
    assert(game.PlaceId == cfg.destination_place_id, "Wrong destination place")
    assert(not workspace:FindFirstChild(cfg.destination_root), "Crossroads already exists")
    assert(
        not game.ServerStorage:FindFirstChild(cfg.authoring_archive),
        "Authoring archive already exists"
    )
    local delta = Vector3.new(unpack(cfg.translation))
    assert(delta.X % 4 == 0 and delta.Y % 4 == 0 and delta.Z % 4 == 0, "Terrain grid alignment")
    local world = assert(package:FindFirstChild(cfg.source_root), "Missing map")
    local terrain = assert(package:FindFirstChild("NativeTerrain"), "Missing TerrainRegion")
    local archive =
        assert(package:FindFirstChild(cfg.authoring_archive), "Missing authoring inputs")
    local destinations = {
        ReplicatedStorage = game.ReplicatedStorage,
        StarterPlayerScripts = game.StarterPlayer.StarterPlayerScripts,
    }
    for name, destination in pairs(destinations) do
        for _, child in ipairs(package[name]:GetChildren()) do
            assert(
                not destination:FindFirstChild(child.Name),
                "Companion collision: " .. child.Name
            )
        end
    end
    local low = Vector3.new(unpack(cfg.terrain_min_cell)) * 4 + delta
    -- CopyRegion uses inclusive maximum cell coordinates.
    local high = (Vector3.new(unpack(cfg.terrain_max_cell)) + Vector3.one) * 4 + delta
    local materials, occupancy = workspace.Terrain:ReadVoxels(Region3.new(low, high), 4)
    for x = 1, #materials do
        for y = 1, #materials[x] do
            for z = 1, #materials[x][y] do
                assert(occupancy[x][y][z] == 0, "Destination Terrain is occupied")
            end
        end
    end
    local bounds = OverlapParams.new()
    bounds.FilterType = Enum.RaycastFilterType.Exclude
    bounds.FilterDescendantsInstances = { workspace.Terrain }
    assert(
        #workspace:GetPartBoundsInBox(CFrame.new((low + high) / 2), high - low, bounds) == 0,
        "Destination geometry is occupied"
    )
    local transform = CFrame.new(delta)
    world:PivotTo(transform * world:GetPivot())
    local spawns, prompts, bulwarks = 0, 0, 0
    for _, object in ipairs(world:GetDescendants()) do
        assert(not object:IsA("BaseScript"), "Unexpected embedded runtime script")
        if object:IsA("SpawnLocation") then
            object.Enabled = cfg.enable_spawn
            spawns += 1
        elseif object:IsA("ProximityPrompt") then
            object.Enabled = false
            prompts += 1
        end
        for _, key in ipairs({ "DeployedPivot", "RetractedPivot" }) do
            local value = object:GetAttribute(key)
            if typeof(value) == "CFrame" then
                object:SetAttribute(key, transform * value)
            end
        end
        if object:GetAttribute("BulwarkId") then
            bulwarks += 1
        end
    end
    local fxValue = package.ReplicatedStorage.CrossroadsVisualFX.ConfigJSON
    local fx = game.HttpService:JSONDecode(fxValue.Value)
    local origin = fx.presets.hell_pool_mist.origin
    fx.presets.hell_pool_mist.origin =
        { origin[1] + delta.X, origin[2] + delta.Y, origin[3] + delta.Z }
    for _, field in ipairs(fx.integration.fields) do
        if field.ground_y then
            field.ground_y += delta.Y
        end
    end
    fxValue.Value = game.HttpService:JSONEncode(fx)
    local fishValue = package.ReplicatedStorage.CrossroadsPondLife.Config
    local fish = game.HttpService:JSONDecode(fishValue.Value)
    fish.preview_only = not cfg.pond_cosmetics_enabled
    for _, pond in ipairs(fish.ponds) do
        pond.center_xz[1] += delta.X
        pond.center_xz[2] += delta.Z
        pond.water_y += delta.Y
    end
    fishValue.Value = game.HttpService:JSONEncode(fish)
    world.Name = cfg.destination_root
    world:SetAttribute("FarmImportVersion", cfg.version)
    world:SetAttribute("FarmImportTranslation", delta)
    world:SetAttribute("GameplayConnected", cfg.gameplay_connected)
    local record = Instance.new("StringValue")
    record.Name, record.Value, record.Parent =
        "FarmImportConfig", game.HttpService:JSONEncode(cfg), archive
    local cell = Vector3int16.new(low.X / 4, low.Y / 4, low.Z / 4)
    local backup = workspace.Terrain:CopyRegion(
        Region3int16.new(cell, Vector3int16.new(high.X / 4 - 1, high.Y / 4 - 1, high.Z / 4 - 1))
    )
    backup.Name, backup.Parent = "DestinationTerrainBeforeImport", archive
    local installed = {}
    local ok, err = pcall(function()
        workspace.Terrain:PasteRegion(terrain, cell, true)
        world.Parent = workspace
        table.insert(installed, world)
        for name, destination in pairs(destinations) do
            for _, child in ipairs(package[name]:GetChildren()) do
                child.Parent = destination
                table.insert(installed, child)
            end
        end
        archive.Parent = game.ServerStorage
    end)
    if not ok then
        workspace.Terrain:PasteRegion(backup, cell, true)
        for _, object in ipairs(installed) do
            object:Destroy()
        end
        error(err)
    end
    package:Destroy()
    return {
        world = world:GetFullName(),
        disabledSpawns = spawns,
        disabledPrompts = prompts,
        bulwarks = bulwarks,
    }
end
