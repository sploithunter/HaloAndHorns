--[[
    MergePortalTransitFX (client)

    Acknowledges cross-place gate travel immediately. Replicated player attributes drive a
    client-only ForceField shell, character highlight, sparks, orbiting motes, and world label for
    every observer. The travelling client also gets a small status card and installs a matching
    custom teleport screen that survives the loading handoff. Presentation and timing live in
    configs/merge_egg_prototype.lua; MergeEggPrototypeService remains teleport authority.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)

local MergePortalTransitFX = {}

local started = false
local config
local localPlayer = Players.LocalPlayer
local effectsByPlayer = setmetatable({}, { __mode = "k" })
local watchersByPlayer = setmetatable({}, { __mode = "k" })
local localStatusGui
local stagedTeleportGui

local function requiredNumber(value, field)
    local number = tonumber(value)
    assert(number ~= nil, ("Merge transit FX config is missing %s"):format(field))
    return number
end

local function asColor(value, field)
    assert(
        type(value) == "table" and #value >= 3,
        ("Invalid Merge transit color: %s"):format(field)
    )
    return Color3.fromRGB(value[1], value[2], value[3])
end

local function asMaterial(value, field)
    local material = Enum.Material[tostring(value)]
    assert(material ~= nil, ("Invalid Merge transit material: %s"):format(field))
    return material
end

local function asNumberRange(value, field)
    assert(
        type(value) == "table" and #value >= 2,
        ("Invalid Merge transit range: %s"):format(field)
    )
    return NumberRange.new(value[1], value[2])
end

local function asNumberSequence(values, field)
    assert(
        type(values) == "table" and #values >= 2,
        ("Invalid Merge transit sequence: %s"):format(field)
    )
    local points = {}
    for _, value in ipairs(values) do
        assert(
            type(value) == "table" and #value >= 2,
            ("Invalid Merge transit keypoint: %s"):format(field)
        )
        table.insert(points, NumberSequenceKeypoint.new(value[1], value[2]))
    end
    return NumberSequence.new(points)
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

local function corner(parent, radius)
    local item = Instance.new("UICorner")
    item.CornerRadius = UDim.new(0, radius)
    item.Parent = parent
    return item
end

local function stroke(parent, color, thickness)
    local item = Instance.new("UIStroke")
    item.Color = color
    item.Thickness = thickness
    item.Transparency = 0.04
    item.Parent = parent
    return item
end

local function roleSpec(role)
    local roles = config.roles
    assert(type(roles) == "table", "Merge transit roles config is required")
    local spec = roles[tostring(role)]
    assert(
        type(spec) == "table",
        ("Merge transit role is not configured: %s"):format(tostring(role))
    )
    return spec
end

local function destroyLocalPresentation()
    if localStatusGui then
        localStatusGui:Destroy()
        localStatusGui = nil
    end
    if stagedTeleportGui then
        stagedTeleportGui:Destroy()
        stagedTeleportGui = nil
    end
end

local function destroyEffect(player)
    local effect = effectsByPlayer[player]
    if not effect then
        return
    end
    effectsByPlayer[player] = nil
    if effect.renderConnection then
        effect.renderConnection:Disconnect()
    end
    if effect.runtime then
        effect.runtime:Destroy()
    end
    if player == localPlayer then
        destroyLocalPresentation()
    end
end

local function makeText(parent, name, text, position, size, color, textSize, font)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Position = position
    label.Size = size
    label.Font = font
    label.Text = tostring(text)
    label.TextColor3 = color
    label.TextSize = textSize
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end

local function makeWorldLabel(bubble, diameter, spec)
    local labelConfig = config.world_label
    local gui = Instance.new("BillboardGui")
    gui.Name = "TransitLabel"
    gui.Adornee = bubble
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.MaxDistance = requiredNumber(labelConfig.max_distance, "world_label.max_distance")
    gui.Size = UDim2.fromOffset(
        requiredNumber(labelConfig.width, "world_label.width"),
        requiredNumber(labelConfig.height, "world_label.height")
    )
    gui.StudsOffsetWorldSpace = Vector3.new(
        0,
        diameter * 0.5
            + requiredNumber(labelConfig.height_above_bubble, "world_label.height_above_bubble"),
        0
    )
    gui.Parent = bubble

    local title = makeText(
        gui,
        "Title",
        spec.title,
        UDim2.fromScale(labelConfig.title_position[1], labelConfig.title_position[2]),
        UDim2.fromScale(labelConfig.title_size[1], labelConfig.title_size[2]),
        asColor(spec.primary, "role.primary"),
        requiredNumber(labelConfig.title_text_size, "world_label.title_text_size"),
        Enum.Font.GothamBlack
    )
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.TextStrokeColor3 = asColor(spec.panel, "role.panel")
    title.TextStrokeTransparency =
        requiredNumber(labelConfig.stroke_transparency, "world_label.stroke_transparency")

    local detail = makeText(
        gui,
        "Detail",
        spec.detail,
        UDim2.fromScale(labelConfig.detail_position[1], labelConfig.detail_position[2]),
        UDim2.fromScale(labelConfig.detail_size[1], labelConfig.detail_size[2]),
        asColor(spec.accent, "role.accent"),
        requiredNumber(labelConfig.detail_text_size, "world_label.detail_text_size"),
        Enum.Font.GothamMedium
    )
    detail.TextXAlignment = Enum.TextXAlignment.Center
    detail.TextStrokeColor3 = asColor(spec.panel, "role.panel")
    detail.TextStrokeTransparency =
        requiredNumber(labelConfig.stroke_transparency, "world_label.stroke_transparency")
end

local function makeStatusGui(spec)
    local hudConfig = config.hud
    local gui = Instance.new("ScreenGui")
    gui.Name = config.runtime_name .. "Status"
    gui.DisplayOrder = requiredNumber(hudConfig.display_order, "hud.display_order")
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.AnchorPoint = Vector2.new(0.5, 0)
    panel.Position = UDim2.new(0.5, 0, 0, requiredNumber(hudConfig.top_margin, "hud.top_margin"))
    panel.Size = UDim2.fromOffset(
        requiredNumber(hudConfig.width, "hud.width"),
        requiredNumber(hudConfig.height, "hud.height")
    )
    panel.BackgroundColor3 = asColor(spec.panel, "role.panel")
    panel.BackgroundTransparency =
        requiredNumber(hudConfig.panel_transparency, "hud.panel_transparency")
    panel.BorderSizePixel = 0
    panel.Parent = gui
    corner(panel, requiredNumber(hudConfig.panel_corner_radius, "hud.panel_corner_radius"))
    stroke(
        panel,
        asColor(spec.secondary, "role.secondary"),
        requiredNumber(hudConfig.border_thickness, "hud.border_thickness")
    )

    local sigilConfig = hudConfig.sigil
    local sigilSize = requiredNumber(sigilConfig.size, "hud.sigil.size")
    local sigil = Instance.new("Frame")
    sigil.Name = "Sigil"
    sigil.Position = UDim2.fromOffset(
        requiredNumber(sigilConfig.left, "hud.sigil.left"),
        requiredNumber(sigilConfig.top, "hud.sigil.top")
    )
    sigil.Size = UDim2.fromOffset(sigilSize, sigilSize)
    sigil.BackgroundColor3 = asColor(spec.secondary, "role.secondary")
    sigil.BackgroundTransparency =
        requiredNumber(sigilConfig.transparency, "hud.sigil.transparency")
    sigil.BorderSizePixel = 0
    sigil.Rotation = 45
    sigil.Parent = panel
    corner(sigil, requiredNumber(sigilConfig.corner_radius, "hud.sigil.corner_radius"))
    stroke(
        sigil,
        asColor(spec.accent, "role.accent"),
        requiredNumber(hudConfig.border_thickness, "hud.border_thickness")
    )
    TweenService:Create(
        sigil,
        TweenInfo.new(
            requiredNumber(sigilConfig.spin_seconds, "hud.sigil.spin_seconds"),
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.InOut,
            -1
        ),
        { Rotation = 405, BackgroundColor3 = asColor(spec.primary, "role.primary") }
    ):Play()

    local contentLeft = requiredNumber(hudConfig.content_left, "hud.content_left")
    local contentRight = requiredNumber(hudConfig.content_right, "hud.content_right")
    makeText(
        panel,
        "Title",
        spec.title,
        UDim2.fromOffset(contentLeft, requiredNumber(hudConfig.title_top, "hud.title_top")),
        UDim2.new(
            1,
            -(contentLeft + contentRight),
            0,
            requiredNumber(hudConfig.title_height, "hud.title_height")
        ),
        asColor(spec.primary, "role.primary"),
        requiredNumber(hudConfig.title_text_size, "hud.title_text_size"),
        Enum.Font.GothamBlack
    )
    makeText(
        panel,
        "Detail",
        spec.detail,
        UDim2.fromOffset(contentLeft, requiredNumber(hudConfig.detail_top, "hud.detail_top")),
        UDim2.new(
            1,
            -(contentLeft + contentRight),
            0,
            requiredNumber(hudConfig.detail_height, "hud.detail_height")
        ),
        asColor(spec.accent, "role.accent"),
        requiredNumber(hudConfig.detail_text_size, "hud.detail_text_size"),
        Enum.Font.GothamMedium
    )
    return gui
end

local function makeTeleportGui(spec)
    local screenConfig = config.teleport_screen
    local gui = Instance.new("ScreenGui")
    gui.Name = config.runtime_name .. "Loading"
    gui.DisplayOrder = requiredNumber(screenConfig.display_order, "teleport_screen.display_order")
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local backdrop = Instance.new("Frame")
    backdrop.Name = "Backdrop"
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.BackgroundColor3 = asColor(spec.panel, "role.panel")
    backdrop.BackgroundTransparency =
        requiredNumber(screenConfig.backdrop_transparency, "teleport_screen.backdrop_transparency")
    backdrop.BorderSizePixel = 0
    backdrop.Parent = gui

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(
        requiredNumber(screenConfig.card_width, "teleport_screen.card_width"),
        requiredNumber(screenConfig.card_height, "teleport_screen.card_height")
    )
    card.BackgroundColor3 = asColor(spec.panel, "role.panel")
    card.BackgroundTransparency =
        requiredNumber(screenConfig.card_transparency, "teleport_screen.card_transparency")
    card.BorderSizePixel = 0
    card.Parent = backdrop
    corner(
        card,
        requiredNumber(screenConfig.card_corner_radius, "teleport_screen.card_corner_radius")
    )
    stroke(
        card,
        asColor(spec.primary, "role.primary"),
        requiredNumber(screenConfig.border_thickness, "teleport_screen.border_thickness")
    )

    local spinnerSize = requiredNumber(screenConfig.spinner_size, "teleport_screen.spinner_size")
    local spinner = Instance.new("Frame")
    spinner.Name = "Spinner"
    spinner.BackgroundTransparency = 1
    spinner.Position = UDim2.new(
        0,
        requiredNumber(screenConfig.spinner_left, "teleport_screen.spinner_left"),
        0.5,
        -spinnerSize * 0.5
    )
    spinner.Size = UDim2.fromOffset(spinnerSize, spinnerSize)
    spinner.Parent = card
    corner(spinner, spinnerSize)
    local spinnerStroke = stroke(
        spinner,
        asColor(spec.secondary, "role.secondary"),
        requiredNumber(screenConfig.spinner_thickness, "teleport_screen.spinner_thickness")
    )
    local spinnerGradient = Instance.new("UIGradient")
    spinnerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, asColor(spec.primary, "role.primary")),
        ColorSequenceKeypoint.new(0.5, asColor(spec.accent, "role.accent")),
        ColorSequenceKeypoint.new(1, asColor(spec.secondary, "role.secondary")),
    })
    spinnerGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.72, 0.08),
        NumberSequenceKeypoint.new(1, 1),
    })
    spinnerGradient.Parent = spinnerStroke
    TweenService
        :Create(
            spinnerGradient,
            TweenInfo.new(
                requiredNumber(screenConfig.spinner_seconds, "teleport_screen.spinner_seconds"),
                Enum.EasingStyle.Linear,
                Enum.EasingDirection.InOut,
                -1
            ),
            { Rotation = 360 }
        )
        :Play()

    local contentLeft = requiredNumber(screenConfig.content_left, "teleport_screen.content_left")
    local contentRight = requiredNumber(screenConfig.content_right, "teleport_screen.content_right")
    makeText(
        card,
        "Title",
        spec.title,
        UDim2.fromOffset(
            contentLeft,
            requiredNumber(screenConfig.title_top, "teleport_screen.title_top")
        ),
        UDim2.new(
            1,
            -(contentLeft + contentRight),
            0,
            requiredNumber(screenConfig.title_height, "teleport_screen.title_height")
        ),
        asColor(spec.primary, "role.primary"),
        requiredNumber(screenConfig.title_text_size, "teleport_screen.title_text_size"),
        Enum.Font.GothamBlack
    )
    makeText(
        card,
        "Detail",
        spec.detail,
        UDim2.fromOffset(
            contentLeft,
            requiredNumber(screenConfig.detail_top, "teleport_screen.detail_top")
        ),
        UDim2.new(
            1,
            -(contentLeft + contentRight),
            0,
            requiredNumber(screenConfig.detail_height, "teleport_screen.detail_height")
        ),
        asColor(spec.accent, "role.accent"),
        requiredNumber(screenConfig.detail_text_size, "teleport_screen.detail_text_size"),
        Enum.Font.GothamMedium
    )
    return gui
