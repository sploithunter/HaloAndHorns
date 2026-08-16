--[[
    AscensionPresentation — the local, cinematic payoff for claiming a level at the altar.

    The server owns the claim and fires `level_claimed`; this module is presentation only. It
    animates an anchored visual clone so the real character is never teleported or handed to
    client physics. The original avatar is hidden locally for the short ceremony and always
    restored, including on respawn/error cleanup.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AscensionPresentation = {}

local GOLD = Color3.fromRGB(255, 210, 75)
local WHITE_GOLD = Color3.fromRGB(255, 247, 205)

local activeCleanup

local function smoothstep(t)
    t = math.clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

local function setControlsEnabled(enabled)
    pcall(function()
        local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
        local module = scripts and scripts:FindFirstChild("PlayerModule")
        if not module then
            return
        end
        local controls = require(module):GetControls()
        if enabled then
            controls:Enable()
        else
            controls:Disable()
        end
    end)
end

local function makeRing(parent, position, diameter, delaySeconds)
    local ring = Instance.new("Part")
    ring.Name = "AscensionRing"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.12, diameter * 0.25, diameter * 0.25)
    ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
    ring.Anchored = true
    ring.CanCollide = false
    ring.CanTouch = false
    ring.CanQuery = false
    ring.CastShadow = false
    ring.Material = Enum.Material.Neon
    ring.Color = GOLD
    ring.Transparency = 0.1
    ring.Parent = parent

    TweenService:Create(
        ring,
        TweenInfo.new(
            1.15,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out,
            0,
            false,
            delaySeconds
        ),
        {
            Size = Vector3.new(0.08, diameter, diameter),
            Transparency = 1,
            CFrame = ring.CFrame + Vector3.new(0, 2.4, 0),
        }
    ):Play()
    return ring
end

local function makeTitle(level)
    local gui = Instance.new("ScreenGui")
    gui.Name = "AscensionPresentationGui"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 220

    local title = Instance.new("TextLabel")
    title.AnchorPoint = Vector2.new(0.5, 0.5)
    title.Position = UDim2.fromScale(0.5, 0.26)
    title.Size = UDim2.fromScale(0.7, 0.16)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.Text = "ASCENSION\nLEVEL " .. tostring(level or "UP")
    title.TextColor3 = WHITE_GOLD
    title.TextScaled = true
    title.TextTransparency = 1
    title.ZIndex = 2
    title.Parent = gui

    local constraint = Instance.new("UITextSizeConstraint")
    constraint.MinTextSize = 20
    constraint.MaxTextSize = 64
    constraint.Parent = title

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(105, 55, 15)
    stroke.Thickness = 3
    stroke.Transparency = 1
    stroke.Parent = title

    local scale = Instance.new("UIScale")
    scale.Scale = 0.68
    scale.Parent = title

    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    TweenService:Create(title, TweenInfo.new(0.42, Enum.EasingStyle.Back), {
        TextTransparency = 0,
    }):Play()
    TweenService:Create(stroke, TweenInfo.new(0.42), { Transparency = 0 }):Play()
    TweenService:Create(scale, TweenInfo.new(0.52, Enum.EasingStyle.Back), { Scale = 1 }):Play()

    return gui, title, stroke, scale
end

function AscensionPresentation.play(ctx, spec)
    if activeCleanup then
        activeCleanup()
    end

    spec = type(spec) == "table" and spec or {}
    ctx = type(ctx) == "table" and ctx or {}
    local player = Players.LocalPlayer
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not (character and root) then
        return
    end

    local duration = math.max(3.5, tonumber(spec.seconds) or 7.5)
    local oldArchivable = character.Archivable
    character.Archivable = true
    local clone = character:Clone()
    character.Archivable = oldArchivable
    clone.Name = "AscensionAvatar"

    for _, descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA("BaseScript") or descendant:IsA("Tool") then
            descendant:Destroy()
        elseif descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            descendant.CastShadow = false
        elseif descendant:IsA("Humanoid") then
            descendant.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end

    local basePivot = character:GetPivot()
    clone:PivotTo(basePivot)
    clone.Parent = Workspace

    local highlight = Instance.new("Highlight")
    highlight.Name = "AscensionGlow"
    highlight.Adornee = clone
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = GOLD
    highlight.FillTransparency = 0.72
    highlight.OutlineColor = WHITE_GOLD
    highlight.OutlineTransparency = 0.05
    highlight.Parent = clone

    local fxAnchor = Instance.new("Part")
    fxAnchor.Name = "AscensionFxAnchor"
    fxAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
    fxAnchor.CFrame = CFrame.new(root.Position)
    fxAnchor.Transparency = 1
    fxAnchor.Anchored = true
    fxAnchor.CanCollide = false
    fxAnchor.CanTouch = false
    fxAnchor.CanQuery = false
    fxAnchor.Parent = Workspace

    local attachment = Instance.new("Attachment")
    attachment.Parent = fxAnchor
    local sparks = Instance.new("ParticleEmitter")
    sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparks.Color = ColorSequence.new(WHITE_GOLD, GOLD)
    sparks.LightEmission = 1
    sparks.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, 0),
    })
    sparks.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(1, 1),
    })
    sparks.Lifetime = NumberRange.new(0.8, 1.5)
    sparks.Rate = 75
    sparks.Speed = NumberRange.new(5, 10)
    sparks.SpreadAngle = Vector2.new(32, 32)
    sparks.Acceleration = Vector3.new(0, 10, 0)
    sparks.Parent = attachment

    local light = Instance.new("PointLight")
    light.Color = WHITE_GOLD
    light.Brightness = 1
    light.Range = 16
    light.Shadows = false
    light.Parent = attachment
    TweenService:Create(light, TweenInfo.new(duration * 0.55, Enum.EasingStyle.Quint), {
        Brightness = 3.25,
        Range = 24,
    }):Play()

    local rings = {
        makeRing(fxAnchor, root.Position - Vector3.new(0, 2.5, 0), 8, 0),
        makeRing(fxAnchor, root.Position - Vector3.new(0, 2.2, 0), 10, duration * 0.18),
        makeRing(fxAnchor, root.Position - Vector3.new(0, 1.9, 0), 12, duration * 0.38),
    }

    local titleGui, title, titleStroke, titleScale = makeTitle(ctx.level)
    local transparencies = {}
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") then
            transparencies[descendant] = descendant.LocalTransparencyModifier
            descendant.LocalTransparencyModifier = 1
        end
    end
    setControlsEnabled(false)

    local cleaned = false
    local connection
    local function cleanup()
        if cleaned then
            return
        end
        cleaned = true
        if connection then
            connection:Disconnect()
        end
        for part, transparency in pairs(transparencies) do
            if part.Parent then
                part.LocalTransparencyModifier = transparency
            end
        end
        setControlsEnabled(true)
        if clone.Parent then
            clone:Destroy()
        end
        if fxAnchor.Parent then
            fxAnchor:Destroy()
        end
        if titleGui.Parent then
            titleGui:Destroy()
        end
        if activeCleanup == cleanup then
            activeCleanup = nil
        end
    end
    activeCleanup = cleanup

    local started = os.clock()
    local finishing = false
    local finishAt
    connection = RunService.RenderStepped:Connect(function()
        if player.Character ~= character or not root.Parent then
            cleanup()
            return
        end
        local elapsed = os.clock() - started
        local p = math.clamp(elapsed / duration, 0, 1)
        local lift
        if p < 0.62 then
            lift = 6.5 * smoothstep(p / 0.62)
        else
            lift = 6.5 * (1 - smoothstep((p - 0.62) / 0.38))
        end
        local turns = 3.25 * (p ^ 1.35)
        clone:PivotTo(basePivot * CFrame.new(0, lift, 0) * CFrame.Angles(0, turns * math.pi * 2, 0))
        fxAnchor.CFrame = CFrame.new(root.Position + Vector3.new(0, lift * 0.45, 0))
        highlight.FillTransparency = 0.74 - 0.24 * math.sin(math.pi * p)
        if p >= 1 and not finishing then
            finishing = true
            finishAt = elapsed + 0.55
            sparks.Enabled = false
            makeRing(fxAnchor, root.Position - Vector3.new(0, 2.3, 0), 10, 0)
            makeRing(fxAnchor, root.Position - Vector3.new(0, 2.3, 0), 13, 0.08)
            makeRing(fxAnchor, root.Position - Vector3.new(0, 2.3, 0), 16, 0.16)
            TweenService:Create(title, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
            TweenService:Create(titleStroke, TweenInfo.new(0.45), { Transparency = 1 }):Play()
            TweenService:Create(titleScale, TweenInfo.new(0.45), { Scale = 1.18 }):Play()
            TweenService:Create(light, TweenInfo.new(0.45), { Brightness = 0 }):Play()
        elseif finishing and finishAt and elapsed >= finishAt then
            cleanup()
        end
    end)
    return rings
end

return AscensionPresentation
