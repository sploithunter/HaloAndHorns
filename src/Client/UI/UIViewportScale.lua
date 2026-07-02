--[[
    UIViewportScale — one fix for the "pixel-designed HUD explodes on small screens" problem.

    The HUD is designed in PIXELS against a desktop canvas (panes, hotbar, player bar, squad
    strip). On a small viewport (mobile, small Studio window) those pixels don't shrink, so
    everything collides. Standard remedy: attach a UIScale to each HUD ROOT that tracks
    viewport ÷ design-baseline, clamped so desktop renders exactly as designed (scale 1) and
    small screens shrink proportionally. Roots keep their corner AnchorPoints, so scaling pins
    them in place.

        local UIViewportScale = require(...UI.UIViewportScale)
        UIViewportScale.attach(rootFrame)            -- defaults: 1280x720 baseline, [0.45, 1]
        UIViewportScale.attach(rootFrame, { min = 0.6 })

    One camera listener total (all attached scales update together).
]]

local Workspace = game:GetService("Workspace")

local UIViewportScale = {}

local BASE_X, BASE_Y = 1280, 720 -- design canvas: the HUD reads correctly at/above this
local DEFAULT_MIN, DEFAULT_MAX = 0.45, 1

local attached = {} -- { { scale = UIScale, min, max } } (weak via instance lifetime)

local function factorFor(entry)
    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(BASE_X, BASE_Y)
    local f = math.min(vp.X / BASE_X, vp.Y / BASE_Y)
    return math.clamp(f, entry.min, entry.max)
end

local function refreshAll()
    for i = #attached, 1, -1 do
        local entry = attached[i]
        if entry.scale.Parent then
            entry.scale.Scale = factorFor(entry)
        else
            table.remove(attached, i)
        end
    end
end

local listening = false
local function ensureListener()
    if listening then
        return
    end
    listening = true
    local function hook(cam)
        if cam then
            cam:GetPropertyChangedSignal("ViewportSize"):Connect(refreshAll)
        end
    end
    hook(Workspace.CurrentCamera)
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        hook(Workspace.CurrentCamera)
        refreshAll()
    end)
end

-- Attach (or reuse) a viewport-tracking UIScale on `guiObject`. opts = { min?, max? }.
function UIViewportScale.attach(guiObject, opts)
    opts = opts or {}
    local existing = guiObject:FindFirstChild("ViewportScale")
    local scale = existing or Instance.new("UIScale")
    scale.Name = "ViewportScale"
    scale.Parent = guiObject
    local entry = {
        scale = scale,
        min = tonumber(opts.min) or DEFAULT_MIN,
        max = tonumber(opts.max) or DEFAULT_MAX,
    }
    attached[#attached + 1] = entry
    scale.Scale = factorFor(entry)
    ensureListener()
    return scale
end

return UIViewportScale
