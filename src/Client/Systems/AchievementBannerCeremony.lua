--!strict

-- Owner-only checkpoint camera beat. The server has already mounted the replicated final banner;
-- this client briefly frames it with local light/glints, then restores the exact camera state.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Locations = require(ReplicatedStorage.Shared.Locations)
local ConfigLoader = require(Locations.ConfigLoader)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local AchievementBannerCeremony = {}

local started = false
local config: any = nil
local generation = 0
local activeCleanup: (() -> ())? = nil

local function configuredNumber(value: any, path: string): number
    local parsed = tonumber(value)
    assert(parsed ~= nil, "achievement_banners is missing numeric " .. path)
    return parsed
end

local function rgb(values: any, path: string): Color3
    assert(type(values) == "table", "achievement_banners is missing color " .. path)
    return Color3.fromRGB(
        configuredNumber(values[1], path .. "[1]"),
        configuredNumber(values[2], path .. "[2]"),
        configuredNumber(values[3], path .. "[3]")
    )
end

local function setControlsEnabled(enabled: boolean)
    pcall(function()
        local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
        local playerModule = scripts and scripts:FindFirstChild("PlayerModule")
        if not playerModule then
            return
        end
        local controls = require(playerModule :: ModuleScript):GetControls()
        if enabled then
            controls:Enable()
        else
            controls:Disable()
        end
    end)
end

local function findHost(presentation: any): Instance?
    local host = type(presentation) == "table" and presentation.host or nil
    if typeof(host) == "Instance" and host.Parent then
        return host
    end
    local awardId = type(presentation) == "table" and tostring(presentation.awardId or "") or ""
    local userId = Players.LocalPlayer.UserId
    for _, candidate in CollectionService:GetTagged(config.tag) do
        if
            candidate.Parent
            and candidate:GetAttribute("AchievementOwnerUserId") == userId
            and candidate:GetAttribute("AchievementAwardId") == awardId
        then
            return candidate
        end
    end
    return nil
end

local function waitForHost(presentation: any, token: number): Instance?
    local deadline = os.clock()
        + math.max(
            0,
            configuredNumber(
                config.ceremony.stream_timeout_seconds,
                "ceremony.stream_timeout_seconds"
            )
        )
    repeat
        if generation ~= token then
            return nil
        end
        local host = findHost(presentation)
        if host then
            return host
        end
        RunService.RenderStepped:Wait()
    until os.clock() >= deadline
    return nil
end

local function waitForPresentation(
    seconds: number,
    token: number,
    isCleaned: () -> boolean
): boolean
    local deadline = os.clock() + math.max(0, seconds)
    while os.clock() < deadline do
        if generation ~= token or isCleaned() then
            return false
        end
        RunService.RenderStepped:Wait()
    end
    return generation == token and not isCleaned()
end

local function cameraTarget(host: Instance): CFrame?
    local valueName = tostring(config.display.camera.value_name)
    local value = host:FindFirstChild(valueName)
    if value and value:IsA("CFrameValue") then
        return value.Value
    end
    return nil
end

local function bounds(host: Instance): (CFrame?, Vector3?)
    if host:IsA("Model") then
        return host:GetBoundingBox()
    elseif host:IsA("BasePart") then
        return host.CFrame, host.Size
    end
    return nil, nil
end

local function makeLocalFx(host: Instance): { Instance }
    local created = {}
    local ceremony = config.ceremony
    local color = rgb(ceremony.highlight_color, "ceremony.highlight_color")

    local highlight = Instance.new("Highlight")
    highlight.Name = "AchievementBannerCeremonyGlow"
    highlight.Adornee = host
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.FillColor = color
    highlight.FillTransparency = math.clamp(
        configuredNumber(
            ceremony.highlight_fill_transparency,
            "ceremony.highlight_fill_transparency"
        ),
        0,
        1
    )
    highlight.OutlineColor = color
    highlight.OutlineTransparency = math.clamp(
        configuredNumber(
            ceremony.highlight_outline_transparency,
            "ceremony.highlight_outline_transparency"
        ),
        0,
        1
    )
    highlight.Parent = host
    table.insert(created, highlight)

    local box, size = bounds(host)
    if not (box and size) then
        return created
    end
    local anchor = Instance.new("Part")
    anchor.Name = "AchievementBannerCeremonyFx"
    anchor.Size = size
    anchor.CFrame = box
    anchor.Transparency = 1
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    anchor.Parent = Workspace
    table.insert(created, anchor)

    local attachment = Instance.new("Attachment")
    attachment.Parent = anchor
    local glints = Instance.new("ParticleEmitter")
    glints.Texture = tostring(ceremony.glint_texture)
    glints.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
    glints.LightEmission = 1
    glints.Lifetime = NumberRange.new(
        math.max(
            0.05,
            configuredNumber(ceremony.glint_lifetime_seconds, "ceremony.glint_lifetime_seconds")
        )
    )
    glints.Speed =
        NumberRange.new(math.max(0, configuredNumber(ceremony.glint_speed, "ceremony.glint_speed")))
    local spread = math.clamp(
        configuredNumber(ceremony.glint_spread_degrees, "ceremony.glint_spread_degrees"),
        0,
        180
    )
    glints.SpreadAngle = Vector2.new(spread, spread)
    glints.Shape = Enum.ParticleEmitterShape.Box
    glints.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
    glints.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(
            0,
            math.max(0.05, configuredNumber(ceremony.glint_size, "ceremony.glint_size"))
        ),
        NumberSequenceKeypoint.new(1, 0),
    })
    glints.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(1, 1),
    })
    glints.Parent = attachment
    attachment.Position = Vector3.new(0, 0, 0)
    attachment.Axis = Vector3.new(0, 1, 0)
    glints:Emit(
        math.max(1, math.floor(configuredNumber(ceremony.glint_count, "ceremony.glint_count")))
    )

    local light = Instance.new("PointLight")
    light.Color = color
    light.Brightness =
        math.max(0, configuredNumber(ceremony.light_brightness, "ceremony.light_brightness"))
    light.Range = math.max(0, configuredNumber(ceremony.light_range, "ceremony.light_range"))
    light.Shadows = false
    light.Parent = attachment

    -- Size is intentionally read so a streamed zero-bounds host cannot silently build an effect.
    if size.Magnitude <= 0 then
        anchor:Destroy()
    end
    return created
