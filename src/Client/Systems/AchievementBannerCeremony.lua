--!strict

-- Owner-only checkpoint camera beat. The server has already mounted the replicated final banner;
-- this client briefly frames it with local light/glints, then restores the exact camera state.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local function rgb(values: any, fallback: Color3): Color3
    if type(values) ~= "table" then
        return fallback
    end
    return Color3.fromRGB(
        tonumber(values[1]) or math.floor(fallback.R * 255),
        tonumber(values[2]) or math.floor(fallback.G * 255),
        tonumber(values[3]) or math.floor(fallback.B * 255)
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
    local deadline = os.clock() + math.max(0, tonumber(config.ceremony.stream_timeout_seconds) or 0)
    repeat
        if generation ~= token then
            return nil
        end
        local host = findHost(presentation)
        if host then
            return host
        end
        task.wait()
    until os.clock() >= deadline
    return nil
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
    local color = rgb(ceremony.highlight_color, Color3.fromRGB(255, 214, 92))

    local highlight = Instance.new("Highlight")
    highlight.Name = "AchievementBannerCeremonyGlow"
    highlight.Adornee = host
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.FillColor = color
    highlight.FillTransparency =
        math.clamp(tonumber(ceremony.highlight_fill_transparency) or 0.68, 0, 1)
    highlight.OutlineColor = color
    highlight.OutlineTransparency =
        math.clamp(tonumber(ceremony.highlight_outline_transparency) or 0.05, 0, 1)
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
    glints.Lifetime =
        NumberRange.new(math.max(0.05, tonumber(ceremony.glint_lifetime_seconds) or 0.75))
    glints.Speed = NumberRange.new(math.max(0, tonumber(ceremony.glint_speed) or 4))
    local spread = math.clamp(tonumber(ceremony.glint_spread_degrees) or 180, 0, 180)
    glints.SpreadAngle = Vector2.new(spread, spread)
    glints.Shape = Enum.ParticleEmitterShape.Box
    glints.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
    glints.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, math.max(0.05, tonumber(ceremony.glint_size) or 0.42)),
        NumberSequenceKeypoint.new(1, 0),
    })
    glints.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(1, 1),
    })
    glints.Parent = attachment
    attachment.Position = Vector3.new(0, 0, 0)
    attachment.Axis = Vector3.new(0, 1, 0)
    glints:Emit(math.max(1, math.floor(tonumber(ceremony.glint_count) or 32)))

    local light = Instance.new("PointLight")
    light.Color = color
    light.Brightness = math.max(0, tonumber(ceremony.light_brightness) or 2.4)
    light.Range = math.max(0, tonumber(ceremony.light_range) or 18)
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
    local function cleanup()
        if cleaned then
            return
        end
        cleaned = true
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
    task.delay(math.max(0.1, tonumber(config.ceremony.safety_timeout_seconds) or 2.5), cleanup)

    local ok, err = xpcall(function()
        local oldDepth = Lighting:FindFirstChild("AchievementBannerCeremonyDepth")
        if oldDepth then
            oldDepth:Destroy()
        end

        depth = Instance.new("DepthOfFieldEffect")
        depth.Name = "AchievementBannerCeremonyDepth"
        depth.FarIntensity =
            math.clamp(tonumber(config.ceremony.depth_far_intensity) or 0.12, 0, 1)
        depth.FocusDistance = (target.Position - hostCFrame.Position).Magnitude
        depth.InFocusRadius =
            math.max(0, tonumber(config.ceremony.depth_in_focus_radius) or 12)
        depth.NearIntensity =
            math.clamp(tonumber(config.ceremony.depth_near_intensity) or 0.08, 0, 1)
        depth.Parent = Lighting
        localFx = makeLocalFx(host)
        setControlsEnabled(false)
        camera.CameraType = Enum.CameraType.Scriptable

        local cameraIn = math.max(0, tonumber(config.ceremony.camera_in_seconds) or 0.35)
        local hold = math.max(0, tonumber(config.ceremony.hold_seconds) or 0.85)
        local cameraOut = math.max(0, tonumber(config.ceremony.camera_out_seconds) or 0.4)
        TweenService
            :Create(
                camera,
                TweenInfo.new(cameraIn, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {
                    CFrame = target,
                    Focus = CFrame.new(hostCFrame.Position),
                    FieldOfView =
                        math.clamp(tonumber(config.ceremony.field_of_view) or 44, 20, 100),
                }
            )
            :Play()
        task.wait(cameraIn + hold)
        if generation ~= token or cleaned then
            return
        end
        TweenService
            :Create(
                camera,
                TweenInfo.new(cameraOut, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
                {
                    CFrame = oldCFrame,
                    Focus = oldFocus,
                    FieldOfView = oldFieldOfView,
                }
            )
            :Play()
        task.wait(cameraOut)
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
