return function(world, cfg)
    assert(
        game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(),
        "Local Edit preview only"
    )
    local V, C = Vector3, CFrame
    local backupName = cfg.root .. "Originals"
    local prior = world:FindFirstChild(cfg.root)
    local backup = game.ServerStorage:FindFirstChild(backupName)
    if backup then
        for _, p in ipairs(backup:GetChildren()) do
            local parent = world
            for name in string.gmatch(p:GetAttribute("RestorePath") or "", "[^.]+") do
                parent = parent:FindFirstChild(name)
                assert(parent, "Missing restore parent")
            end
            p.Parent = parent
        end
        backup:Destroy()
    end
    if prior then
        prior:Destroy()
    end
    backup = Instance.new("Folder")
    backup.Name = backupName
    backup.Parent = game.ServerStorage
    local root = Instance.new("Model")
    root.Name = cfg.root
    root.Parent = world
    local function group(name)
        local m = Instance.new("Model")
        m.Name = name
        m.Parent = root
        return m
    end
    local function stash(p, path)
        p:SetAttribute("RestorePath", path)
        p.Parent = backup
    end
    local function part(parent, name, size, cf, color, mat, collide)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.CFrame = cf
        p.Anchored = true
        p.Color = Color3.fromRGB(unpack(color))
        p.Material = Enum.Material[mat or "Limestone"]
        p.CanCollide = collide == true
        p.CanTouch = false
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent = parent
        return p
    end
    local paving = group("FittedPaving")
    local made = 0
    for _, src in ipairs(world.PathsAndLandings:GetChildren()) do
        if src:IsA("BasePart") and table.find(cfg.paving.names, src.Name) then
            local lo, hi =
                V.new(math.huge, math.huge, math.huge), V.new(-math.huge, -math.huge, -math.huge)
            for _, x in ipairs({ -1, 1 }) do
                for _, y in ipairs({ -1, 1 }) do
                    for _, z in ipairs({ -1, 1 }) do
                        local pt = src.CFrame:PointToWorldSpace(src.Size * V.new(x, y, z) / 2)
                        lo = lo:Min(pt)
                        hi = hi:Max(pt)
                    end
                end
            end
            local tiles = Instance.new("Model")
            tiles.Name = src.Name
            tiles.Parent = paving
            local step = cfg.paving.module
            local n = 0
            for x = math.floor(lo.X / step) * step, hi.X, step do
                for z = math.floor(lo.Z / step) * step, hi.Z, step do
                    local cutter = Instance.new("Part")
                    cutter.Size = V.new(step, hi.Y - lo.Y + 2, step)
                    cutter.CFrame = C.new(x + step / 2, (hi.Y + lo.Y) / 2, z + step / 2)
                    local ok, tile = pcall(function()
                        return src:IntersectAsync(
                            { cutter },
                            Enum.CollisionFidelity.PreciseConvexDecomposition,
                            Enum.RenderFidelity.Precise
                        )
                    end)
                    cutter:Destroy()
                    if ok and tile then
                        n += 1
                        tile.Name = "StonePaver"
                        tile.Anchored = true
                        tile.UsePartColor = true
                        tile.Material = Enum.Material.Limestone
                        local delta = ((math.floor(x / step) + math.floor(z / step) * 3) % 5 - 2)
                            * cfg.paving.variation
                        tile.Color = src.Color:Lerp(
                            delta > 0 and Color3.new(1, 1, 1) or Color3.new(0, 0, 0),
                            math.abs(delta)
                        )
                        tile.CanCollide = true
                        tile.CanTouch = false
                        tile.Parent = tiles
                    end
                end
            end
            assert(n > 0, "No fitted paving produced for " .. src.Name)
            made += n
            stash(src, "PathsAndLandings")
        end
    end
    local seal = group("ArrivalSeal")
    local s = cfg.seal
    local center = V.new(unpack(s.center))
    local disk = part(
        seal,
        "MeetingSeal",
        V.new(s.thickness, s.radius * 2, s.radius * 2),
        C.new(center - V.new(0, s.thickness / 2, 0)) * C.Angles(0, 0, math.pi / 2),
        s.color,
        "Metal",
        true
    )
    disk.Shape = Enum.PartType.Cylinder
    local cutter = disk:Clone()
    cutter.Size = V.new(4, s.radius * 2, s.radius * 2)
    cutter.Parent = nil
    local floor = world.BraggRotundaR6.TerraceAndEntry
    for _, p in ipairs(floor:GetChildren()) do
        if
            p.Name == "ArrivalPaver"
            and (V.new(p.Position.X, 0, p.Position.Z) - V.new(center.X, 0, center.Z)).Magnitude
                < s.radius + p.Size.Magnitude / 2
        then
            local result = p:SubtractAsync(
                { cutter },
                Enum.CollisionFidelity.PreciseConvexDecomposition,
                Enum.RenderFidelity.Precise
            )
            if result then
                result.Name = "SealSurround"
                result.UsePartColor = true
                result.Color = p.Color
                result.Anchored = true
                result.Parent = seal
            end
            stash(p, "BraggRotundaR6.TerraceAndEntry")
        end
    end
    cutter:Destroy()
    -- Flush fitted center replaces its own circular footprint; no overlaid medallion face.
    local inset = disk:Clone()
    inset.Name = "SealInset"
    inset.Size = V.new(s.thickness, s.radius * 1.5, s.radius * 1.5)
    inset.Color = Color3.fromRGB(unpack(s.inner_color))
    inset.Parent = seal
    local ring = disk:SubtractAsync(
        { inset },
        Enum.CollisionFidelity.PreciseConvexDecomposition,
        Enum.RenderFidelity.Precise
    )
    ring.Name = "SealRing"
    ring.UsePartColor = true
    ring.Color = disk.Color
    ring.Anchored = true
    ring.Parent = seal
    disk:Destroy()
    -- Remove development-only gold floor chips from the user-facing arrival.
    for _, p in ipairs(world.ElevationMarkers:GetChildren()) do
        if p:IsA("BasePart") and (p.Name == "Spawn" or p.Name == "Overlook") then
            p.Transparency = 1
            p.CanCollide = false
        end
    end
    local gates = group("GateRearCraft")
    for _, key in ipairs({ "FarmAndFight", "Merge" }) do
        local gate = world.ExistingMergeArches[key]
        local crest = gate.GateCrestR5
        local base = C.new(gate.Arch.Position.X, 0, gate.Arch.Position.Z)
            * gate.Arch.CFrame.Rotation
        local theme = key == "FarmAndFight" and cfg.gate.back_heaven or cfg.gate.back_hell
        local field = crest.RecessedField:Clone()
        field.Name = key .. "RearHeraldicField"
        field.CFrame += base:VectorToWorldSpace(V.new(0, 0, cfg.gate.back_offset))
        field.UsePartColor = true
        field.Color = Color3.fromRGB(unpack(theme))
        field.Parent = gates
        local border = crest.RaisedBorder:Clone()
        border.Name = key .. "RearBorder"
        border.CFrame += base:VectorToWorldSpace(V.new(0, 0, -1.3))
        border.Parent = gates
        local relief = crest.ModeRelief
        local backing = relief.ReliefBacking
        part(
            gates,
            key .. "ReliefRear",
            V.new(unpack(cfg.gate.relief_back_size)),
            backing.CFrame * C.new(0, 0, cfg.gate.relief_back_offset),
            theme,
            "Limestone",
            false
        )
        -- Repeat the existing heraldry around the rear with a physical 180-degree transform.
        local at = base * C.new(0, 23.4, 5.8)
        for _, name in ipairs({ "Heraldry", "SculptedTitle" }) do
            local ornament = crest[name]:Clone()
            ornament.Name = key .. "Rear" .. name
            ornament.Parent = gates
            for _, p in ipairs(ornament:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.CFrame = at * C.Angles(0, math.pi, 0) * at:ToObjectSpace(p.CFrame)
                    p.CanCollide = false
                end
            end
        end
        local light = crest.FaceKeyFixture:FindFirstChildOfClass("PointLight")
        if light then
            light.Brightness = cfg.gate.face_brightness
            light.Range = cfg.gate.face_range
        end
        local anchor = part(
            gates,
            key .. "TravelAnchor",
            V.one,
            C.new(base:PointToWorldSpace(V.new(0, 3, 2))),
            theme,
            "SmoothPlastic",
            false
        )
        anchor.Transparency = 1
        anchor:SetAttribute("StubAction", cfg.interaction.gate_action)
        anchor:SetAttribute("Destination", key)
        anchor:SetAttribute("GameplayConnected", false)
        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = "Enter"
        prompt.ObjectText = key == "FarmAndFight" and "Farm & Fight" or "Pet Siege"
        prompt.HoldDuration = cfg.interaction.hold
        prompt.MaxActivationDistance = cfg.interaction.range
        prompt.Enabled = cfg.interaction.enabled
        prompt.Parent = anchor
    end
    local plants = group("ArrivalPlanting")
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { plants }
    for _, cluster in ipairs(cfg.plant_groups) do
        for i, name in ipairs(cfg.plant_palette[cluster[3]]) do
            local off = cfg.plant_offsets[i]
            local x, z = cluster[1] + off[1], cluster[2] + off[2]
            local hit = workspace:Raycast(V.new(x, 40, z), V.new(0, -80, 0), params)
            local template = game.ServerStorage.CrossroadsLandscapeAssets:FindFirstChild(name)
            if hit and hit.Instance == workspace.Terrain and template then
                local m = template:Clone()
                m.Name = name
                m.Parent = plants
                local _, size = m:GetBoundingBox()
                m:ScaleTo(m:GetScale() * cfg.plant_height[i] / size.Y)
                m:PivotTo(C.new(x, hit.Position.Y, z) * C.Angles(0, x + z, 0))
                local box, sz = m:GetBoundingBox()
                m:PivotTo(m:GetPivot() + V.new(0, hit.Position.Y - (box.Position.Y - sz.Y / 2), 0))
                for _, p in ipairs(m:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.Anchored = true
                        p.CanCollide = false
                        p.CanTouch = false
                        p.CanQuery = false
                    end
                end
            end
        end
    end
    local rail = group("OverlookStonework")
    local r = cfg.overlook
    for x = r.x_min, r.x_max, r.post_step do
        part(
            rail,
            "PierBase",
            V.new(2.2, 0.55, 2.2),
            C.new(x, r.base_y + 0.275, r.z),
            r.stone,
            "Limestone",
            true
        )
        part(
            rail,
            "Pier",
            V.new(1.4, r.rail_height, 1.4),
            C.new(x, r.base_y + r.rail_height / 2, r.z),
            r.stone,
            "Limestone",
            true
        )
        part(
            rail,
            "PierCap",
            V.new(2, 0.35, 2),
            C.new(x, r.base_y + r.rail_height + 0.175, r.z),
            r.trim,
            "Metal",
            false
        )
        if x < r.x_max then
            part(
                rail,
                "StoneRail",
                V.new(r.post_step - 1.4, 0.65, 0.8),
                C.new(x + r.post_step / 2, r.base_y + 2.8, r.z),
                r.stone,
                "Limestone",
                true
            )
            for dx = 3, r.post_step - 3, 3 do
                part(
                    rail,
                    "Baluster",
                    V.new(0.6, r.baluster_height, 0.6),
                    C.new(x + dx, r.base_y + r.baluster_height / 2, r.z),
                    r.stone,
                    "Limestone",
                    true
                )
            end
        end
    end
    for _, p in ipairs(world.OverlookRail:GetChildren()) do
        stash(p, "OverlookRail")
    end
    return { pavers = made, plants = #plants:GetChildren(), gateBacks = 2 }
end
