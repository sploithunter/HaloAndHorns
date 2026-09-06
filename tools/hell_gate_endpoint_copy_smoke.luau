-- Native Edit test: invoke the returned function with hell_gate_endpoint_copy's function.
return function(copier)
    local root = Instance.new("Folder")
    root.Name = "_HellGateCopySmoke"
    root.Parent = game.ServerStorage
    local backups = {}
    local ok, result = pcall(function()
        local source = Instance.new("Model")
        source.Name = "Source"
        source.Parent = root
        local group = Instance.new("Model")
        group.Name = "Markers"
        group.Parent = source
        local names = { "sky", "inner", "side" }
        local originals = {}
        for index, name in ipairs(names) do
            local point = Instance.new("Part")
            point.Name = name
            point.Anchored = true
            point.CanCollide = false
            point.Transparency = 1
            point.Size = Vector3.new(0.5, 0.5, 0.5)
            point.CFrame = CFrame.new(index * 4, index * 10, 3) * CFrame.Angles(0, index, 0)
            point:SetAttribute("Endpoint", true)
            point.Parent = group
            originals[point] = point.CFrame
        end
        source:PivotTo(CFrame.new(10, 2, -20) * CFrame.Angles(0, 0.4, 0))
        for point in pairs(originals) do
            originals[point] = point.CFrame
        end
        local targets = {}
        for index = 1, 2 do
            local target = Instance.new("Model")
            target.Name = "Target" .. index
            target.Parent = root
            local art = Instance.new("Part")
            art.Name = "PreservedArt"
            art.Anchored = true
            art.Parent = target
            local light = Instance.new("Attachment")
            light.Name = "PreservedLight"
            light.Parent = art
            local old = Instance.new("Model")
            old.Name = "Markers"
            old.Parent = target
            local point = Instance.new("Part")
            point.Name = "legacy1"
            point.Parent = old
            target:ScaleTo(index)
            target:PivotTo(CFrame.new(index * 100, 5, 50) * CFrame.Angles(0, index, 0))
            targets[index] = target
        end
        local spec = {
            root = root,
            source = source,
            targets = targets,
            groupName = "Markers",
            markerNames = names,
            legacyMarkerPattern = "^legacy%d+$",
        }
        local before = targets[1].Markers
        local preview = copier(spec, true)
        assert(preview.copied == 2 and targets[1].Markers == before, "dry-run mutated target")
        local applied = copier(spec, false)
        backups[#backups + 1] =
            game.ServerStorage:FindFirstChild(applied.backup:match("ServerStorage%.(.+)"))
        assert(applied.copied == 2 and backups[1] and before:IsDescendantOf(backups[1]))
        for _, target in ipairs(targets) do
            assert(
                target.PreservedArt.PreservedLight.Parent == target.PreservedArt,
                "lost authored attachment"
            )
            assert(#target.Markers:GetChildren() == #names)
            for point, cf in pairs(originals) do
                assert(point.CFrame == cf, "source moved")
                local relative = source:GetPivot():ToObjectSpace(cf)
                local ratio = target:GetScale() / source:GetScale()
                local wanted = target:GetPivot()
                    * (CFrame.new(relative.Position * ratio) * relative.Rotation)
                local clone = target.Markers[point.Name]
                assert(clone.CFrame:FuzzyEq(wanted), "wrong local-space transform")
                assert(clone.Size == point.Size * ratio and clone:GetAttribute("Endpoint") == true)
            end
        end
        local second = copier(spec, false)
        assert(second.copied == 0 and second.unchanged == 2, "not idempotent")
        local unrelated = Instance.new("Folder")
        unrelated.Name = "DoNotReplace"
        unrelated.Parent = targets[2].Markers
        local current = targets[1].Markers
        assert(not pcall(copier, spec, false), "accepted unrelated target content")
        assert(targets[1].Markers == current, "mutated before all targets validated")
        return "PASS: dry run, transformed/scaled copies, source/art preservation, backups, idempotence, preflight refusal"
    end)
    root:Destroy()
    for _, backup in ipairs(backups) do
        backup:Destroy()
    end
    assert(ok, result)
    return result
end
