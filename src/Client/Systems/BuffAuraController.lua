--[[
    BuffAuraController (client) — renders a themed AURA on any player while a timed buff is active.

    The in-world counterpart to PlayerPowerBadges (the HUD row): the badge tells YOU a buff is up,
    the aura shows EVERYONE. Pure SSOT — for each row in configs/buff_auras.lua we watch the
    player attribute `<attr>Until` (an os.time stamp written by PowerService:_setAxisBuff); when it's
    in the future the player wears the aura, when it lapses the aura tears down. Player attributes
    replicate, so this runs on every client and renders every player's auras (Windfall etc.).

    Reusable: a new buff aura (or a potion) is one config row — no code change here.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrewJuice = require(ReplicatedStorage.Shared.Game.BrewJuice)

local BuffAuraController = {}
local started = false

local function toColor(rgb)
    if typeof(rgb) == "Color3" then
        return rgb
    end
    if type(rgb) == "table" then
        return Color3.fromRGB(rgb[1] or 255, rgb[2] or 255, rgb[3] or 255)
    end
    return Color3.fromRGB(255, 255, 255)
end

local function spawnContainment(hrp, def, c1)
    if def.contain ~= true then
        return nil
    end
    local bubble = Instance.new("Part")
    bubble.Name = "BuffContain_" .. tostring(def.attr)
    bubble.Shape = Enum.PartType.Ball
    bubble.Material = Enum.Material.ForceField
    bubble.Color = c1
    bubble.Transparency = 0.62
    bubble.Anchored = false
    bubble.CanCollide = false
    bubble.CanQuery = false
    bubble.CastShadow = false
    bubble.Massless = true
    bubble.Size = Vector3.new(6.4, 7.4, 6.4)
    bubble.CFrame = hrp.CFrame
    bubble.Parent = hrp.Parent
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = hrp
    weld.Part1 = bubble
    weld.Parent = bubble
    return bubble
end

-- Build the aura instances on a character's HumanoidRootPart. Returns a handle we can tear down.
local function spawnAura(hrp, def)
    local c1 = toColor(def.color)
    local c2 = toColor(def.color2 or def.color)

    local att = Instance.new("Attachment")
    att.Name = "BuffAura_" .. tostring(def.attr)
    att.Position = Vector3.new(0, -2.2, 0) -- low on the body so sparkles rise up past it
    att.Parent = hrp

    local size = tonumber(def.size) or 0.5
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(c1, c2)
    emitter.LightEmission = 0.85
    emitter.LightInfluence = 0
    emitter.Lifetime = NumberRange.new(0.8, 1.5)
    emitter.Rate = tonumber(def.rate) or 14
    emitter.Speed = NumberRange.new((tonumber(def.speed) or 3) * 0.6, tonumber(def.speed) or 3)
    emitter.SpreadAngle = Vector2.new(45, 45)
    emitter.Acceleration = Vector3.new(0, tonumber(def.rise) or 6, 0)
    emitter.Drag = 2
    emitter.Rotation = NumberRange.new(0, 360)
    emitter.RotSpeed = NumberRange.new(-90, 90)
    emitter.EmissionDirection = Enum.NormalId.Top
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, size * 0.2),
        NumberSequenceKeypoint.new(0.3, size),
        NumberSequenceKeypoint.new(1, 0),
    })
    -- fade in fast, hold OPAQUE through the peak (reads clearly even on bright ground), fade out
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.2, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Parent = att
    emitter:Emit(tonumber(def.burst) or 0) -- cast-moment flourish

    local light = Instance.new("PointLight")
    light.Color = c1
    light.Brightness = tonumber(def.light_brightness) or 2
    light.Range = tonumber(def.light_range) or 12
    light.Parent = att

    return {
        att = att,
        emitter = emitter,
        light = light,
        hrp = hrp,
        def = def,
        contain = spawnContainment(hrp, def, c1),
        lastCharge = 0,
        baseSize = size,
    }
end