end

local function installLocalPresentation(spec)
    destroyLocalPresentation()
    localStatusGui = makeStatusGui(spec)
    localStatusGui.Parent = localPlayer:WaitForChild("PlayerGui")

    stagedTeleportGui = makeTeleportGui(spec)
    local ok = pcall(function()
        TeleportService:SetTeleportGui(stagedTeleportGui)
    end)
    if not ok then
        stagedTeleportGui:Destroy()
        stagedTeleportGui = nil
    end
end

local function makeWorldEffect(player, role, token)
    destroyEffect(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not (character and root and root:IsA("BasePart")) then
        return
    end

    local spec = roleSpec(role)
    local bubbleConfig = config.bubble
    local extents = character:GetExtentsSize()
    local diameter = math.clamp(
        math.max(extents.X, extents.Y, extents.Z)
            + requiredNumber(bubbleConfig.character_padding, "bubble.character_padding"),
        requiredNumber(bubbleConfig.minimum_diameter, "bubble.minimum_diameter"),
        requiredNumber(bubbleConfig.maximum_diameter, "bubble.maximum_diameter")
    )

    local runtime = Instance.new("Model")
    runtime.Name = string.format("%s_%d", config.runtime_name, player.UserId)
    runtime:SetAttribute("TransitRole", role)
    runtime:SetAttribute("TransitToken", token)
    runtime.Parent = Workspace

    local bubble = Instance.new("Part")
    bubble.Name = "TransitShield"
    bubble.Shape = Enum.PartType.Ball
    bubble.Material = asMaterial(bubbleConfig.material, "bubble.material")
    bubble.Color = asColor(spec.primary, "role.primary")
    bubble.Size = Vector3.one * diameter
    bubble.Transparency = requiredNumber(bubbleConfig.transparency_min, "bubble.transparency_min")
    bubble.Massless = true
    bubble.Anchored = false
    bubble.CanCollide = false
    bubble.CanQuery = false
    bubble.CanTouch = false
    bubble.CastShadow = false
    bubble.CFrame = root.CFrame
    bubble.Parent = runtime

    local weld = Instance.new("WeldConstraint")
    weld.Name = "FollowCharacter"
    weld.Part0 = bubble
    weld.Part1 = root
    weld.Parent = bubble

    local highlight = Instance.new("Highlight")
    highlight.Name = "TransitHighlight"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = asColor(spec.secondary, "role.secondary")
    highlight.FillTransparency = requiredNumber(
        bubbleConfig.highlight_fill_transparency,
        "bubble.highlight_fill_transparency"
    )
    highlight.OutlineColor = asColor(spec.accent, "role.accent")
    highlight.OutlineTransparency = requiredNumber(
        bubbleConfig.highlight_outline_transparency,
        "bubble.highlight_outline_transparency"
    )
    highlight.Parent = runtime

    local attachment = Instance.new("Attachment")
    attachment.Name = "TransitSparkOrigin"
    attachment.Parent = bubble
    local particleConfig = config.particles
    local particles = Instance.new("ParticleEmitter")
    particles.Name = "RisingTransitSparks"
    particles.Texture = tostring(particleConfig.texture)
    particles.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, asColor(spec.primary, "role.primary")),
        ColorSequenceKeypoint.new(0.5, asColor(spec.accent, "role.accent")),
        ColorSequenceKeypoint.new(1, asColor(spec.secondary, "role.secondary")),
    })
    particles.Rate = requiredNumber(particleConfig.rate, "particles.rate")
    particles.Lifetime = asNumberRange(particleConfig.lifetime, "particles.lifetime")
    particles.Speed = asNumberRange(particleConfig.speed, "particles.speed")
    particles.Rotation = asNumberRange(particleConfig.rotation, "particles.rotation")
    particles.RotSpeed =
        asNumberRange(particleConfig.rotational_speed, "particles.rotational_speed")
    particles.SpreadAngle =
        Vector2.new(particleConfig.spread_angle[1], particleConfig.spread_angle[2])
    particles.Acceleration =
        Vector3.new(0, requiredNumber(particleConfig.acceleration_y, "particles.acceleration_y"), 0)
    particles.LightEmission =
        requiredNumber(particleConfig.light_emission, "particles.light_emission")
    particles.Size = asNumberSequence(particleConfig.size, "particles.size")
    particles.Transparency = asNumberSequence(particleConfig.transparency, "particles.transparency")
    particles.Parent = attachment

    local light = Instance.new("PointLight")
    light.Name = "TransitGlow"
    light.Color = asColor(spec.secondary, "role.secondary")
    light.Brightness = requiredNumber(bubbleConfig.light_brightness, "bubble.light_brightness")
    light.Range = diameter
        * requiredNumber(bubbleConfig.light_range_scale, "bubble.light_range_scale")
    light.Shadows = false
    light.Parent = bubble
    makeWorldLabel(bubble, diameter, spec)

    TweenService
        :Create(
            bubble,
            TweenInfo.new(
                requiredNumber(bubbleConfig.pulse_seconds, "bubble.pulse_seconds"),
                Enum.EasingStyle.Sine,
                Enum.EasingDirection.InOut,
                -1,
                true
            ),
            {
                Size = Vector3.one
                    * diameter
                    * requiredNumber(bubbleConfig.pulse_scale, "bubble.pulse_scale"),
                Transparency = requiredNumber(
                    bubbleConfig.transparency_max,
                    "bubble.transparency_max"
                ),
            }
        )
        :Play()

    local orbitConfig = config.orbit
    local motes = {}
    local orbitCount = math.floor(requiredNumber(orbitConfig.count, "orbit.count"))
    for index = 1, orbitCount do
        local mote = Instance.new("Part")
        mote.Name = string.format("OrbitMote_%02d", index)
        mote.Shape = Enum.PartType.Ball
        mote.Size = Vector3.one * requiredNumber(orbitConfig.part_size, "orbit.part_size")
        mote.Material = asMaterial(orbitConfig.material, "orbit.material")
        mote.Color = index % 3 == 0 and asColor(spec.accent, "role.accent")
            or (
                index % 2 == 0 and asColor(spec.secondary, "role.secondary")
                or asColor(spec.primary, "role.primary")
            )
        mote.Transparency = requiredNumber(orbitConfig.transparency_min, "orbit.transparency_min")
        setSafePart(mote)
        mote.Parent = runtime
        table.insert(motes, mote)
    end

    local startedAt = Workspace:GetServerTimeNow()
    local renderConnection = RunService.RenderStepped:Connect(function()
        if not (root.Parent and runtime.Parent) then
            destroyEffect(player)
            return
        end
        local elapsed = Workspace:GetServerTimeNow() - startedAt
        local speed = requiredNumber(orbitConfig.angular_speed, "orbit.angular_speed")
        local radius = diameter * requiredNumber(orbitConfig.radius_scale, "orbit.radius_scale")
        local height = diameter * requiredNumber(orbitConfig.height_scale, "orbit.height_scale")
        local cycles = requiredNumber(orbitConfig.vertical_cycles, "orbit.vertical_cycles")
        for index, mote in ipairs(motes) do
            local phase = (index - 1) / orbitCount
            local angle = phase * math.pi * 2 + elapsed * speed
            local vertical = math.sin(angle * cycles) * height
            local fadeWave = (
                math.sin(
                    angle + elapsed * requiredNumber(orbitConfig.fade_speed, "orbit.fade_speed")
                ) + 1
            ) * 0.5
            mote.Position = root.Position
                + Vector3.new(math.cos(angle) * radius, vertical, math.sin(angle) * radius)
            mote.Transparency = requiredNumber(
                orbitConfig.transparency_min,
                "orbit.transparency_min"
            ) + fadeWave * (requiredNumber(
                orbitConfig.transparency_max,
                "orbit.transparency_max"
            ) - requiredNumber(orbitConfig.transparency_min, "orbit.transparency_min"))
        end
    end)

    effectsByPlayer[player] = {
        token = token,
        role = role,
        runtime = runtime,
        renderConnection = renderConnection,
    }
    if player == localPlayer then
        installLocalPresentation(spec)
    end
