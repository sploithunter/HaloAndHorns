-- EggHatchFX.lua
-- Client-side visual effect for egg hatching: swirl particles, beam ribbon, and bloom flash

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local EggHatchFX = {}

-- Create or get a single BloomEffect we can animate safely
local function getBloom()
    local bloom = Lighting:FindFirstChild("EggFXBloom")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Name = "EggFXBloom"
        bloom.Size = 24
        bloom.Threshold = 1.0
        bloom.Intensity = 0
        bloom.Parent = Lighting
    end
    return bloom
end

-- Build a swirl of N attachments around 'center', at 'radius', orbiting at 'rpm'
local function buildSwirl(centerAttachment, radius, count, rpm)
    -- Use an Attachment as the rig root so children attachments have valid parents
    local rigRoot = Instance.new("Attachment")
    rigRoot.Name = "SwirlRig"
    rigRoot.Parent = centerAttachment

    local attachments = {}
    for i = 1, count do
        local a = Instance.new("Attachment")
        a.Name = "SwirlA" .. i
        a.Parent = rigRoot

        local theta = (i / count) * math.pi * 2
        a.Position = Vector3.new(math.cos(theta) * radius, 0, math.sin(theta) * radius)

        local p = Instance.new("ParticleEmitter")
        p.Rate = 0
        p.Lifetime = NumberRange.new(0.6, 1.0)
        p.Speed = NumberRange.new(1, 3)
        p.SpreadAngle = Vector2.new(10, 10)
        p.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.6),
            NumberSequenceKeypoint.new(0.7, 0.25),
            NumberSequenceKeypoint.new(1.0, 0.0),
        })
        p.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 0.0),
            NumberSequenceKeypoint.new(0.7, 0.1),
            NumberSequenceKeypoint.new(1.0, 1.0),
        })
        p.LightEmission = 0.6
        p.Enabled = true
        p.Parent = a

        table.insert(attachments, { a = a, emitter = p })
    end

    local helixA = Instance.new("Attachment")
    helixA.Name = "HelixA"
    helixA.Parent = rigRoot
    local helixB = Instance.new("Attachment")
    helixB.Name = "HelixB"
    helixB.Parent = rigRoot

    local beam = Instance.new("Beam")
    beam.Attachment0 = helixA
    beam.Attachment1 = helixB
    beam.Width0 = 0.12
    beam.Width1 = 0.12
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.Transparency = NumberSequence.new(0.25)
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
    beam.Parent = rigRoot

    local t0 = tick()
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not rigRoot.Parent then
            connection:Disconnect()
            return
        end
        local t = tick() - t0
        local angle = t * rpm * 2 * math.pi / 60

        for _, entry in ipairs(attachments) do
            local off = entry.a.Position
            local rotX = off.X * math.cos(angle) - off.Z * math.sin(angle)
            local rotZ = off.X * math.sin(angle) + off.Z * math.cos(angle)
            entry.a.WorldPosition = centerAttachment.WorldPosition + Vector3.new(rotX, off.Y, rotZ)
        end

        local helixR = radius * 0.6
        helixA.WorldPosition = centerAttachment.WorldPosition
            + Vector3.new(
                math.cos(angle) * helixR,
                0.5 * math.sin(angle * 2),
                math.sin(angle) * helixR
            )
        helixB.WorldPosition = centerAttachment.WorldPosition
            + Vector3.new(
                math.cos(angle + math.pi) * helixR,
                0.5 * math.cos(angle * 2),
                math.sin(angle + math.pi) * helixR
            )
    end)

    return rigRoot, attachments
end

function EggHatchFX.Play(eggPart, durationSeconds)
    if not eggPart or not eggPart.Parent then
        return
    end

    durationSeconds = durationSeconds or 2.5

    local center = eggPart:FindFirstChild("FXCenter")
    if not center then
        center = Instance.new("Attachment")
        center.Name = "FXCenter"
        center.Parent = eggPart
        center.Position = Vector3.new(0, eggPart.Size.Y * 0.5, 0)
    end

    local sparkles = Instance.new("Sparkles")
    sparkles.Enabled = true
    sparkles.SparkleColor = Color3.fromRGB(255, 255, 255)
    sparkles.Parent = eggPart

    local light = Instance.new("PointLight")
    light.Brightness = 0
    light.Range = 14
    light.Color = Color3.fromRGB(255, 255, 255)
    light.Parent = eggPart
    TweenService:Create(
        light,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Brightness = 5 }
    ):Play()

    local radius, count, rpm = 3.2, 14, 60
    local rig, points = buildSwirl(center, radius, count, rpm)

    local bloom = getBloom()
    TweenService:Create(
        bloom,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Intensity = 1.6 }
    ):Play()

    task.spawn(function()
        local t0 = tick()
        while tick() - t0 < durationSeconds do
            for _, entry in ipairs(points) do
                entry.emitter:Emit(2)
            end
            task.wait(0.08)
        end
    end)

    task.delay(durationSeconds, function()
        TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()
        TweenService:Create(bloom, TweenInfo.new(0.3), { Intensity = 0 }):Play()

        task.wait(0.45)
        sparkles.Enabled = false
        if rig then
            rig:Destroy()
        end
        sparkles:Destroy()
        light:Destroy()
    end)
end

return EggHatchFX
