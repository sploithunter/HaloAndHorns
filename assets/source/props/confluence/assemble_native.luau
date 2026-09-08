-- Authored offline companion; no map placement or runtime geometry generation.
return function(model, config, manifest)
    local rotation = CFrame.Angles(0, math.rad(config.raw_upload_yaw_degrees), 0)
    model.Name = "Confluence"
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            part.CFrame = rotation * part.CFrame
            part.Anchored = true
            part.CanTouch = false
            part.CanCollide = not (part.Name:find("Water") or part.Name:find("Lava"))
            part.CastShadow = part.CanCollide
            if part:IsA("MeshPart") then
                part.DoubleSided = true
            end
        end
    end
    model.WorldPivot = CFrame.identity
    model:SetAttribute("AuthoredDiameter", config.diameter_studs)
    model:SetAttribute("AuthoredHeight", manifest.height_studs)
    model:SetAttribute("HeavenSide", "NegativeX")
    model:SetAttribute("HellSide", "PositiveX")
    model:SetAttribute("SourceModelId", config.roblox_model_id)
    local effects = Instance.new("Folder")
    effects.Name = "FlowEffects"
    effects.Parent = model
    local host = Instance.new("Part")
    host.Name = "EffectAnchor"
    host.Anchored = true
    host.CanCollide = false
    host.CanTouch = false
    host.CanQuery = false
    host.Transparency = 1
    host.Size = Vector3.one * 0.1
    host.CFrame = CFrame.new(0, 0.05, 0)
    host.Parent = effects
    for _, fall in manifest.falls do
        local angle = math.rad(fall.angle_degrees)
        local lava = fall.name:find("Lava") ~= nil
        local top =
            Vector3.new(math.cos(angle) * fall.radius, fall.top, -math.sin(angle) * fall.radius)
        local bottom = Vector3.new(
            math.cos(angle) * (fall.radius + 0.17),
            fall.bottom,
            -math.sin(angle) * (fall.radius + 0.17)
        )
        local tangent = Vector3.new(-math.sin(angle), 0, -math.cos(angle))
        local a = Instance.new("Attachment")
        a.Name = fall.name .. "_Top"
        a.CFrame = host.CFrame:ToObjectSpace(CFrame.fromMatrix(top, tangent, Vector3.yAxis))
        a.Parent = host
        local b = Instance.new("Attachment")
        b.Name = fall.name .. "_Bottom"
        b.CFrame = host.CFrame:ToObjectSpace(CFrame.fromMatrix(bottom, tangent, Vector3.yAxis))
        b.Parent = host
        local beam = Instance.new("Beam")
        beam.Name = fall.name .. "_Flow"
        beam.Attachment0 = a
        beam.Attachment1 = b
        beam.Width0 = fall.radius * config.effects.beam_width_angle
        beam.Width1 = beam.Width0
        beam.FaceCamera = false
        beam.Texture = "rbxassetid://" .. tostring(config.texture_ids[lava and "lava" or "water"])
        beam.TextureMode = Enum.TextureMode.Wrap
        beam.TextureLength = config.effects.texture_length
        beam.TextureSpeed = lava and config.effects.lava_speed or config.effects.water_speed
        beam.LightEmission = lava and config.effects.lava_emission or config.effects.water_emission
        beam.Transparency = NumberSequence.new(config.effects.transparency)
        beam.Segments = config.effects.segments
        beam.Parent = effects
    end
    return model
end
