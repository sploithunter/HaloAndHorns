-- R5 authored art companion. Edit-only CSG preserves Blender font silhouettes in the place.
return function()
    assert(not game:GetService("RunService"):IsRunning(), "Crest bake requires Edit")
    assert(game.PlaceId == 0, "Local Crossroads preview only")
    local H = game:GetService("HttpService")
    local cfg = H:JSONDecode(game.ServerStorage.CrossroadsCrestConfig.Value)
    local font = H:JSONDecode(game.ServerStorage.CrossroadsGlyphConfig.Value).glyphs
    local V, C = Vector3, CFrame
    local function make(class, parent, name)
        local p = Instance.new(class)
        p.Name = name or class
        p.Parent = parent
        return p
    end
    local cache = game.ServerStorage:FindFirstChild("CrossroadsLetterSolids")
        or make("Folder", game.ServerStorage, "CrossroadsLetterSolids")
    local scratch = make("Model", workspace, "CrossroadsCrestAuthoring")
    local function part(parent, name, size, cf, color, material, class)
        local p = make(class or "Part", parent, name)
        p.Size = size
        p.CFrame = cf
        p.Anchored = true
        p.CanCollide = false
        p.CanTouch = false
        p.CanQuery = false
        p.Color = color
        p.Material = material or Enum.Material.Metal
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        return p
    end
    local function triangle(a, b, c, depth, parts)
        local ab, ac, bc = b - a, c - a, c - b
        if ab:Dot(ab) > ac:Dot(ac) and ab:Dot(ab) > bc:Dot(bc) then
            c, a = a, c
        elseif ac:Dot(ac) > bc:Dot(bc) then
            a, b = b, a
        end
        ab, ac, bc = b - a, c - a, c - b
        if ac:Cross(ab).Magnitude < 0.000001 then
            return
        end
        local right = ac:Cross(ab).Unit
        local up = bc:Cross(right).Unit
        local back = bc.Unit
        local h = math.abs(ab:Dot(up))
        local l1, l2 = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
        if h < 0.001 then
            return
        end
        if l1 > 0.001 then
            table.insert(
                parts,
                part(
                    scratch,
                    "W",
                    V.new(depth, h, l1),
                    C.fromMatrix((a + b) / 2, right, up, back),
                    Color3.new(1, 1, 1),
                    nil,
                    "WedgePart"
                )
            )
        end
        if l2 > 0.001 then
            table.insert(
                parts,
                part(
                    scratch,
                    "W",
                    V.new(depth, h, l2),
                    C.fromMatrix((a + c) / 2, -right, up, -back),
                    Color3.new(1, 1, 1),
                    nil,
                    "WedgePart"
                )
            )
        end
    end
    local function solid(triangles, depth)
        local parts = {}
        for _, tri in ipairs(triangles) do
            triangle(
                V.new(tri[1][1], tri[1][2] + 500, 0),
                V.new(tri[2][1], tri[2][2] + 500, 0),
                V.new(tri[3][1], tri[3][2] + 500, 0),
                depth,
                parts
            )
        end
        assert(#parts > 0, "Empty solid")
        local first = table.remove(parts, 1)
        local u = first:UnionAsync(parts, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
        first:Destroy()
        for _, p in ipairs(parts) do
            p:Destroy()
        end
        u.CFrame = C.new(0, -500, 0) * u.CFrame
        u.Anchored = true
        u.CanCollide = false
        u.CanTouch = false
        u.CanQuery = false
        u.UsePartColor = true
        return u
    end
    for char, g in pairs(font) do
        if not cache:FindFirstChild(char) then
            local u = solid(g.triangles, cfg.glyph_depth / 4)
            u.Name = char
            u.Parent = cache
        end
    end
    local function polygon(parent, name, points, depth, cf, color, material)
        local tris = {}
        for i = 1, #points do
            table.insert(tris, { { 0, 0 }, points[i], points[i % #points + 1] })
        end
        local p = solid(tris, depth)
        p.Name = name
        p.CFrame = cf * p.CFrame
        p.Color = color
        p.Material = material or Enum.Material.Metal
        p.Parent = parent
        return p
    end
    local function rod(parent, name, a, b, thickness, color, material)
        return part(
            parent,
            name,
            V.new(thickness, thickness, (b - a).Magnitude),
            C.lookAt((a + b) / 2, b),
            color,
            material
        )
    end
    local function ring(parent, name, cf, r, thickness, color, material, segments)
        for i = 1, segments do
            local a, b = (i - 1) * math.pi * 2 / segments, i * math.pi * 2 / segments
            rod(
                parent,
                name,
                cf:PointToWorldSpace(V.new(math.cos(a) * r, math.sin(a) * r, 0)),
                cf:PointToWorldSpace(V.new(math.cos(b) * r, math.sin(b) * r, 0)),
                thickness,
                color,
                material
            )
        end
    end
    local function letter(parent, char, scale, cf, color)
        local template = cache[char]
        local p = template:Clone()
        p.Name = "Letter_" .. char
        p.Size = template.Size * scale
        p.CFrame = cf * C.new(template.Position * scale) * template.CFrame.Rotation
        p.Color = color
        p.Material = Enum.Material.Metal
        p.Parent = parent
        return p
    end
    local function text(parent, word, height, maxWidth, cf, color, edge)
        local total = 0
        for i = 1, #word do
            local char = word:sub(i, i)
            total += char == " " and 0.38 or (font[char].width + 0.12)
        end
        local scale = math.min(height, maxWidth / total)
        local x = -total * scale / 2
        for i = 1, #word do
            local char = word:sub(i, i)
            if char == " " then
                x += 0.38 * scale
            else
                local width = font[char].width * scale
                local pos = cf * C.new(x + width / 2, 0, 0)
                if edge then
                    letter(parent, char, scale * 1.045, pos * C.new(0, 0, -0.12), edge)
                end
                letter(parent, char, scale, pos, color)
                x += width + 0.12 * scale
            end
        end
    end
    local roots = {}
    for _, theme in ipairs(cfg.themes) do
        local gate = workspace.RealmCrossroadsR4.ExistingMergeArches[theme.gate]
        local base = C.new(gate.Arch.Position.X, 0, gate.Arch.Position.Z)
            * gate.Arch.CFrame.Rotation
        local prior = gate:FindFirstChild(cfg.root)
        if prior then
            prior:Destroy()
        end
        local model = make("Model", gate, cfg.root)
        model:SetAttribute("DisplayName", theme.mode_name)
        table.insert(roots, model)
        local color = {}
        for _, key in ipairs({ "body", "inset", "trim", "letters", "letter_edge", "glow", "accent" }) do
            color[key] = Color3.fromRGB(unpack(theme[key]))
        end
        local center = base * C.new(unpack(cfg.position))
        polygon(model, "ForgedBacking", cfg.outline, cfg.panel_depth, center, color.body)
        local trimPoints, insetPoints = {}, {}
        for _, p in ipairs(cfg.outline) do
            table.insert(trimPoints, { p[1] * 0.98, p[2] * 0.98 })
            table.insert(insetPoints, { p[1] * 0.94, p[2] * 0.85 })
        end
        polygon(model, "RaisedBorder", trimPoints, 0.28, center * C.new(0, 0, 0.64), color.trim)
        polygon(
            model,
            "RecessedField",
            insetPoints,
            0.24,
            center * C.new(0, 0, 0.84),
            color.inset,
            theme.ornament == "wings" and Enum.Material.Limestone or Enum.Material.Slate
        )
        for i, p in ipairs(cfg.outline) do
            local q = cfg.outline[i % #cfg.outline + 1]
            rod(
                model,
                "LightInlay",
                center:PointToWorldSpace(V.new(p[1] * 0.955, p[2] * 0.91, 1.02)),
                center:PointToWorldSpace(V.new(q[1] * 0.955, q[2] * 0.91, 1.02)),
                0.065,
                color.glow,
                Enum.Material.Neon
            )
        end
        -- Visible mounting straps tie the crest into the existing arch shoulders.
        for _, side in ipairs({ -1, 1 }) do
            local a = base:PointToWorldSpace(V.new(side * 9.8, 17.5, 4.3))
            local b = center:PointToWorldSpace(V.new(side * 10.3, -1.8, -0.4))
            rod(model, "MountingStrap", a, b, 0.5, color.trim)
            local socket = part(
                model,
                "CrestSocket",
                V.new(1.7, 1.2, 1.2),
                C.new(a) * base.Rotation,
                color.body
            )
            socket.Material = Enum.Material.Metal
        end
        local lettering = make("Model", model, "SculptedTitle")
        for _, ln in ipairs(theme.lines) do
            text(
                lettering,
                ln.text,
                ln.height,
                ln.max_width,
                center * C.new(0, ln.y, 1.26),
                color.letters,
                color.letter_edge
            )
        end
        for _, side in ipairs({ -1, 1 }) do
            for n = 0, 3 do
                local bolt = part(
                    model,
                    "BorderStud",
                    V.new(0.32, 0.32, 0.24),
                    center * C.new(side * (10.8 - n * 0.5), -2.6, 1.03),
                    color.trim
                )
                bolt.Shape = Enum.PartType.Ball
            end
        end
        local ornaments = make("Model", model, "Heraldry")
        if theme.ornament == "wings" then
            ring(
                ornaments,
                "Halo",
                center * C.new(0, 6.1, -0.15),
                cfg.halo_radius,
                0.24,
                color.trim,
                Enum.Material.Metal,
                cfg.halo_segments
            )
            ring(
                ornaments,
                "HaloLight",
                center * C.new(0, 6.1, 0.03),
                cfg.halo_radius - 0.3,
                0.08,
                color.glow,
                Enum.Material.Neon,
                cfg.halo_segments
            )
            for _, side in ipairs({ -1, 1 }) do
                for n = 5, 0, -1 do
                    local points =
                        { { -3 * side, -0.5 }, { -3 * side, 0.2 }, { 0, 0.5 }, { 5 * side, 1.1 }, {
                            2 * side,
                            -0.45,
                        } }
                    local cf = center * C.new(side * (8 + n * 0.75), 3.6 + n * 0.4, 0.1 - n * 0.1)
                    polygon(
                        ornaments,
                        "Feather",
                        points,
                        cfg.ornament_depth,
                        cf,
                        color.accent,
                        Enum.Material.Marble
                    )
                    rod(
                        ornaments,
                        "FeatherSpine",
                        cf:PointToWorldSpace(V.new(-2.7 * side, 0, 0.44)),
                        cf:PointToWorldSpace(V.new(4.2 * side, 0.8, 0.44)),
                        0.07,
                        color.trim
                    )
                end
            end
            polygon(
                ornaments,
                "SunDiamond",
                { { 0, 1.8 }, { 1, 0 }, { 0, -1.8 }, { -1, 0 } },
                0.6,
                center * C.new(0, 5.6, 0.25),
                color.trim
            )
        else
            for _, side in ipairs({ -1, 1 }) do
                local path = {
                    { 9.7, 2.4, 1.15 },
                    { 11.8, 4.1, 0.95 },
                    { 12.7, 6.0, 0.65 },
                    { 12.1, 7.6, 0.35 },
                    { 10.7, 8.8, 0.035 },
                }
                for n = 1, #path - 1 do
                    local a, b = path[n], path[n + 1]
                    local midx, midy = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
                    local pts = {
                        { side * (a[1] - midx - a[3]), a[2] - midy },
                        { side * (a[1] - midx + a[3]), a[2] - midy },
                        { side * (b[1] - midx + b[3]), b[2] - midy },
                        { side * (b[1] - midx - b[3]), b[2] - midy },
                    }
                    polygon(
                        ornaments,
                        "HornSegment",
                        pts,
                        1.2,
                        center * C.new(side * midx, midy, -0.25),
                        color.accent
                    )
                end
            end
            polygon(
                ornaments,
                "Crown",
                { { -2, -0.8 }, { -2.6, 2.2 }, { -0.8, 1 }, { 0, 3.7 }, { 0.8, 1 }, { 2.6, 2.2 }, {
                    2,
                    -0.8,
                } },
                0.8,
                center * C.new(0, 4.5, -0.2),
                color.trim
            )
            polygon(
                ornaments,
                "EmberGem",
                { { 0, 1.65 }, { 0.65, 0 }, { 0, -1.2 }, { -0.65, 0 } },
                0.2,
                center * C.new(0, 5.4, 0.32),
                color.glow,
                Enum.Material.Neon
            )
        end
        -- Small, physical information panel; all captions are extruded solids, no GUI.
        local info = make("Model", model, "ModeRelief")
        local plate = base * C.new(unpack(cfg.relief_position))
        part(
            info,
            "Plinth",
            V.new(13.6, 0.6, 3),
            base * C.new(-20, 0.6, 7),
            color.body,
            Enum.Material.Slate
        )
        part(
            info,
            "Stem",
            V.new(3, 3.8, 1.6),
            base * C.new(-20, 2, 6),
            color.body,
            Enum.Material.Slate
        )
        part(info, "ReliefBacking", V.new(unpack(cfg.relief_size)), plate, color.body)
        part(
            info,
            "ReliefField",
            V.new(12.4, 5.2, 0.18),
            plate * C.new(0, 0, 0.6),
            color.inset,
            theme.ornament == "wings" and Enum.Material.Limestone or Enum.Material.Slate
        )
        for n, caption in ipairs(theme.captions) do
            local x = (n - 2) * 4.05
            local icon = plate * C.new(x, 0.65, 0.9)
            local kind = theme.icons[n]
            local function ball(name, size, offset)
                local p = part(info, name, size, icon * C.new(offset), color.trim)
                p.Shape = Enum.PartType.Ball
            end
            if kind == "egg" then
                ball("EggRelief", V.new(1.25, 1.8, 0.5), V.zero)
            elseif kind == "paw" then
                ball("PawPad", V.new(1.05, 0.75, 0.4), V.new(0, -0.3, 0))
                for k = -1, 1 do
                    ball("PawToe", V.new(0.4, 0.5, 0.4), V.new(k * 0.5, 0.5, 0))
                end
            elseif kind == "shield" then
                polygon(
                    info,
                    "ShieldRelief",
                    { { -1, 0.9 }, { 1, 0.9 }, { 0.9, -0.3 }, { 0, -1.2 }, { -0.9, -0.3 } },
                    0.25,
                    icon,
                    color.trim
                )
            elseif kind == "sprout" then
                rod(
                    info,
                    "SproutStem",
                    icon:PointToWorldSpace(V.new(0, -0.9, 0)),
                    icon:PointToWorldSpace(V.new(0, 0.5, 0)),
                    0.16,
                    color.trim
                )
                ball("Leaf", V.new(1.1, 0.55, 0.3), V.new(-0.45, 0.35, 0))
                ball("Leaf", V.new(1.1, 0.55, 0.3), V.new(0.45, 0.8, 0))
            else
                for _, sign in ipairs({ -1, 1 }) do
                    rod(
                        info,
                        "Sword",
                        icon:PointToWorldSpace(V.new(-0.65 * sign, -0.9, 0)),
                        icon:PointToWorldSpace(V.new(0.7 * sign, 0.95, 0)),
                        0.2,
                        color.trim
                    )
                end
            end
            text(info, caption, 0.52, 3.55, plate * C.new(x, -1.45, 0.89), color.letters)
        end
        local fixture = part(
            model,
            "FaceKeyFixture",
            V.new(0.15, 0.15, 0.15),
            base * C.new(0, 8, 5),
            color.glow
        )
        fixture.Transparency = 1
        local light = make("PointLight", fixture, "FaceKeyLight")
        light.Color = color.glow
        light.Brightness = cfg.face_light_brightness
        light.Range = 12
        light.Shadows = false
        local crownLight = make("PointLight", model:FindFirstChild("RecessedField"), "CrestLight")
        crownLight.Color = color.glow
        crownLight.Brightness = cfg.light_brightness
        crownLight.Range = cfg.light_range
        crownLight.Shadows = false
        gate:SetAttribute("DisplayName", theme.mode_name)
        local old = gate:FindFirstChild("ModeSign")
        if old then
            old:Destroy()
        end
    end
    scratch:Destroy()
    local old = game.StarterPlayer.StarterPlayerScripts:FindFirstChild("CrossroadsCrestLight")
    if old then
        old:Destroy()
    end
    local anim =
        make("LocalScript", game.StarterPlayer.StarterPlayerScripts, "CrossroadsCrestLight")
    anim.Source = string.format(
        [[
local run=game:GetService("RunService")
local player=game.Players.LocalPlayer
local gates=workspace:WaitForChild("RealmCrossroadsR4"):WaitForChild("ExistingMergeArches")
local list={}
for _,gate in ipairs(gates:GetChildren()) do
    local crest=gate:WaitForChild(%q)
    for _,p in ipairs(crest:GetDescendants()) do if p:IsA("PointLight") then table.insert(list,{light=p,base=p.Brightness,position=gate.Arch.Position}) end end
end
local t=0
run.RenderStepped:Connect(function(dt)
    t+=dt
    local c=player.Character;local root=c and c:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for _,item in ipairs(list) do
        local d=(Vector3.new(root.Position.X,0,root.Position.Z)-Vector3.new(item.position.X,0,item.position.Z)).Magnitude
        local near=math.clamp(1-d/%f,0,1)
        item.light.Brightness=item.base*(1+near*.35+math.sin(t*math.pi*2/%f)*.07)
    end
end)
]],
        cfg.root,
        cfg.approach_radius,
        cfg.pulse_seconds
    )
    -- Hide the engineering overlay while judging the arrival composition.
    local preview = game.StarterGui:FindFirstChild("CrossroadsTerrainPreview")
    if preview then
        preview.Enabled = false
    end
    game:GetService("ChangeHistoryService"):SetWaypoint("Crossroads sculpted gate crests R5")
    return { glyphs = #cache:GetChildren(), gates = #roots, geometry = "Native CSG; no title GUIs" }
end
