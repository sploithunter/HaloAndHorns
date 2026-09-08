-- R8 authored landscaping; no gameplay scripts or animated geometry.
return function()
    assert(
        game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(),
        "Local Edit preview only"
    )
    local cfg = game.HttpService:JSONDecode(game.ServerStorage.CrossroadsLandscapeConfig.Value)
    local V, C = Vector3, CFrame
    local world = workspace.RealmCrossroadsR4
    local old = world:FindFirstChild(cfg.root)
    if old then
        old:Destroy()
    end
    local root = Instance.new("Model")
    root.Name = cfg.root
    root.Parent = world
    local flora = Instance.new("Folder")
    flora.Name = "PerimeterFlora"
    flora.Parent = root
    local cache = game.ServerStorage.CrossroadsLandscapeAssets
    local random = Random.new(cfg.seed)
    local function rgb(v)
        return Color3.fromRGB(unpack(v))
    end
    local terrain = workspace.Terrain
    terrain:SetMaterialColor(Enum.Material.LeafyGrass, rgb(cfg.heaven.terrain))
    terrain:SetMaterialColor(Enum.Material.Ground, rgb(cfg.hell.terrain))
    local region = Region3.new(V.new(unpack(cfg.region_min)), V.new(unpack(cfg.region_max)))
        :ExpandToGrid(4)
    local materials, occupancy = terrain:ReadVoxels(region, 4)
    local min = region.CFrame.Position - region.Size / 2
    for ix = 1, #materials do
        local x = min.X + (ix - 0.5) * 4
        for iy = 1, #materials[ix] do
            for iz = 1, #materials[ix][iy] do
                if occupancy[ix][iy][iz] > 0 and math.abs(x) > cfg.center_blend_width then
                    materials[ix][iy][iz] = x < 0 and Enum.Material.LeafyGrass
                        or Enum.Material.Ground
                end
            end
        end
    end
    terrain:WriteVoxels(region, 4, materials, occupancy)
    -- Theme architectural surfaces, preserving textures on imported meshes and neutral central hall.
    for _, groupName in ipairs({
        "PathsAndLandings",
        "GradedStairsAndRamps",
        "RetainingWalls",
        "CrossroadsActivitiesR7",
    }) do
        local group = world:FindFirstChild(groupName)
        if group then
            for _, p in ipairs(group:GetDescendants()) do
                if
                    p.ClassName == "Part"
                    and p.Transparency < 1
                    and math.abs(p.Position.X) > cfg.center_blend_width
                then
                    local theme = p.Position.X < 0 and cfg.heaven or cfg.hell
                    local name = p.Name
                    if name == "Playfield" then
                        p.Material = p.Position.X < 0 and Enum.Material.Grass or Enum.Material.Slate
                        p.Color = rgb(theme.ground)
                    elseif name:find("Letter_", 1, true) then
                        p.Color = p.Position.X < 0 and Color3.fromRGB(68, 54, 37)
                            or Color3.fromRGB(230, 178, 108)
                    elseif
                        not name:find("Anchor")
                        and not name:find("Marker")
                        and p.Material ~= Enum.Material.Metal
                        and p.Material ~= Enum.Material.Neon
                    then
                        p.Color = rgb(theme.stone)
                        if p.Position.X > 0 then
                            p.Material = Enum.Material.Slate
                        end
                    end
                end
            end
        end
    end
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Include
    ray.FilterDescendantsInstances = { terrain }
    local function place(name, x, z, height)
        local template = cache:FindFirstChild(name)
        if not template then
            template = game:GetService("InsertService"):LoadAsset(cfg.models[name])
            template.Name = name
            template.Parent = cache
        end
        local hit = workspace:Raycast(V.new(x, 80, z), V.new(0, -130, 0), ray)
        if not hit then
            return
        end
        local m = template:Clone()
        m.Parent = flora
        m.Name = name
        for _, p in ipairs(m:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Anchored = true
                p.CanCollide = false
                p.CanTouch = false
                p.CanQuery = false
            elseif p:IsA("LuaSourceContainer") then
                p:Destroy()
            end
        end
        m:PivotTo(C.new())
        m:ScaleTo(m:GetScale() * height / m:GetExtentsSize().Y)
        local box, size = m:GetBoundingBox()
        m:PivotTo(
            C.new(x, hit.Position.Y - 0.2, z)
                * C.Angles(0, random:NextNumber(0, math.pi * 2), 0)
                * C.new(-box.Position.X, -box.Position.Y + size.Y / 2, -box.Position.Z)
                * m:GetPivot()
        )
        m:SetAttribute("Realm", x < 0 and "heaven" or "hell")
    end
    local function cluster(x, z, tree)
        local theme = x < 0 and cfg.heaven or cfg.hell
        local choices = tree and theme.trees or theme.plants
        local heights = tree and cfg.tree_height or cfg.plant_height
        place(
            choices[random:NextInteger(1, #choices)],
            x,
            z,
            random:NextNumber(heights[1], heights[2])
        )
    end
    for _, side in ipairs({ -1, 1 }) do
        for row, x in ipairs(cfg.side_rows) do
            for z = cfg.side_z_range[1], cfg.side_z_range[2], cfg.side_tree_step do
                cluster(
                    side * (x + random:NextNumber(-1.2, 1.2)),
                    z + (row - 1) * 5 + random:NextNumber(-3, 3),
                    true
                )
            end
        end
        for z = cfg.side_z_range[1], cfg.side_z_range[2], cfg.understory_step do
            cluster(side * random:NextNumber(160, 174), z, false)
            local theme = side < 0 and cfg.heaven or cfg.hell
            if random:NextNumber() < 0.65 then
                place(
                    theme.rocks[random:NextInteger(1, #theme.rocks)],
                    side * random:NextNumber(163, 173),
                    z + 3,
                    random:NextNumber(unpack(cfg.rock_height))
                )
            end
        end
    end
    for row, z in ipairs(cfg.rear_rows) do
        for x = cfg.rear_x_range[1], cfg.rear_x_range[2], cfg.rear_tree_step do
            -- Leave clearance around the rear edge of Bragg, without losing the distant canopy.
            if math.abs(x) > 62 or row == 2 then
                cluster(x + random:NextNumber(-3, 3), z, true)
            end
        end
    end
    for _, range in ipairs(cfg.front_x_ranges) do
        for _, z in ipairs(cfg.front_rows) do
            for x = range[1], range[2], cfg.front_tree_step do
                cluster(x + random:NextNumber(-2, 2), z, true)
            end
        end
    end
    for x = -145, 145, cfg.understory_step do
        if math.abs(x) > 62 then
            cluster(x, -150, false)
        end
    end
    local activities = world:FindFirstChild("CrossroadsActivitiesR7")
    if activities then
        for _, model in ipairs(activities.PatrolGrove:GetChildren()) do
            if model:IsA("Model") and model.Name == "cloud_sapling" then
                model:Destroy()
            end
        end
    end
    for _, at in ipairs(cfg.hell_accent_trees) do
        place("coldfire_pine", at[1], at[2], at[3])
    end
    local fence = Instance.new("Folder")
    fence.Name = "InvisibleIslandBoundary"
    fence.Parent = root
    for i, a in ipairs(cfg.boundary) do
        local b = cfg.boundary[i % #cfg.boundary + 1]
        local av, bv =
            V.new(a[1], cfg.edge_bottom + cfg.edge_height / 2, a[2]),
            V.new(b[1], cfg.edge_bottom + cfg.edge_height / 2, b[2])
        local p = Instance.new("Part")
        p.Name = "OuterSafetyWall" .. i
        p.Anchored = true
        p.Transparency = 1
        p.Size =
            V.new(cfg.edge_thickness, cfg.edge_height, (bv - av).Magnitude + cfg.edge_thickness)
        p.CFrame = C.lookAt((av + bv) / 2, bv)
        p.CanCollide = true
        p.CanTouch = false
        p.CastShadow = false
        p.Parent = fence
    end
    return {
        floraModels = #flora:GetChildren(),
        safetyWalls = #fence:GetChildren(),
        height = cfg.edge_height,
    }
end
