--[[
    EnchantLightning

    Server/client-safe procedural lightning strike adapted from the
    ColorfulClickers enchanter concept. It creates animated neon cylinder bolts
    between station-authored origin parts and the temporary pet endpoint.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundGroups = require(ReplicatedStorage.Shared.Effects.SoundGroups)

local EnchantLightning = {}

local DEFAULT_COLORS = {
    Color3.fromRGB(80, 255, 255),
    Color3.fromRGB(120, 145, 255),
    Color3.fromRGB(255, 95, 240),
    Color3.fromRGB(255, 245, 120),
}

local xInverse = CFrame.lookAt(Vector3.new(), Vector3.new(1, 0, 0)):Inverse()

local function asColorList(values)
    if type(values) ~= "table" then
        return DEFAULT_COLORS
    end

    local colors = {}
    for _, value in ipairs(values) do
        if typeof(value) == "Color3" then
            table.insert(colors, value)
        elseif type(value) == "table" then
            table.insert(
                colors,
                Color3.fromRGB(
                    math.clamp(tonumber(value[1]) or 255, 0, 255),
                    math.clamp(tonumber(value[2]) or 255, 0, 255),
                    math.clamp(tonumber(value[3]) or 255, 0, 255)
                )
            )
        end
    end

    return #colors > 0 and colors or DEFAULT_COLORS
end

local function getPrimaryPartOrSelf(instance)
    if not instance then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance
    end
    if instance:IsA("Model") then
        return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function findNamedPart(root, name)
    if type(name) ~= "string" or name == "" or not root then
        return nil
    end
    local direct = root:FindFirstChild(name, true)
    if direct and direct:IsA("BasePart") then
        return direct
    end
    return nil
end

local function findRelativePart(root, path)
    if type(path) ~= "string" or path == "" or not root then
        return nil
    end

    local current = root
    for segment in path:gmatch("[^%.\\/]+") do
        current = current:FindFirstChild(segment)
        if not current then
            return nil
        end
    end

    if current:IsA("BasePart") then
        return current
    end
    return nil
end

local function collectOriginParts(station, config)
    local origins = {}
    local seen = {}
    local paths = config.origin_part_paths

    if type(paths) == "table" then
        for _, path in ipairs(paths) do
            local part = findRelativePart(station, path)
            if part and not seen[part] then
                seen[part] = true
                table.insert(origins, part)
            end
        end
    end

    local names = #origins == 0 and config.origin_part_names or nil

    if type(names) == "table" then
        for _, name in ipairs(names) do
            local part = findNamedPart(station, name)
            if part and not seen[part] then
                seen[part] = true
                table.insert(origins, part)
            end
        end
    end

    if #origins == 0 then
        for _, descendant in ipairs(station:GetDescendants()) do
            if
                descendant:IsA("BasePart")
                and descendant.Name == (config.origin_part_name or "Rune")
                and not seen[descendant]
            then
                seen[descendant] = true
                table.insert(origins, descendant)
            end
        end
    end

    if #origins == 0 then
        local fallback = getPrimaryPartOrSelf(station)
        if fallback then
            table.insert(origins, fallback)
        end
    end

    table.sort(origins, function(a, b)
        return a:GetFullName() < b:GetFullName()
    end)

    return origins
end

local function resolveCenterPart(station, config, targetInstance)
    local targetPart = getPrimaryPartOrSelf(targetInstance)
    if targetPart then
        return targetPart, true
    end

    local centerPart = findNamedPart(station, config.center_part_name or "EnchantTouchPart")
    return centerPart or getPrimaryPartOrSelf(station), false
end

local function cubicBezier(alpha, p0, p1, p2, p3)
    local inverse = 1 - alpha
    return p0 * inverse ^ 3
        + p1 * 3 * alpha * inverse ^ 2
        + p2 * 3 * inverse * alpha ^ 2
        + p3 * alpha ^ 3
end

local function createBoltPart(parent, name, color)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Locked = true
    part.Material = Enum.Material.Neon
    part.Shape = Enum.PartType.Cylinder
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Color = color
    part.Transparency = 1
    part.Size = Vector3.new(0.1, 0.1, 0.1)
    part.Parent = parent
    return part
end

local function unitOrFallback(vector, fallback)
    if vector.Magnitude > 0.001 then
        return vector.Unit
    end
    return fallback
end

local function makeBasis(direction)
    local up = math.abs(direction:Dot(Vector3.yAxis)) > 0.95 and Vector3.xAxis or Vector3.yAxis
    local right = unitOrFallback(direction:Cross(up), Vector3.xAxis)
    local second = unitOrFallback(direction:Cross(right), Vector3.zAxis)
    return right, second
end

local function noiseBetween(value, seed, minValue, maxValue)
    return minValue + (maxValue - minValue) * (math.noise(value, seed, seed * 0.27) + 0.5)
end

local function setSegment(part, previousPoint, nextPoint, thickness, opacity, color)
    local delta = nextPoint - previousPoint
    local length = delta.Magnitude
    if length <= 0.03 or opacity <= 0.02 or thickness <= 0.01 then
        part.Transparency = 1
        return
    end

    part.Size = Vector3.new(length, thickness, thickness)
    part.CFrame = CFrame.lookAt((previousPoint + nextPoint) * 0.5, nextPoint) * xInverse
    part.Color = color
    part.Transparency = 1 - math.clamp(opacity, 0, 1)
end

local function createProceduralBolt(parent, startPart, endPosition, color, config)
    local startPosition = startPart.Position
    local direction = unitOrFallback(endPosition - startPosition, Vector3.yAxis)
    local distance = (endPosition - startPosition).Magnitude
    if distance <= 0.1 then
        return
    end

    local partCount = math.max(4, math.floor(tonumber(config.segments) or 40))
    local duration = math.max(0.12, tonumber(config.duration) or 2)
    local thickness = math.max(0.02, tonumber(config.thickness) or 0.28)
    local minThickness = math.max(0.02, tonumber(config.min_thickness_multiplier) or 0.2)
    local maxThickness = math.max(minThickness, tonumber(config.max_thickness_multiplier) or 1)
    local minRadius = math.max(0, tonumber(config.min_radius) or 0)
    local maxRadius =
        math.max(minRadius, tonumber(config.max_radius) or tonumber(config.jitter) or 1)
    local frequency = math.max(0.01, tonumber(config.frequency) or 1)
    local animationSpeed = tonumber(config.animation_speed) or 7
    local curveSize0 = tonumber(config.curve_size0) or math.min(10, distance * 0.35)
    local curveSize1 = tonumber(config.curve_size1) or math.min(15, distance * 0.45)
    local fadeOutSeconds = math.max(0.05, tonumber(config.fade_out_seconds) or 0.35)
    local flicker = math.clamp(tonumber(config.flicker) or 0.35, 0, 0.95)
    local neonLift = math.clamp(tonumber(config.neon_lift) or 0.2, 0, 1)
    local coreEnabled = config.core_enabled ~= false
    local coreThicknessMultiplier =
        math.max(0.05, tonumber(config.core_thickness_multiplier) or 0.32)
    local coreOpacityMultiplier = math.max(0.05, tonumber(config.core_opacity_multiplier) or 1)
    local seed = math.random() * 1000
    local right, second = makeBasis(direction)
    local parts = table.create(partCount)
    local coreParts = table.create(partCount)

    for index = 1, partCount do
        parts[index] = createBoltPart(parent, "EnchantLightningBoltPart", color)
        if coreEnabled then
            coreParts[index] =
                createBoltPart(parent, "EnchantLightningCorePart", Color3.fromRGB(255, 255, 255))
        end
    end

    local startTime = os.clock()
    local connection
    connection = RunService.Heartbeat:Connect(function()
        local elapsed = os.clock() - startTime
        if elapsed >= duration then
            connection:Disconnect()
            for _, part in ipairs(parts) do
                part:Destroy()
            end
            for _, part in ipairs(coreParts) do
                part:Destroy()
            end
            return
        end

        local endDir = -direction
        local p0 = startPart.Position
        local p1 = p0 + startPart.CFrame.UpVector * curveSize0
        local p3 = endPosition
        local p2 = p3 + endDir * curveSize1
        local fadeMultiplier = elapsed > duration - fadeOutSeconds
                and math.max(0, (duration - elapsed) / fadeOutSeconds)
            or 1
        local previousPoint = p0

        for index, part in ipairs(parts) do
            local alpha = index / partCount
            local center = cubicBezier(alpha, p0, p1, p2, p3)
            local taper = math.sin(alpha * math.pi)
            local wave = animationSpeed * -elapsed + frequency * 10 * alpha + seed
            local angle = noiseBetween(wave * 3.7, seed, 0, math.pi * 2)
            local radius = noiseBetween(wave * 1.9, seed + 21, minRadius, maxRadius) * taper
            local nextPoint = center + (right * math.cos(angle) + second * math.sin(angle)) * radius
            local thicknessNoise = noiseBetween(wave * 2.3, seed + 42, minThickness, maxThickness)
            local flickerNoise = noiseBetween(wave * 5.1, seed + 84, 1 - flicker, 1)
            local opacity = fadeMultiplier * flickerNoise
            local segmentColor = color:Lerp(Color3.fromRGB(255, 255, 255), neonLift)

            setSegment(
                part,
                previousPoint,
                nextPoint,
                thickness * thicknessNoise,
                opacity,
                segmentColor
            )
            if coreParts[index] then
                setSegment(
                    coreParts[index],
                    previousPoint,
                    nextPoint,
                    thickness * thicknessNoise * coreThicknessMultiplier,
                    opacity * coreOpacityMultiplier,
                    Color3.fromRGB(255, 255, 255)
                )
            end
            previousPoint = nextPoint
        end
    end)
end

local function createCenterFlash(parent, position, color, radius, duration)
    local orb = Instance.new("Part")
    orb.Name = "EnchantLightningCore"
    orb.Anchored = true
    orb.CanCollide = false
    orb.CanQuery = false
    orb.CanTouch = false
    orb.CastShadow = false
    orb.Material = Enum.Material.Neon
    orb.Shape = Enum.PartType.Ball
    orb.Color = color
    orb.Transparency = 0.55
    orb.Size = Vector3.new(radius, radius, radius)
    orb.Position = position
    orb.Parent = parent

    local light = Instance.new("PointLight")
    light.Name = "EnchantLightningFlash"
    light.Color = color
    light.Brightness = 3
    light.Range = radius * 5
    light.Parent = orb

    TweenService
        :Create(orb, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 1,
            Size = Vector3.new(radius * 1.35, radius * 1.35, radius * 1.35),
        })
        :Play()
    TweenService
        :Create(light, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Brightness = 0,
            Range = radius * 2,
        })
        :Play()
    Debris:AddItem(orb, duration + 0.25)
