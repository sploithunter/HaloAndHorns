--[[
    FillBar — the ONE on-screen fill bar widget (quest progress, effect duration, XP, sliders, shield).
    The on-screen analogue of OverheadBar (which owns the over-the-head world bars). A backing Frame
    with a fraction-filled foreground Frame; every surface fills in colors/size/corner and calls
    `set` — never hand-rolls another BG+fill+UICorner pair.

        local bar = FillBar.create({ parent = row, size = UDim2.new(1, 0, 0, 6),
            fillColor = Color3.fromRGB(80, 200, 120), fraction = 0.4 })
        FillBar.set(bar, 0.75)               -- update the fill (0..1)
        FillBar.set(bar, 0.2, Color3.new(1,0,0))  -- update + recolour

    Structure is fixed so any updater can find the fill: <root>.Fill.
]]

local FillBar = {}

local DEFAULT_BG = Color3.fromRGB(35, 35, 40)
local DEFAULT_FILL = Color3.fromRGB(90, 200, 130)

-- Build the bar under opts.parent and return the backing Frame (with a "Fill" child).
-- opts: parent, size, position, anchorPoint, cornerRadius (default pill), bgColor, bgTransparency,
--       fillColor, fillGradient (ColorSequence, optional glossy), fraction (0..1), zIndex.
function FillBar.create(opts)
    opts = opts or {}
    local corner = opts.cornerRadius or UDim.new(1, 0)

    local bg = Instance.new("Frame")
    bg.Name = opts.name or "FillBar"
    bg.Size = opts.size or UDim2.new(1, 0, 0, 6)
    if opts.position then
        bg.Position = opts.position
    end
    if opts.anchorPoint then
        bg.AnchorPoint = opts.anchorPoint
    end
    bg.BackgroundColor3 = opts.bgColor or DEFAULT_BG
    bg.BackgroundTransparency = opts.bgTransparency or 0
    bg.BorderSizePixel = 0
    if opts.zIndex then
        bg.ZIndex = opts.zIndex
    end
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = corner
    bgCorner.Parent = bg

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(math.clamp(opts.fraction or 0, 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = opts.fillColor or DEFAULT_FILL
    fill.BorderSizePixel = 0
    if opts.zIndex then
        fill.ZIndex = opts.zIndex + 1
    end
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = corner
    fillCorner.Parent = fill
    if opts.fillGradient then
        local grad = Instance.new("UIGradient")
        grad.Color = opts.fillGradient
        grad.Rotation = opts.fillGradientRotation or 90
        grad.Parent = fill
    end
    fill.Parent = bg

    bg.Parent = opts.parent
    return bg
end

-- The fill Frame for a bar root (or nil).
function FillBar.fillOf(root)
    return root and root:FindFirstChild("Fill")
end

-- Set the fill to a 0..1 fraction; optional colour override.
function FillBar.set(root, frac, color)
    local fill = FillBar.fillOf(root)
    if not fill then
        return
    end
    fill.Size = UDim2.new(math.clamp(frac or 0, 0, 1), 0, 1, 0)
    if color then
        fill.BackgroundColor3 = color
    end
end

return FillBar
