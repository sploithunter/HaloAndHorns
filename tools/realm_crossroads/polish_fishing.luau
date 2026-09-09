-- Edit-time finish only; safe to rerun against the same R10 authored ponds.
return function(world, cfg)
    assert(not game:GetService("RunService"):IsRunning(), "Fishing polish requires Edit mode")
    assert(not cfg.preview_only or game.PlaceId == 0, "Fishing polish is for the isolated preview")
    local V, C = Vector3, CFrame
    local source = assert(world:FindFirstChild(cfg.source_root), "Missing R10 fishing root")
    local g, l, integration = cfg.geometry, cfg.landscape, cfg.integration
    local terrain = workspace.Terrain
    local cache = game:GetService("ServerStorage"):FindFirstChild(cfg.template_cache)
    local old = source:FindFirstChild(cfg.root)
    if old then
        old:Destroy()
    end
    local root = Instance.new("Model")
    root.Name = cfg.root
    root:SetAttribute("FishingConnected", false)
    root:SetAttribute("IntegrationStatus", integration.status)
    root.Parent = source
    local terrainRay = RaycastParams.new()
    terrainRay.FilterType = Enum.RaycastFilterType.Include
    terrainRay.FilterDescendantsInstances = { terrain }
    terrainRay.IgnoreWater = false
    local bedRay = RaycastParams.new()
    bedRay.FilterType = Enum.RaycastFilterType.Include
    bedRay.FilterDescendantsInstances = { terrain }
    bedRay.IgnoreWater = true
    local clearRay = RaycastParams.new()
    clearRay.FilterType = Enum.RaycastFilterType.Exclude
    clearRay.FilterDescendantsInstances = { root }
    clearRay.IgnoreWater = false
    local report = {
        stations = 0,
        postsMoved = 0,
        approaches = 0,
        skippedApproaches = {},
        grounded = 0,
        flora = 0,
    }
    local function rgb(values, factor)
        return Color3.fromRGB(
            values[1] * (factor or 1),
            values[2] * (factor or 1),
            values[3] * (factor or 1)
        )
    end
    local function dryGround(position, params)
        local hit = workspace:Raycast(
            position + V.new(0, g.sample_height, 0),
            V.new(0, -g.sample_depth, 0),
            params or terrainRay
        )
        if hit and hit.Instance == terrain and hit.Material ~= Enum.Material.Water then
            return hit.Position.Y
        end
        return nil
    end
    local function part(parent, name, size, cf, color, material)
        local p = Instance.new("Part")
        p.Name, p.Size, p.CFrame = name, size, cf
        p.Color, p.Material = color, material
        p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow =
            true, false, false, false, false
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p.Parent = parent
        return p
    end
    local function beam(parent, name, a, b, width, color)
        return part(
            parent,
            name,
            V.new(width, width, (b - a).Magnitude),
            C.lookAt((a + b) / 2, b),
            color,
            Enum.Material.Wood
        )
    end
    local decks = {}
    for _, pond in ipairs(cfg.ponds) do
        local model = assert(source:FindFirstChild(pond.name), "Missing pond " .. pond.name)
        model:SetAttribute("FishingConnected", false)
        model:SetAttribute("AnglerCapacity", pond.stations)
        for n = 1, pond.stations do
            local deck = assert(
                model:FindFirstChild("FishingStation" .. n),
                "Missing authored fishing station"
            )
            local base = deck:GetAttribute("FishingPolishBaseCFrame")
            if typeof(base) ~= "CFrame" then
                base = deck.CFrame
                deck:SetAttribute("FishingPolishBaseCFrame", base)
                deck:SetAttribute("FishingPolishOriginalTransparency", deck.Transparency)
            end
            local offset = V.new(unpack(pond.station_offsets[tostring(n)] or { 0, 0, 0 }))
            for _, post in ipairs(model:GetChildren()) do
                if post:IsA("BasePart") and post.Name == "PierPost" then
                    local postBase = post:GetAttribute("FishingPolishBaseCFrame") or post.CFrame
                    local localPosition = base:PointToObjectSpace(postBase.Position)
                    local matches = false
                    for _, expected in ipairs(g.original_post_local_xz) do
                        if
                            math.abs(localPosition.X - expected[1]) < g.post_match_tolerance
                            and math.abs(localPosition.Z - expected[2]) < g.post_match_tolerance
                        then
                            matches = true
                        end
                    end
                    if matches then
                        if post:GetAttribute("FishingPolishOriginalSize") == nil then
                            post:SetAttribute("FishingPolishOriginalSize", post.Size)
                            post:SetAttribute("FishingPolishOriginalColor", post.Color)
                        end
                        post:SetAttribute("FishingPolishBaseCFrame", postBase)
                        post:SetAttribute("FishingStationOwner", pond.name .. ":" .. n)
                        local originalSize = post:GetAttribute("FishingPolishOriginalSize")
                        local anchor = postBase + offset
                        local top = anchor.Position.Y + originalSize.Y / 2
                        local bottom = anchor.Position.Y - originalSize.Y / 2
                        local bed = workspace:Raycast(
                            anchor.Position + V.new(0, g.sample_height, 0),
                            V.new(0, -g.sample_depth, 0),
                            bedRay
                        )
                        assert(bed, "Missing terrain bed under fishing post")
                        bottom = math.min(bottom, bed.Position.Y - g.post_bed_embed)
                        local height = top - bottom
                        post.CFrame = anchor + V.new(0, (top + bottom) / 2 - anchor.Position.Y, 0)
                        post.Size = V.new(g.post_width, height, g.post_width)
                        post.Color = rgb(pond.frame)
                        if offset.Magnitude > 0 then
                            report.postsMoved += 1
                        end
                    end
                end
            end
            deck.CFrame, deck.Transparency = base + offset, 1
            deck.CanCollide, deck.CanTouch = true, false
            table.insert(decks, deck)
        end
    end
    -- All dock protection checks use the final positions, including the Hell correction.
    local function outsideDecks(point, extra)
        for _, deck in ipairs(decks) do
            local p = deck.CFrame:PointToObjectSpace(point)
            if
                math.abs(p.X) < deck.Size.X / 2 + extra
                and math.abs(p.Z) < deck.Size.Z / 2 + extra
            then
                return false
            end
        end
        return true
    end
    local digitSegments = {
        ["0"] = "abcedf",
        ["1"] = "bc",
        ["2"] = "abged",
        ["3"] = "abgcd",
        ["4"] = "fgbc",
        ["5"] = "afgcd",
        ["6"] = "afgecd",
        ["7"] = "abc",
        ["8"] = "abcdefg",
        ["9"] = "abfgcd",
    }
    local function numeral(parent, cf, number, color)
        local text = tostring(number)
        local w, h, stroke = g.numeral_digit_width, g.numeral_digit_height, g.numeral_stroke
        local positions = {
            a = { 0, -h / 2, true },
            b = { w / 2, -h / 4, false },
            c = { w / 2, h / 4, false },
            d = { 0, h / 2, true },
            e = { -w / 2, h / 4, false },
            f = { -w / 2, -h / 4, false },
            g = { 0, 0, true },
        }
        for i = 1, #text do
            for segment in string.gmatch(digitSegments[string.sub(text, i, i)], ".") do
                local p = positions[segment]
                part(
                    parent,
                    "StationNumeral",
                    V.new(p[3] and w or stroke, g.numeral_relief, p[3] and stroke or h / 2),
                    cf * C.new((i - (#text + 1) / 2) * g.numeral_digit_spacing + p[1], 0, p[2]),
                    color,
                    Enum.Material.Metal
                )
            end
        end
    end
    for _, pond in ipairs(cfg.ponds) do
        local model = source[pond.name]
        local section = Instance.new("Model")
        section.Name, section.Parent = pond.name, root
        for n = 1, pond.stations do
            local deck = model["FishingStation" .. n]
            local assembly = Instance.new("Model")
            assembly.Name, assembly.Parent = "CraftedStation" .. n, section
            local cf = deck.CFrame
            local w, d, top = deck.Size.X, deck.Size.Z, deck.Size.Y / 2
            local wood, frame, metal = rgb(pond.wood), rgb(pond.frame), rgb(pond.metal)
            local plankWidth = (w - (g.plank_count - 1) * g.plank_gap) / g.plank_count
            for i = 1, g.plank_count do
                part(
                    assembly,
                    "DeckPlank",
                    V.new(plankWidth, g.plank_height, d),
                    cf
                        * C.new(
                            -w / 2 + plankWidth / 2 + (i - 1) * (plankWidth + g.plank_gap),
                            top - g.plank_height / 2,
                            0
                        ),
                    rgb(pond.wood, pond.plank_variation[i]),
                    Enum.Material.WoodPlanks
                )
            end
            for _, sign in ipairs({ -1, 1 }) do
                part(
                    assembly,
                    "LateralFascia",
                    V.new(g.fascia_width, g.fascia_height, d),
                    cf
                        * C.new(
                            sign * (w - g.fascia_width) / 2,
                            top - g.plank_height - g.fascia_height / 2,
                            0
                        ),
                    frame,
                    Enum.Material.Wood
                )
                part(
                    assembly,
                    "EndFascia",
                    V.new(w - 2 * g.fascia_width, g.fascia_height, g.fascia_width),
                    cf
                        * C.new(
                            0,
                            top - g.plank_height - g.fascia_height / 2,
                            sign * (d - g.fascia_width) / 2
                        ),
                    frame,
                    Enum.Material.Wood
                )
                part(
                    assembly,
                    "UnderDeckBeam",
                    V.new(g.beam_width, g.beam_height, d),
                    cf
                        * C.new(
                            sign * g.beam_x,
                            top - g.plank_height - g.fascia_height - g.beam_height / 2,
                            0
                        ),
                    frame,
                    Enum.Material.Wood
                )
                for _, endSign in ipairs({ -1, 1 }) do
                    beam(
                        assembly,
                        "DiagonalBrace",
                        cf:PointToWorldSpace(
                            V.new(sign * g.beam_x, top - g.plank_height - g.fascia_height, 0)
                        ),
                        cf:PointToWorldSpace(
                            V.new(sign * g.beam_x, -g.brace_drop, endSign * g.beam_x)
                        ),
                        g.brace_width,
                        frame
                    )
                end
                local cleatCF = cf * C.new(sign * g.cleat_x, top + g.cleat_height / 2, g.cleat_z)
                part(
                    assembly,
                    "MooringCleatBase",
                    V.new(g.cleat_width, g.cleat_height, g.cleat_width),
                    cleatCF,
                    metal,
                    Enum.Material.Metal
                )
                part(
                    assembly,
                    "MooringCleatBar",
                    V.new(g.cleat_bar, g.cleat_width, g.cleat_width),
                    cleatCF * C.new(0, g.cleat_height / 2, 0),
                    metal,
                    Enum.Material.Metal
                )
            end
            local restCF = cf * C.new(g.rest_x, top + g.rest_height / 2, g.rest_z)
            part(
                assembly,
                "RodRest",
                V.new(g.rest_width, g.rest_height, g.rest_width),
                restCF,
                metal,
                Enum.Material.Metal
            )
            for _, sign in ipairs({ -1, 1 }) do
                part(
                    assembly,
                    "RodRestFork",
                    V.new(g.rest_width, g.rest_height / 3, g.rest_width),
                    restCF * C.new(sign * g.rest_width, g.rest_height / 2, 0),
                    metal,
                    Enum.Material.Metal
                )
            end
            local plateSize = V.new(unpack(g.marker_size))
            local plateCF = cf * C.new(g.marker_x, top + plateSize.Y / 2, g.marker_z)
            part(assembly, "StationPlate", plateSize, plateCF, metal, Enum.Material.Metal)
            numeral(
                assembly,
                plateCF * C.new(0, plateSize.Y / 2 + g.numeral_relief / 2, 0),
                n,
                rgb(pond.marker)
            )
            for _, name in ipairs({ "Standing", "Cast", "LineTip", "PreviewCast" }) do
                local existing = deck:FindFirstChild(name)
                if existing then
                    existing:Destroy()
                end
            end
            local standing = Instance.new("Attachment")
            standing.Name, standing.Position, standing.Parent =
                "Standing", V.new(unpack(integration.standing_local)), deck
            local lineTip = Instance.new("Attachment")
            lineTip.Name, lineTip.Position, lineTip.Parent =
                "LineTip", V.new(unpack(integration.line_tip_local)), deck
            local cast = Instance.new("Attachment")
            cast.Name = "Cast"
            local target = cf.Position + cf.LookVector * integration.cast_distance
            cast.Position = cf:PointToObjectSpace(
                V.new(target.X, pond.water_y + integration.water_clearance, target.Z)
            )
            cast.Parent = deck
            deck:SetAttribute("StationKey", pond.name .. ":" .. n)
            deck:SetAttribute("StationIndex", n)
            deck:SetAttribute("FishingConnected", false)
            deck:SetAttribute("StubAction", integration.stub_action)
            local prompt = Instance.new("ProximityPrompt")
            prompt.Name, prompt.ActionText, prompt.ObjectText =
                "PreviewCast", integration.prompt_action, integration.prompt_object .. " " .. n
            prompt.Enabled, prompt.MaxActivationDistance, prompt.HoldDuration =
                integration.prompt_enabled, integration.prompt_distance, integration.prompt_hold
            prompt.RequiresLineOfSight = false
            prompt:SetAttribute("StubAction", integration.stub_action)
            prompt:SetAttribute("StationKey", pond.name .. ":" .. n)
            prompt.Parent = standing
            local safe = not table.find(pond.skip_approaches, n)
            local startZ = d / 2 + g.approach_gap
            local heights = {}
            for _, x in ipairs({ -g.approach_width / 2, 0, g.approach_width / 2 }) do
                for _, z in ipairs({
                    startZ,
                    startZ + g.approach_depth / 2,
                    startZ + g.approach_depth,
                }) do
                    local point = cf:PointToWorldSpace(V.new(x, 0, z))
                    local height = dryGround(point, clearRay)
                    if
                        not height
                        or height < g.approach_min_height
                        or height > g.approach_max_height
                        or not outsideDecks(point, 0)
                    then
                        safe = false
                    else
                        table.insert(heights, height)
                    end
                end
            end
            if safe and #heights > 0 then
                local groundY = 0
                for _, height in ipairs(heights) do
                    groundY += height
                end
                groundY /= #heights
                local rise = cf.Position.Y + top - groundY
                local angle = math.atan2(rise, g.approach_depth)
                local center = cf:PointToWorldSpace(V.new(0, 0, startZ + g.approach_depth / 2))
                local rotation = cf - cf.Position
                local approach = part(
                    assembly,
                    "DryBankApproach",
                    V.new(
                        g.approach_width,
                        g.approach_thickness,
                        math.sqrt(g.approach_depth ^ 2 + rise ^ 2)
                    ),
                    C.new(center.X, groundY + rise / 2 - g.approach_thickness / 2, center.Z)
                        * rotation
                        * C.Angles(angle, 0, 0),
                    wood,
                    Enum.Material.WoodPlanks
                )
                approach.CanCollide, approach.CanQuery = true, true
                report.approaches += 1
            else
                table.insert(report.skippedApproaches, pond.name .. ":" .. n)
            end
            report.stations += 1
        end
        if cache then
            for _, index in ipairs(pond.cluster_indices) do
                local a = (index - 0.5) * math.pi * 2 / pond.stations
                local center = V.new(
                    pond.center[1] + math.cos(a) * (pond.radii[1] + l.cluster_radial_offset),
                    0,
                    pond.center[2] + math.sin(a) * (pond.radii[2] + l.cluster_radial_offset)
                )
                for j, localOffset in ipairs(l.cluster_offsets) do
                    local position = center + V.new(localOffset[1], 0, localOffset[2])
                    local y = dryGround(position)
                    local inRearPassage = pond.name == "HellFishingPool"
                        and position.X > l.hell_clear_x_min
                        and position.X < l.hell_clear_x_max
                    if y and not inRearPassage and outsideDecks(position, l.deck_clearance) then
                        local template = cache:FindFirstChild(pond.flora[j])
                        if template and template:IsA("Model") then
                            local decor = template:Clone()
                            local _, size = decor:GetBoundingBox()
                            local scale = math.min(
                                l.cluster_heights[j] / size.Y,
                                l.cluster_max_extent / math.max(size.X, size.Z)
                            )
                            decor:ScaleTo(decor:GetScale() * scale)
                            decor.Name = "BankCluster_" .. index .. "_" .. j
                            decor.Parent = section
                            for _, child in ipairs(decor:GetDescendants()) do
                                if child:IsA("BasePart") then
                                    child.Anchored, child.CanCollide, child.CanTouch, child.CanQuery =
                                        true, false, false, false
                                elseif
                                    child:IsA("LuaSourceContainer") or child:IsA("ProximityPrompt")
                                then
                                    child:Destroy()
                                end
                            end
                            decor:PivotTo(C.new(position.X, y, position.Z) * C.Angles(0, a + j, 0))
                            local box, bounds = decor:GetBoundingBox()
                            decor:PivotTo(
                                decor:GetPivot()
                                    + V.new(
                                        0,
                                        y - l.ground_embed - (box.Position.Y - bounds.Y / 2),
                                        0
                                    )
                            )
                            report.flora += 1
                        end
                    end
                end
            end
        end
    end
    -- Re-seat existing native models independently; roots are not placed by a shared pivot offset.
    for _, model in ipairs(world:GetDescendants()) do
        if
            model:IsA("Model")
            and not model:IsDescendantOf(root)
            and table.find(l.ground_names, model.Name)
        then
            local box, size = model:GetBoundingBox()
            local position = box.Position
            if
                math.abs(position.X) >= l.ground_x_min
                and math.abs(position.X) <= l.ground_x_max
                and position.Z >= l.ground_z_min
                and position.Z <= l.ground_z_max
            then
                local ground = dryGround(position)
                if ground then
                    local delta = ground - l.ground_embed - (position.Y - size.Y / 2)
                    if math.abs(delta) <= l.max_ground_shift then
                        model:PivotTo(model:GetPivot() + V.new(0, delta, 0))
                        report.grounded += 1
                    end
                end
            end
        end
    end
    -- A clear rear passage needs visual clearance as well as noncolliding props.
    -- Retain original native models outside Workspace instead of moving them onto water.
    local hell = source:FindFirstChild("HellFishingPool")
    report.passagePropsArchived = 0
    if hell then
        for _, model in ipairs(hell:GetChildren()) do
            if model:IsA("Model") and table.find(l.ground_names, model.Name) then
                local box, size = model:GetBoundingBox()
                local h = size / 2
                local r, u, f = box.RightVector, box.UpVector, box.LookVector
                local extent = V.new(
                    math.abs(r.X) * h.X + math.abs(u.X) * h.Y + math.abs(f.X) * h.Z,
                    math.abs(r.Y) * h.X + math.abs(u.Y) * h.Y + math.abs(f.Y) * h.Z,
                    math.abs(r.Z) * h.X + math.abs(u.Z) * h.Y + math.abs(f.Z) * h.Z
                )
                local low, high = box.Position - extent, box.Position + extent
                if
                    low.X < l.hell_clear_x_max
                    and high.X > l.hell_clear_x_min
                    and low.Z < l.ground_z_max
                    and high.Z > l.ground_z_min
                then
                    local storage = game:GetService("ServerStorage")
                    local archive = storage:FindFirstChild(cfg.root .. "PassageBackup")
                    if not archive then
                        archive = Instance.new("Folder")
                        archive.Name = cfg.root .. "PassageBackup"
                        archive.Parent = storage
                    end
                    if model:GetAttribute("FishingPolishPassagePivot") == nil then
                        model:SetAttribute("FishingPolishPassagePivot", model:GetPivot())
                        model:SetAttribute(
                            "FishingPolishOriginalParent",
                            model.Parent:GetFullName()
                        )
                    end
                    model.Parent = archive
                    report.passagePropsArchived += 1
                end
            end
        end
    end
    root:SetAttribute("StationCount", report.stations)
    root:SetAttribute("ApproachCount", report.approaches)
    root:SetAttribute("NewFloraCount", report.flora)
    return report
end