end

local function reconcilePlayer(player)
    local active = player:GetAttribute(config.active_attribute) == true
    if not active then
        destroyEffect(player)
        return
    end
    local role = tostring(player:GetAttribute(config.role_attribute) or "")
    local token = tostring(player:GetAttribute(config.token_attribute) or "")
    if role == "" or token == "" then
        return
    end
    local current = effectsByPlayer[player]
    if current and current.token == token and current.role == role then
        return
    end
    makeWorldEffect(player, role, token)
end

local function watchPlayer(player)
    if watchersByPlayer[player] then
        return
    end
    local connections = {}
    for _, attribute in ipairs({
        config.active_attribute,
        config.role_attribute,
        config.token_attribute,
    }) do
        table.insert(
            connections,
            player:GetAttributeChangedSignal(attribute):Connect(function()
                reconcilePlayer(player)
            end)
        )
    end
    table.insert(
        connections,
        player.CharacterAdded:Connect(function()
            destroyEffect(player)
            task.defer(function()
                reconcilePlayer(player)
            end)
        end)
    )
    watchersByPlayer[player] = connections
    reconcilePlayer(player)
end

local function unwatchPlayer(player)
    destroyEffect(player)
    local connections = watchersByPlayer[player]
    watchersByPlayer[player] = nil
    for _, connection in ipairs(connections or {}) do
        connection:Disconnect()
    end
