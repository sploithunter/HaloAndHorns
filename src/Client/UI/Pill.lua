--[[
    Pill — the ONE capsule widget: a fully-rounded frame/button with the standard treatment
    (pill corner + vertical gradient + stroke), and for buttons a CHILD white label (a gradient
    tints the button's own text, so the label rides in a child where the gradient can't reach it —
    that's how the capsules read pure white over a coloured fill).

        local btn, label = Pill.button({ parent = gui, color = Color3.fromRGB(90,55,160),
            size = UDim2.fromOffset(118, 30), text = "🛠 ADMIN: OFF" })
        local cap = Pill.frame({ parent = row, color = Color3.fromRGB(40,40,48), size = ... })

    color = the base/fill (and gradient bottom). gradientTop / strokeColor default to lightened
    shades of color; pass them to match an exact existing look. cornerRadius defaults to a full pill.
]]

local Pill = {}

local function lighten(c, amt)
    amt = (amt or 50) / 255
    return Color3.new(
        math.clamp(c.R + amt, 0, 1),
        math.clamp(c.G + amt, 0, 1),
        math.clamp(c.B + amt, 0, 1)
    )
end

-- Apply the shared capsule treatment (corner + gradient + stroke) to an instance.
local function style(obj, opts)
    local color = opts.color or Color3.fromRGB(60, 60, 70)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = opts.cornerRadius or UDim.new(1, 0)
    corner.Parent = obj

    if opts.gradient ~= false then
        local grad = Instance.new("UIGradient")
        grad.Rotation = opts.gradientRotation or 90
        grad.Color = ColorSequence.new(opts.gradientTop or lighten(color, 60), color)
        grad.Parent = obj
    end

    if opts.stroke ~= false then
        local stroke = Instance.new("UIStroke")
        stroke.Color = opts.strokeColor or lighten(color, 80)
        stroke.Thickness = opts.strokeThickness or 2
        stroke.Transparency = opts.strokeTransparency or 0
        stroke.Parent = obj
    end
end

local function baseProps(obj, opts)
    obj.Name = opts.name or "Pill"
    if opts.size then
        obj.Size = opts.size
    end
    if opts.position then
        obj.Position = opts.position
    end
    if opts.anchorPoint then
        obj.AnchorPoint = opts.anchorPoint
    end
    obj.BackgroundColor3 = opts.color or Color3.fromRGB(60, 60, 70)
    obj.BackgroundTransparency = opts.bgTransparency or 0
    obj.BorderSizePixel = 0
    if opts.zIndex then
        obj.ZIndex = opts.zIndex
    end
    if opts.visible ~= nil then
        obj.Visible = opts.visible
    end
end

-- Apply the capsule treatment (pill corner + gradient + stroke) to an EXISTING instance — for
-- surfaces that already have the frame and just want to make it a standard capsule.
function Pill.applyTo(obj, opts)
    style(obj, opts or {})
    return obj
end

-- A non-interactive capsule (Frame). Returns the Frame.
function Pill.frame(opts)
    opts = opts or {}
    local f = Instance.new("Frame")
    baseProps(f, opts)
    style(f, opts)
    f.Parent = opts.parent
    return f
end

-- An interactive capsule (TextButton) with a child white label. Returns (button, label).
function Pill.button(opts)
    opts = opts or {}
    local btn = Instance.new("TextButton")
    baseProps(btn, opts)
    btn.AutoButtonColor = opts.autoButtonColor ~= false
    btn.Text = "" -- text lives in the child label (gradient must not tint it)
    style(btn, opts)
    btn.Parent = opts.parent

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = opts.font or Enum.Font.GothamBold
    label.TextSize = opts.textSize or 13
    label.TextColor3 = opts.textColor or Color3.fromRGB(255, 255, 255)
    label.Text = opts.text or ""
    label.ZIndex = (btn.ZIndex or 1) + 1
    label.Parent = btn

    return btn, label
end

return Pill
