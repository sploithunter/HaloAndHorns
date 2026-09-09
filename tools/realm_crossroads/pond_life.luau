-- Edit-only installation; surveys the real water and bed before changing the preview.
return function(world, cfg, clientSource)
    assert(
        game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(),
        "Local Edit preview only"
    )
    assert(world == workspace:FindFirstChild(cfg.world), "Unexpected world")
    local template = game.ServerStorage[cfg.asset_cache][cfg.asset_template]
    local _, size = template:GetBoundingBox()
    local limit = Vector3.new(unpack(cfg.max_size))
    assert(size.X <= limit.X and size.Y <= limit.Y and size.Z <= limit.Z, "Fish exceeds envelope")
    local waterRay = RaycastParams.new()
    waterRay.FilterType = Enum.RaycastFilterType.Include
    waterRay.FilterDescendantsInstances = { workspace.Terrain }
    local bedRay = RaycastParams.new()
    bedRay.FilterType = Enum.RaycastFilterType.Include
    bedRay.FilterDescendantsInstances = { workspace.Terrain }
    bedRay.IgnoreWater = true
    local config = game.HttpService:JSONDecode(game.HttpService:JSONEncode(cfg))
    for _, pond in ipairs(config.ponds) do
        assert(world.CrossroadsFishingR10:FindFirstChild(pond.owner), "Missing pond")
        local surface
        for i = 0, cfg.survey.samples - 1 do
            local angle = i * math.pi * 2 / cfg.survey.samples
            local origin = Vector3.new(
                pond.center_xz[1] + math.sin(angle) * pond.radii[1],
                cfg.survey.origin_y,
                pond.center_xz[2] + math.cos(angle) * pond.radii[2]
            )
            local direction = Vector3.new(0, -cfg.survey.depth, 0)
            local water = workspace:Raycast(origin, direction, waterRay)
            local bed = workspace:Raycast(origin, direction, bedRay)
            assert(
                water and water.Material == Enum.Material.Water and bed,
                "Swim path leaves water"
            )
            surface = surface or water.Position.Y
            assert(
                math.abs(water.Position.Y - surface) <= cfg.survey.water_tolerance,
                "Uneven waterline"
            )
            local low = surface - cfg.depth - cfg.vertical_drift - size.Magnitude / 2
            local high = surface - cfg.depth + cfg.vertical_drift + size.Y / 2
            assert(low >= bed.Position.Y + cfg.survey.bed_clearance, "Fish path intersects bed")
            assert(high <= surface - cfg.survey.surface_clearance, "Fish breaks water surface")
        end
        pond.water_y = surface
    end
    local runtime = Instance.new("Folder")
    runtime.Name = cfg.runtime_root
    runtime:SetAttribute("CosmeticOnly", true)
    local fish = template:Clone()
    fish.Name = cfg.template_name
    local box = fish:GetBoundingBox()
    fish:PivotTo(CFrame.new(-box.Position) * fish:GetPivot())
    fish.PrimaryPart = nil
    fish.WorldPivot = CFrame.new()
    for _, item in ipairs(fish:GetDescendants()) do
        if item:IsA("BasePart") then
            item.Anchored = true
            item.CanCollide, item.CanTouch, item.CanQuery, item.CastShadow =
                false, false, false, false
        elseif
            item:IsA("LuaSourceContainer")
            or item:IsA("ProximityPrompt")
            or item:IsA("ClickDetector")
            or item:IsA("Humanoid")
            or item:IsA("AnimationController")
        then
            item:Destroy()
        end
    end
    fish.Parent = runtime
    local data = Instance.new("StringValue")
    data.Name = "Config"
    data.Value = game.HttpService:JSONEncode(config)
    data.Parent = runtime
    local client = Instance.new("LocalScript")
    client.Name = cfg.runtime_root
    client.Source = clientSource
    local storage = game:GetService("ReplicatedStorage")
    local starter = game.StarterPlayer.StarterPlayerScripts
    local old = storage:FindFirstChild(cfg.runtime_root)
    if old then
        old:Destroy()
    end
    old = starter:FindFirstChild(cfg.runtime_root)
    if old then
        old:Destroy()
    end
    runtime.Parent = storage
    client.Parent = starter
    return {
        ponds = #config.ponds,
        pathSamples = #config.ponds * cfg.survey.samples,
        gameplayConnected = false,
    }
end
