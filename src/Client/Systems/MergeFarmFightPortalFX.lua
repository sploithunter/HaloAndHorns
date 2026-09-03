--[[
    MergeFarmFightPortalFX (client)

    Turns the two Studio-authored Merge return-gate LightningRing cylinders into invisible layout
    markers. Each marker drives a themed portal veil, orbiting motes, destination lettering, and
    procedural circumference-to-circumference lightning. Geometry, copy, palette, and cadence are
    owned by configs/merge_egg_prototype.lua.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
local EnchantLightning = require(ReplicatedStorage.Shared.Effects.EnchantLightning)

local MergeFarmFightPortalFX = {}

local started = false
local records = {}

local function requiredNumber(value, field)
    local number = tonumber(value)
    assert(number ~= nil, ("Merge portal FX config is missing %s"):format(field))
    return number
end

local function asColor(value, field)
    assert(type(value) == "table" and #value >= 3, ("Invalid Merge portal color: %s"):format(field))
    return Color3.fromRGB(value[1], value[2], value[3])
end

local function asMaterial(value, field)
    local material = Enum.Material[tostring(value)]
    assert(material ~= nil, ("Invalid Merge portal material: %s"):format(field))
    return material
end

local function asFont(value, field)
    local font = Enum.Font[tostring(value)]
    assert(font ~= nil, ("Invalid Merge portal font: %s"):format(field))
    return font
end

local function asNumberRange(value, field)
    assert(type(value) == "table" and #value >= 2, ("Invalid Merge portal range: %s"):format(field))
    return NumberRange.new(value[1], value[2])
end

local function asNumberSequence(values, field)
    assert(
        type(values) == "table" and #values >= 2,
        ("Invalid Merge portal sequence: %s"):format(field)
    )
    local points = {}
    for _, value in ipairs(values) do
        assert(
            type(value) == "table" and #value >= 2,
            ("Invalid Merge portal keypoint: %s"):format(field)
        )
        table.insert(points, NumberSequenceKeypoint.new(value[1], value[2]))
    end
    return NumberSequence.new(points)
end

local function asColorSequence(values, field)
    assert(
        type(values) == "table" and #values >= 2,
        ("Invalid Merge portal palette: %s"):format(field)
    )
    local points = {}
    for index, value in ipairs(values) do
        table.insert(
            points,
            ColorSequenceKeypoint.new((index - 1) / (#values - 1), asColor(value, field))
        )
    end
    return ColorSequence.new(points)
end

local function layoutValue(value, field)
    assert(
        type(value) == "table" and #value >= 2,
        ("Invalid Merge portal layout: %s"):format(field)
    )
    return UDim2.fromScale(value[1], value[2])
end

local function hideMarker(ring)
    ring.LocalTransparencyModifier = 1
    ring.CanCollide = false
    ring.CanQuery = false
    ring.CanTouch = false
    ring.CastShadow = false
end

local function setSafePart(part)
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Locked = true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
end

local function makeTextLabel(parent, name, text, layout, color, stroke)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Position = layoutValue(layout.position, name .. ".position")
    label.Size = layoutValue(layout.size, name .. ".size")
    label.Font = asFont(layout.font, name .. ".font")
    label.Text = tostring(text)
    label.TextColor3 = color
    label.TextScaled = true
    label.TextStrokeColor3 = stroke
    label.TextStrokeTransparency =
        requiredNumber(layout.stroke_transparency, name .. ".stroke_transparency")
    label.TextWrapped = false
    label.Parent = parent

    local constraint = Instance.new("UITextSizeConstraint")
    constraint.MinTextSize = requiredNumber(layout.text_size_min, name .. ".text_size_min")
    constraint.MaxTextSize = requiredNumber(layout.text_size_max, name .. ".text_size_max")
    constraint.Parent = label
    return label
end

local function makeSignFace(veil, face, cfg, spec, palette)
    local surface = Instance.new("SurfaceGui")
    surface.Name = "PortalLettering_" .. face.Name
    surface.Adornee = veil
    surface.Face = face
    surface.AlwaysOnTop = cfg.always_on_top == true
    surface.LightInfluence = requiredNumber(cfg.light_influence, "signage.light_influence")
    surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    surface.CanvasSize = Vector2.new(cfg.canvas_size[1], cfg.canvas_size[2])
    surface.MaxDistance = requiredNumber(cfg.max_distance, "signage.max_distance")
    surface.ZOffset = requiredNumber(cfg.z_offset, "signage.z_offset")
    surface.Parent = veil

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.AnchorPoint = Vector2.new(0.5, 0.5)
    content.Position = UDim2.fromScale(0.5, 0.5)
    content.Size = UDim2.fromScale(1, 1)
    content.BackgroundTransparency = 1
    content.Rotation = requiredNumber(cfg.content_rotation, "signage.content_rotation")
    content.Parent = surface

    makeTextLabel(
        content,
        "Destination",
        spec.destination,
        cfg.destination,
        palette.accent,
        palette.stroke
    )
    local word =
        makeTextLabel(content, "Word", spec.word, cfg.word, palette.primary, palette.stroke)
    makeTextLabel(content, "Tagline", spec.tagline, cfg.tagline, palette.secondary, palette.stroke)
    makeTextLabel(
        content,
        "Invitation",
        cfg.invitation.text,
        cfg.invitation,
        palette.accent,
        palette.stroke
    )

    local wordGradient = Instance.new("UIGradient")
    wordGradient.Name = "ThemeShimmer"
    wordGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, palette.primary),
        ColorSequenceKeypoint.new(0.5, palette.accent),
        ColorSequenceKeypoint.new(1, palette.secondary),
    })
    wordGradient.Rotation =
        requiredNumber(cfg.word.gradient_rotation, "signage.word.gradient_rotation")
    wordGradient.Offset = Vector2.new(-1, 0)
    wordGradient.Parent = word
    TweenService:Create(
        wordGradient,
        TweenInfo.new(
            requiredNumber(cfg.word.shimmer_seconds, "signage.word.shimmer_seconds"),
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.InOut,
            -1,
            true
        ),
        { Offset = Vector2.new(1, 0) }
    ):Play()

    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.BorderSizePixel = 0
    divider.BackgroundColor3 = palette.primary
    divider.BackgroundTransparency =
        requiredNumber(cfg.divider.transparency, "signage.divider.transparency")
    divider.Position = layoutValue(cfg.divider.position, "signage.divider.position")
    divider.Size = layoutValue(cfg.divider.size, "signage.divider.size")
    divider.Parent = content

    local dividerGradient = Instance.new("UIGradient")
    dividerGradient.Color = ColorSequence.new(palette.primary, palette.secondary)
    dividerGradient.Parent = divider
    return surface
end

local function makeSigns(veil, cfg, spec, palette)
    return {
        makeSignFace(veil, Enum.NormalId.Right, cfg, spec, palette),
        makeSignFace(veil, Enum.NormalId.Left, cfg, spec, palette),
    }
end

local function makeVeil(runtime, ring, cfg, spec, diameter)
    local palette = spec.palette
    local veil = ring:Clone()
    veil:ClearAllChildren()
    veil.Name = "PortalVeil"
    setSafePart(veil)
    veil.LocalTransparencyModifier = 0
    veil.Material = asMaterial(cfg.material, "veil.material")
    veil.Color = asColor(palette.veil, spec.id .. ".palette.veil")
    veil.Size = Vector3.new(
        requiredNumber(cfg.thickness, "veil.thickness"),
        diameter * requiredNumber(cfg.diameter_scale, "veil.diameter_scale"),
        diameter * requiredNumber(cfg.diameter_scale, "veil.diameter_scale")
    )
    veil.CFrame = ring.CFrame
    veil.Transparency = requiredNumber(cfg.transparency_min, "veil.transparency_min")
    veil.Parent = runtime

    TweenService:Create(
        veil,
        TweenInfo.new(
            requiredNumber(cfg.pulse_seconds, "veil.pulse_seconds"),
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.InOut,
            -1,
            true
        ),
        { Transparency = requiredNumber(cfg.transparency_max, "veil.transparency_max") }
    ):Play()

    local light = Instance.new("PointLight")
    light.Name = "PortalGlow"
    light.Color = asColor(palette.secondary, spec.id .. ".palette.secondary")
    light.Brightness = requiredNumber(cfg.light_brightness, "veil.light_brightness")
    light.Range = diameter * requiredNumber(cfg.light_range_scale, "veil.light_range_scale")
    light.Shadows = false
    light.Parent = veil
    return veil, light
end

local function makeParticles(veil, cfg, spec)
    local attachment = Instance.new("Attachment")
    attachment.Name = "PortalMoteOrigin"
    attachment.Axis = Vector3.xAxis
    attachment.Parent = veil

    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "PortalMotes"
    emitter.Texture = tostring(cfg.texture)
    emitter.Color = asColorSequence(spec.palette.particles, spec.id .. ".palette.particles")
    emitter.Rate = requiredNumber(cfg.rate, "particles.rate")
    emitter.Lifetime = asNumberRange(cfg.lifetime, "particles.lifetime")
    emitter.Speed = asNumberRange(cfg.speed, "particles.speed")
    emitter.Rotation = asNumberRange(cfg.rotation, "particles.rotation")
    emitter.RotSpeed = asNumberRange(cfg.rotational_speed, "particles.rotational_speed")
    emitter.SpreadAngle = Vector2.new(cfg.spread_angle[1], cfg.spread_angle[2])
    emitter.LightEmission = requiredNumber(cfg.light_emission, "particles.light_emission")
    emitter.LightInfluence = requiredNumber(cfg.light_influence, "particles.light_influence")
    emitter.Size = asNumberSequence(cfg.size, "particles.size")
    emitter.Transparency = asNumberSequence(cfg.transparency, "particles.transparency")
    emitter.EmissionDirection = Enum.NormalId.Right
    emitter.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
    emitter.Parent = attachment
    return emitter
end

local function makeOrbitParts(runtime, cfg, spec)
    local count = math.max(1, math.floor(requiredNumber(cfg.count, "orbit.count")))
    local colors = spec.palette.particles
    local partSize = requiredNumber(cfg.part_size, "orbit.part_size")
    local parts = {}
    for index = 1, count do
        local part = Instance.new("Part")
        part.Name = "PortalOrbitMote"
        setSafePart(part)
        part.Shape = Enum.PartType.Ball
        part.Material = asMaterial(cfg.material, "orbit.material")
        part.Size = Vector3.new(partSize, partSize, partSize)
        part.Color = asColor(colors[((index - 1) % #colors) + 1], spec.id .. ".orbit")
        part.Transparency = requiredNumber(cfg.transparency_min, "orbit.transparency_min")
        part.Parent = runtime
        table.insert(parts, {
            part = part,
            phase = ((index - 1) / count) * math.pi * 2,
            inner = index % 2 == 0,
            direction = index % 3 == 0 and -1 or 1,
        })
    end
    return parts
end

local function makeBeacon(runtime, ring, cfg, spec, portalRadius)
    if cfg.enabled == false then
        return nil
    end

    local height = requiredNumber(cfg.height_above_center, "beacon.height_above_center")
    local bottomY = ring.Position.Y
        + portalRadius
        + requiredNumber(cfg.column_bottom_gap, "beacon.column_bottom_gap")
    local topY = ring.Position.Y + height
    local columnHeight = math.max(0.1, topY - bottomY)
    local columnWidth = requiredNumber(cfg.column_width, "beacon.column_width")
    local colors = spec.palette.lightning

    local column = Instance.new("Part")
    column.Name = "PortalBeaconColumn"
    setSafePart(column)
    column.Material = asMaterial(cfg.material, "beacon.material")
    column.Color = asColor(colors[1], spec.id .. ".beacon.column")
    column.Size = Vector3.new(columnWidth, columnHeight, columnWidth)
    column.Position = Vector3.new(ring.Position.X, bottomY + columnHeight * 0.5, ring.Position.Z)
    column.Transparency = requiredNumber(cfg.column_transparency, "beacon.column_transparency")
    column.Parent = runtime

    local core = Instance.new("Part")
    core.Name = "PortalBeaconCore"
    setSafePart(core)
    core.Shape = Enum.PartType.Ball
    core.Material = asMaterial(cfg.material, "beacon.material")
    local coreSize = requiredNumber(cfg.core_size, "beacon.core_size")
    core.Size = Vector3.new(coreSize, coreSize, coreSize)
    core.Color = asColor(colors[2] or colors[1], spec.id .. ".beacon.core")
    core.Position = ring.Position + Vector3.yAxis * height
    core.Transparency = requiredNumber(cfg.core_transparency, "beacon.core_transparency")
    core.Parent = runtime

    local light = Instance.new("PointLight")
    light.Name = "PortalBeaconGlow"
    light.Color = asColor(colors[3] or colors[1], spec.id .. ".beacon.light")
    light.Brightness = requiredNumber(cfg.light_brightness, "beacon.light_brightness")
    light.Range = requiredNumber(cfg.light_range, "beacon.light_range")
    light.Shadows = false
    light.Parent = core

    local orbit = {}
    local count = math.max(1, math.floor(requiredNumber(cfg.orbit_count, "beacon.orbit_count")))
    local moteSize = requiredNumber(cfg.orbit_part_size, "beacon.orbit_part_size")
    for index = 1, count do
        local mote = Instance.new("Part")
        mote.Name = "PortalBeaconMote"
        setSafePart(mote)
        mote.Shape = Enum.PartType.Ball
        mote.Material = asMaterial(cfg.material, "beacon.material")
        mote.Size = Vector3.new(moteSize, moteSize, moteSize)
        mote.Color = asColor(colors[((index - 1) % #colors) + 1], spec.id .. ".beacon.orbit")
        mote.Transparency = requiredNumber(cfg.orbit_transparency, "beacon.orbit_transparency")
        mote.Parent = runtime
        table.insert(orbit, {
            part = mote,
            phase = ((index - 1) / count) * math.pi * 2,
        })
    end

    return {
        column = column,
        core = core,
        light = light,
        orbit = orbit,
        height = height,
    }
end

local function makeEndpoint(runtime, name, size)
    local part = Instance.new("Part")
    part.Name = name
    setSafePart(part)
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.new(size, size, size)
    part.Transparency = 1
    part.Parent = runtime
    return part
end

local function findSpec(ring, portalSpecs)
    for _, spec in ipairs(portalSpecs) do
        local cursor = ring.Parent
        while cursor and cursor ~= Workspace do
            if cursor.Name == spec.ancestor_name then
                return spec
            end
            cursor = cursor.Parent
        end
    end
    return nil
end

local function playerPosition()
    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return root and root.Position or nil
end

local function buildPortal(ring, cfg, spec)
    if records[ring] then
        return
    end
    hideMarker(ring)

    local oldRuntime = ring.Parent and ring.Parent:FindFirstChild(cfg.runtime_name)
    if oldRuntime then
        oldRuntime:Destroy()
    end

    local runtime = Instance.new("Model")
    runtime.Name = cfg.runtime_name
    runtime:SetAttribute("PortalId", spec.id)
    runtime.Parent = ring.Parent

    local diameter = math.min(ring.Size.Y, ring.Size.Z)
    local radius = diameter * 0.5
    local palette = {
        primary = asColor(spec.palette.primary, spec.id .. ".palette.primary"),
        secondary = asColor(spec.palette.secondary, spec.id .. ".palette.secondary"),
        accent = asColor(spec.palette.accent, spec.id .. ".palette.accent"),
        stroke = asColor(spec.palette.stroke, spec.id .. ".palette.stroke"),
    }
    local veil, light = makeVeil(runtime, ring, cfg.veil, spec, diameter)
    local emitter = makeParticles(veil, cfg.particles, spec)
    local signs = makeSigns(veil, cfg.signage, spec, palette)
    local beacon = makeBeacon(runtime, ring, cfg.beacon, spec, radius)
    local markerSize = requiredNumber(cfg.lightning.marker_size, "lightning.marker_size")
    local startMarker = makeEndpoint(runtime, "LightningStart", markerSize)
    local endMarker = makeEndpoint(runtime, "LightningEnd", markerSize)
    local boltConfig = table.clone(cfg.lightning.bolt)
    boltConfig.colors = spec.palette.lightning

    records[ring] = {
        ring = ring,
        runtime = runtime,
        radius = radius,
        veil = veil,
        light = light,
        emitter = emitter,
        signs = signs,
        beacon = beacon,
        orbit = makeOrbitParts(runtime, cfg.orbit, spec),
        startMarker = startMarker,
        endMarker = endMarker,
        boltConfig = boltConfig,
        nextBoltAt = os.clock(),
        active = nil,
    }
end

local function applyCandidate(instance, cfg)
    if not (instance:IsA("BasePart") and instance.Name == cfg.marker_name) then
        return
    end
    local spec = findSpec(instance, cfg.portals)
    if spec then
        buildPortal(instance, cfg, spec)
    end
end

local function scan(cfg)
    for _, instance in ipairs(Workspace:GetDescendants()) do
        applyCandidate(instance, cfg)
    end
end

local function fireBolt(record, cfg)
    local ring = record.ring
    local angleA = math.random() * math.pi * 2
    local minimum =
        math.rad(requiredNumber(cfg.minimum_arc_degrees, "lightning.minimum_arc_degrees"))
    local maximum =
        math.rad(requiredNumber(cfg.maximum_arc_degrees, "lightning.maximum_arc_degrees"))
    local delta = minimum + math.random() * (maximum - minimum)
    if math.random() < 0.5 then
        delta = -delta
    end
    local angleB = angleA + delta
    local radius = record.radius * requiredNumber(cfg.radius_scale, "lightning.radius_scale")
    local depth = requiredNumber(cfg.depth_jitter, "lightning.depth_jitter")
    local ringCf = ring.CFrame
    local function pointAt(angle)
        return ring.Position
            + ringCf.UpVector * (math.cos(angle) * radius)
            + ringCf.LookVector * (math.sin(angle) * radius)
            + ringCf.RightVector * ((math.random() * 2 - 1) * depth)
    end
    local startPosition = pointAt(angleA)
    local endPosition = pointAt(angleB)
    record.startMarker.CFrame =
        CFrame.lookAt(startPosition, startPosition + ringCf.RightVector, ringCf.UpVector)
    record.endMarker.CFrame =
        CFrame.lookAt(endPosition, endPosition + ringCf.RightVector, ringCf.UpVector)
    EnchantLightning.Play(record.startMarker, record.boltConfig, record.endMarker)
end

local function setActive(record, active)
    if record.active == active then
        return
    end
    record.active = active
    record.emitter.Enabled = active
    record.light.Enabled = active
    record.veil.LocalTransparencyModifier = active and 0 or 1
    for _, sign in ipairs(record.signs) do
        sign.Enabled = active
    end
    for _, mote in ipairs(record.orbit) do
        mote.part.LocalTransparencyModifier = active and 0 or 1
    end
    if record.beacon then
        record.beacon.column.LocalTransparencyModifier = active and 0 or 1
        record.beacon.core.LocalTransparencyModifier = active and 0 or 1
        record.beacon.light.Enabled = active
        for _, mote in ipairs(record.beacon.orbit) do
            mote.part.LocalTransparencyModifier = active and 0 or 1
        end
    end
end

local function updateOrbit(record, cfg, now)
    local ring = record.ring
    local ringCf = ring.CFrame
    local speed = requiredNumber(cfg.angular_speed, "orbit.angular_speed")
    local waveCycles = requiredNumber(cfg.radial_wave_cycles, "orbit.radial_wave_cycles")
    local waveAmplitude = requiredNumber(cfg.radial_wave_amplitude, "orbit.radial_wave_amplitude")
    local depthAmplitude = requiredNumber(cfg.depth_amplitude, "orbit.depth_amplitude")
    local minTransparency = requiredNumber(cfg.transparency_min, "orbit.transparency_min")
    local maxTransparency = requiredNumber(cfg.transparency_max, "orbit.transparency_max")
    for _, mote in ipairs(record.orbit) do
        local angle = mote.phase + now * speed * mote.direction
        local scale = mote.inner and cfg.inner_radius_scale or cfg.radius_scale
        local radius = record.radius * requiredNumber(scale, "orbit.radius_scale")
            + math.sin(angle * waveCycles + now) * waveAmplitude
        local depth = math.sin(angle * 2 - now * speed) * depthAmplitude
        local position = ring.Position
            + ringCf.UpVector * (math.cos(angle) * radius)
            + ringCf.LookVector * (math.sin(angle) * radius)
            + ringCf.RightVector * depth
        mote.part.Position = position
        local pulse = (math.sin(angle * waveCycles - now * 2) + 1) * 0.5
        mote.part.Transparency = minTransparency + (maxTransparency - minTransparency) * pulse
    end
end

local function updateBeacon(record, cfg, now)
    local beacon = record.beacon
    if not beacon then
        return
    end

    local center = record.ring.Position + Vector3.yAxis * beacon.height
    local speed = requiredNumber(cfg.orbit_angular_speed, "beacon.orbit_angular_speed")
    local radius = requiredNumber(cfg.orbit_radius, "beacon.orbit_radius")
    local wave = requiredNumber(cfg.orbit_vertical_wave, "beacon.orbit_vertical_wave")
    local bob = math.sin(now * speed * 1.7) * requiredNumber(cfg.core_bob, "beacon.core_bob")
    beacon.core.Position = center + Vector3.yAxis * bob
    for _, mote in ipairs(beacon.orbit) do
        local angle = mote.phase + now * speed
        mote.part.Position = center
            + Vector3.new(
                math.cos(angle) * radius,
                math.sin(angle * 2) * wave,
                math.sin(angle) * radius
            )
    end
end

function MergeFarmFightPortalFX.start()
    if started then
        return
    end
    started = true

    local mergeConfig = ConfigLoader:LoadConfig("merge_egg_prototype") or {}
    local cfg = mergeConfig.farm_fight_portals or {}
    if cfg.enabled == false then
        return
    end
    assert(type(cfg.portals) == "table", "Merge portal FX requires configured portals")

    scan(cfg)
    Workspace.DescendantAdded:Connect(function(instance)
        if instance.Name ~= cfg.runtime_name then
            applyCandidate(instance, cfg)
        end
    end)

    local scanWait = 0
    RunService.Heartbeat:Connect(function(dt)
        scanWait += dt
        if scanWait >= requiredNumber(cfg.scan_interval, "scan_interval") then
            scanWait = 0
            scan(cfg)
        end

        local here = playerPosition()
        local now = os.clock()
        for ring, record in pairs(records) do
            if not ring.Parent or not record.runtime.Parent then
                if record.runtime.Parent then
                    record.runtime:Destroy()
                end
                records[ring] = nil
                continue
            end

            local active = here ~= nil
                and (here - ring.Position).Magnitude
                    <= requiredNumber(cfg.view_distance, "view_distance")
            setActive(record, active)
            if active and now >= record.nextBoltAt then
                local boltCount = math.max(
                    1,
                    math.floor(requiredNumber(cfg.lightning.bolts_per_pulse, "bolts_per_pulse"))
                )
                for _ = 1, boltCount do
                    fireBolt(record, cfg.lightning)
                end
                local intervalMin = requiredNumber(cfg.lightning.interval_min, "interval_min")
                local intervalMax = requiredNumber(cfg.lightning.interval_max, "interval_max")
                record.nextBoltAt = now + intervalMin + math.random() * (intervalMax - intervalMin)
            end
        end
    end)

    RunService.RenderStepped:Connect(function()
        local now = os.clock()
        for ring, record in pairs(records) do
            if ring.Parent and record.runtime.Parent and record.active then
                updateOrbit(record, cfg.orbit, now)
                updateBeacon(record, cfg.beacon, now)
            end
        end
    end)
end

return MergeFarmFightPortalFX