local function applyCharge(handle, charge, knobs)
    if not handle then
        return
    end
    local def = handle.def or {}
    local juice = BrewJuice.sample(charge, knobs)
    local rate = tonumber(def.rate) or 14
    local bright = tonumber(def.light_brightness) or 2
    local range = tonumber(def.light_range) or 12
    local speed = tonumber(def.speed) or 3
    local size = handle.baseSize or tonumber(def.size) or 0.5
    local scale = 0.55 + juice.glow * 0.7 + juice.leak * 1.1
    if handle.emitter then
        handle.emitter.Rate = rate * scale
        handle.emitter.Speed = NumberRange.new(speed * 0.6 * scale, speed * scale)
        local sz = size * (0.85 + juice.leak * 0.55)
        handle.emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, sz * 0.2),
            NumberSequenceKeypoint.new(0.3, sz),
            NumberSequenceKeypoint.new(1, 0),
        })
        if charge > (handle.lastCharge or 0) + 0.04 then
            handle.emitter:Emit(tonumber(def.burst) or 16)
        end
    end
    if handle.light then
        handle.light.Brightness = bright * (0.45 + juice.glow * 0.7 + juice.leak * 0.9)
        handle.light.Range = range * (0.75 + juice.leak * 0.55)
    end
    if handle.contain and handle.contain.Parent then
        local leak = juice.leak
        local pulse = 1 + leak * 0.12 * (0.55 + 0.45 * math.sin(os.clock() * 11))
        handle.contain.Transparency = 0.78 - leak * 0.28
        handle.contain.Size = Vector3.new(6.2, 7.2, 6.2) * pulse
        handle.contain.Color = toColor(def.color)
    end
    handle.lastCharge = charge
end

-- Stop emitting + fade the glow, then clean up once the last sparkles have died.
local function despawnAura(handle)
    if not handle then
        return
    end
    if handle.emitter then
        handle.emitter.Enabled = false
        handle.emitter.Rate = 0
    end
    if handle.light then
        pcall(function()
            TweenService:Create(handle.light, TweenInfo.new(0.4), { Brightness = 0 }):Play()
        end)
    end
    if handle.contain then
        pcall(function()
            TweenService:Create(handle.contain, TweenInfo.new(0.35), {
                Transparency = 1,
                Size = handle.contain.Size * 1.2,
            }):Play()
        end)
        Debris:AddItem(handle.contain, 0.45)
    end
    if handle.att then
        Debris:AddItem(handle.att, 1.4)
    end
end

function BuffAuraController.start()
    if started then
        return
    end
    started = true

    local config = require(ReplicatedStorage.Configs:WaitForChild("buff_auras"))
    if config.enabled == false or type(config.auras) ~= "table" or #config.auras == 0 then
        return
    end
    local interval = math.max(0.05, tonumber(config.poll_interval) or 0.2)
    local potions = require(ReplicatedStorage.Configs:WaitForChild("potions"))
    local juiceKnobs = potions.overcharge or {}

    -- live[player][attr] = aura handle
    local live = setmetatable({}, { __mode = "k" })

    local function handlesFor(player)
        local t = live[player]
        if not t then
            t = {}
            live[player] = t
        end
        return t
    end

    local function clearPlayer(player)
        local t = live[player]
        if t then
            for _, h in pairs(t) do
                despawnAura(h)
            end
            live[player] = nil
        end
    end

    local function poll(player)
        local handles = handlesFor(player)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local now = os.time()
        for _, def in ipairs(config.auras) do
            local until_ = tonumber(player:GetAttribute(tostring(def.attr) .. "Until")) or 0
            local active = hrp ~= nil and until_ > now
            local h = handles[def.attr]
            -- A respawn replaces the HRP, orphaning the old attachment — treat that as stale.
            local stale = h ~= nil and (h.hrp ~= hrp or h.att.Parent == nil)
            if active then
                if not h or stale then
                    if h then
                        despawnAura(h)
                    end
                    h = spawnAura(hrp, def)
                    handles[def.attr] = h
                end
                if type(def.charge_attr) == "string" then
                    applyCharge(
                        h,
                        BrewJuice.clamp01(player:GetAttribute(def.charge_attr)),
                        juiceKnobs
                    )
                end
            elseif h then
                despawnAura(h)
                handles[def.attr] = nil
            end
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        handlesFor(player)
    end
    Players.PlayerAdded:Connect(handlesFor)
    Players.PlayerRemoving:Connect(clearPlayer)

    local acc = 0
    RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < interval then
            return
        end
        acc = 0
        for _, player in ipairs(Players:GetPlayers()) do
            poll(player)
        end
    end)
end

return BuffAuraController
