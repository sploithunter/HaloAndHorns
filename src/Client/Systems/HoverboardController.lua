--[[
    HoverboardController — HUD toggle plus skate-stance ride.

    Roadblock pattern (Roblox hoverboard/skate threads):
      Humanoid.PlatformStand = true  -- kills walk/run physics and locomotion anims
      LinearVelocity (World)         -- WASD via ControlModule:GetMoveVector()
      AlignOrientation               -- stay upright, face travel
      Mount leap, then stance weld   -- reset run pose before the deck appears
      Weld to HumanoidRootPart       -- deck stays under the body, not mid-stride feet
    Idle is replayed so PlatformStand does not leave a ragdoll pose.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)
local HoverboardLogic = require(ReplicatedStorage.Shared.Game.HoverboardLogic)

local HoverboardController = {}

function HoverboardController.Toggle()
    if HoverboardController._ignoreNextToggle then
        HoverboardController._ignoreNextToggle = false
        return
    end
    if HoverboardController._toggle then
        HoverboardController._toggle()
    end
end

local function loadConfig()
    local ok, cfg = pcall(function()
        return require(ReplicatedStorage.Configs.hoverboard)
    end)
    if ok and type(cfg) == "table" then
        return cfg
    end
    return {
        keybind = "H",
        hover_height = 3.6,
        stance_yaw_degrees = 90,
        mount = {
            source = "animate",
            jump_height = 11,
            jump_seconds = 0.36,
            anim_speed = 2.2,
            boot_below_box = 0,
            sole_drop = 0,
        },
        button = { text = "Board", icon = "rbxassetid://87061483301808" },
    }
end

local function keyCode(name)
    local ok, code = pcall(function()
        return Enum.KeyCode[name]
    end)
    if ok then
        return code
    end
    return Enum.KeyCode.H
end

local STANCE_WELD = "HoverboardStanceWeld"

local function isRigJoint(joint)
    return joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint"))
end

local function getRootJoint(character)
    local lower = character and character:FindFirstChild("LowerTorso")
    local root = lower and lower:FindFirstChild("Root")
    if isRigJoint(root) then
        return root
    end
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local joint = hrp and hrp:FindFirstChild("RootJoint")
    if isRigJoint(joint) then
        return joint
    end
    return nil
end

local function jointCFrame(joint, prop, fallback)
    local ok, value = pcall(function()
        return joint[prop]
    end)
    if ok and typeof(value) == "CFrame" then
        return value
    end
    return fallback
end

-- Current R15 avatars use AnimationConstraint for Root, not Motor6D. Disable
-- that constraint and weld LowerTorso with a HumanoidRootPart-space yaw.
local function applyStanceWeld(character, yaw)
    local motor = getRootJoint(character)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local body = motor and motor.Part1 or (character and character:FindFirstChild("LowerTorso"))
    if not (root and body and body:IsA("BasePart")) then
        return nil
    end
    local existing = root:FindFirstChild(STANCE_WELD)
    if existing then
        existing:Destroy()
    end
    if motor then
        motor.Enabled = false
        pcall(function()
            motor.Transform = CFrame.identity
        end)
    end
    local c0 = motor and jointCFrame(motor, "C0", nil)
    local c1 = motor and jointCFrame(motor, "C1", CFrame.identity) or CFrame.identity
    if not c0 then
        c0 = root.CFrame:ToObjectSpace(body.CFrame)
        c1 = CFrame.identity
    end
    local weld = Instance.new("Weld")
    weld.Name = STANCE_WELD
    weld.Part0 = root
    weld.Part1 = body
    weld.C0 = CFrame.Angles(0, yaw, 0) * c0
    weld.C1 = c1
    weld.Parent = root
    return weld
end

local function clearStanceWeld(character)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local weld = root and root:FindFirstChild(STANCE_WELD)
    if weld then
        weld:Destroy()
    end
    local motor = getRootJoint(character)
    if motor then
        motor.Enabled = true
        pcall(function()
            motor.Transform = CFrame.identity
        end)
    end
end

local function destroyBoard(character)
    local existing = character and character:FindFirstChild("Hoverboard")
    if existing then
        existing:Destroy()
    end
end

local function isR6(humanoid)
    return humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6
end

local function hipOffset(humanoid)
    local hip = tonumber(humanoid and humanoid.HipHeight) or 0
    if hip >= 1.2 then
        return hip
    end
    -- Classic R6 reports HipHeight 0; keep the deck under the blocky legs.
    if isR6(humanoid) then
        return 2
    end
    return 2.8
end

local function partLowestY(part)
    local cf = part.CFrame
    local half = part.Size * 0.5
    local lowest = math.huge
    for _, x in ipairs({ -1, 1 }) do
        for _, y in ipairs({ -1, 1 }) do
            for _, z in ipairs({ -1, 1 }) do
                local world = cf:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
                if world.Y < lowest then
                    lowest = world.Y
                end
            end
        end
    end
    return lowest
end

local function lowestSoleY(character, root)
    local lowest = nil
    local function consider(part)
        if not (part and part:IsA("BasePart")) then
            return
        end
        local y = partLowestY(part)
        if not lowest or y < lowest then
            lowest = y
        end
    end
    local left = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg")
    local right = character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg")
    consider(left)
    consider(right)
    for _, inst in ipairs(character:GetChildren()) do
        if inst:IsA("Accoutrement") then
            local handle = inst:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") and handle.Position.Y < root.Position.Y - 1 then
                local near = (left and (handle.Position - left.Position).Magnitude < 4)
                    or (right and (handle.Position - right.Position).Magnitude < 4)
                if near then
                    consider(handle)
                end
            end
        end
    end
    return lowest
end

local DECK_YAW = CFrame.Angles(0, math.rad(-90), 0)
local meshTemplates = {}
local configuredBootBelow = 0.85

-- Nose-to-tail in mesh space. Roll banks around this so one rail drops.
local function deckLongLocalAxis(deck)
    local size = deck and deck.Size
    if typeof(size) ~= "Vector3" then
        return Vector3.xAxis
    end
    if size.X >= size.Y and size.X >= size.Z then
        return Vector3.xAxis
    end
    if size.Z >= size.Y then
        return Vector3.zAxis
    end
    return Vector3.yAxis
end

local function deckOrientCFrame(deck)
    local yaw = deck and deck:GetAttribute("YawDegrees")
    local pitch = deck and deck:GetAttribute("PitchDegrees")
    local roll = deck and deck:GetAttribute("RollDegrees")
    if typeof(yaw) ~= "number" and typeof(pitch) ~= "number" and typeof(roll) ~= "number" then
        return DECK_YAW
    end
    -- Pitch lays the mesh flat (Rx). Yaw then spins on the ground. Roll is a
    -- bank around the long axis — not a second yaw. Angles(pitch, 0, roll)
    -- applies world-Z after pitch, so at surf pitch 90 roll matched yaw.
    local laid = CFrame.Angles(0, math.rad(tonumber(yaw) or 0), 0)
        * CFrame.Angles(math.rad(tonumber(pitch) or 0), 0, 0)
    local rollRad = math.rad(tonumber(roll) or 0)
    if math.abs(rollRad) < 1e-5 then
        return laid
    end
    return laid * CFrame.fromAxisAngle(deckLongLocalAxis(deck), rollRad)
end

-- Offset from deck center to the standing face, along world up. Uses the
-- local axis most aligned with up so pitch 90 (surf) uses thickness, not
-- length, and a small hoverboard pitch does not treat the long deck as tall.
local function deckHalfExtentY(deck)
    local orient = deckOrientCFrame(deck)
    local localUp = orient:VectorToObjectSpace(Vector3.yAxis)
    local ax, ay, az = math.abs(localUp.X), math.abs(localUp.Y), math.abs(localUp.Z)
    local topLocal
    if ay >= ax and ay >= az then
        topLocal = Vector3.new(0, (localUp.Y >= 0 and 1 or -1) * deck.Size.Y * 0.5, 0)
    elseif az >= ax then
        topLocal = Vector3.new(0, 0, (localUp.Z >= 0 and 1 or -1) * deck.Size.Z * 0.5)
    else
        topLocal = Vector3.new((localUp.X >= 0 and 1 or -1) * deck.Size.X * 0.5, 0, 0)
    end
    return (orient * topLocal).Y
end

local function applySkinOrient(deck, skin, config)
    local flatten = type(config) == "table" and config.flatten or nil
    deck:SetAttribute("YawDegrees", tonumber(skin and skin.deck_yaw_degrees) or 0)
    deck:SetAttribute(
        "PitchDegrees",
        tonumber(skin and skin.pitch_degrees) or tonumber(flatten and flatten.pitch_degrees) or 0
    )
    deck:SetAttribute(
        "RollDegrees",
        tonumber(skin and skin.roll_degrees) or tonumber(flatten and flatten.roll_degrees) or 0
    )
end

local function defaultSkin(config)
    local skins = config and config.skins
    local key = config and config.default_skin
    if type(skins) == "table" and type(key) == "string" then
        return skins[key]
    end
    return nil
end

local function selectedSkinKey(config, player)
    local key = player and player:GetAttribute("HoverboardSkin")
    if type(key) == "string" and config and config.skins and config.skins[key] then
        return key
    end
    return config and config.default_skin
end

local function selectedSkin(config, player)
    local key = selectedSkinKey(config, player)
    local skins = config and config.skins
    if type(skins) == "table" and type(key) == "string" then
        return skins[key], key
    end
    return defaultSkin(config), key
end

local function publishedTemplate(key)
    local folder = ReplicatedStorage:FindFirstChild("HoverboardTemplates")
    if folder and type(key) == "string" then
        return folder:FindFirstChild(key)
    end
    return nil
end

local function buildClientTemplate(config, key)
    local skins = config and config.skins
    local skin = type(skins) == "table" and type(key) == "string" and skins[key]
        or defaultSkin(config)
    if type(skin) ~= "table" or type(skin.mesh_asset) ~= "string" then
        return nil
    end
    local MeshAssembly = require(ReplicatedStorage.Shared.Assets.MeshAssembly)
    local model = MeshAssembly.build(skin.mesh_asset, skin.texture_asset, {
        modelName = "Hoverboard",
        partName = "Deck",
        anchored = false,
        canCollide = false,
    })
    if not model then
        return nil
    end
    local deck = model.PrimaryPart
    local target = tonumber(skin.length) or 5.4
    local longest = math.max(deck.Size.X, deck.Size.Y, deck.Size.Z)
    if longest > 0 then
        deck.Size = deck.Size * (target / longest)
    end
    deck.Color = Color3.new(1, 1, 1)
    applySkinOrient(deck, skin, config)
    return model
end

local function ensureMeshTemplate(config, waitForServer, key)
    key = key or (config and config.default_skin)
    if type(key) == "string" and meshTemplates[key] then
        return meshTemplates[key]
    end
    local published = publishedTemplate(key)
    if not published and waitForServer then
        local folder = ReplicatedStorage:WaitForChild("HoverboardTemplates", 8)
        published = folder and type(key) == "string" and folder:FindFirstChild(key)
    end
    if published then
        meshTemplates[key] = published
        return published
    end
    local built = buildClientTemplate(config, key)
    if built and type(key) == "string" then
        meshTemplates[key] = built
    end
    return built
end

local function glowFlatC0(deck)
    -- Mesh flatten pitches the Deck part; keep the debug box world-flat.
    return deckOrientCFrame(deck):Inverse() * CFrame.new(0, -deckHalfExtentY(deck) - 0.04, 0)
end

local function restampGlow(deck)
    local glow = deck and deck.Parent and deck.Parent:FindFirstChild("Glow")
    local weld = glow and glow:FindFirstChild("GlowGlue")
    if weld then
        weld.C0 = glowFlatC0(deck)
    end
end

local function rgbColor(rgb, fallback)
    if type(rgb) == "table" then
        return Color3.fromRGB(rgb[1] or 255, rgb[2] or 255, rgb[3] or 255)
    end
    return fallback
end

local function attachDeckTrail(glow, deck, fx)
    local deckFx = type(fx.deck) == "table" and fx.deck or {}
    local alongX = deck.Size.X >= deck.Size.Z
    local trail = Instance.new("Trail")
    trail.Color = ColorSequence.new(
        rgbColor(deckFx.color, Color3.fromRGB(255, 230, 160)),
        rgbColor(deckFx.fade, Color3.fromRGB(120, 200, 220))
    )
    trail.Transparency = NumberSequence.new(0.35, 1)
    trail.Lifetime = tonumber(fx.lifetime) or 0.28
    trail.MinLength = tonumber(fx.min_length) or 0.2
    local half = (alongX and deck.Size.X or deck.Size.Z) * 0.37
    trail.Attachment0 = Instance.new("Attachment")
    trail.Attachment0.Position = alongX and Vector3.new(-half, 0, 0) or Vector3.new(0, 0, -half)
    trail.Attachment0.Parent = glow
    trail.Attachment1 = Instance.new("Attachment")
    trail.Attachment1.Position = alongX and Vector3.new(half, 0, 0) or Vector3.new(0, 0, half)
    trail.Attachment1.Parent = glow
    trail.Parent = glow
end

local function attachEngineTrails(deck, glow, skin, fx)
    local engines = type(fx.engines) == "table" and fx.engines or {}
    local along = tonumber(engines.along) or -0.8
    local across = tonumber(engines.across) or 0.52
    local height = tonumber(engines.height) or -0.12
    local width = tonumber(engines.width) or 0.36
    local lifetime = tonumber(engines.lifetime) or 0.42
    local accent = rgbColor(skin and skin.accent_color, Color3.fromRGB(255, 118, 28))
    local fade = accent:Lerp(Color3.new(1, 1, 1), 0.4)
    local hx, hy, hz = deck.Size.X * 0.5, deck.Size.Y * 0.5, deck.Size.Z * 0.5
    local x = hx * along
    local y = hy * height
    for index, side in ipairs({ -1, 1 }) do
        local z = hz * across * side
        local a0 = Instance.new("Attachment")
        a0.Name = "EngineTrail0_" .. index
        a0.Position = Vector3.new(x, y, z - width * 0.5)
        a0.Parent = deck
        local a1 = Instance.new("Attachment")
        a1.Name = "EngineTrail1_" .. index
        a1.Position = Vector3.new(x, y, z + width * 0.5)
        a1.Parent = deck
        local trail = Instance.new("Trail")
        trail.Name = "EngineTrail_" .. index
        trail.Color = ColorSequence.new(accent, fade)
        trail.Transparency = NumberSequence.new(0.2, 1)
        trail.Lifetime = lifetime
        trail.MinLength = 0.15
        trail.LightEmission = 0.75
        trail.Attachment0 = a0
        trail.Attachment1 = a1
        trail.Parent = glow
    end
    glow.Color = accent
    local light = glow:FindFirstChildOfClass("PointLight")
    if light then
        light.Color = accent
    end
end

local function attachRideFx(deck, skin, config)
    local fx = type(config) == "table" and type(config.ride_fx) == "table" and config.ride_fx or {}
    local alongX = deck.Size.X >= deck.Size.Z
    local glow = Instance.new("Part")
    glow.Name = "Glow"
    if alongX then
        glow.Size = Vector3.new(deck.Size.X * 0.82, 0.1, deck.Size.Z * 0.73)
    else
        glow.Size = Vector3.new(deck.Size.X * 0.73, 0.1, deck.Size.Z * 0.82)
    end
    glow.Material = Enum.Material.Neon
    glow.Color = Color3.fromRGB(255, 214, 110)
    glow.CanCollide = false
    glow.CanQuery = false
    glow.Massless = true
    glow.CastShadow = false
    glow.Transparency = 1
    glow.Parent = deck.Parent

    local deckFx = type(fx.deck) == "table" and fx.deck or {}
    local light = Instance.new("PointLight")
    light.Color = rgbColor(deckFx.light, Color3.fromRGB(255, 220, 140))
    light.Brightness = 0.7
    light.Range = 10
    light.Parent = glow

    if skin and skin.ride_fx == "engines" then
        attachEngineTrails(deck, glow, skin, fx)
    else
        attachDeckTrail(glow, deck, fx)
    end

    local glowWeld = Instance.new("Weld")
    glowWeld.Name = "GlowGlue"
    glowWeld.Part0 = deck
    glowWeld.Part1 = glow
    glowWeld.C0 = glowFlatC0(deck)
    glowWeld.Parent = glow
end

local function solePlaneY(character, root, humanoid)
    local boxY = lowestSoleY(character, root)
    if not boxY then
        boxY = root.Position.Y - hipOffset(humanoid)
    end
    return boxY - configuredBootBelow
end

local function syncDeckOrientFromPlayer(character, deck)
    local owner = Players:GetPlayerFromCharacter(character)
    if not (owner and deck) then
        return
    end
    -- Live tuner only. Otherwise the global flatten attrs overwrite per-skin
    -- surf/rocket pitch (surf needs ~90; hoverboards use 10.1).
    if owner:GetAttribute("AdminOverlaysOn") ~= true then
        return
    end
    local yaw = tonumber(owner:GetAttribute("HoverboardYaw"))
    local pitch = tonumber(owner:GetAttribute("HoverboardPitch"))
    local roll = tonumber(owner:GetAttribute("HoverboardRoll"))
    if yaw ~= nil then
        deck:SetAttribute("YawDegrees", yaw)
    end
    if pitch ~= nil then
        deck:SetAttribute("PitchDegrees", pitch)
    end
    if roll ~= nil then
        deck:SetAttribute("RollDegrees", roll)
    end
end

local function restampDeck(character, drop)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local board = character and character:FindFirstChild("Hoverboard")
    local deck = board and board:FindFirstChild("Deck")
    local weld = deck and deck:FindFirstChild("RootGlue")
    if not (root and deck and weld) then
        return false
    end
    syncDeckOrientFromPlayer(character, deck)
    local soleY = solePlaneY(character, root, humanoid)
    local topY = soleY - (tonumber(drop) or 0)
    local centerY = topY - deckHalfExtentY(deck)
    weld.C0 = CFrame.new(0, centerY - root.Position.Y, 0) * deckOrientCFrame(deck)
    restampGlow(deck)
    return true
end

-- Deck is welded to HumanoidRootPart. The TOP face is what the soles stand on.
local function attachBoardUnderRoot(character, root, humanoid, drop, config)
    destroyBoard(character)
    local soleY = solePlaneY(character, root, humanoid)
    local model
    local deck
    local player = Players:GetPlayerFromCharacter(character)
    local skin, skinKey = selectedSkin(config, player)
    local template = ensureMeshTemplate(config, true, skinKey)
    if template then
        model = template:Clone()
        model.Name = "Hoverboard"
        deck = model.PrimaryPart or model:FindFirstChild("Deck")
        if type(skinKey) == "string" and template.Name ~= skinKey then
            model:Destroy()
            model = buildClientTemplate(config, skinKey)
            deck = model and (model.PrimaryPart or model:FindFirstChild("Deck"))
        end
        if deck then
            deck.Anchored = false
            deck.CanCollide = false
            deck.CanQuery = false
            deck.Massless = true
            deck.CastShadow = false
            deck.Color = Color3.new(1, 1, 1)
            applySkinOrient(deck, skin, config)
            syncDeckOrientFromPlayer(character, deck)
            model:SetAttribute("SkinId", skinKey)
        end
    end
    if not (model and deck) then
        model = Instance.new("Model")
        model.Name = "Hoverboard"
        deck = Instance.new("Part")
        deck.Name = "Deck"
        deck.Size = Vector3.new(5.4, 0.28, 2.2)
        deck.Material = Enum.Material.SmoothPlastic
        deck.Color = Color3.fromRGB(28, 42, 68)
        deck.CanCollide = false
        deck.CanQuery = false
        deck.Massless = true
        deck.CastShadow = false
        deck:SetAttribute("YawDegrees", -90)
        deck.Parent = model
        model.PrimaryPart = deck
    end

    attachRideFx(deck, skin, config)

    local weld = Instance.new("Weld")
    weld.Name = "RootGlue"
    weld.Part0 = root
    weld.Part1 = deck
    -- Weld C0 is the deck CENTER. TOP = visual sole (box + boot_below_box) minus tuner.
    local topY = soleY - (tonumber(drop) or 0)
    local centerY = topY - deckHalfExtentY(deck)
    weld.C0 = CFrame.new(0, centerY - root.Position.Y, 0) * deckOrientCFrame(deck)
    weld.Parent = deck

    model.PrimaryPart = deck
    model.Parent = character
    return deck
end

local function playIdle(humanoid, character)
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        return nil
    end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        track:Stop(0.12)
    end
    local animate = character:FindFirstChild("Animate")
    local idle = animate and animate:FindFirstChild("idle")
    local anim = idle and idle:FindFirstChildWhichIsA("Animation")
    if not anim then
        return nil
    end
    local track = animator:LoadAnimation(anim)
    track.Priority = Enum.AnimationPriority.Action
    track.Looped = true
    track:Play(0.15)
    return track
end

local function playAnimateClip(humanoid, character, folderName)
    local animator = humanoid:FindFirstChildOfClass("Animator")
    local animate = character and character:FindFirstChild("Animate")
    local folder = animate and animate:FindFirstChild(folderName)
    local anim = folder and folder:FindFirstChildWhichIsA("Animation")
    if not (animator and anim) then
        return nil
    end
    local ok, track = pcall(function()
        return animator:LoadAnimation(anim)
    end)
    if not ok or not track then
        return nil
    end
    track.Priority = Enum.AnimationPriority.Action4
    track.Looped = false
    track:Play(0.04)
    return track
end

local function stopTracks(humanoid)
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        return
    end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        track:Stop(0.08)
    end
end

local function eggCardOpen(player)
    local gui = player:FindFirstChild("PlayerGui")
    local card = gui and gui:FindFirstChild("EggCurrentTarget")
    if not card or not card:IsA("ScreenGui") then
        return false
    end
    return card.Enabled == true
end

function HoverboardController.start()
    local player = Players.LocalPlayer
    if not player then
        return
    end

    local config = loadConfig()
    if config.enabled == false then
        return
    end
    task.spawn(function()
        ensureMeshTemplate(config, true, selectedSkinKey(config, player))
    end)

    local bind = keyCode(config.keybind or "H")
    local hoverHeight = tonumber(config.hover_height) or 3.6
    local stanceYaw = math.rad(tonumber(config.stance_yaw_degrees) or 90)
    local mountCfg = type(config.mount) == "table" and config.mount or {}
    local jumpHeight = tonumber(mountCfg.jump_height) or 11
    local jumpSeconds = tonumber(mountCfg.jump_seconds) or 0.36
    local animSpeed = tonumber(mountCfg.anim_speed) or 2.2
    configuredBootBelow = tonumber(mountCfg.boot_below_box) or 0
    local soleDrop = tonumber(mountCfg.sole_drop) or 0
    local buttonCfg = type(config.button) == "table" and config.button or {}

    local liner
    local aligner
    local idleTrack
    local mountTrack
    local mounting = false
    local mountT0 = 0
    local rideGeneration = 0
    local lastTravel = Vector3.new(0, 0, -1)
    local lastPrecision = false
    local button
    local tunerLabels = {}
    local controls
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local flattenCfg = type(config.flatten) == "table" and config.flatten or {}
    local defaultPitch = tonumber(flattenCfg.pitch_degrees) or 0
    local defaultRoll = tonumber(flattenCfg.roll_degrees) or 0

    local function adminTunerOn()
        return player:GetAttribute("AdminOverlaysOn") == true
    end

    local function skinOrient(kind)
        local skin = selectedSkin(config, player)
        local flatten = type(config.flatten) == "table" and config.flatten or {}
        if kind == "sole" then
            return tonumber(skin and skin.sole_drop) or soleDrop
        end
        if kind == "yaw" then
            return tonumber(skin and skin.deck_yaw_degrees) or 0
        end
        if kind == "pitch" then
            return tonumber(skin and skin.pitch_degrees)
                or tonumber(flatten.pitch_degrees)
                or defaultPitch
        end
        return tonumber(skin and skin.roll_degrees) or tonumber(flatten.roll_degrees) or defaultRoll
    end

    local function currentSoleDrop()
        if adminTunerOn() then
            return tonumber(player:GetAttribute("HoverboardSoleDrop")) or skinOrient("sole")
        end
        return skinOrient("sole")
    end

    local function currentPitch()
        if adminTunerOn() then
            return tonumber(player:GetAttribute("HoverboardPitch")) or skinOrient("pitch")
        end
        return skinOrient("pitch")
    end

    local function currentRoll()
        if adminTunerOn() then
            return tonumber(player:GetAttribute("HoverboardRoll")) or skinOrient("roll")
        end
        return skinOrient("roll")
    end

    local function currentYaw()
        if adminTunerOn() then
            return tonumber(player:GetAttribute("HoverboardYaw")) or skinOrient("yaw")
        end
        return skinOrient("yaw")
    end

    local function seedTunerFromSkin()
        player:SetAttribute("HoverboardSoleDrop", skinOrient("sole"))
        player:SetAttribute("HoverboardYaw", skinOrient("yaw"))
        player:SetAttribute("HoverboardPitch", skinOrient("pitch"))
        player:SetAttribute("HoverboardRoll", skinOrient("roll"))
    end

    local function paintGlow(character)
        local board = character and character:FindFirstChild("Hoverboard")
        local glow = board and board:FindFirstChild("Glow")
        if glow and glow:IsA("BasePart") then
            glow.Transparency = adminTunerOn() and 0.25 or 1
            glow.CastShadow = false
        end
    end

    local function paintTuner()
        if tunerLabels.sole then
            tunerLabels.sole.Text = string.format("sole  %.2f", currentSoleDrop())
        end
        if tunerLabels.pitch then
            tunerLabels.pitch.Text = string.format("pitch  %.1f", currentPitch())
        end
        if tunerLabels.roll then
            tunerLabels.roll.Text = string.format("roll  %.1f", currentRoll())
        end
        if tunerLabels.yaw then
            tunerLabels.yaw.Text = string.format("yaw  %.1f", currentYaw())
        end
    end

    local function restampFromAttr()
        if mounting then
            paintTuner()
            return
        end
        restampDeck(player.Character, currentSoleDrop())
        paintTuner()
    end

    local function nudgeSoleDrop(delta)
        if not adminTunerOn() then
            return
        end
        local nextDrop = math.clamp(currentSoleDrop() + delta, -6, 4)
        nextDrop = math.floor(nextDrop * 20 + 0.5) / 20
        player:SetAttribute("HoverboardSoleDrop", nextDrop)
        restampFromAttr()
    end

    local function nudgeDegrees(attrName, current, delta, lo, hi)
        if not adminTunerOn() then
            return
        end
        local nextValue = math.clamp(current + delta, lo, hi)
        nextValue = math.floor(nextValue * 10 + 0.5) / 10
        player:SetAttribute(attrName, nextValue)
        restampFromAttr()
    end

    local function nudgePitch(delta)
        nudgeDegrees("HoverboardPitch", currentPitch(), delta, -180, 180)
    end

    local function nudgeRoll(delta)
        nudgeDegrees("HoverboardRoll", currentRoll(), delta, -180, 180)
    end

    local function nudgeYaw(delta)
        nudgeDegrees("HoverboardYaw", currentYaw(), delta, -180, 180)
    end

    local function request(mounted)
        Signals.Hoverboard_Toggle:FireServer({ mounted = mounted })
    end

    local function toggle()
        if player:GetAttribute("HoverboardEligible") ~= true then
            return
        end
        request(player:GetAttribute("HoverboardMounted") ~= true)
    end
    HoverboardController._toggle = toggle

    local function loadControls()
        if controls then
            return controls
        end
        local scripts = player:FindFirstChild("PlayerScripts")
        local module = scripts and scripts:FindFirstChild("PlayerModule")
        if not module then
            return nil
        end
        local ok, playerModule = pcall(require, module)
        if ok and playerModule and playerModule.GetControls then
            controls = playerModule:GetControls()
        end
        return controls
    end

    local function cameraMove()
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        local module = loadControls()
        local move = module and module.GetMoveVector and module:GetMoveVector()
        local camera = Workspace.CurrentCamera
        if not camera then
            return Vector3.zero
        end
        local flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
        local flatRight = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
        if flatLook.Magnitude < 0.05 then
            flatLook = lastTravel
        end
        flatLook = flatLook.Unit
        if flatRight.Magnitude > 0.05 then
            flatRight = flatRight.Unit
        else
            flatRight = flatLook:Cross(Vector3.new(0, 1, 0))
        end
        local fallback = humanoid and humanoid.MoveDirection or Vector3.zero
        local rawX = typeof(move) == "Vector3" and move.X or nil
        local rawZ = typeof(move) == "Vector3" and move.Z or nil
        local worldX, worldZ = HoverboardLogic.planarMoveDirection(
            rawX,
            rawZ,
            flatRight.X,
            flatRight.Z,
            flatLook.X,
            flatLook.Z,
            fallback.X,
            fallback.Z
        )
        return Vector3.new(worldX, 0, worldZ)
    end

    local speedGui
    local speedBound = false
    local speedPushAt = 0
    local pendingScale
    local speedDragConn

    local function callBus(name, args)
        local remote = ReplicatedStorage:FindFirstChild("GameAPICommand")
        if not remote then
            return nil
        end
        local ok, envelope = pcall(function()
            return remote:InvokeServer(name, args or {})
        end)
        if ok and type(envelope) == "table" then
            return envelope.result
        end
        return nil
    end

    local function hideSpeedSlider()
        if speedDragConn then
            speedDragConn:Disconnect()
            speedDragConn = nil
        end
        if speedGui then
            speedGui:Destroy()
            speedGui = nil
        end
    end

    local function pushSpeedScale(scale)
        pendingScale = scale
        player:SetAttribute("HoverboardSpeedScale", scale)
        if player:GetAttribute("HoverboardMounted") == true then
            local liveConfig = loadConfig()
            local cruise = HoverboardLogic.skinCruiseSpeed(
                selectedSkin(liveConfig, player),
                liveConfig.cruise_speed
            )
            local preview = HoverboardLogic.mountedSpeed(16, 1, cruise, scale)
            player:SetAttribute("HoverboardWalkSpeed", preview)
        end
        local now = os.clock()
        if now - speedPushAt < 0.08 then
            return
        end
        speedPushAt = now
        task.spawn(function()
            callBus("hoverboard.speed", { scale = pendingScale })
        end)
    end

    local function showSpeedSlider()
        if player:GetAttribute("HoverboardEligible") ~= true or not button then
            return
        end
        hideSpeedSlider()
        local knobs = loadConfig().speed or {}
        local lo = tonumber(knobs.min_scale) or 0.2
        local hi = tonumber(knobs.max_scale) or 1
        local scale =
            HoverboardLogic.clampSpeedScale(player:GetAttribute("HoverboardSpeedScale"), knobs)
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then
            return
        end
        local gui = Instance.new("ScreenGui")
        gui.Name = "HoverboardSpeedSlider"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 80
        gui.Parent = pg
        speedGui = gui
        local scrim = Instance.new("TextButton")
        scrim.Name = "Scrim"
        scrim.Text = ""
        scrim.AutoButtonColor = false
        scrim.BackgroundTransparency = 1
        scrim.Size = UDim2.fromScale(1, 1)
        scrim.ZIndex = 1
        scrim.Parent = gui
        scrim.Activated:Connect(function()
            if pendingScale then
                callBus("hoverboard.speed", { scale = pendingScale })
            end
            hideSpeedSlider()
        end)
        local panel = Instance.new("Frame")
        panel.Name = "Panel"
        panel.AnchorPoint = Vector2.new(0.5, 1)
        panel.Size = UDim2.fromOffset(220, 72)
        panel.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
        panel.BackgroundTransparency = 0.08
        panel.ZIndex = 2
        panel.Parent = gui
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = panel
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 210, 90)
        stroke.Thickness = 1.5
        stroke.Transparency = 0.35
        stroke.Parent = panel
        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Position = UDim2.fromOffset(12, 6)
        title.Size = UDim2.new(1, -24, 0, 22)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 14
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = Color3.fromRGB(255, 236, 190)
        title.ZIndex = 3
        title.Parent = panel
        local function paintTitle()
            title.Text = string.format("Board speed  %d%%", math.floor(scale * 100 + 0.5))
        end
        paintTitle()
        local track = Instance.new("TextButton")
        track.Name = "Track"
        track.Text = ""
        track.AutoButtonColor = false
        track.AnchorPoint = Vector2.new(0, 0.5)
        track.Position = UDim2.new(0, 14, 1, -22)
        track.Size = UDim2.new(1, -28, 0, 10)
        track.BackgroundColor3 = Color3.fromRGB(50, 54, 68)
        track.ZIndex = 3
        track.Parent = panel
        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(1, 0)
        trackCorner.Parent = track
        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.BackgroundColor3 = Color3.fromRGB(255, 190, 70)
        fill.BorderSizePixel = 0
        fill.Size = UDim2.new((scale - lo) / math.max(1e-4, hi - lo), 0, 1, 0)
        fill.ZIndex = 4
        fill.Parent = track
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = fill
        local function setFromX(x)
            local width = math.max(1, track.AbsoluteSize.X)
            local alpha = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
            scale = lo + (hi - lo) * alpha
            scale = math.floor(scale * 100 + 0.5) / 100
            fill.Size = UDim2.new((scale - lo) / math.max(1e-4, hi - lo), 0, 1, 0)
            paintTitle()
            pushSpeedScale(scale)
        end
        local dragging = false
        track.InputBegan:Connect(function(input)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragging = true
                setFromX(input.Position.X)
            end
        end)
        track.InputEnded:Connect(function(input)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragging = false
                if pendingScale then
                    callBus("hoverboard.speed", { scale = pendingScale })
                end
            end
        end)
        if speedDragConn then
            speedDragConn:Disconnect()
        end
        speedDragConn = UserInputService.InputChanged:Connect(function(input)
            if not dragging or not speedGui then
                return
            end
            if
                input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
            then
                setFromX(input.Position.X)
            end
        end)
        local function placePanel()
            local ap = button.AbsolutePosition
            local as = button.AbsoluteSize
            panel.Position = UDim2.fromOffset(ap.X + as.X * 0.5, ap.Y - 10)
        end
        placePanel()
        button:GetPropertyChangedSignal("AbsolutePosition"):Connect(placePanel)
    end

    local function bindSpeedSlider(host)
        if speedBound or not host then
            return
        end
        speedBound = true
        host.MouseButton2Click:Connect(function()
            showSpeedSlider()
        end)
        local pressToken = 0
        local holdSeconds = tonumber((loadConfig().speed or {}).long_press) or 0.45
        host.InputBegan:Connect(function(input)
            if
                input.UserInputType ~= Enum.UserInputType.Touch
                and input.UserInputType ~= Enum.UserInputType.MouseButton1
            then
                return
            end
            pressToken += 1
            local mine = pressToken
            task.delay(holdSeconds, function()
                if pressToken == mine then
                    HoverboardController._ignoreNextToggle = true
                    showSpeedSlider()
                end
            end)
        end)
        local function cancelPress()
            pressToken += 1
        end
        host.InputEnded:Connect(cancelPress)
        host.MouseLeave:Connect(cancelPress)
    end

    local function paintButton()
        if not button then
            return
        end
        button.Visible = player:GetAttribute("HoverboardEligible") == true
        local label = button:FindFirstChild("Label", true)
        if label and label:IsA("TextLabel") then
            label.Text = if player:GetAttribute("CombatTutorialDone") ~= true
                    and player:GetAttribute("HoverboardMounted") ~= true
                    and (tonumber(player:GetAttribute("MergeHighestWave")) or 0)
                        >= config.unlock.merge_wave
                then buttonCfg.tutorial_text
                else buttonCfg.text
        end
    end

    local function ensureButton()
        local pg = player:WaitForChild("PlayerGui")
        local hotbarGui = pg:WaitForChild("HotbarBar")
        local greaterHotbar = hotbarGui:WaitForChild("GreaterHotbarFrame", 15)
        local rightControls = greaterHotbar and greaterHotbar:WaitForChild("RightControls", 15)
        if not rightControls then
            return
        end
        -- BaseUI builds this, MenuTrayStyle pills it, HotbarFlank docks it.
        -- Destroy a leftover hand-rolled chrome copy if one is still on the bar.
        local name = buttonCfg.name or "HoverboardButton"
        local existing = rightControls:FindFirstChild(name)
        if existing and existing:GetAttribute("Pillified") ~= true then
            existing:Destroy()
        end
        button = rightControls:WaitForChild(name, 20)
        if not button then
            return
        end
        bindSpeedSlider(button)
        paintButton()
    end

    local function bindTunerRow(row, key)
        tunerLabels[key] = row and row:FindFirstChild("Label")
    end

    local function addTunerRow(parent, name, layoutOrder, onMinus, onPlus)
        local row = Instance.new("Frame")
        row.Name = name
        row.LayoutOrder = layoutOrder
        row.Size = UDim2.new(1, 0, 0, 36)
        row.BackgroundColor3 = Color3.fromRGB(32, 24, 14)
        row.BorderSizePixel = 0
        row.Parent = parent
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.2, 0)
        corner.Parent = row
        local minus = Instance.new("TextButton")
        minus.Name = "Minus"
        minus.Size = UDim2.fromOffset(40, 36)
        minus.BackgroundTransparency = 1
        minus.Font = Enum.Font.GothamBlack
        minus.Text = "−"
        minus.TextSize = 22
        minus.TextColor3 = Color3.fromRGB(255, 236, 190)
        minus.Parent = row
        minus.MouseButton1Click:Connect(onMinus)
        local plus = Instance.new("TextButton")
        plus.Name = "Plus"
        plus.AnchorPoint = Vector2.new(1, 0)
        plus.Position = UDim2.fromScale(1, 0)
        plus.Size = UDim2.fromOffset(40, 36)
        plus.BackgroundTransparency = 1
        plus.Font = Enum.Font.GothamBlack
        plus.Text = "+"
        plus.TextSize = 22
        plus.TextColor3 = Color3.fromRGB(255, 236, 190)
        plus.Parent = row
        plus.MouseButton1Click:Connect(onPlus)
        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(40, 0)
        label.Size = UDim2.new(1, -80, 1, 0)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 16
        label.TextColor3 = Color3.fromRGB(255, 236, 190)
        label.Parent = row
        return row
    end

    local function ensureTuner()
        -- Same audience as AdminController: Studio or a live admin. Visibility
        -- then follows AdminOverlaysOn so the bar is gone until ADMIN is ON.
        if not (RunService:IsStudio() or player:GetAttribute("IsAdmin") == true) then
            Readiness.awaitAttributePresent(player, "IsAdmin", 15)
            if player:GetAttribute("IsAdmin") ~= true then
                return
            end
        end
        local pg = player:WaitForChild("PlayerGui")
        local gui = pg:FindFirstChild("HoverboardSoleTuner")
        if gui and (not gui:FindFirstChild("Pitch") or not gui:FindFirstChild("Yaw")) then
            gui:Destroy()
            gui = nil
        end
        if gui then
            bindTunerRow(gui:FindFirstChild("Sole"), "sole")
            bindTunerRow(gui:FindFirstChild("Pitch"), "pitch")
            bindTunerRow(gui:FindFirstChild("Roll"), "roll")
            bindTunerRow(gui:FindFirstChild("Yaw"), "yaw")
            gui.Enabled = adminTunerOn()
            paintTuner()
            player:GetAttributeChangedSignal("AdminOverlaysOn"):Connect(function()
                if adminTunerOn() then
                    seedTunerFromSkin()
                end
                gui.Enabled = adminTunerOn()
            end)
            return
        end
        gui = Instance.new("ScreenGui")
        gui.Name = "HoverboardSoleTuner"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Enabled = adminTunerOn()
        gui.Parent = pg
        local stack = Instance.new("Frame")
        stack.Name = "Stack"
        stack.AnchorPoint = Vector2.new(1, 1)
        stack.Position = UDim2.new(1, -18, 1, -150)
        stack.Size = UDim2.fromOffset(228, 156)
        stack.BackgroundTransparency = 1
        stack.Parent = gui
        local list = Instance.new("UIListLayout")
        list.FillDirection = Enum.FillDirection.Vertical
        list.Padding = UDim.new(0, 4)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = stack
        bindTunerRow(
            addTunerRow(stack, "Sole", 1, function()
                nudgeSoleDrop(-0.1)
            end, function()
                nudgeSoleDrop(0.1)
            end),
            "sole"
        )
        bindTunerRow(
            addTunerRow(stack, "Pitch", 2, function()
                nudgePitch(-0.5)
            end, function()
                nudgePitch(0.5)
            end),
            "pitch"
        )
        bindTunerRow(
            addTunerRow(stack, "Roll", 3, function()
                nudgeRoll(-0.5)
            end, function()
                nudgeRoll(0.5)
            end),
            "roll"
        )
        bindTunerRow(
            addTunerRow(stack, "Yaw", 4, function()
                nudgeYaw(-0.5)
            end, function()
                nudgeYaw(0.5)
            end),
            "yaw"
        )
        paintTuner()
        player:GetAttributeChangedSignal("AdminOverlaysOn"):Connect(function()
            if adminTunerOn() then
                seedTunerFromSkin()
            end
            gui.Enabled = adminTunerOn()
        end)
    end

    local function teardownRide(character, humanoid)
        rideGeneration += 1
        mounting = false
        if mountTrack then
            mountTrack:Stop(0.08)
            mountTrack = nil
        end
        if idleTrack then
            idleTrack:Stop(0.12)
            idleTrack = nil
        end
        if liner then
            liner:Destroy()
            liner = nil
        end
        if aligner then
            aligner:Destroy()
            aligner = nil
        end
        clearStanceWeld(character)
        if humanoid then
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
        end
        local animate = character and character:FindFirstChild("Animate")
        if animate and animate:IsA("LocalScript") then
            animate.Disabled = false
        end
        destroyBoard(character)
    end

    local function applyVisual(character)
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not (humanoid and root) then
            return
        end
        local mounted = player:GetAttribute("HoverboardMounted") == true
        teardownRide(character, humanoid)
        if not mounted then
            paintButton()
            return
        end

        humanoid.AutoRotate = false
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid.PlatformStand = true
        local animate = character:FindFirstChild("Animate")
        if animate and animate:IsA("LocalScript") then
            animate.Disabled = true
        end
        local gen = rideGeneration

        local attachment = root:FindFirstChild("RootAttachment")
        if not attachment then
            attachment = Instance.new("Attachment")
            attachment.Name = "RootAttachment"
            attachment.Parent = root
        end

        liner = Instance.new("LinearVelocity")
        liner.Name = "HoverboardLiner"
        liner.Attachment0 = attachment
        liner.RelativeTo = Enum.ActuatorRelativeTo.World
        liner.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
        liner.MaxForce = 1e6
        pcall(function()
            liner.ForceLimitMode = Enum.ForceLimitMode.PerAxis
            liner.MaxAxesForce = Vector3.new(1e6, 1e6, 1e6)
        end)
        liner.VectorVelocity = Vector3.zero
        liner.Parent = root

        aligner = Instance.new("AlignOrientation")
        aligner.Name = "HoverboardAlign"
        aligner.Mode = Enum.OrientationAlignmentMode.OneAttachment
        aligner.Attachment0 = attachment
        aligner.RigidityEnabled = true
        aligner.CFrame = CFrame.lookAt(root.Position, root.Position + lastTravel)
        aligner.Parent = root

        lastTravel = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
        if lastTravel.Magnitude < 0.05 then
            lastTravel = Vector3.new(0, 0, -1)
        else
            lastTravel = lastTravel.Unit
        end
        paintButton()

        mounting = true
        mountT0 = os.clock()

        task.spawn(function()
            local function stillRiding()
                return gen == rideGeneration
                    and player:GetAttribute("HoverboardMounted") == true
                    and player.Character == character
            end

            local function hold(seconds)
                local started = os.clock()
                while stillRiding() and os.clock() - started < seconds do
                    task.wait()
                end
            end

            local function playHopClip(name)
                local track = playAnimateClip(humanoid, character, name)
                if track then
                    track:AdjustSpeed(animSpeed)
                end
                return track
            end

            stopTracks(humanoid)
            -- Hop first. Glue only after idle is the standing pose that we already tuned.
            mountTrack = playHopClip("jump")
            hold(jumpSeconds * 0.35)
            if mountTrack then
                mountTrack:Stop(0.04)
                mountTrack = nil
            end
            if not stillRiding() then
                return
            end
            mountTrack = playHopClip("fall")
            local hopLeft = math.max(0, (mountT0 + jumpSeconds) - os.clock())
            hold(math.max(hopLeft, jumpSeconds * 0.2))
            if mountTrack then
                mountTrack:Stop(0.06)
                mountTrack = nil
            end
            if not stillRiding() then
                return
            end
            idleTrack = playIdle(humanoid, character)
            applyStanceWeld(character, stanceYaw)
            -- Idle + stance must finish posing the feet. Welding two frames
            -- after fall left the deck under a low hop pose; standing idle
            -- then floated the boots above the board until Admin restamped.
            hold(0.2)
            if not stillRiding() then
                return
            end
            attachBoardUnderRoot(character, root, humanoid, currentSoleDrop(), config)
            paintGlow(character)
            mounting = false
            hold(0.12)
            if stillRiding() then
                restampDeck(character, currentSoleDrop())
            end
        end)
    end

    task.spawn(ensureButton)
    task.spawn(ensureTuner)
    player:GetAttributeChangedSignal("HoverboardSoleDrop"):Connect(restampFromAttr)
    player:GetAttributeChangedSignal("HoverboardPitch"):Connect(restampFromAttr)
    player:GetAttributeChangedSignal("HoverboardRoll"):Connect(restampFromAttr)
    player:GetAttributeChangedSignal("HoverboardYaw"):Connect(restampFromAttr)

    player:GetAttributeChangedSignal("HoverboardEligible"):Connect(paintButton)
    player:GetAttributeChangedSignal("CombatTutorialDone"):Connect(paintButton)
    player:GetAttributeChangedSignal("HoverboardMounted"):Connect(paintButton)
    player:GetAttributeChangedSignal("AdminOverlaysOn"):Connect(function()
        paintGlow(player.Character)
        if adminTunerOn() then
            seedTunerFromSkin()
        end
        if not mounting then
            restampDeck(player.Character, currentSoleDrop())
        end
    end)
    player:GetAttributeChangedSignal("HoverboardMounted"):Connect(function()
        applyVisual(player.Character)
    end)
    player:GetAttributeChangedSignal("HoverboardSkin"):Connect(function()
        if adminTunerOn() then
            seedTunerFromSkin()
        end
        if player:GetAttribute("HoverboardMounted") == true then
            applyVisual(player.Character)
        end
    end)
    player.CharacterAdded:Connect(function(character)
        liner = nil
        aligner = nil
        task.defer(applyVisual, character)
    end)
    if player.Character then
        task.defer(applyVisual, player.Character)
    end

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end
        if input.KeyCode == bind then
            toggle()
        elseif input.KeyCode == Enum.KeyCode.LeftBracket then
            nudgeSoleDrop(-0.1)
        elseif input.KeyCode == Enum.KeyCode.RightBracket then
            nudgeSoleDrop(0.1)
        end
    end)

    RunService.Heartbeat:Connect(function()
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local precision = eggCardOpen(player)
        if precision ~= lastPrecision then
            lastPrecision = precision
            if precision and player:GetAttribute("HoverboardMounted") == true then
                request(false)
            end
        end
        if
            not liner
            or not aligner
            or not humanoid
            or not root
            or player:GetAttribute("HoverboardMounted") ~= true
        then
            return
        end

        if idleTrack and not idleTrack.IsPlaying and not mountTrack then
            idleTrack = playIdle(humanoid, character)
        end

        -- Re-require so a long Play session still sees Rojo cruise edits.
        local liveConfig = loadConfig()
        local skinCruise = HoverboardLogic.skinCruiseSpeed(
            selectedSkin(liveConfig, player),
            liveConfig.cruise_speed
        )
        local attrSpeed = tonumber(player:GetAttribute("HoverboardWalkSpeed"))
        local scale = HoverboardLogic.clampSpeedScale(
            player:GetAttribute("HoverboardSpeedScale"),
            liveConfig.speed
        )
        local speed = attrSpeed or HoverboardLogic.mountedSpeed(16, 1, skinCruise, scale)
        local dir = cameraMove()
        if dir.Magnitude > 0.05 then
            lastTravel = dir
        end
        local excluded = { character }
        rayParams.FilterDescendantsInstances = excluded
        local hover
        local originY = root.Position.Y
        local from = root.Position
        local maxDepth = 28
        for _ = 1, 8 do
            -- Keep the original 28-stud probe. After skipping a steep/underside
            -- hit, budget used to become (rootY - hitY) and the real floor
            -- below the hop was never found until the rider moved.
            local budget = math.max(0, maxDepth - (originY - from.Y))
            if budget < 0.1 then
                break
            end
            local hit = Workspace:Raycast(from, Vector3.new(0, -budget, 0), rayParams)
            if not hit then
                break
            end
            if hit.Normal.Y >= 0.65 then
                hover = hit
                break
            end
            table.insert(excluded, hit.Instance)
            rayParams.FilterDescendantsInstances = excluded
            from = hit.Position - Vector3.new(0, 0.05, 0)
        end
        local yVel = 0
        local xVel = 0
        local zVel = 0
        if hover then
            local hip = hipOffset(humanoid)
            local landY = hover.Position.Y + hoverHeight + hip
            local targetY = landY
            if mounting then
                local t = math.clamp((os.clock() - mountT0) / jumpSeconds, 0, 1)
                local apexY = hover.Position.Y + hip + jumpHeight
                targetY = landY + (apexY - landY) * math.sin(t * math.pi)
            else
                targetY = landY + math.sin(os.clock() * 5) * 0.12
            end
            yVel = (targetY - root.Position.Y) * 28
        else
            yVel = -36
        end
        if dir.Magnitude > 0.05 then
            xVel = lastTravel.X * speed
            zVel = lastTravel.Z * speed
        end
        liner.VectorVelocity = Vector3.new(xVel, yVel, zVel)
        aligner.CFrame = CFrame.lookAt(root.Position, root.Position + lastTravel)
    end)
end

return HoverboardController
