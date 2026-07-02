--[[
    UITheme (client) — resolve the local player's HOME AREA to Color3 palette for HUD widgets.

    Thin wrapper over the pure UIPalette + configs/ui_theme: reads HomeArea (falls back to CurrentArea),
    returns Color3-wrapped colors, and lets a widget subscribe to re-tint when the area changes (admin
    area toggle / the level-5 home-area choice).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIPalette = require(ReplicatedStorage.Shared.Game.UIPalette)
local themeConfig = require(ReplicatedStorage.Configs:WaitForChild("ui_theme"))

local UITheme = {}

local function c3(t)
    return t and Color3.fromRGB(t[1], t[2], t[3]) or Color3.fromRGB(255, 255, 255)
end

function UITheme.palette(player)
    player = player or Players.LocalPlayer
    local area = player:GetAttribute("HomeArea") or player:GetAttribute("CurrentArea")
    local p = UIPalette.resolve(area, themeConfig)
    return {
        color = p.color,
        primary = c3(p.primary),
        fill = c3(p.fill),
        text = c3(p.text),
        dim = c3(p.dim),
        metrics = p.metrics or {},
    }
end

-- Call fn(palette) now and whenever the area changes. Returns the bound function.
function UITheme.bind(player, fn)
    player = player or Players.LocalPlayer
    local function go()
        fn(UITheme.palette(player))
    end
    player:GetAttributeChangedSignal("HomeArea"):Connect(go)
    player:GetAttributeChangedSignal("CurrentArea"):Connect(go)
    go()
    return go
end

return UITheme
