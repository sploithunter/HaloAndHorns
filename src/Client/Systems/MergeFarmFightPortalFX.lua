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
local signRoot = nil

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

local function makeSignRoot(cfg)
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local rootName = tostring(cfg.root_name)
    local oldRoot = playerGui:FindFirstChild(rootName)
    if oldRoot then
        oldRoot:Destroy()
    end

    local root = Instance.new("ScreenGui")
    root.Name = rootName
    root.DisplayOrder = requiredNumber(cfg.display_order, "signage.display_order")
    root.IgnoreGuiInset = cfg.ignore_gui_inset == true
    root.ResetOnSpawn = false
    root.Parent = playerGui
    return root
end

local function makeSign(cfg, spec, palette)
    local sign = Instance.new("Frame")
    sign.Name = "PortalLettering_" .. spec.id
    sign.AnchorPoint = Vector2.new(0.5, 0.5)
    sign.BackgroundTransparency = 1
    sign.Visible = false
    sign.Parent = signRoot

    makeTextLabel(
        sign,
        "Destination",
        spec.destination,
        cfg.destination,
        palette.accent,
        palette.stroke
    )
    local word = makeTextLabel(sign, "Word", spec.word, cfg.word, palette.primary, palette.stroke)
    makeTextLabel(sign, "Tagline", spec.tagline, cfg.tagline, palette.secondary, palette.stroke)
    makeTextLabel(
        sign,
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
    divider.Parent = sign

    local dividerGradient = Instance.new("UIGradient")
    dividerGradient.Color = ColorSequence.new(palette.primary, palette.secondary)
    dividerGradient.Parent = divider
    return sign
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
    local sign = makeSign(cfg.signage, spec, palette)
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
        sign = sign,
        orbit = makeOrbitParts(runtime, cfg.orbit, spec),
        startMarker = startMarker,
        endMarker = endMarker,
        boltConfig = boltConfig,
        nextBoltAt = os.clock(),
        active = false,
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
    if not active then
        record.sign.Visible = false
    end
    for _, mote in ipairs(record.orbit) do
        mote.part.LocalTransparencyModifier = active and 0 or 1
    end
end

local function updateSign(record, cfg)
    local camera = Workspace.CurrentCamera
    if not camera then
        record.sign.Visible = false
        return
    end

    local ring = record.ring
    local center, onScreen = camera:WorldToViewportPoint(ring.Position)
    local edge = camera:WorldToViewportPoint(
        ring.Position
            + ring.CFrame.UpVector
                * record.radius
                * requiredNumber(cfg.diameter_scale, "signage.diameter_scale")
    )
    if not onScreen or center.Z <= 0 or edge.Z <= 0 then
        record.sign.Visible = false
        return
    end

    local center2d = Vector2.new(center.X, center.Y)
    local edge2d = Vector2.new(edge.X, edge.Y)
    local pixelDiameter = (center2d - edge2d).Magnitude * 2
    pixelDiameter = math.clamp(
        pixelDiameter,
        requiredNumber(cfg.minimum_pixel_size, "signage.minimum_pixel_size"),
        requiredNumber(cfg.maximum_pixel_size, "signage.maximum_pixel_size")
    )
    record.sign.Position = UDim2.fromOffset(
        center.X + requiredNumber(cfg.pixel_offset[1], "signage.pixel_offset.x"),
        center.Y + requiredNumber(cfg.pixel_offset[2], "signage.pixel_offset.y")
    )
    record.sign.Size = UDim2.fromOffset(pixelDiameter, pixelDiameter)
    record.sign.Visible = true
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

    signRoot = makeSignRoot(cfg.signage)
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
                record.sign:Destroy()
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
                updateSign(record, cfg.signage)
            end
        end
    end)
end

return MergeFarmFightPortalFX