end

local function play(presentation: any)
    if activeCleanup then
        activeCleanup()
    end
    generation += 1
    local token = generation

    local host = waitForHost(presentation, token)
    if not host or generation ~= token then
        return
    end
    local target = cameraTarget(host)
    local camera = Workspace.CurrentCamera
    if not (target and camera) then
        return
    end

    local oldType = camera.CameraType
    local oldSubject = camera.CameraSubject
    local oldCFrame = camera.CFrame
    local oldFocus = camera.Focus
    local oldFieldOfView = camera.FieldOfView
    local hostCFrame = bounds(host)
    if not hostCFrame then
        return
    end
    local cleaned = false
    local depth: DepthOfFieldEffect? = nil
    local localFx: { Instance } = {}
    local safetyConnection: RBXScriptConnection? = nil
    local function cleanup()
        if cleaned then
            return
        end
        cleaned = true
        if safetyConnection then
            safetyConnection:Disconnect()
            safetyConnection = nil
        end
        pcall(function()
            camera.CFrame = oldCFrame
            camera.Focus = oldFocus
            camera.FieldOfView = oldFieldOfView
            camera.CameraSubject = oldSubject
            camera.CameraType = oldType
        end)
        setControlsEnabled(true)
        for _, instance in ipairs(localFx) do
            if instance.Parent then
                instance:Destroy()
            end
        end
        if depth and depth.Parent then
            depth:Destroy()
        end
        if activeCleanup == cleanup then
            activeCleanup = nil
        end
    end
    activeCleanup = cleanup
    local safetyDeadline = os.clock()
        + math.max(
            0.1,
            configuredNumber(
                config.ceremony.safety_timeout_seconds,
                "ceremony.safety_timeout_seconds"
            )
        )
    safetyConnection = RunService.RenderStepped:Connect(function()
        if os.clock() >= safetyDeadline then
            cleanup()
        end
    end)

    local ok, err = xpcall(function()
        local oldDepth = Lighting:FindFirstChild("AchievementBannerCeremonyDepth")
        if oldDepth then
            oldDepth:Destroy()
        end

        depth = Instance.new("DepthOfFieldEffect")
        depth.Name = "AchievementBannerCeremonyDepth"
        depth.FarIntensity = math.clamp(
            configuredNumber(config.ceremony.depth_far_intensity, "ceremony.depth_far_intensity"),
            0,
            1
        )
        depth.FocusDistance = (target.Position - hostCFrame.Position).Magnitude
        depth.InFocusRadius = math.max(
            0,
            configuredNumber(
                config.ceremony.depth_in_focus_radius,
                "ceremony.depth_in_focus_radius"
            )
        )
        depth.NearIntensity = math.clamp(
            configuredNumber(config.ceremony.depth_near_intensity, "ceremony.depth_near_intensity"),
            0,
            1
        )
        depth.Parent = Lighting
        localFx = makeLocalFx(host)
        setControlsEnabled(false)
        camera.CameraType = Enum.CameraType.Scriptable

        local cameraIn = math.max(
            0,
            configuredNumber(config.ceremony.camera_in_seconds, "ceremony.camera_in_seconds")
        )
        local hold =
            math.max(0, configuredNumber(config.ceremony.hold_seconds, "ceremony.hold_seconds"))
        local cameraOut = math.max(
            0,
            configuredNumber(config.ceremony.camera_out_seconds, "ceremony.camera_out_seconds")
        )
        TweenService
            :Create(
                camera,
                TweenInfo.new(cameraIn, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {
                    CFrame = target,
                    Focus = CFrame.new(hostCFrame.Position),
                    FieldOfView = math.clamp(
                        configuredNumber(config.ceremony.field_of_view, "ceremony.field_of_view"),
                        20,
                        100
                    ),
                }
            )
            :Play()
        if
            not waitForPresentation(cameraIn + hold, token, function()
                return cleaned
            end)
        then
            return
        end
        TweenService:Create(
            camera,
            TweenInfo.new(cameraOut, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
            {
                CFrame = oldCFrame,
                Focus = oldFocus,
                FieldOfView = oldFieldOfView,
            }
        ):Play()
        waitForPresentation(cameraOut, token, function()
            return cleaned
        end)
    end, debug.traceback)
    cleanup()
    if not ok then
        warn("AchievementBannerCeremony: presentation failed", err)
    end
end

function AchievementBannerCeremony.start()
    if started then
        return
    end
    started = true
    config = ConfigLoader:LoadConfig("achievement_banners")
    Signals.AchievementBannerCeremony.OnClientEvent:Connect(function(presentation)
        task.spawn(play, presentation)
    end)
    Players.LocalPlayer.CharacterRemoving:Connect(function()
        if activeCleanup then
            activeCleanup()
        end
        generation += 1
    end)
end

return AchievementBannerCeremony