end

local function getConfiguredSoundTemplate(soundName)
    local soundsFolder = ReplicatedStorage:FindFirstChild("Assets")
        and ReplicatedStorage.Assets:FindFirstChild("Sounds")
    local template = soundsFolder and soundsFolder:FindFirstChild(soundName)
    if template and template:IsA("Sound") then
        return template
    end
    return nil
end

local function playThunder(station, config)
    local soundName = config.sound_name or "Thunder"
    local sound = station:FindFirstChild(soundName, true)
    if sound and sound:IsA("Sound") then
        sound.Volume = tonumber(config.volume) or sound.Volume
        sound.PlaybackSpeed = tonumber(config.playback_speed) or sound.PlaybackSpeed
        sound:Play()
        return
    end

    local template = getConfiguredSoundTemplate(soundName)
    if template then
        sound = template:Clone()
    elseif type(config.sound_id) == "string" and config.sound_id ~= "" then
        sound = Instance.new("Sound")
        sound.SoundId = config.sound_id
    else
        return
    end

    sound.Name = soundName
    sound.Volume = tonumber(config.volume) or sound.Volume or 0.8
    sound.PlaybackSpeed = tonumber(config.playback_speed) or sound.PlaybackSpeed or 1
    sound.RollOffMaxDistance = tonumber(config.roll_off_max_distance) or 90
    SoundGroups.assign(sound, "effects")
    sound.Parent = SoundService
    sound:Play()
    Debris:AddItem(sound, math.max(2, tonumber(config.sound_lifetime_seconds) or 16))
