-- Edit-only: preserve occupancy; remove decorative grass beneath authored paving.
return function(cfg)
    assert(not game:GetService("RunService"):IsRunning(), "Stop Play first")
    local root = assert(workspace:FindFirstChild(cfg.root), "Map missing")
    local low, high = Vector3.new(unpack(cfg.bounds_min)), Vector3.new(unpack(cfg.bounds_max))
    local region = Region3.new(low, high)
    local archive = game.ServerStorage[cfg.archive]
    if not archive:FindFirstChild("TerrainBeforeSurfaceFinish") then
        local backup = workspace.Terrain:CopyRegion(
            Region3int16.new(
                Vector3int16.new(low.X / 4, low.Y / 4, low.Z / 4),
                Vector3int16.new(high.X / 4 - 1, high.Y / 4 - 1, high.Z / 4 - 1)
            )
        )
        backup.Name = "TerrainBeforeSurfaceFinish"
        backup.Parent = archive
    end
    local names = {}
    for _, name in ipairs(cfg.paver_names) do
        names[name] = true
    end
    local materials, occupancy = workspace.Terrain:ReadVoxels(region, 4)
    local changed = 0
    if cfg.replace_all_grass then
        for x, column in ipairs(materials) do
            for y, row in ipairs(column) do
                for z, material in ipairs(row) do
                    if material == Enum.Material.Grass then
                        materials[x][y][z] = Enum.Material[cfg.replacement_material]
                        changed += 1
                    end
                end
            end
        end
    end
    for _, p in ipairs(root:GetDescendants()) do
        if p:IsA("BasePart") and names[p.Name] then
            local half = p.Size / 2
            local extent = p.CFrame.RightVector:Abs() * half.X
                + p.CFrame.UpVector:Abs() * half.Y
                + p.CFrame.LookVector:Abs() * half.Z
            local lo = p.Position
                - extent
                - Vector3.new(cfg.edge_margin, cfg.buried_depth, cfg.edge_margin)
            local hi = p.Position + extent + Vector3.new(cfg.edge_margin, 0, cfg.edge_margin)
            for x = math.max(1, math.floor((lo.X - low.X) / 4) + 1), math.min(#materials, math.floor((hi.X - low.X) / 4) + 1) do
                for z = math.max(1, math.floor((lo.Z - low.Z) / 4) + 1), math.min(#materials[x][1], math.floor((hi.Z - low.Z) / 4) + 1) do
                    for y = math.max(1, math.floor((lo.Y - low.Y) / 4) + 1), math.min(#materials[x], math.floor((hi.Y - low.Y) / 4) + 1) do
                        local point = low + Vector3.new(x * 4 - 2, y * 4 - 2, z * 4 - 2)
                        local localPoint = p.CFrame:PointToObjectSpace(point)
                        if
                            math.abs(localPoint.X) <= half.X + cfg.edge_margin
                            and math.abs(localPoint.Z) <= half.Z + cfg.edge_margin
                            and materials[x][y][z] == Enum.Material.Grass
                        then
                            materials[x][y][z] = Enum.Material[cfg.replacement_material]
                            changed += 1
                        end
                    end
                end
            end
        end
    end
    workspace.Terrain:WriteVoxels(region, 4, materials, occupancy)
    root:SetAttribute("SurfaceGrassCorrected", true)
    return { changedVoxels = changed }
end
