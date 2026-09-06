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
local RunService = game:GetService("RunService")

local RealmTheme = require(ReplicatedStorage.Shared.Game.RealmTheme)
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local MergeAtmosphereZones = require(ReplicatedStorage.Shared.Game.MergeAtmosphereZones)

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
    local merge
    if PlaceRuntime.isMerge(game.PlaceId, require(ReplicatedStorage.Configs.places)) then
        local configured = require(ReplicatedStorage.Configs.merge_egg_prototype).atmosphere
        merge = configured.enabled and configured or nil
    end
    if merge then
        -- Retire the old Studio-authored two-side controller on older published place copies too.
        local scripts = player:WaitForChild("PlayerScripts")
        local function retireLegacy(child)
            if child.Name == merge.legacy_script_name and child:IsA("LocalScript") then
                child.Enabled = false
            end
        end
        for _, child in ipairs(scripts:GetChildren()) do
            retireLegacy(child)
        end
        scripts.ChildAdded:Connect(retireLegacy)
        local legacyTint = Lighting:FindFirstChild(merge.legacy_tint_name)
        if legacyTint then
            legacyTint:Destroy()
        end
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
    -- Streaming can leave the stacked world with no geometry behind the current layer. Roblox
    -- hides legacy FogStart/FogEnd whenever an Atmosphere exists, so establish the shared
    -- distance-obscuring envelope on the authored base before blending toward each realm's deep
    -- endpoint. Colors, clock, ambient light, and the increasing per-level intensity remain
    -- distinct; only the minimum aerial perspective is shared.
    local distanceHaze = themes.distance_haze
    baseTheme = RealmTheme.withDistanceHaze(baseTheme, distanceHaze)

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
        local tx = merge and layerId == merge.layers.mall and merge.mall_sky or cfg and cfg.textures
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
        return RealmTheme.interpolate(baseTheme, RealmTheme.withDistanceHaze(deep, distanceHaze), t)
    end

    local function refresh(announce, spatialLayer)
        local layerId = spatialLayer or player:GetAttribute("CurrentLayer") or "base"
        applyTheme(resolve(layerId))
        applySky(layerId)
        if announce then
            banner(RealmTheme.realmOf(layerId), RealmTheme.depthOf(layerId))
        end
    end

    if merge then
        local currentZone
        local elapsed = 0
        local function update()
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if not root then
                return
            end
            local zone = MergeAtmosphereZones.resolve(merge, root.Position[merge.axis], currentZone)
            if zone ~= currentZone then
                currentZone = zone
                refresh(false, merge.layers[zone])
                -- Local diagnostic only; never changes CurrentLayer or bay ownership.
                player:SetAttribute("MergeAtmosphereZone", zone)
            end
        end
        refresh(false, merge.layers.mall)
        update()
        player.CharacterAdded:Connect(function()
            currentZone = nil
        end)
        RunService.Heartbeat:Connect(function(dt)
            elapsed += dt
            if elapsed >= merge.poll_seconds then
                elapsed = 0
                update()
            end
        end)
    else
        refresh(false) -- silent on join
        player:GetAttributeChangedSignal("CurrentLayer"):Connect(function()
            refresh(true)
        end)
    end
end

return RealmAtmosphere