end

function EnchantLightning.Play(station, config, targetInstance)
    if not station then
        return false
    end

    config = type(config) == "table" and config or {}
    if config.enabled == false then
        return false
    end

    local centerPart, targetIsDisplay = resolveCenterPart(station, config, targetInstance)
    if not centerPart then
        return false
    end

    local parent = workspace:FindFirstChild("Effects")
    if not parent then
        parent = Instance.new("Folder")
        parent.Name = "Effects"
        parent.Parent = workspace
    end

    local origins = collectOriginParts(station, config)
    local originLimit = math.max(1, math.floor(tonumber(config.origin_limit) or #origins))
    local strandsPerOrigin = math.max(1, math.floor(tonumber(config.strands_per_origin) or 2))
    local duration = math.max(0.08, tonumber(config.duration) or 0.8)
    local thickness = math.max(0.03, tonumber(config.thickness) or 0.18)
    local centerOffset = targetIsDisplay and config.target_offset or config.center_offset
    if typeof(centerOffset) ~= "Vector3" then
        centerOffset = Vector3.new(0, 0, 0)
    end

    local colors = asColorList(config.colors)
    local centerPosition = centerPart.Position + centerOffset

    playThunder(station, config)
    createCenterFlash(
        parent,
        centerPosition,
        colors[math.random(1, #colors)],
        thickness * 3.2,
        duration
    )

    for originIndex, origin in ipairs(origins) do
        if originIndex > originLimit then
            break
        end

        for _ = 1, strandsPerOrigin do
            local color = colors[math.random(1, #colors)]
            createProceduralBolt(parent, origin, centerPosition, color, config)
        end
    end

    return true
end

return EnchantLightning
