--[[
    MissionAtmosphere — realm-split mission lighting (client-side).

    The Lighting service is GLOBAL, so mission mood must be per-client (same
    pattern as RealmAtmosphere's realm skin): keyed off the server-published
    InMission + MissionTheme player attributes. On entry we capture the
    current Lighting state and tween to the theme preset; on exit we tween
    back and remove our ColorCorrection. Presets:
      hell   — near-black ambient, ember cast, short fog (DOORS pole:
               darkness hides tiling, torches carry the mood)
      heaven — bright, warm-white, airy (Dungeon Quest pole)
      earth  — mild neutral dungeon dim
    Also runs the torch FLICKER loop (jittering each TorchFlame's PointLight
    locally — flicker is cosmetic, so no replication traffic).

    NOTE: assumes realm doesn't change mid-mission (you enter from a door and
    leave through it), so RealmAtmosphere won't fight the capture/restore.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local TWEEN = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local PRESETS = {
    hell = {
        -- v2 (2026-07-08 playtest: "it is also just dark"): keep the torch-lit
        -- DOORS mood but lift the readability floor — you should always be able
        -- to READ the room; torches carry the drama. The real darkness answer
        -- is the planned light-support pet, not brighter caves.
        lighting = {
            Brightness = 1.1,
            Ambient = Color3.fromRGB(48, 30, 32),
            OutdoorAmbient = Color3.fromRGB(88, 52, 48),
            FogColor = Color3.fromRGB(26, 13, 12),
            FogEnd = 480,
        },
        cc = { Saturation = -0.2, Contrast = 0.08, TintColor = Color3.fromRGB(255, 224, 210) },
    },
    heaven = {
        -- v2 (2026-07-08 playtest: v1 was a whiteout — "too bright to even
        -- see"): bright needs CONTRAST, not exposure. Moderate ambient +
        -- slightly toned surfaces (palette) so edges/shadows still exist.
        lighting = {
            Brightness = 1.6,
            Ambient = Color3.fromRGB(105, 103, 96),
            OutdoorAmbient = Color3.fromRGB(196, 192, 180),
            FogColor = Color3.fromRGB(235, 230, 220),
            FogEnd = 1400,
        },
        cc = { Saturation = 0.05, Contrast = 0.05, TintColor = Color3.fromRGB(255, 250, 240) },
    },
    earth = {
        lighting = {
            Brightness = 1.4,
            Ambient = Color3.fromRGB(70, 68, 72),
            OutdoorAmbient = Color3.fromRGB(120, 116, 122),
            FogColor = Color3.fromRGB(30, 28, 34),
            FogEnd = 700,
        },
        cc = { Saturation = -0.08, Contrast = 0.05, TintColor = Color3.fromRGB(255, 245, 235) },
    },
}

local CAPTURE_PROPS = { "Brightness", "Ambient", "OutdoorAmbient", "FogColor", "FogEnd" }

local MissionAtmosphere = {}

function MissionAtmosphere.start()
    local player = Players.LocalPlayer
    local captured = nil
    local cc = nil

    local function apply()
        local theme = player:GetAttribute("MissionTheme") or "earth"
        local preset = PRESETS[theme] or PRESETS.earth
        if not captured then
            captured = {}
            for _, prop in ipairs(CAPTURE_PROPS) do
                captured[prop] = Lighting[prop]
            end
        end
        TweenService:Create(Lighting, TWEEN, preset.lighting):Play()
        if not cc then
            cc = Instance.new("ColorCorrectionEffect")
            cc.Name = "MissionColorCorrection"
            cc.Parent = Lighting
        end
        TweenService:Create(cc, TWEEN, preset.cc):Play()
    end

    local function restore()
        if captured then
            TweenService:Create(Lighting, TWEEN, captured):Play()
            captured = nil
        end
        if cc then
            local dying = cc
            cc = nil
            TweenService:Create(dying, TWEEN, { Saturation = 0, Contrast = 0, Brightness = 0 })
                :Play()
            task.delay(TWEEN.Time + 0.1, function()
                dying:Destroy()
            end)
        end
    end

    local function refresh()
        if player:GetAttribute("InMission") then
            apply()
        else
            restore()
        end
    end
    player:GetAttributeChangedSignal("InMission"):Connect(refresh)
    player:GetAttributeChangedSignal("MissionTheme"):Connect(refresh)
    refresh()

    -- torch flicker: local-only jitter over the instance's TorchFlame lights
    task.spawn(function()
        local flames = {}
        local lastScan = 0
        while true do
            local instanceId = player:GetAttribute("InMission")
            if instanceId then
                local now = os.clock()
                if now - lastScan > 5 then
                    lastScan = now
                    flames = {}
                    local folder = workspace:FindFirstChild("MissionInstances")
                    local container = folder
                        and folder:FindFirstChild("MissionInstance_" .. instanceId)
                    if container then
                        for _, desc in ipairs(container:GetDescendants()) do
                            if desc.Name:sub(1, 11) == "TorchFlame_" then
                                local light = desc:FindFirstChildOfClass("PointLight")
                                if light then
                                    table.insert(flames, {
                                        light = light,
                                        base = light.Brightness,
                                        range = light.Range,
                                        phase = math.random() * 100,
                                    })
                                end
                            end
                        end
                    end
                end
                local t = os.clock() * 6
                for _, flame in ipairs(flames) do
                    if flame.light.Parent then
                        local jitter = math.noise(t, flame.phase) * 0.35
                        flame.light.Brightness = flame.base * (1 + jitter)
                        flame.light.Range = flame.range * (1 + jitter * 0.4)
                    end
                end
                task.wait(0.09)
            else
                if #flames > 0 then
                    flames = {}
                end
                task.wait(1)
            end
        end
    end)
end

return MissionAtmosphere
