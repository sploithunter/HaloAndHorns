-- R7 authored art companion: map layout only; existing gameplay binds after integration.
return function()
    assert(
        game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(),
        "Local Edit preview only"
    )
    local H = game:GetService("HttpService")
    local cfg = H:JSONDecode(game.ServerStorage.CrossroadsActivityConfig.Value)
    local glyphs = H:JSONDecode(game.ServerStorage.CrossroadsGlyphConfig.Value).glyphs
    local templates = game.ServerStorage.CrossroadsLetterSolids
    local V, C = Vector3, CFrame
    local world = workspace.RealmCrossroadsR4
    local old = world:FindFirstChild(cfg.root)
    if old then
        old:Destroy()
    end
    local function make(class, name, parent)
        local p = Instance.new(class)
        p.Name = name
        p.Parent = parent
        return p
    end
    local root = make("Model", cfg.root, world)
    root:SetAttribute("PreviewOnly", true)
    root:SetAttribute("GameplayConnected", false)
    local colors = {}
    for key, rgb in pairs(cfg.palette) do
        colors[key] = Color3.fromRGB(unpack(rgb))
    end
    local function part(parent, name, size, cf, color, material, collide)
        local p = make("Part", name, parent)
        p.Size = V.new(unpack(size))
        p.CFrame = cf
        p.Anchored = true
        p.Color = colors[color]
        p.Material = Enum.Material[material or "Limestone"]
        p.CanCollide = collide ~= false
        p.CanTouch = false
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        return p
    end
    local function text(parent, word, height, maxWidth, cf)
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
                p.Color = colors.ink
                p.Material = Enum.Material.Metal
                p.CanCollide = false
                p.Parent = parent
                x += (g.width + 0.12) * scale
            end
        end
    end
    local cache = game.ServerStorage.CrossroadsActivityAssets
    local function asset(parent, name, height, cf)
        local template = cache:FindFirstChild(name)
        if not template then
            template = game:GetService("InsertService"):LoadAsset(cfg.models[name])
            template.Name = name
            template.Parent = cache
        end
        local m = template:Clone()
        m.Name = name
        m.Parent = parent
        for _, p in ipairs(m:GetDescendants()) do
            for _, tag in ipairs(game:GetService("CollectionService"):GetTags(p)) do
                game:GetService("CollectionService"):RemoveTag(p, tag)
            end
            if p:IsA("BasePart") then
                p.Anchored = true
                p.CanCollide = false
                p.CanTouch = false
                p.CanQuery = false
            elseif
                p:IsA("LuaSourceContainer")
                or p:IsA("ProximityPrompt")
                or p:IsA("LayerCollector")
            then
                p:Destroy()
            end
        end
        for _, tag in ipairs(game:GetService("CollectionService"):GetTags(m)) do
            game:GetService("CollectionService"):RemoveTag(m, tag)
        end
        m:PivotTo(C.new())
        m:ScaleTo(m:GetScale() * height / m:GetExtentsSize().Y)
        local box, size = m:GetBoundingBox()
        m:PivotTo(
            cf
                * C.new(-box.Position.X, -box.Position.Y + size.Y / 2, -box.Position.Z)
                * m:GetPivot()
        )
        m:SetAttribute("PreviewOnly", true)
        return m
    end
    local function marker(parent, name, size, cf, intent)
        local p = part(parent, name, size, cf, "trim", nil, false)
        p.Transparency = 1
        p.CanQuery = false
        p:SetAttribute("IntendedBinding", intent)
        p:SetAttribute("GameplayConnected", false)
        return p
    end
    local function bench(parent, x, z, yaw)
        local at = C.new(x, 4, z) * C.Angles(0, yaw or 0, 0)
        part(parent, "BenchSeat", { 10, 0.65, 2.5 }, at * C.new(0, 2, 0), "light")
        part(parent, "BenchBack", { 10, 2.1, 0.6 }, at * C.new(0, 3, -1.1), "stone")
        for _, dx in ipairs({ -3.5, 3.5 }) do
            part(parent, "BenchFoot", { 1.3, 1.7, 2 }, at * C.new(dx, 0.85, 0), "stone")
        end
    end
    for _, area in ipairs(cfg.areas) do
        local group = make("Model", area.key, root)
        group:SetAttribute("DesignIntent", area.intent)
        local x, y, z = unpack(area.center)
        local w, d = unpack(area.field_size)
        local coin = area.key == "CoinGarden"
        part(
            group,
            "Playfield",
            { w, 0.3, d },
            C.new(x, y + 0.23, z),
            coin and "grass" or "soil",
            coin and "Grass" or "Slate"
        )
        -- A clear perimeter circuit joins the existing +4 garden stair and ramp landings.
        for _, side in ipairs({ -1, 1 }) do
            part(
                group,
                "SidePromenade",
                { 6, 0.35, d + 14 },
                C.new(x + side * (w / 2 + 3), y + 0.24, z),
                "stone"
            )
            part(
                group,
                "FieldKerb",
                { 0.65, 0.4, d },
                C.new(x + side * w / 2, y + 0.45, z),
                "light"
            )
            -- Outer edge has a low parapet; the hub-facing edge remains open at both entries.
            if side * x > 0 then
                part(
                    group,
                    "OuterParapet",
                    { 1.3, 2.6, d + 14 },
                    C.new(x + side * (w / 2 + 6), y + 1.3, z),
                    coin and "light" or "dark"
                )
            end
        end
        for _, side in ipairs({ -1, 1 }) do
            part(
                group,
                "EndPromenade",
                { w + 12, 0.35, 7 },
                C.new(x, y + 0.24, z + side * (d / 2 + 3.5)),
                "stone"
            )
            part(
                group,
                "FieldKerb",
                { w, 0.4, 0.65 },
                C.new(x, y + 0.45, z + side * d / 2),
                "light"
            )
        end
        local entryX = x < 0 and -86 or 86
        part(group, "StairLandingLink", { 12, 0.35, 24 }, C.new(entryX, y + 0.24, -18), "stone")
        part(group, "InnerWalk", { 8, 0.35, 125 }, C.new(entryX, y + 0.24, 21), "stone")
        part(
            group,
            "RampLandingLink",
            { math.abs(x) - 80 + 8, 0.35, 16 },
            C.new((x + (x < 0 and -80 or 80)) / 2, y + 0.24, 80),
            "stone"
        )
        part(group, "GatheringTerrace", { w + 12, 0.35, 20 }, C.new(x, y + 0.24, 82), "stone")
        bench(group, x - 12, 88)
        bench(group, x + 12, 88)
        local px, py, pz = unpack(area.pavilion_center)
        part(group, "PavilionFloor", { w + 8, 0.5, 28 }, C.new(px, py + 0.35, pz), "light")
        part(
            group,
            "PavilionApproach",
            { 18, 0.35, math.abs(pz - (z - d / 2)) },
            C.new(px, py + 0.24, (pz + z - d / 2) / 2),
            "stone"
        )
        if coin then
            for _, dx in ipairs({ -19, 19 }) do
                for _, dz in ipairs({ -10, 10 }) do
                    part(
                        group,
                        "PavilionColumn",
                        { 1.8, 17, 1.8 },
                        C.new(px + dx, py + 8.5, pz + dz),
                        "light"
                    )
                    part(
                        group,
                        "Capital",
                        { 2.8, 1, 2.8 },
                        C.new(px + dx, py + 16.5, pz + dz),
                        "trim",
                        "Metal"
                    )
                end
            end
            for _, dx in ipairs({ -19, 19 }) do
                part(group, "PergolaBeam", { 2, 1.2, 24 }, C.new(px + dx, py + 17.3, pz), "stone")
            end
            for dz = -10, 10, 4 do
                part(group, "PergolaSlat", { 42, 0.8, 1.3 }, C.new(px, py + 18, pz + dz), "light")
            end
            part(group, "EggTitlePanel", { 36, 3.2, 0.7 }, C.new(px, py + 15.2, pz + 10), "light")
            text(group, area.egg_title, 1.5, 33, C.new(px, py + 15.2, pz + 10.45))
            asset(group, "hall_egg_stand", 6.5, C.new(px, py + 0.6, pz))
            asset(group, "wayfinder_egg", 5, C.new(px, py + 7.2, pz) * C.Angles(0, math.pi, 0))
            marker(
                group,
                "WeeklyEggAnchor",
                { 1, 1, 1 },
                C.new(px, py + 7.2, pz),
                "Existing EggStand / rotating EggId"
            )
            marker(
                group,
                "CoinDropField",
                { w, 2, d },
                C.new(x, py + 1, z),
                "SpawnZone / shared Hall breakables"
            )
            local examples = make("Model", "StaticCoinExamples", group)
            for _, v in ipairs(cfg.coin_examples) do
                asset(examples, v[3], v[4], C.new(x + v[1], y + 0.4, z + v[2]))
            end
        else
            for _, dx in ipairs({ -20, 20 }) do
                part(
                    group,
                    "RuinPier",
                    { 3.2, 12, 3.2 },
                    C.new(px + dx, py + 6, pz - 7),
                    "dark",
                    "Slate"
                )
                part(group, "RuinCap", { 4.5, 1, 4.5 }, C.new(px + dx, py + 12, pz - 7), "stone")
            end
            part(group, "RearRuinWall", { w, 5, 1.5 }, C.new(px, py + 2.5, pz - 9), "dark", "Slate")
            asset(
                group,
                "heaven_compass_banner",
                10,
                C.new(px - 12, py + 0.6, pz - 5) * C.Angles(0, math.pi, 0)
            )
            asset(
                group,
                "hell_skull_banner",
                10,
                C.new(px + 12, py + 0.6, pz - 5) * C.Angles(0, math.pi, 0)
            )
            for _, v in ipairs(cfg.cover) do
                part(
                    group,
                    "LowCover",
                    { v[3], v[4], v[5] },
                    C.new(x + v[1], y + v[4] / 2, z + v[2]),
                    "dark",
                    "Slate"
                )
                part(
                    group,
                    "CoverCap",
                    { v[3] + 0.6, 0.3, v[5] + 0.6 },
                    C.new(x + v[1], y + v[4] + 0.15, z + v[2]),
                    "stone"
                )
            end
            local route = make("Folder", "PatrolRouteDesign", group)
            for n, p in ipairs(cfg.patrol_loop) do
                marker(
                    route,
                    "Waypoint" .. n,
                    { 1, 1, 1 },
                    C.new(x + p[1], y + 0.5, z + p[2]),
                    "Existing patrol route / map containment"
                )
            end
            marker(
                group,
                "PatrolEncounterAnchor",
                { 2, 2, 2 },
                C.new(px, py + 1, pz),
                "Existing patrol cave/spawner + temporary alliances"
            )
            marker(
                group,
                "CombatBounds",
                { w, 8, d },
                C.new(x, y + 4, z),
                "Area bounds / patrol leash"
            )
            text(group, "GATHER FIGHT SHARE", 1, 36, C.new(px, py + 4, pz - 8))
        end
        -- Existing meshes make the edges a garden without consuming the activity footprint.
        for _, dx in ipairs({ -16, 16 }) do
            part(
                group,
                "PlanterBase",
                { 8, 1.4, 7 },
                C.new(px + dx, py + 1.1, pz),
                coin and "light" or "dark"
            )
            asset(
                group,
                coin and "field_flower_bush" or "bone_rock",
                coin and 3.3 or 4,
                C.new(px + dx, py + 1.8, pz)
            )
        end
        for _, dz in ipairs({ -5, 23, 49 }) do
            local outerX = x + (coin and -29 or 29)
            part(
                group,
                "EdgePlanter",
                { 3, 1.1, 8 },
                C.new(outerX, y + 0.55, dz),
                coin and "light" or "dark"
            )
            asset(group, coin and "softglow_bloom" or "bone_rock", 2.8, C.new(outerX, y + 1.1, dz))
        end
        for _, dx in ipairs({ -21, 21 }) do
            asset(
                group,
                coin and "pearl_quartz" or "animal_skull",
                3.8,
                C.new(x + dx, y + 0.4, 72) * C.Angles(0, math.pi, 0)
            )
        end
        part(group, "GatheringLink", { 18, 0.35, 16 }, C.new(x, y + 0.24, 70), "stone")
        -- Physical entry title faces the main court.
        local sign = C.new(entryX, 8, 8) * C.Angles(0, x < 0 and math.pi / 2 or -math.pi / 2, 0)
        part(group, "EntryTitleStone", { 22, 3, 0.8 }, sign, "light")
        text(group, area.name, 1.25, 20, sign * C.new(0, 0, 0.5))
        for _, dx in ipairs({ -8, 8 }) do
            part(group, "EntryTitleFoot", { 1.2, 2.5, 1.2 }, sign * C.new(dx, -2.5, 0), "stone")
        end
        for _, dz in ipairs({ -92, 105 }) do
            asset(group, "cloud_sapling", 12, C.new(x + (coin and -13 or 13), y, dz))
        end
    end
    local markers = world.ElevationMarkers
    for _, name in ipairs({ "GardenWestLabel", "GardenEastLabel", "GardenWest", "GardenEast" }) do
        local m = markers:FindFirstChild(name)
        if m then
            m:Destroy()
        end
    end
    return { areas = 2, geometry = #root:GetDescendants(), gameplayConnected = false }
end
