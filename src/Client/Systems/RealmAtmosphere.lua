--[[
    RealmAtmosphere (client) — DEPTH-SCALED realm skin (World S3 A1).

    Reuses the SAME map. Captures the map's real base lighting at boot, then blends base -> the
    realm's `deep` anchor (configs/layers.lua `atmosphere`) by t = depth / max_depth (RealmTheme):
    layer 1 = a faint 20% wash, the deepest layer = the full deep look. So each descent step
    intensifies, and the most dramatic look (hell = the dark abyss) is reserved for layer 5.
    Driven by the server-published CurrentLayer attribute; neutral/base restores the captured look.
    A brief centered banner names the realm + depth so it's instantly clear where you are.

    Lighting is client-side, so each player sees their own skin (the solo-test path; true spatial
    separation is the production geometry slice, task #157).
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RealmTheme = require(ReplicatedStorage.Shared.Game.RealmTheme)

local TINT_NAME = "RealmTint"

local RealmAtmosphere = {}

local function loadAtmosphere()
    local configs = ReplicatedStorage:FindFirstChild("Configs")
    local mod = configs and configs:FindFirstChild("layers")
    if mod and mod:IsA("ModuleScript") then
        local ok, cfg = pcall(require, mod)
        if ok and type(cfg) == "table" and type(cfg.atmosphere) == "table" then
            return cfg.atmosphere
        end
    end
    return { tween_seconds = 1.2, max_depth = 5 }
end

local function c01(t, fallback)
    if type(t) == "table" and t[1] then
        return Color3.new(t[1], t[2] or t[1], t[3] or t[1])
    end
    return fallback
end

local function c255(t, fallback)
    if type(t) == "table" and t[1] then
        return Color3.fromRGB(t[1], t[2] or t[1], t[3] or t[1])
    end
    return fallback
end

local function arrOf(c)
    return { c.R * 255, c.G * 255, c.B * 255 }
end

function RealmAtmosphere.start()
    local player = Players.LocalPlayer
    if not player then
        return
    end
    local themes = loadAtmosphere()
    local maxDepth = tonumber(themes.max_depth) or 5
    local tweenInfo = TweenInfo.new(
        tonumber(themes.tween_seconds) or 1.2,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    )

    local tint = Lighting:FindFirstChild(TINT_NAME)
    if not tint then
        tint = Instance.new("ColorCorrectionEffect")
        tint.Name = TINT_NAME
        tint.Enabled = true
        tint.Parent = Lighting
    end

    -- Reuse an existing Atmosphere or create+manage one (off at base).
    local atmos = Lighting:FindFirstChildWhichIsA("Atmosphere")
    if not atmos then
        atmos = Instance.new("Atmosphere")
        atmos.Density = 0
        atmos.Parent = Lighting
    end

    -- The map's real base look, as a theme table (the shallow anchor — t=0). Darkness in deep
    -- themes comes from ambient/clock/fog, NOT global Brightness, so we leave Lighting.Brightness
    -- alone and only drive ColorCorrection.Brightness.
    local baseTheme = {
        tint = { 1, 1, 1 },
        brightness = 0,
        contrast = 0,
        clock_time = Lighting.ClockTime,
        ambient = arrOf(Lighting.Ambient),
        outdoor_ambient = arrOf(Lighting.OutdoorAmbient),
        fog_color = arrOf(Lighting.FogColor),
        fog_end = Lighting.FogEnd,
        atmosphere = {
            density = atmos.Density,
            offset = atmos.Offset,
            color = arrOf(atmos.Color),
            decay = arrOf(atmos.Decay),
            glare = atmos.Glare,
            haze = atmos.Haze,
        },
    }

    -- Per-layer skybox swap (configs/layers.lua atmosphere.sky.per_layer). Capture the base sky
    -- faces so a layer with no textures restores the map's original sky.
    local skyConfig = (type(themes.sky) == "table" and type(themes.sky.per_layer) == "table")
            and themes.sky.per_layer
        or {}
    local sky = Lighting:FindFirstChildOfClass("Sky")
    local baseSky
    if sky then
        baseSky = {
            SkyboxFt = sky.SkyboxFt,
            SkyboxBk = sky.SkyboxBk,
            SkyboxLf = sky.SkyboxLf,
            SkyboxRt = sky.SkyboxRt,
            SkyboxUp = sky.SkyboxUp,
            SkyboxDn = sky.SkyboxDn,
            SunTextureId = sky.SunTextureId,
            MoonTextureId = sky.MoonTextureId,
            CelestialBodiesShown = sky.CelestialBodiesShown,
        }
    end

    local function asset(id)
        if type(id) == "number" then
            return "rbxassetid://" .. id
        end
        return id
    end

    local function applySky(layerId)
        local cfg = skyConfig[layerId]
        local tx = cfg and cfg.textures
        if type(tx) == "table" and (tx.ft or tx.up) then
            if not sky then
                sky = Instance.new("Sky")
                sky.Parent = Lighting
            end
            sky.SkyboxFt = asset(tx.ft) or sky.SkyboxFt
            sky.SkyboxBk = asset(tx.bk) or sky.SkyboxBk
            sky.SkyboxLf = asset(tx.lf) or sky.SkyboxLf
            sky.SkyboxRt = asset(tx.rt) or sky.SkyboxRt
            sky.SkyboxUp = asset(tx.up) or sky.SkyboxUp
            sky.SkyboxDn = asset(tx.dn) or sky.SkyboxDn
            if tx.sun then
                sky.SunTextureId = asset(tx.sun)
            end
            if tx.moon then
                sky.MoonTextureId = asset(tx.moon)
            end
            if tx.celestial_bodies_shown ~= nil then
                sky.CelestialBodiesShown = tx.celestial_bodies_shown
            end
            if tx.star_count then
                sky.StarCount = tx.star_count
            end
            if tx.sun_angular_size then
                sky.SunAngularSize = tx.sun_angular_size
            end
            if tx.moon_angular_size then
                sky.MoonAngularSize = tx.moon_angular_size
            end
        elseif baseSky and sky then
            for k, v in pairs(baseSky) do
                sky[k] = v
            end
        end
    end

    local function applyTheme(theme)
        TweenService:Create(Lighting, tweenInfo, {
            Ambient = c255(theme.ambient, Lighting.Ambient),
            OutdoorAmbient = c255(theme.outdoor_ambient, Lighting.OutdoorAmbient),
            FogColor = c255(theme.fog_color, Lighting.FogColor),
            FogEnd = tonumber(theme.fog_end) or Lighting.FogEnd,
            ClockTime = tonumber(theme.clock_time) or Lighting.ClockTime,
        }):Play()
        TweenService:Create(tint, tweenInfo, {
            TintColor = c01(theme.tint, Color3.new(1, 1, 1)),
            Brightness = tonumber(theme.brightness) or 0,
            Contrast = tonumber(theme.contrast) or 0,
        }):Play()
        local a = theme.atmosphere
        if type(a) == "table" then
            TweenService:Create(atmos, tweenInfo, {
                Density = tonumber(a.density) or 0,
                Offset = tonumber(a.offset) or 0,
                Color = c255(a.color, atmos.Color),
                Decay = c255(a.decay, atmos.Decay),
                Glare = tonumber(a.glare) or 0,
                Haze = tonumber(a.haze) or 0,
            }):Play()
        end
    end

    local function banner(realm, depth)
        local gui = player:FindFirstChild("PlayerGui")
        if not gui then
            return
        end
        local screen = gui:FindFirstChild("RealmBanner")
        if not screen then
            screen = Instance.new("ScreenGui")
            screen.Name = "RealmBanner"
            screen.ResetOnSpawn = false
            screen.IgnoreGuiInset = true
            screen.Parent = gui
            local label = Instance.new("TextLabel")
            label.Name = "Label"
            label.AnchorPoint = Vector2.new(0.5, 0.5)
            label.Position = UDim2.new(0.5, 0, 0.28, 0)
            label.Size = UDim2.new(0.6, 0, 0, 60)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamBlack
            label.TextSize = 42
            label.TextStrokeTransparency = 0.4
            label.TextTransparency = 1
            label.Parent = screen
        end
        local label = screen:FindFirstChild("Label")
        if not label then
            return
        end
        if realm == "heaven" then
            label.Text = string.format("✦  HEAVEN · %d  ✦", depth)
            label.TextColor3 = Color3.fromRGB(255, 240, 180)
        elseif realm == "hell" then
            label.Text = string.format("☠  HELL · %d  ☠", depth)
            label.TextColor3 = Color3.fromRGB(255, 110, 90)
        else
            label.Text = "Returned to the Base Realm"
            label.TextColor3 = Color3.fromRGB(235, 235, 245)
        end
        label.TextTransparency = 1
        TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
        task.delay(2.2, function()
            if label and label.Parent then
                TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
            end
        end)
    end

    local function resolve(layerId)
        local realm = RealmTheme.realmOf(layerId)
        local deep = realm and themes[realm]
        if not deep then
            return baseTheme -- base / neutral / unknown
        end
        local t = RealmTheme.progress(layerId, maxDepth)
        return RealmTheme.interpolate(baseTheme, deep, t)
    end

    local function refresh(announce)
        local layerId = player:GetAttribute("CurrentLayer") or "base"
        applyTheme(resolve(layerId))
        applySky(layerId)
        if announce then
            banner(RealmTheme.realmOf(layerId), RealmTheme.depthOf(layerId))
        end
    end

    refresh(false) -- silent on join
    player:GetAttributeChangedSignal("CurrentLayer"):Connect(function()
        refresh(true)
    end)
end

return RealmAtmosphere
