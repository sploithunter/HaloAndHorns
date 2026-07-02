--[[
    CloseButton — THE standard panel close button (Jason: "this exit button doesn't
    match what we have in the other parts of the menu... let's just reuse it
    everywhere"). One look, sourced from configs/ui.lua defaults.panel.header
    .close_button: the red rounded square with the X IMAGE asset.

    Why an image and not text: several panels used `Text = "✕"` (U+2715) — Gotham has
    no glyph for it, so it rendered as the tofu/"weird page" box. Never use glyph
    text for the X; always this component.

        local CloseButton = require(script.Parent.Parent.Components.CloseButton)
        CloseButton.attach(header, {
            onClick = function() self:Hide() end,
            size = UDim2.new(0, 52, 0, 52),       -- optional; defaults to config size
            position = UDim2.new(1, -64, 0, 12),  -- optional; defaults to config corner
            anchor = Vector2.new(0, 0),           -- optional; defaults (1, 0) top-right
            zindex = 102,                          -- optional
        }) -> ImageButton
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Fallbacks mirror configs/ui.lua defaults.panel.header.close_button exactly, so the
-- button looks right even if the config is unreachable (template resilience).
local FALLBACK = {
    icon = "89257673063270",
    size = { width = 30, height = 30 },
    offset = { x = 10, y = -10 },
    background_color = Color3.fromRGB(220, 60, 60),
    hover_color = Color3.fromRGB(180, 40, 40),
    corner_radius = 8,
}

local _cfg
local function config()
    if _cfg == nil then
        local ok, ui = pcall(function()
            return require(ReplicatedStorage.Configs:WaitForChild("ui"))
        end)
        local c = ok
            and ui
            and ui.defaults
            and ui.defaults.panel
            and ui.defaults.panel.header
            and ui.defaults.panel.header.close_button
        _cfg = c or false
    end
    return _cfg or FALLBACK
end

local CloseButton = {}

function CloseButton.attach(parent, opts)
    opts = opts or {}
    local c = config()

    local button = Instance.new("ImageButton")
    button.Name = "CloseButton"
    button.Size = opts.size
        or UDim2.new(0, (c.size and c.size.width) or 30, 0, (c.size and c.size.height) or 30)
    button.AnchorPoint = opts.anchor or Vector2.new(1, 0)
    button.Position = opts.position
        or UDim2.new(1, (c.offset and c.offset.x) or 10, 0, (c.offset and c.offset.y) or -10)
    button.BackgroundColor3 = c.background_color or FALLBACK.background_color
    button.BorderSizePixel = 0
    button.Image = "rbxassetid://" .. tostring(c.icon or FALLBACK.icon)
    button.ScaleType = Enum.ScaleType.Fit
    button.ZIndex = opts.zindex or 100
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, c.corner_radius or FALLBACK.corner_radius)
    corner.Parent = button

    local base = c.background_color or FALLBACK.background_color
    local hover = c.hover_color or FALLBACK.hover_color
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = hover
    end)
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = base
    end)

    if opts.onClick then
        button.Activated:Connect(opts.onClick)
    end
    return button
end

return CloseButton
