-- Small physical entrance markers reuse the sculpted gate lettering.
return function(world, cfg, fontData)
    assert(
        game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(),
        "Local Edit preview only"
    )
    local cache = assert(
        game.ServerStorage:FindFirstChild("CrossroadsLetterSolids"),
        "Missing native letter cache"
    )
    local font = fontData.glyphs
    for i = 1, #cfg.text do
        local char = cfg.text:sub(i, i)
        assert(font[char] and cache:FindFirstChild(char), "Missing physical glyph " .. char)
    end
    local old = world:FindFirstChild(cfg.root)
    if old then
        old:Destroy()
    end
    local root = Instance.new("Model")
    root.Name = cfg.root
    root.Parent = world
    local function part(parent, name, size, cf, color, material)
        local p = Instance.new("Part")
        p.Name, p.Size, p.CFrame = name, Vector3.new(unpack(size)), cf
        p.Color, p.Material = Color3.fromRGB(unpack(color)), Enum.Material[material]
        p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
        p.Parent = parent
        return p
    end
    for _, site in ipairs(cfg.sites) do
        local model = Instance.new("Model")
        model.Name = site.name
        model:SetAttribute("GameplayConnected", false)
        model.Parent = root
        local base = CFrame.new(unpack(site.position)) * CFrame.Angles(0, math.rad(site.yaw), 0)
        part(
            model,
            "StoneFoot",
            cfg.base_size,
            base * CFrame.new(0, cfg.base_size[2] / 2, 0),
            site.stone,
            "Limestone"
        )
        part(
            model,
            "CarvedPanel",
            cfg.body_size,
            base * CFrame.new(0, cfg.body_y, 0),
            site.stone,
            "Limestone"
        )
        part(
            model,
            "BronzeCap",
            cfg.cap_size,
            base * CFrame.new(0, cfg.cap_y, 0),
            site.metal,
            "Metal"
        )
        for _, side in ipairs({ -1, 1 }) do
            part(
                model,
                "Support",
                cfg.post_size,
                base * CFrame.new(side * cfg.post_x, cfg.post_y, 0),
                site.metal,
                "Metal"
            )
        end
        local width = 0
        for i = 1, #cfg.text do
            width += font[cfg.text:sub(i, i)].width + cfg.letter_spacing
        end
        local scale = math.min(cfg.text_height, cfg.text_width / width)
        local x = -width * scale / 2
        for i = 1, #cfg.text do
            local char = cfg.text:sub(i, i)
            local template = cache[char]
            local glyph = template:Clone()
            glyph.Size = template.Size * scale
            glyph.CFrame = base
                * CFrame.new(x + font[char].width * scale / 2, cfg.text_y, cfg.text_z)
                * CFrame.new(template.Position * scale)
                * template.CFrame.Rotation
            glyph.Color = Color3.fromRGB(unpack(site.letters))
            glyph.UsePartColor = true
            glyph.Material = Enum.Material.Metal
            glyph.CanCollide, glyph.CanTouch, glyph.CanQuery = false, false, false
            glyph.Name = "Letter_" .. char
            glyph.Parent = model
            x += (font[char].width + cfg.letter_spacing) * scale
        end
        -- A real rod silhouette repeats the newly authored fishing prop below the title.
        local theme = site.rod_theme
        local rod = game.ServerStorage.CrossroadsFishingRodAssets[theme]:Clone()
        rod.Name = "RodEmblem"
        local rawPivot = rod:GetPivot()
        local emblem = cfg.rod_emblem
        rod:ScaleTo(rod:GetScale() * emblem.scale)
        local frame = base
            * CFrame.new(unpack(emblem.position))
            * CFrame.Angles(0, 0, math.rad(emblem.roll))
            * CFrame.Angles(0, math.rad(emblem.yaw), 0)
        rod:PivotTo(frame * CFrame.new(rawPivot.Position * emblem.scale) * rawPivot.Rotation)
        for _, p in ipairs(rod:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
            end
        end
        rod.Parent = model
    end
    return { signs = #cfg.sites, physicalText = cfg.text }
end
