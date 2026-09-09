-- Post-import Edit pass: re-seat perimeter landscaping against the final Terrain.
-- Raised-bed decor is intentionally outside this scope. Replays only lower floating models.
return function(world, cfg, dryRun)
    assert(not game:GetService("RunService"):IsRunning(), "Ground foliage in Edit mode")
    local target = world
    for _, name in ipairs(cfg.target_path) do
        target = assert(target:FindFirstChild(name), "Missing foliage scope: " .. name)
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { workspace.Terrain }
    params.IgnoreWater = true
    local report = { scanned = 0, floating = 0, moved = 0, unresolved = {}, changes = {} }
    local planned = {}
    for _, model in ipairs(target:GetChildren()) do
        if model:IsA("Model") then
            report.scanned += 1
            local box, size = model:GetBoundingBox()
            local point = box.Position
            local hit = workspace:Raycast(
                Vector3.new(point.X, cfg.ray_origin_y, point.Z),
                Vector3.new(0, -cfg.ray_length, 0),
                params
            )
            if not hit then
                table.insert(report.unresolved, model.Name .. ": no terrain support")
            else
                local gap = point.Y - size.Y / 2 - hit.Position.Y
                if gap > cfg.float_tolerance then
                    report.floating += 1
                    local lowering = gap + cfg.root_embed
                    if lowering > cfg.max_lowering then
                        table.insert(report.unresolved, model.Name .. ": exceeds lowering limit")
                    else
                        table.insert(planned, { model = model, lowering = lowering })
                        table.insert(report.changes, {
                            name = model.Name,
                            position = { point.X, point.Y, point.Z },
                            gap = gap,
                            lowering = lowering,
                        })
                    end
                end
            end
        end
    end
    -- Validate the complete pass before changing any geometry.
    assert(#report.unresolved == 0, table.concat(report.unresolved, "; "))
    if not dryRun then
        for _, item in ipairs(planned) do
            local model = item.model
            if model:GetAttribute(cfg.original_pivot_attribute) == nil then
                model:SetAttribute(cfg.original_pivot_attribute, model:GetPivot())
            end
            model:PivotTo(model:GetPivot() - Vector3.new(0, item.lowering, 0))
            report.moved += 1
        end
    end
    return report
end
