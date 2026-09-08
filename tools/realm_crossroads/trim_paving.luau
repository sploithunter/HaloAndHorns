-- Edit-time solid cuts: each patch owns its footprint, with no stacked floor faces.
return function(root, cfg)
    local patches = {}
    for _, path in ipairs(cfg.groups) do
        local group = root
        for segment in string.gmatch(path, "[^.]+") do
            group = group and group:FindFirstChild(segment)
        end
        if group then
            for _, p in ipairs(group:GetChildren()) do
                if p:IsA("BasePart") and cfg.priorities[p.Name] then
                    assert(
                        not p:GetAttribute("PavingTrimmed"),
                        "Rebuild paving before trimming again"
                    )
                    table.insert(
                        patches,
                        { part = p, cf = p.CFrame, size = p.Size, priority = cfg.priorities[p.Name] }
                    )
                end
            end
        end
    end
    table.sort(patches, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return a.part:GetFullName() < b.part:GetFullName()
    end)
    local function overlaps(a, b)
        if math.abs(a.cf.Position.Y - b.cf.Position.Y) > cfg.height_tolerance then
            return false
        end
        local delta = b.cf.Position - a.cf.Position
        for _, axis in ipairs({ a.cf.RightVector, a.cf.LookVector, b.cf.RightVector, b.cf.LookVector }) do
            local ra = math.abs(axis:Dot(a.cf.RightVector)) * a.size.X / 2
                + math.abs(axis:Dot(a.cf.LookVector)) * a.size.Z / 2
            local rb = math.abs(axis:Dot(b.cf.RightVector)) * b.size.X / 2
                + math.abs(axis:Dot(b.cf.LookVector)) * b.size.Z / 2
            if math.abs(delta:Dot(axis)) >= ra + rb - cfg.overlap_epsilon then
                return false
            end
        end
        return true
    end
    local backup = Instance.new("Folder")
    backup.Name = "CrossroadsPavingBeforeTrim"
    backup.Parent = game.ServerStorage
    local count = 0
    for n, a in ipairs(patches) do
        local cutters = {}
        for j = 1, n - 1 do
            local b = patches[j]
            if overlaps(a, b) then
                local cutter = Instance.new("Part")
                cutter.Size = Vector3.new(b.size.X, cfg.cutter_height, b.size.Z)
                cutter.CFrame = b.cf
                table.insert(cutters, cutter)
            end
        end
        if #cutters > 0 then
            local p = a.part
            local ok, result = pcall(function()
                return p:SubtractAsync(
                    cutters,
                    Enum.CollisionFidelity.PreciseConvexDecomposition,
                    Enum.RenderFidelity.Precise
                )
            end)
            for _, c in ipairs(cutters) do
                c:Destroy()
            end
            assert(ok, tostring(result))
            if result then
                result.Name = p.Name
                result.Anchored = true
                result.Color = p.Color
                result.Material = p.Material
                result.UsePartColor = true
                result.CanCollide = p.CanCollide
                result:SetAttribute("PavingTrimmed", true)
                result.Parent = p.Parent
            end
            p.Parent = backup
            count += 1
        end
    end
    return { trimmed = count, examined = #patches }
end
