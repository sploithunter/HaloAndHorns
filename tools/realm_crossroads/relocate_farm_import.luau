-- Move an existing import to cfg.translation; keep Terrain, visual origins and stored pivots aligned.
return function(cfg)
    assert(not game:GetService("RunService"):IsRunning(), "Stop Play")
    assert(game.PlaceId == cfg.destination_place_id, "Wrong place")
    local world = workspace[cfg.destination_root]
    local old = assert(world:GetAttribute("FarmImportTranslation"), "Import metadata missing")
    local destination = Vector3.new(unpack(cfg.translation))
    local delta = destination - old
    if delta.Magnitude == 0 then
        return "Already positioned"
    end
    assert(delta.X % 4 == 0 and delta.Y % 4 == 0 and delta.Z % 4 == 0, "Voxel alignment")
    local archive = game.ServerStorage[cfg.authoring_archive]
    local originalEmpty = assert(
        archive:FindFirstChild("DestinationTerrainBeforeImport"),
        "Missing original Terrain backup"
    )
    local minCell = Vector3.new(unpack(cfg.terrain_min_cell))
    local maxCell = Vector3.new(unpack(cfg.terrain_max_cell))
    local function int(v)
        return Vector3int16.new(v.X, v.Y, v.Z)
    end
    local low, high = minCell * 4 + destination, (maxCell + Vector3.one) * 4 + destination
    local _, occupancy = workspace.Terrain:ReadVoxels(Region3.new(low, high), 4)
    for _, column in ipairs(occupancy) do
        for _, row in ipairs(column) do
            for _, value in ipairs(row) do
                assert(value == 0, "Target Terrain occupied")
            end
        end
    end
    assert(
        #workspace:GetPartBoundsInBox(CFrame.new((low + high) / 2), high - low) == 0,
        "Target parts occupied"
    )
    local terrain = workspace.Terrain:CopyRegion(
        Region3int16.new(int(minCell + old / 4), int(maxCell + old / 4))
    )
    terrain.Name = "TerrainBeforeRelocation"
    terrain.Parent = archive
    terrain:SetAttribute("Translation", old)
    local empty = workspace.Terrain:CopyRegion(
        Region3int16.new(int(minCell + destination / 4), int(maxCell + destination / 4))
    )
    local fxValue = game.ReplicatedStorage.CrossroadsVisualFX.ConfigJSON
    local fishValue = game.ReplicatedStorage.CrossroadsPondLife.Config
    local fx, fish =
        game.HttpService:JSONDecode(fxValue.Value), game.HttpService:JSONDecode(fishValue.Value)
    local origin = fx.presets.hell_pool_mist.origin
    origin[1] += delta.X
    origin[2] += delta.Y
    origin[3] += delta.Z
    for _, field in ipairs(fx.integration.fields) do
        if field.ground_y then
            field.ground_y += delta.Y
        end
    end
    for _, pond in ipairs(fish.ponds) do
        pond.center_xz[1] += delta.X
        pond.center_xz[2] += delta.Z
        pond.water_y += delta.Y
    end
    local oldPivot = world:GetPivot()
    local ok, err = pcall(function()
        workspace.Terrain:PasteRegion(terrain, int(minCell + destination / 4), true)
        world:PivotTo(CFrame.new(delta) * oldPivot)
        workspace.Terrain:PasteRegion(originalEmpty, int(minCell + old / 4), true)
    end)
    if not ok then
        world:PivotTo(oldPivot)
        workspace.Terrain:PasteRegion(terrain, int(minCell + old / 4), true)
        workspace.Terrain:PasteRegion(empty, int(minCell + destination / 4), true)
        empty:Destroy()
        error(err)
    end
    for _, d in ipairs(world:GetDescendants()) do
        for _, key in ipairs({ "DeployedPivot", "RetractedPivot" }) do
            local value = d:GetAttribute(key)
            if typeof(value) == "CFrame" then
                d:SetAttribute(key, CFrame.new(delta) * value)
            end
        end
    end
    fxValue.Value = game.HttpService:JSONEncode(fx)
    fishValue.Value = game.HttpService:JSONEncode(fish)
    world:SetAttribute("FarmImportTranslation", destination)
    archive.FarmImportConfig.Value = game.HttpService:JSONEncode(cfg)
    originalEmpty.Name = "PreviousLocationTerrainBeforeImport"
    empty.Name = "DestinationTerrainBeforeImport"
    empty.Parent = archive
    return {
        translation = tostring(destination),
        spawn = tostring(world:FindFirstChild("PreviewSpawn", true).Position),
    }
end
