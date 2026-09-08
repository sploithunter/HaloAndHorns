-- Author the Bragg Rotunda once in Edit. Display hosts are preview-only, never fake scores.
return function()
    assert(not game:GetService("RunService"):IsRunning(), "Bragg bake requires Edit")
    assert(game.PlaceId == 0, "Isolated Crossroads only")
    local H = game:GetService("HttpService")
    local cfg = H:JSONDecode(game.ServerStorage.CrossroadsBraggConfig.Value)
    local glyphs = H:JSONDecode(game.ServerStorage.CrossroadsGlyphConfig.Value).glyphs
    local templates = game.ServerStorage.CrossroadsLetterSolids
    local V, C = Vector3, CFrame
    local oldRoot = workspace.RealmCrossroadsR4
    local function make(class, name, parent)
        local p = Instance.new(class)
        p.Name = name
        p.Parent = parent
        return p
    end
    local backup = game.ServerStorage:FindFirstChild("BeforeBraggR6")
    if not backup then
        backup = make("Folder", "BeforeBraggR6", game.ServerStorage)
        local region = workspace.Terrain:CopyRegion(
            Region3int16.new(Vector3int16.new(-25, -2, -39), Vector3int16.new(24, 5, 2))
        )
        region.Name = "OriginalTerrain"
        region.Parent = backup
    end
    -- Move only superseded preview elements. Retain the gate art and all other routes.
    for _, name in ipairs({ "GalleryMassing", "LandmarkEnvelope" }) do
        local p = oldRoot:FindFirstChild(name)
        if p then
            p.Parent = backup
        end
    end
    for _, group in ipairs({
        "PathsAndLandings",
        "RetainingWalls",
        "GradedStairsAndRamps",
        "ElevationMarkers",
    }) do
        for _, p in ipairs(oldRoot[group]:GetChildren()) do
            if
                string.find(p.Name, "Gallery", 1, true)
                or string.find(p.Name, "RearTerrace", 1, true)
            then
                p.Parent = backup
            end
        end
    end
    local old = oldRoot:FindFirstChild("BraggRotundaR6")
    if old then
        old:Destroy()
    end
    local root = make("Model", "BraggRotundaR6", oldRoot)
    root:SetAttribute("PreviewOnly", true)
    root:SetAttribute("RankingsConnected", false)
    local color = {}
    for k, rgb in pairs(cfg.art.palette) do
        color[k] = Color3.fromRGB(unpack(rgb))
    end
    local origin = V.new(cfg.center[1], cfg.court_elevation, cfg.center[2])
    local function group(name)
        return make("Model", name, root)
    end
    local function part(parent, name, size, cf, key, material, collide)
        local p = make("Part", name, parent)
        p.Size = V.new(unpack(size))
        p.CFrame = cf
        p.Color = color[key]
        p.Material = Enum.Material[material or "Limestone"]
        p.Anchored = true
        p.CanCollide = collide ~= false
        p.CanTouch = false
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        return p
    end
    local function disk(parent, name, radius, height, pos, key, mat, collide)
        local p = part(
            parent,
            name,
            { height, radius * 2, radius * 2 },
            C.new(pos) * C.Angles(0, 0, math.pi / 2),
            key,
            mat,
            collide
        )
        p.Shape = Enum.PartType.Cylinder
        return p
    end
    local function line(parent, name, a, b, width, key, mat, collide)
        return part(
            parent,
            name,
            { width, width, (b - a).Magnitude },
            C.lookAt((a + b) / 2, b),
            key,
            mat,
            collide
        )
    end
    local function ring(parent, name, r, y, width, height, key, mat, fromAngle, toAngle)
        local count = cfg.art.ring_segments
        fromAngle = fromAngle or 0
        toAngle = toAngle or math.pi * 2
        for n = 1, count do
            local a = fromAngle + (toAngle - fromAngle) * (n - 0.5) / count
            local len = 2 * r * math.tan((toAngle - fromAngle) / count / 2) + 0.04
            part(
                parent,
                name,
                { len, height, width },
                C.new(origin + V.new(math.sin(a) * r, y, math.cos(a) * r)) * C.Angles(0, a, 0),
                key,
                mat
            )
        end
    end
    local function text(parent, word, height, maxWidth, cf, key)
        local width = 0
        for i = 1, #word do
            local ch = word:sub(i, i)
            width += ch == " " and 0.38 or glyphs[ch].width + 0.12
        end
        local scale = math.min(height, maxWidth / width)
        local x = -width * scale / 2
        for i = 1, #word do
            local ch = word:sub(i, i)
            if ch == " " then
                x += 0.38 * scale
            else
                local g = glyphs[ch]
                local template = templates[ch]
                local p = template:Clone()
                p.Name = "Letter_" .. ch
                p.Size = template.Size * scale
                p.CFrame = cf
                    * C.new(x + g.width * scale / 2, 0, 0)
                    * C.new(template.Position * scale)
                    * template.CFrame.Rotation
                p.Color = color[key]
                p.Material = Enum.Material.Metal
                p.CanCollide = false
                p.Parent = parent
                x += (g.width + 0.12) * scale
            end
        end
    end
    -- Replace the old rectangular gallery grading within a bounded region.
    local region = Region3.new(V.new(-100, -8, -156), V.new(100, 24, 12))
    local mats, occ = workspace.Terrain:ReadVoxels(region, 4)
    for ix = 1, 50 do
        local x = -100 + (ix - 0.5) * 4
        for iz = 1, 42 do
            local z = -156 + (iz - 0.5) * 4
            local h = math.abs(x) >= 80 and 4 or 0
            if z < -132 then
                h = 4 + 8 * math.clamp((-132 - z) / 16, 0, 1)
            end
            local dx, dz = x - origin.X, z - origin.Z
            if dx * dx + dz * dz <= cfg.outer_radius ^ 2 then
                h = cfg.court_elevation
            end
            local ax = math.abs(dx)
            local apron = cfg.entrance_apron
            if ax <= apron.half_width and dz >= apron.far_offset and dz <= apron.near_offset then
                h = 4
            end
            if ax <= cfg.entrance_width / 2 and dz >= 62 and dz <= 78 then
                h = 4 * (78 - dz) / 16
            end
            if ax >= 19 and ax <= 35 and dz >= 62 and dz <= 94 then
                h = 4 * (94 - dz) / 32
            end
            for iy = 1, 8 do
                local bottom = -8 + (iy - 1) * 4
                local amount = math.clamp((h - 2 - bottom) / 4, 0, 1)
                occ[ix][iy][iz] = amount
                mats[ix][iy][iz] = amount > 0 and Enum.Material.Grass or Enum.Material.Air
            end
        end
    end
    workspace.Terrain:WriteVoxels(region, 4, mats, occ)
    local floors = group("TerraceAndEntry")
    disk(floors, "CircularCourt", cfg.outer_radius, 0.42, origin + V.new(0, 0.23, 0), "floor")
    ring(
        floors,
        "RetainingFace",
        cfg.outer_radius,
        -2,
        1.2,
        4,
        "stone",
        nil,
        math.rad(14),
        math.rad(346)
    )
    ring(
        floors,
        "RetainingCap",
        cfg.outer_radius,
        0.25,
        1.5,
        0.45,
        "light_stone",
        nil,
        math.rad(14),
        math.rad(346)
    )
    ring(floors, "InnerInlay", 33, 0.51, 0.25, 0.08, "trim", "Metal")
    ring(floors, "OuterInlay", 37, 0.51, 0.2, 0.08, "trim", "Metal")
    local apron = cfg.entrance_apron
    part(
        floors,
        "EntryApron",
        { apron.half_width * 2, 0.42, apron.near_offset - apron.far_offset },
        C.new(origin + V.new(0, 0.23, (apron.near_offset + apron.far_offset) / 2)),
        "light_stone"
    )
    for n = 1, cfg.stair_risers do
        local top = 4 - (n - 1) * cfg.stair_rise
        part(
            floors,
            "EntryStep" .. n,
            { cfg.entrance_width, top + 1, cfg.stair_tread },
            C.new(origin.X, (top - 1) / 2 + 0.24, origin.Z + 62 + (n - 0.5) * cfg.stair_tread),
            "light_stone"
        )
    end
    for _, side in ipairs({ -1, 1 }) do
        local top = V.new(origin.X + side * 27, 4, origin.Z + 62)
        local bottom = V.new(origin.X + side * 27, 0, origin.Z + 94)
        part(
            floors,
            "EntryRamp",
            { cfg.ramp_width, 0.35, (bottom - top).Magnitude },
            C.lookAt((top + bottom) / 2 + V.new(0, 0.24, 0), bottom + V.new(0, 0.24, 0)),
            "light_stone"
        )
        part(
            floors,
            "ApronRetaining",
            { 9, 4, 1 },
            C.new(origin + V.new(side * 17.5, -2, 62)),
            "stone"
        )
    end
    part(floors, "ArrivalWalk", { 20, 0.3, 90 }, C.new(0, 0.22, 51), "floor")
    local bays = group("PodiumAlcoves")
    for _, b in ipairs(cfg.bays) do
        local theta = math.rad(33.75 + (b.number - 1) * 22.5)
        local radial = V.new(math.sin(theta), 0, math.cos(theta))
        local center = origin + radial * cfg.podium_radius
        local base = C.lookAt(center, center + radial)
        local bay = make("Model", string.format("Alcove%02d", b.number), bays)
        bay:SetAttribute("DisplayName", b.display_name or b.name)
        bay:SetAttribute("BoardId", b.board_id or "")
        bay:SetAttribute("RankingsConnected", false)
        local active = b.phase == "initial"
        part(
            bay,
            "FloorMosaic",
            { cfg.alcove_width, 0.25, cfg.alcove_depth },
            base * C.new(0, 0.52, 0),
            "light_stone"
        )
        part(
            bay,
            "RearWall",
            { cfg.alcove_width, cfg.art.wall_height, 1.2 },
            base * C.new(0, cfg.art.wall_height / 2, -5.1),
            "stone"
        )
        part(
            bay,
            "WallInset",
            { cfg.alcove_width - 1.5, 8, 0.22 },
            base * C.new(0, 6.2, -4.42),
            "floor"
        )
        for _, x in ipairs({ -9, 9 }) do
            part(
                bay,
                "Column",
                { 1.2, cfg.art.column_height, 1.2 },
                base * C.new(x, cfg.art.column_height / 2, -4.3),
                "light_stone"
            )
            part(
                bay,
                "Capital",
                { 2, 1, 2 },
                base * C.new(x, cfg.art.column_height - 0.4, -4.3),
                "trim",
                "Metal"
            )
        end
        part(bay, "Cornice", { 19, 1.2, 3.6 }, base * C.new(0, 15, -4.5), "light_stone")
        part(
            bay,
            "CorniceInlay",
            { 18, 0.14, 0.15 },
            base * C.new(0, 15.15, -2.64),
            "trim",
            "Metal",
            false
        )
        part(bay, "TitlePlaque", { 17.5, 4.3, 0.3 }, base * C.new(0, 12.25, -3.8), "light_stone")
        part(
            bay,
            "TitleBorder",
            { 17.5, 0.12, 0.12 },
            base * C.new(0, 14.35, -3.58),
            "trim",
            "Metal",
            false
        )
        if active then
            local header = make("Model", "SculptedHeader", bay)
            for n, title in ipairs(b.title_lines) do
                text(header, title, 1.45, 16, base * C.new(0, 13.25 - (n - 1) * 1.7, -3.5), "ink")
            end
            text(header, b.scope, 0.45, 14, base * C.new(0, 9.45, -3.5), "ink")
            local hook = part(bay, "AwardPodiumHook", { 1, 1, 1 }, base, "trim", nil, false)
            hook.Transparency = 1
            hook:SetAttribute("BoardId", b.board_id)
            hook:SetAttribute("PreviewOnly", true)
            -- Hook intentionally untagged until the real leaderboard renderer is installed.
            for k, rank in ipairs({ 2, 1, 3 }) do
                local x = (k - 2) * 5.2
                local h = cfg.art.podium_heights[k]
                part(
                    bay,
                    "Podium" .. rank,
                    { 4.7, h, 4.7 },
                    base * C.new(x, h / 2 + 0.55, 1),
                    "stone"
                )
                part(
                    bay,
                    "PodiumCap" .. rank,
                    { 5, 0.3, 5 },
                    base * C.new(x, h + 0.7, 1),
                    "rank" .. rank,
                    "Metal"
                )
                text(
                    bay,
                    tostring(rank),
                    1.25,
                    2,
                    base * C.new(x, h / 2 + 0.8, 3.43),
                    "rank" .. rank
                )
                part(
                    bay,
                    "Nameplate" .. rank,
                    { 4.6, 0.5, 0.18 },
                    base * C.new(x, 0.95, 3.5),
                    "ink",
                    "Metal",
                    false
                )
                text(bay, "PREVIEW", 0.25, 4.1, base * C.new(x, 0.95, 3.64), "light_stone")
            end
        else
            bay.TitlePlaque:Destroy()
            bay.TitleBorder:Destroy()
            local decor = cfg.art.existing_decor
            local cache = game.ServerStorage:FindFirstChild(decor.template_folder)
            if not cache then
                cache = make("Folder", decor.template_folder, game.ServerStorage)
            end
            local garden = make("Model", "RealmDecor", bay)
            garden:SetAttribute("ReservedFor", b.name)
            garden:SetAttribute("Theme", b.decoration)
            local hell = b.decoration == "hell"
            local stoneKey = hell and "hell_stone" or "light_stone"
            if hell then
                bay.RearWall.Color = color.hell_stone
                bay.WallInset.Color = color.hell_stone
            end
            part(garden, "RaisedBed", { 14, 1.5, 5.4 }, base * C.new(0, 1.3, 0.2), stoneKey)
            part(garden, "BedRim", { 14.4, 0.25, 5.8 }, base * C.new(0, 2.08, 0.2), stoneKey)
            part(
                garden,
                "BedSurface",
                { 13.5, 0.16, 4.9 },
                base * C.new(0, 2.24, 0.2),
                hell and "ink" or "leaf_dark",
                "Ground"
            )
            for _, spec in ipairs(b.props) do
                local template = cache:FindFirstChild(spec.model)
                if not template then
                    local loaded = game:GetService("InsertService")
                        :LoadAsset(decor.models[spec.model])
                    loaded.Name = spec.model
                    loaded.Parent = cache
                    template = loaded
                end
                local model = template:Clone()
                model.Name = spec.model
                model.Parent = garden
                for _, item in ipairs(model:GetDescendants()) do
                    if item:IsA("BasePart") then
                        item.Anchored = true
                        item.CanCollide = false
                        item.CanTouch = false
                        item.CanQuery = false
                    elseif item:IsA("LuaSourceContainer") then
                        item:Destroy()
                    end
                end
                model:PivotTo(C.new())
                model:ScaleTo(model:GetScale() * spec.height / model:GetExtentsSize().Y)
                local box, size = model:GetBoundingBox()
                local footing = C.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
                local destination = base
                    * C.new(unpack(spec.position))
                    * C.Angles(0, math.rad(spec.yaw), 0)
                model:PivotTo(destination * footing:Inverse() * model:GetPivot())
                model:SetAttribute("SourceAsset", decor.models[spec.model])
            end
        end
    end
    local fountain = group("HaloAndHornsFountain")
    disk(fountain, "Foundation", 11, 0.65, origin + V.new(0, 0.75, 0), "stone")
    disk(
        fountain,
        "BasinFloor",
        cfg.fountain_radius,
        0.3,
        origin + V.new(0, 1.05, 0),
        "light_stone"
    )
    ring(fountain, "BasinRim", cfg.fountain_radius, 1.45, 0.8, 1.3, "light_stone")
    ring(fountain, "BasinGold", cfg.fountain_radius + 0.12, 2.03, 0.14, 0.13, "trim", "Metal")
    local water = disk(
        fountain,
        "Water",
        cfg.fountain_radius - 0.45,
        0.1,
        origin + V.new(0, 1.7, 0),
        "water",
        "Glass",
        false
    )
    water.Transparency = cfg.art.water_transparency
    disk(fountain, "CentralPedestal", 1.8, 3.1, origin + V.new(0, 2.2, 0), "stone")
    disk(fountain, "UpperBowl", 3.2, 0.65, origin + V.new(0, 4, 0), "light_stone")
    ring(fountain, "UpperBowlGold", 3.2, 4.37, 0.15, 0.2, "trim", "Metal")
    local upper =
        disk(fountain, "UpperWater", 2.9, 0.1, origin + V.new(0, 4.36, 0), "water", "Glass", false)
    upper.Transparency = 0.22
    -- Low paired arcs echo the entrance themes without blocking views across the court.
    local haloCenter = origin + V.new(0, 5.5, 0)
    for n = 1, 40 do
        local a, b = (n - 1) * math.pi * 2 / 40, n * math.pi * 2 / 40
        line(
            fountain,
            "Halo",
            haloCenter + V.new(math.cos(a) * 2, math.sin(a) * 2, 0),
            haloCenter + V.new(math.cos(b) * 2, math.sin(b) * 2, 0),
            0.2,
            "trim",
            "Metal",
            false
        )
    end
    for _, side in ipairs({ -1, 1 }) do
        local a = origin + V.new(side * 1.2, 4.7, 0.2)
        for n = 1, 7 do
            local t = n / 7
            local b = origin
                + V.new(side * (1.2 + 1.2 * math.sin(t * math.pi * 0.8)), 4.7 + t * 2.3, 0.2)
            line(fountain, "HornArc", a, b, 0.38 * (1 - t) + 0.08, "ink", "Metal", false)
            a = b
        end
    end
    local jets = make("Folder", "WaterJets", fountain)
    for n = 1, cfg.art.jet_count do
        local theta = n * math.pi * 2 / cfg.art.jet_count
        local radial = V.new(math.sin(theta), 0, math.cos(theta))
        local from = origin + radial * 2.8 + V.new(0, 4.5, 0)
        local to = origin + radial * 7.7 + V.new(0, 1.76, 0)
        local host = part(jets, "JetAnchor", { 0.1, 0.1, 0.1 }, C.new(from), "water", nil, false)
        host.Transparency = 1
        local a = make("Attachment", "From", host)
        a.WorldCFrame = C.fromMatrix(from, (radial + V.yAxis).Unit, V.yAxis:Cross(radial).Unit)
        local b = make("Attachment", "To", host)
        b.WorldCFrame = C.fromMatrix(to, (-radial + V.yAxis).Unit, V.yAxis:Cross(radial).Unit)
        local beam = make("Beam", "WaterArc", host)
        beam.Attachment0 = a
        beam.Attachment1 = b
        beam.CurveSize0 = 3
        beam.CurveSize1 = 2
        beam.Width0 = cfg.art.jet_width
        beam.Width1 = cfg.art.jet_width * 0.8
        beam.FaceCamera = true
        beam.Segments = 24
        beam.Color = ColorSequence.new(color.water)
        beam.Transparency = NumberSequence.new(0.35)
        beam.LightEmission = 0.25
    end
    text(fountain, "BRAGG", 1.3, 10, C.new(origin + V.new(0, 1.1, 10.9)), "ink")
    game:GetService("ChangeHistoryService"):SetWaypoint("Bragg Rotunda R6")
    return {
        alcoves = #cfg.bays,
        podiumGroups = 8,
        rankingsConnected = false,
        center = tostring(origin),
        instances = #root:GetDescendants(),
    }
end
