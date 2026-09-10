-- Edit-time replacement of the exact authored Playfield volume, never an overlay.
return function(world, cfg)
    assert(game.PlaceId == 0, "Arena floor finish is restricted to the unpublished preview")
    assert(not game:GetService("RunService"):IsRunning(), "Stop Play before arena floor finish")
    local activities = world and world:FindFirstChild(cfg.activity_root)
    local arena = activities and activities:FindFirstChild(cfg.arena_name)
    assert(arena, "Missing authored PatrolGrove")
    local storage = game:GetService("ServerStorage")
    local archive = storage:FindFirstChild(cfg.backup_name)
    local source = archive and archive:FindFirstChild(cfg.source_archive_name)
        or arena:FindFirstChild(cfg.source_name)
    assert(source and source:IsA("BasePart"), "Missing original arena Playfield")
    local V, C = Vector3, CFrame
    local tolerance = cfg.validation_tolerance
    assert(
        (source.Position - V.new(unpack(cfg.expected_center))).Magnitude < tolerance,
        "Arena center changed; review config"
    )
    assert(
        (source.Size - V.new(unpack(cfg.expected_size))).Magnitude < tolerance,
        "Arena dimensions changed; review config"
    )
    assert(
        source.CFrame.UpVector:Dot(V.yAxis) > 1 - tolerance,
        "Arena floor is no longer horizontal"
    )
    local top = source.Position.Y + source.Size.Y / 2
    assert(math.abs(top - cfg.expected_top) < tolerance, "Arena top changed; review config")
    assert(
        cfg.finish_depth < source.Size.Y and cfg.finish_depth > cfg.receivers.recess,
        "Invalid floor layer depths"
    )
    assert(
        math.abs(cfg.mortar_recess - cfg.finish_depth) < tolerance,
        "Mortar and finish must share one contact plane"
    )
    local covers = {}
    for _, p in ipairs(arena:GetChildren()) do
        if p:IsA("BasePart") and (p.Name == "LowCover" or p.Name == "CoverCap") then
            table.insert(covers, { part = p, cf = p.CFrame, size = p.Size })
        end
    end
    local colors = {}
    for key, rgb in pairs(cfg.palette) do
        colors[key] = Color3.fromRGB(unpack(rgb))
    end
    local stats = { panels = 0, cutPanels = 0, receiverFaces = 0, foundations = 0, medalParts = 0 }
    local out = Instance.new("Model")
    out.Name = cfg.output_name .. "Preparing"
    out.Parent = workspace
    local function part(name, size, cf, key, material, collide)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = V.new(unpack(size))
        p.CFrame = cf
        p.Anchored = true
        p.CanCollide = collide == true
        p.CanQuery = collide == true
        p.CanTouch = false
        p.CastShadow = false
        p.Material = Enum.Material[material or cfg.materials[key]]
        p.Color = colors[key]
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent = out
        return p
    end
    local frame = C.new(source.Position.X, top - cfg.finish_depth / 2, source.Position.Z)
    local function finish(p, name, key, material)
        p.Name = name
        p.UsePartColor = true
        p.Color = colors[key]
        p.Material = Enum.Material[material or cfg.materials[key]]
        p.Anchored = true
        p.CanCollide = true
        p.CanQuery = true
        p.CanTouch = false
        p.CastShadow = false
        p.Transparency = 0
        p.Parent = out
        return p
    end
    local function disk(name, radius, height, key)
        local p =
            part(name, { height, radius * 2, radius * 2 }, frame * C.Angles(0, 0, math.pi / 2), key)
        p.Shape = Enum.PartType.Cylinder
        return p
    end
    local function slab(name, x0, x1, z0, z1, key, recess)
        recess = recess or 0
        assert(x1 > x0 and z1 > z0, "Invalid floor panel bounds")
        return part(
            name,
            { x1 - x0, cfg.finish_depth - recess, z1 - z0 },
            frame * C.new((x0 + x1) / 2, -recess / 2, (z0 + z1) / 2),
            key,
            cfg.materials[key],
            true
        )
    end
    local ok, err = pcall(function()
        local width, depth = source.Size.X, source.Size.Z
        local halfW, halfD = width / 2, depth / 2
        local border = cfg.border_width
        local bottom = source.Position.Y - source.Size.Y / 2
        local mortarHeight = source.Size.Y - cfg.finish_depth
        part(
            "MortarFoundation",
            { width, mortarHeight, depth },
            C.new(source.Position.X, bottom + mortarHeight / 2, source.Position.Z),
            "mortar",
            cfg.materials.mortar,
            true
        )
        local m = cfg.medal
        local circleCut = disk("MedalCutTemporary", m.radius, m.cutter_height, "mortar")
        local innerW, innerD = width - border * 2, depth - border * 2
        local rowDepth = innerD / cfg.rows
        for row = 1, cfg.rows do
            local z0 = -innerD / 2 + (row - 1) * rowDepth
            local z1 = z0 + rowDepth
            local cuts = cfg.column_cuts[(row - 1) % #cfg.column_cuts + 1]
            for col = 1, #cuts - 1 do
                local x0 = -innerW / 2 + innerW * cuts[col]
                local x1 = -innerW / 2 + innerW * cuts[col + 1]
                local gap = cfg.joint_width / 2
                local panel =
                    slab("CombatStonePanel", x0 + gap, x1 - gap, z0 + gap, z1 - gap, "stone")
                local factor = cfg.stone_variations[(row + col - 2) % #cfg.stone_variations + 1]
                panel.Color = Color3.new(
                    colors.stone.R * factor,
                    colors.stone.G * factor,
                    colors.stone.B * factor
                )
                local closestX = math.clamp(0, x0 + gap, x1 - gap)
                local closestZ = math.clamp(0, z0 + gap, z1 - gap)
                if closestX * closestX + closestZ * closestZ < m.radius * m.radius then
                    local cut = panel:SubtractAsync(
                        { circleCut },
                        Enum.CollisionFidelity.PreciseConvexDecomposition,
                        Enum.RenderFidelity.Precise
                    )
                    finish(cut, "CombatStonePanel", "stone")
                    cut.Color = panel.Color
                    panel:Destroy()
                    stats.cutPanels += 1
                end
                stats.panels += 1
            end
        end
        circleCut:Destroy()
        -- Four foundations partition the original floor edges; nothing extends outside them.
        slab("EastBulwarkFoundation", halfW - border, halfW, -halfD, halfD, "foundation")
        slab(
            "NorthBulwarkFoundation",
            -halfW + border,
            halfW - border,
            -halfD,
            -halfD + border,
            "foundation"
        )
        stats.foundations += 2
        local r = cfg.receivers
        local function receiverSegments(axis, lo, hi, center)
            local a, b = center - r.clear_span / 2, center + r.clear_span / 2
            local cuts = { lo, a - r.guide_width, a, b, b + r.guide_width, hi }
            for n = 1, #cuts - 1 do
                local key = n == 3 and "iron" or (n == 2 or n == 4) and "bronze" or "foundation"
                local recess = n == 3 and r.recess or 0
                local name = "BulwarkFoundation"
                if n == 3 then
                    name = "RetractedGateReceiver"
                elseif n == 2 or n == 4 then
                    name = "GateGuideShoe"
                end
                local p
                if axis == "west" then
                    p = slab(name, -halfW, -halfW + border, cuts[n], cuts[n + 1], key, recess)
                else
                    p = slab(name, cuts[n], cuts[n + 1], halfD - border, halfD, key, recess)
                end
                p:SetAttribute("PreviewOnly", true)
                if n == 3 then
                    p:SetAttribute("GatewaySide", axis)
                    p:SetAttribute("ClearSpan", r.clear_span)
                    p:SetAttribute(
                        "IntendedBinding",
                        "Existing bulwark receiver; visual finish only"
                    )
                    stats.receiverFaces += 1
                else
                    stats.foundations += 1
                end
            end
        end
        receiverSegments("west", -halfD, halfD, r.west_center_local_z)
        receiverSegments("south", -halfW + border, halfW - border, r.south_center_local_x)
        local outer = disk("MedalOuterTemporary", m.radius, cfg.finish_depth, "bronze")
        local innerCut = disk("MedalInnerCutTemporary", m.inner_radius, m.cutter_height, "mortar")
        local ring = outer:SubtractAsync(
            { innerCut },
            Enum.CollisionFidelity.PreciseConvexDecomposition,
            Enum.RenderFidelity.Precise
        )
        finish(ring, "WeatheredCrestRing", "bronze", cfg.materials.bronze)
        outer:Destroy()
        innerCut:Destroy()
        local core = disk("MedalCoreTemporary", m.inner_radius, cfg.finish_depth, "heaven")
        local pieces = {}
        local function add(p)
            table.insert(pieces, p)
        end
        local scale = m.motif_scale
        add(
            part(
                "CrestNorthSouthTemporary",
                { m.cross_width * scale, cfg.finish_depth, m.cross_span * scale },
                frame,
                "bronze",
                cfg.materials.bronze
            )
        )
        add(
            part(
                "CrestEastWestTemporary",
                { m.cross_span * scale, cfg.finish_depth, m.cross_width * scale },
                frame,
                "bronze",
                cfg.materials.bronze
            )
        )
        add(
            part(
                "CrestDiamondTemporary",
                { m.diamond_size * scale, cfg.finish_depth, m.diamond_size * scale },
                frame * C.Angles(0, math.pi / 4, 0),
                "bronze",
                cfg.materials.bronze
            )
        )
        local function stroke(points)
            local a = frame:PointToWorldSpace(V.new(points[1][1] * scale, 0, points[1][2] * scale))
            local b = frame:PointToWorldSpace(V.new(points[2][1] * scale, 0, points[2][2] * scale))
            add(
                part(
                    "CrestStrokeTemporary",
                    { m.stroke_width * scale, cfg.finish_depth, (b - a).Magnitude },
                    C.lookAt((a + b) / 2, b),
                    "bronze",
                    cfg.materials.bronze
                )
            )
        end
        for _, points in ipairs(m.feather_segments) do
            stroke(points)
        end
        for _, points in ipairs(m.horn_segments) do
            stroke(points)
        end
        for _, p in ipairs(pieces) do
            for _, x in ipairs({ -1, 1 }) do
                for _, z in ipairs({ -1, 1 }) do
                    local q = frame:PointToObjectSpace(
                        p.CFrame:PointToWorldSpace(V.new(x * p.Size.X / 2, 0, z * p.Size.Z / 2))
                    )
                    assert(
                        V.new(q.X, 0, q.Z).Magnitude < m.inner_radius,
                        "Crest motif outside inner disk"
                    )
                end
            end
        end
        local first = table.remove(pieces, 1)
        local motif = first:UnionAsync(
            pieces,
            Enum.CollisionFidelity.PreciseConvexDecomposition,
            Enum.RenderFidelity.Precise
        )
        motif.Parent = out
        first:Destroy()
        for _, p in ipairs(pieces) do
            p:Destroy()
        end
        local tallMotif = motif:Clone()
        tallMotif.Size = V.new(motif.Size.X, m.cutter_height, motif.Size.Z)
        tallMotif.Parent = out
        local remainder = core:SubtractAsync(
            { tallMotif },
            Enum.CollisionFidelity.PreciseConvexDecomposition,
            Enum.RenderFidelity.Precise
        )
        remainder.Parent = out
        core:Destroy()
        tallMotif:Destroy()
        local splitSize = m.radius * 2
        local eastCut = part(
            "EastCrestCutTemporary",
            { splitSize, m.cutter_height, splitSize },
            frame * C.new(splitSize / 2, 0, 0),
            "mortar"
        )
        local westCut = part(
            "WestCrestCutTemporary",
            { splitSize, m.cutter_height, splitSize },
            frame * C.new(-splitSize / 2, 0, 0),
            "mortar"
        )
        local heaven = remainder:SubtractAsync(
            { eastCut },
            Enum.CollisionFidelity.PreciseConvexDecomposition,
            Enum.RenderFidelity.Precise
        )
        finish(heaven, "HeavenCrestStone", "heaven")
        local hell = remainder:SubtractAsync(
            { westCut },
            Enum.CollisionFidelity.PreciseConvexDecomposition,
            Enum.RenderFidelity.Precise
        )
        finish(hell, "HellCrestStone", "hell")
        finish(motif, "EngravedSharedCrest", "bronze", cfg.materials.bronze)
        remainder:Destroy()
        eastCut:Destroy()
        westCut:Destroy()
        stats.medalParts = 4
        for _, record in ipairs(covers) do
            assert(
                record.part.CFrame == record.cf and record.part.Size == record.size,
                "Cover changed during floor preparation"
            )
        end
    end)
    if not ok then
        out:Destroy()
        error("Arena floor preparation failed; original retained: " .. tostring(err))
    end
    if not archive then
        archive = Instance.new("Folder")
        archive.Name = cfg.backup_name
        archive.Parent = storage
    end
    if not archive:FindFirstChild(cfg.source_archive_name) then
        local original = source:Clone()
        original.Name = cfg.source_archive_name
        original.Parent = archive
    end
    local marker = archive:FindFirstChild(cfg.source_archive_name):Clone()
    local current = arena:FindFirstChild(cfg.source_name)
    if current then
        current:Destroy()
    end
    marker.Name = cfg.source_name
    marker.Transparency = 1
    marker.CanCollide = false
    marker.CanQuery = false
    marker.CanTouch = false
    marker.CastShadow = false
    marker:SetAttribute("FloorAuthoringProxy", true)
    marker:SetAttribute("PreviewOnly", true)
    marker:SetAttribute("GameplayConnected", false)
    marker.Parent = arena
    local previous = arena:FindFirstChild(cfg.output_name)
    if previous then
        previous:Destroy()
    end
    out.Name = cfg.output_name
    out:SetAttribute("PreviewOnly", true)
    out:SetAttribute("GameplayConnected", false)
    out:SetAttribute("ArtRevision", cfg.revision)
    out.Parent = arena
    stats.coverPartsPreserved = #covers
    stats.floorTop = top
    return stats
end
