--[[
    CurrencyStyle (client) — skin the left-side currency boxes (gems + per-area coins) as ROUND
    capsules ("pills") in each currency's area color, and show the actual GEM icon (tinted per area)
    instead of an emoji.

    Capsule: UICorner(1,0) on the pane + glossy gradient + brighter stroke border (a full-circle ring
    asset just turns into an ellipse stretched this thin, so the round ends are shaped programmatically).

    Icon: the gem-diamond image (the same asset BaseUI already uses on the gems box) tinted to the area
    color, with a dark shadow copy behind so it pops on the colored capsule. The box's original emoji/
    image icon is hidden (kept as a fallback) — currencies with no gem color keep their emoji.

    Scoped post-process of ProfessionalBaseUI's *_pane currency frames (BaseUI logic untouched).
    Idempotent per box.
]]

local Players = game:GetService("Players")
local Pill = require(script.Parent.Parent.UI.Pill)

local CurrencyStyle = {}
local started = false

local GEM_IMAGE = "rbxassetid://136309678310342" -- generic diamond (tint fallback)

-- REAL gem renders (Jason: "why aren't we using our actual assets?") — purpose-made flat
-- UI gem singles (assets/ui/gems_*/gem_single.png, uploaded 2026-06-10; ids in
-- scripts/gem_ui_ids.*.json) via rbxthumb, which renders a Decal's image with no
-- Edit-mode Decal->Image resolution. All five colors, including the purple the 3D-gem
-- set lacked.
local function thumb(decalId)
    return "rbxthumb://type=Asset&id=" .. decalId .. "&w=150&h=150"
end
local REAL_GEMS = {
    amethyst = thumb("102357151476128"), -- gems_purple/gem_single
    emerald = thumb("80734166119788"), -- gems_green/gem_single
    citrine = thumb("134037429410412"), -- gems_yellow/gem_single
    ruby = thumb("121052659627160"), -- gems_red/gem_single
    sapphire = thumb("88757009582701"), -- gems_blue/gem_single
}

-- area key -> capsule fill + lighter top/stroke + bright gem tint
local COLORS = {
    amethyst = {
        fill = Color3.fromRGB(120, 60, 200),
        light = Color3.fromRGB(180, 110, 235),
        gem = Color3.fromRGB(205, 150, 255),
    },
    emerald = {
        fill = Color3.fromRGB(40, 155, 75),
        light = Color3.fromRGB(95, 220, 125),
        gem = Color3.fromRGB(150, 255, 175),
    },
    citrine = {
        fill = Color3.fromRGB(200, 150, 35),
        light = Color3.fromRGB(240, 200, 70),
        gem = Color3.fromRGB(255, 230, 130),
    },
    ruby = {
        fill = Color3.fromRGB(185, 45, 45),
        light = Color3.fromRGB(235, 90, 90),
        gem = Color3.fromRGB(255, 150, 150),
    },
    sapphire = {
        fill = Color3.fromRGB(40, 110, 210),
        light = Color3.fromRGB(95, 165, 240),
        gem = Color3.fromRGB(155, 205, 255),
    },
}

local BOXES = {
    gems_pane = "amethyst",
    grass_coins_pane = "emerald",
    desert_coins_pane = "citrine",
    lava_coins_pane = "ruby",
    ice_coins_pane = "sapphire",
}

-- Match the original gems-box icon: 32x32 offset to OVERHANG the left edge of the pill (emblem style).
local ICON_SIZE = UDim2.fromOffset(32, 32)
local ICON_POS = UDim2.new(0, -10, 0.5, 0)

local function addGemIcon(pane, col, key)
    -- find the existing icon (emoji TextLabel or the gems image) and its holder frame
    local icon
    for _, d in ipairs(pane:GetDescendants()) do
        if d.Name == "Icon" then
            icon = d
            break
        end
    end
    if not icon then
        return
    end
    local holder = icon.Parent
    if holder:FindFirstChild("GemIcon") then
        return
    end
    icon.Visible = false -- keep the emoji/original as a fallback

    local shadow = Instance.new("ImageLabel")
    shadow.Name = "GemShadow"
    shadow.BackgroundTransparency = 1
    shadow.Image = GEM_IMAGE
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.5
    shadow.Size = ICON_SIZE
    shadow.AnchorPoint = Vector2.new(0, 0.5)
    shadow.Position =
        UDim2.new(ICON_POS.X.Scale, ICON_POS.X.Offset + 1, ICON_POS.Y.Scale, ICON_POS.Y.Offset + 1)
    shadow.ZIndex = icon.ZIndex + 4
    shadow.Parent = holder

    local real = REAL_GEMS[key]
    local gem = Instance.new("ImageLabel")
    gem.Name = "GemIcon"
    gem.BackgroundTransparency = 1
    gem.Image = real or GEM_IMAGE
    gem.ImageColor3 = real and Color3.new(1, 1, 1) or col.gem -- real renders carry their color
    gem.Size = ICON_SIZE
    gem.AnchorPoint = Vector2.new(0, 0.5)
    gem.Position = ICON_POS
    gem.ZIndex = icon.ZIndex + 5
    gem.Parent = holder
    if real then
        shadow.Image = real
    end
end

local function styleBox(pane, key)
    if pane:GetAttribute("Capsuled") then
        return
    end
    pane:SetAttribute("Capsuled", true)
    local col = COLORS[key]

    -- drop the old square border / any earlier squircle overlay, and any heavy text outlines added before
    for _, c in ipairs(pane:GetChildren()) do
        if
            c:IsA("UIStroke")
            or c:IsA("UICorner")
            or c:IsA("UIGradient")
            or c.Name == "PillPanel"
            or c.Name == "PillFrame"
        then
            c:Destroy()
        end
    end
    for _, d in ipairs(pane:GetDescendants()) do
        if d:IsA("UIStroke") and d.Parent and d.Parent:IsA("TextLabel") then
            d:Destroy()
        end
    end

    -- the pane itself becomes the round capsule
    pane.BackgroundColor3 = col.fill
    pane.BackgroundTransparency = 0
    -- shared capsule treatment (pill corner + glossy gradient + brighter stroke)
    Pill.applyTo(pane, {
        color = col.fill,
        gradientTop = col.light,
        strokeColor = col.light,
        strokeThickness = 2.5,
    })

    addGemIcon(pane, col, key)
end

function CurrencyStyle.start()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local pg = player:WaitForChild("PlayerGui")

    task.spawn(function()
        -- No give-up timeout (see MenuTrayStyle): a non-owner's late/stalled BaseUI boot used to
        -- outlast the old 20s window, leaving currencies in the raw unstyled state.
        local base = pg:WaitForChild("ProfessionalBaseUI")
        local mc = base and base:WaitForChild("MainContainer", 10)
        if not mc then
            return
        end
        for _ = 1, 12 do
            for name, key in pairs(BOXES) do
                local pane = mc:FindFirstChild(name, true) -- recursive: panes live in CurrencyStack
                if pane then
                    styleBox(pane, key)
                end
            end
            task.wait(0.5)
        end
    end)
end

return CurrencyStyle