end

local function dismissArrivingTeleportGui()
    local ok, arrivingGui = pcall(function()
        return TeleportService:GetArrivingTeleportGui()
    end)
    if not ok or not arrivingGui then
        return
    end
    local arrivedAt = os.clock()
    local holdConnection
    holdConnection = RunService.Heartbeat:Connect(function()
        if not arrivingGui.Parent then
            holdConnection:Disconnect()
            return
        end
        if
            os.clock() - arrivedAt
            < requiredNumber(config.arrival_hold_seconds, "arrival_hold_seconds")
        then
            return
        end
        holdConnection:Disconnect()
        local fadeSeconds = requiredNumber(config.arrival_fade_seconds, "arrival_fade_seconds")
        local completionTween
        for _, descendant in ipairs(arrivingGui:GetDescendants()) do
            local tween
            if descendant:IsA("Frame") then
                tween = TweenService:Create(
                    descendant,
                    TweenInfo.new(fadeSeconds),
                    { BackgroundTransparency = 1 }
                )
            elseif descendant:IsA("TextLabel") then
                tween = TweenService:Create(
                    descendant,
                    TweenInfo.new(fadeSeconds),
                    { TextTransparency = 1 }
                )
            elseif descendant:IsA("UIStroke") then
                tween = TweenService:Create(
                    descendant,
                    TweenInfo.new(fadeSeconds),
                    { Transparency = 1 }
                )
            end
            if tween then
                completionTween = completionTween or tween
                tween:Play()
            end
        end
        if completionTween then
            completionTween.Completed:Once(function()
                arrivingGui:Destroy()
            end)
        else
            arrivingGui:Destroy()
        end
    end)
end

function MergePortalTransitFX.start()
    if started then
        return
    end
    started = true
    local mergeConfig = ConfigLoader:LoadConfig("merge_egg_prototype")
    config = (mergeConfig.gate or {}).transit_feedback
    assert(type(config) == "table", "Merge gate transit_feedback config is required")
    if config.enabled == false then
        return
    end

    dismissArrivingTeleportGui()
    Players.PlayerAdded:Connect(watchPlayer)
    Players.PlayerRemoving:Connect(unwatchPlayer)
    TeleportService.TeleportInitFailed:Connect(function(player)
        if player == nil or player == localPlayer then
            destroyEffect(localPlayer)
        end
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        watchPlayer(player)
    end
end

return MergePortalTransitFX
