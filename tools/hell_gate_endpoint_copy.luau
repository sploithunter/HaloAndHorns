-- Studio Edit utility. Invoke the returned function with configured/resolved Instances:
-- { root, source, targets, groupName, markerNames, legacyMarkerPattern }, dryRun.
-- Gate 1 is read-only. Replaced groups remain recoverable in ServerStorage.
return function(spec, dryRun)
    assert(game:GetService("RunService"):IsStudio(), "Studio only")
    assert(not game:GetService("RunService"):IsRunning(), "stop Play before copying endpoints")
    local root, source = spec.root, spec.source
    assert(typeof(root) == "Instance" and source:IsA("Model") and source.Parent == root)
    local sourceGroup = assert(source:FindFirstChild(spec.groupName), "source group missing")
    local names, points = {}, {}
    for _, name in ipairs(spec.markerNames) do
        assert(not names[name], "duplicate configured endpoint")
        names[name] = true
        local part = assert(sourceGroup:FindFirstChild(name), "missing source endpoint: " .. name)
        assert(part:IsA("BasePart") and #part:GetChildren() == 0, "endpoint must be a plain Part")
        points[#points + 1] = part
    end
    assert(#points > 0 and #sourceGroup:GetChildren() == #points, "unclassified source contents")
    local plans, seen = {}, {}
    for _, target in ipairs(spec.targets) do
        assert(
            target:IsA("Model") and target.Parent == root and target ~= source and not seen[target]
        )
        seen[target] = true
        local old = target:FindFirstChild(spec.groupName)
        if old then
            assert(old:IsA("Model") or old:IsA("Folder"), "unexpected target group class")
            for _, child in ipairs(old:GetChildren()) do
                assert(
                    child:IsA("BasePart")
                        and #child:GetChildren() == 0
                        and (names[child.Name] or child.Name:match(spec.legacyMarkerPattern)),
                    "refusing to replace unrelated target content: " .. child:GetFullName()
                )
            end
        end
        local ratio = target:GetScale() / source:GetScale()
        local desired, changed = {}, old == nil or #old:GetChildren() ~= #points
        for _, part in ipairs(points) do
            local relative = source:GetPivot():ToObjectSpace(part.CFrame)
            local cf = target:GetPivot()
                * (CFrame.new(relative.Position * ratio) * relative.Rotation)
            local size = part.Size * ratio
            desired[#desired + 1] = { original = part, cf = cf, size = size }
            local existing = old and old:FindFirstChild(part.Name)
            if not existing or not existing.CFrame:FuzzyEq(cf) or existing.Size ~= size then
                changed = true
            end
        end
        plans[#plans + 1] = { target = target, old = old, desired = desired, changed = changed }
    end
    local result =
        { copied = 0, unchanged = 0, endpointsPerGate = #points, dryRun = dryRun == true }
    local backup
    for _, plan in ipairs(plans) do
        if not plan.changed then
            result.unchanged += 1
        else
            result.copied += 1
            if not dryRun then
                if not backup then
                    backup = Instance.new("Folder")
                    backup.Name = "HellGateEndpointBackup_"
                        .. game:GetService("HttpService"):GenerateGUID(false)
                    backup.Parent = game.ServerStorage
                    result.backup = backup:GetFullName()
                end
                local group = Instance.new("Model")
                group.Name = spec.groupName
                for _, item in ipairs(plan.desired) do
                    local copy = item.original:Clone()
                    copy.CFrame = item.cf
                    copy.Size = item.size
                    copy.Parent = group
                end
                if plan.old then
                    local holder = Instance.new("Folder")
                    holder.Name = plan.target.Name
                    holder.Parent = backup
                    plan.old.Parent = holder
                end
                group.Parent = plan.target
            end
        end
    end
    return result
end
