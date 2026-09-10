-- Install validated cached mesh props in Edit. No gameplay or new asset requests.
return function(world, cfg)
    assert(not game:GetService("RunService"):IsRunning(), "Rod installation requires Edit")
    assert(game.PlaceId == 0, "Crossroads rod display is preview-only")
    local V, C = Vector3, CFrame
    local cache = assert(
        game:GetService("ServerStorage"):FindFirstChild(cfg.cache),
        "Missing native rod cache"
    )
    local fishing = assert(world:FindFirstChild(cfg.fishing_root), "Missing fishing stations")
    -- Validate before removing the prior display.
    for _, pond in ipairs(cfg.ponds) do
        assert(cache:FindFirstChild(pond.realm), "Missing rod template " .. pond.realm)
        local source = assert(fishing:FindFirstChild(pond.name), "Missing pond")
        for n = 1, pond.stations do
            assert(source:FindFirstChild("FishingStation" .. n), "Missing fishing deck")
        end
    end
    local old = world:FindFirstChild(cfg.display_root)
    if old then
        old:Destroy()
    end
    local root = Instance.new("Model")
    root.Name, root.Parent = cfg.display_root, world
    root:SetAttribute("FishingConnected", false)
    local report = { rods = 0, lineTips = 0 }
    local d = cfg.display
    for _, pond in ipairs(cfg.ponds) do
        local spec = cfg.models[pond.realm]
        for n = 1, pond.stations do
            local deck = fishing[pond.name]["FishingStation" .. n]
            local model = cache[pond.realm]:Clone()
            model.Name = pond.realm .. "Rod_" .. n
            model:SetAttribute("StationKey", pond.name .. ":" .. n)
            model:SetAttribute("FishingConnected", false)
            local rawPivot = model:GetPivot()
            local intendedGrip = V.new(unpack(spec.grip_local))
            local frame = deck.CFrame
                * C.new(
                    d.grip_offset_x,
                    deck.Size.Y / 2 + d.grip_height_above_deck,
                    d.grip_offset_z
                )
                * C.Angles(math.rad(d.lean_x_degrees), 0, 0)
                * C.new(-intendedGrip)
                * C.Angles(0, math.rad(d.raw_to_intended_yaw_degrees), 0)
            -- Imported MeshParts retain positions about raw FBX origin, not bounding-box pivot.
            -- Compose that raw pivot rather than putting the bounding-box center on the hand.
            model:PivotTo(frame * rawPivot)
            local first
            for _, p in ipairs(model:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow =
                        true, false, false, false, false
                    first = first or p
                elseif p:IsA("LuaSourceContainer") or p:IsA("ProximityPrompt") then
                    p:Destroy()
                end
            end
            assert(first, "Rod contains no geometry")
            model.Parent = root
            local rawTip = V.new(unpack(spec.raw_line_tip_local))
            local tipWorld = frame:PointToWorldSpace(rawTip)
            for name, position in pairs({
                Grip = V.new(unpack(spec.raw_grip_local)),
                LineTip = rawTip,
            }) do
                local at = Instance.new("Attachment")
                at.Name = "Rod" .. name
                at.Parent = first
                at.WorldCFrame = frame * C.new(position)
            end
            local line = deck:FindFirstChild("LineTip")
            if not line then
                line = Instance.new("Attachment")
                line.Name, line.Parent = "LineTip", deck
            end
            if deck:GetAttribute("RodDisplayOriginalLineTip") == nil then
                deck:SetAttribute("RodDisplayOriginalLineTip", line.Position)
            end
            line.Position = deck.CFrame:PointToObjectSpace(tipWorld)
            line:SetAttribute("Source", "ActualRodTip")
            local reference = deck:FindFirstChild("RodDisplay")
            if reference then
                reference:Destroy()
            end
            reference = Instance.new("ObjectValue")
            reference.Name, reference.Value, reference.Parent = "RodDisplay", model, deck
            report.rods += 1
            report.lineTips += 1
        end
    end
    root:SetAttribute("RodCount", report.rods)
    return report
end
