-- Run before trim; borders are added after trim by the returned finish function.
return function(world, cfg)
    local c = cfg.arrival
    local walk = world.BraggRotundaR6.TerraceAndEntry.ArrivalWalk
    assert(walk:IsA("Part"), "Restore uncut paving before finishing arrival")
    walk.Size = Vector3.new(c.width, c.thickness, c.end_z - c.start_z)
    walk.CFrame = CFrame.new(0, c.surface_y - c.thickness / 2, (c.start_z + c.end_z) / 2)
    walk.Color = Color3.fromRGB(unpack(c.stone_color))
    walk.Material = Enum.Material.Cobblestone
    local spawn = world.PathsAndLandings.PreviewSpawn
    spawn.Transparency = 1
    spawn.CanCollide = false
    for _, d in ipairs(spawn:GetChildren()) do
        if d:IsA("Decal") or d:IsA("Texture") then
            d:Destroy()
        end
    end
    for _, p in ipairs(world.PathsAndLandings:GetChildren()) do
        if p:IsA("BasePart") and p.Position.Y > 0 and p.Position.Y < 1 and p ~= spawn then
            p.Position = Vector3.new(p.Position.X, c.surface_y - p.Size.Y / 2, p.Position.Z)
        end
    end
    return function()
        walk.Size = Vector3.new(c.width - c.border_width * 2, c.thickness, c.end_z - c.start_z)
        local width = (c.width - c.border_width * 2) / c.tile_columns
        local depth = (c.end_z - c.start_z) / c.tile_rows
        for row = 1, c.tile_rows do
            for col = 1, c.tile_columns do
                local tile = walk:Clone()
                tile.Name = "ArrivalPaver"
                tile.Size = Vector3.new(width - c.joint, c.thickness, depth - c.joint)
                tile.Position = Vector3.new(
                    -(c.width - c.border_width * 2) / 2 + (col - 0.5) * width,
                    walk.Position.Y,
                    c.start_z + (row - 0.5) * depth
                )
                tile.Color =
                    Color3.fromRGB(unpack(c.tile_colors[(row + col * 3) % #c.tile_colors + 1]))
                tile.Material = Enum.Material.Limestone
                tile.Parent = walk.Parent
            end
        end

        for _, side in ipairs({ -1, 1 }) do
            local edge = walk:Clone()
            edge.Name = "ArrivalStoneBorder"
            edge.Size = Vector3.new(c.border_width, c.thickness, c.end_z - c.start_z)
            edge.Position =
                Vector3.new(side * (c.width - c.border_width) / 2, walk.Position.Y, walk.Position.Z)
            edge.Material = Enum.Material.Slate
            edge.Color = Color3.fromRGB(unpack(c.edge_color))
            edge.Parent = walk.Parent
        end
        walk:Destroy()
    end
end
