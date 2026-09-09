-- Semantic identity only. Validate the complete one-to-one match before assigning attributes.
return function(world, cfg)
    assert(game.PlaceId == 0, "Interaction bindings require the unpublished preview")
    assert(not game:GetService("RunService"):IsRunning(), "Interaction bindings require Edit")
    local root = assert(world, "Missing world")
    for _, name in ipairs(cfg.root_path) do
        root = assert(root:FindFirstChild(name), "Missing binding path component " .. name)
    end
    local models = {}
    for _, item in ipairs(root:GetChildren()) do
        if item:IsA("Model") then
            table.insert(models, item)
        end
    end
    assert(
        #models == cfg.expected_count and #cfg.entries == cfg.expected_count,
        "Bulwark count mismatch"
    )
    local used, ids, pending = {}, {}, {}
    local attr = cfg.attributes
    for _, spec in ipairs(cfg.entries) do
        assert(not ids[spec.id], "Duplicate configured bulwark ID")
        ids[spec.id] = true
        local expected = CFrame.new(unpack(spec.pivot))
        local matched
        for _, model in ipairs(models) do
            local pivot = model:GetPivot()
            if (pivot.Position - expected.Position).Magnitude <= cfg.position_tolerance then
                assert(not matched, "Ambiguous bulwark position " .. spec.id)
                matched = model
            end
        end
        assert(matched and not used[matched], "Missing or duplicate bulwark match " .. spec.id)
        used[matched] = true
        local pivot = matched:GetPivot()
        local box, size = matched:GetBoundingBox()
        assert(matched.Name == spec.name, "Bulwark source name mismatch " .. spec.id)
        assert(
            matched:GetAttribute("Entrance") == spec.entrance,
            "Entrance classification mismatch " .. spec.id
        )
        assert(
            (size - Vector3.new(unpack(spec.size))).Magnitude <= cfg.size_tolerance,
            "Bulwark envelope mismatch " .. spec.id
        )
        assert(
            (box.Position - Vector3.new(unpack(spec.center))).Magnitude <= cfg.position_tolerance,
            "Bulwark center mismatch " .. spec.id
        )
        assert(
            (pivot.RightVector - expected.RightVector).Magnitude <= cfg.rotation_tolerance
                and (pivot.UpVector - expected.UpVector).Magnitude <= cfg.rotation_tolerance,
            "Bulwark orientation mismatch " .. spec.id
        )
        assert(
            typeof(matched:GetAttribute("DeployedPivot")) == "CFrame"
                and typeof(matched:GetAttribute("RetractedPivot")) == "CFrame",
            "Missing authored motion references " .. spec.id
        )
        local values = {
            [attr.id] = spec.id,
            [attr.side] = spec.side,
            [attr.segment] = spec.segment,
            [attr.entrance_segment] = spec.entrance_segment,
            [attr.revision] = cfg.revision,
        }
        for key, value in pairs(values) do
            local previous = matched:GetAttribute(key)
            assert(
                previous == nil or previous == value,
                "Conflicting existing binding " .. key .. ":" .. spec.id
            )
        end
        table.insert(pending, { model = matched, values = values, entrance = spec.entrance })
    end
    local entrances = 0
    for _, record in ipairs(pending) do
        for key, value in pairs(record.values) do
            record.model:SetAttribute(key, value)
        end
        if record.entrance then
            entrances += 1
        end
    end
    return {
        bound = #pending,
        entrances = entrances,
        perimeter = #pending - entrances,
        revision = cfg.revision,
    }
end
