-- Finish existing trimmed paths without rebuilding the terrain or other art.
return function(world, cfg)
    local c = cfg.side_junction
    local paths = world.PathsAndLandings
    local backup = Instance.new("Folder")
    backup.Name = "SideJunctionsBeforeRepair"
    backup.Parent = game.ServerStorage
    local count = 0
    for _, old in ipairs(paths:GetChildren()) do
        if old.Name == "GardenRampConnection" then
            local side = old.Position.X < 0 and -1 or 1
            local slab = Instance.new("Part")
            slab.Name = old.Name
            slab.Anchored = true
            slab.Parent = paths
            slab.Color = old.Color
            slab.Material = old.Material
            slab.Size = Vector3.new(c.outer_x - c.inner_x, cfg.arrival.thickness, c.width)
            slab.CFrame = CFrame.new(
                side * (c.inner_x + c.outer_x) / 2,
                cfg.arrival.surface_y - cfg.arrival.thickness / 2,
                c.center_z
            )
            local branch = paths[side < 0 and "ModeApproach1" or "ModeApproach2"]
            local cutter = branch:Clone()
            cutter.Size = Vector3.new(cutter.Size.X, cfg.cutter_height, cutter.Size.Z)
            local result = slab:SubtractAsync(
                { cutter },
                Enum.CollisionFidelity.PreciseConvexDecomposition,
                Enum.RenderFidelity.Precise
            )
            assert(result, "Junction cut produced no paving")
            result.Name = old.Name
            result.Anchored = true
            result.UsePartColor = true
            result.Color = old.Color
            result.Material = old.Material
            result:SetAttribute("PavingTrimmed", true)
            result.Parent = paths
            old.Parent = backup
            cutter:Destroy()
            slab:Destroy()
            count += 1
        end
    end
    return count
end
