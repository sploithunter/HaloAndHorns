--[[
    PowerSlotRow — a CoH-style "power + enhancement slots" row. RELATIVE-FIRST (resize-safe).

        PowerSlotRow.create(parent, {
            powerId   = "fortune",          -- disc badge via PetBadge.forPower
            name      = "Luck",             -- power name (TextScaled)
            subtitle  = "Targeted DoT",     -- optional short tag (hidden if nil)
            slotCount = 3,                  -- enhancement slots GRANTED (1..6); the rest stay hidden
            selected  = nil,                -- optional highlighted slot index
            size      = UDim2.fromScale(0.96, 0.17),  -- the row's size (caller's call; scale or offset)
            theme     = PowerSlotRow.THEMES.blue,
        })

    Every internal size/position is a SCALE fraction of the row, the circular disc + slots use
    UIAspectRatioConstraint (square, sized by the row's HEIGHT — full-width box so height binds), the
    name is TextScaled, and corners are full pills — so the row keeps its proportions at any
    resolution. Built and tuned live over assets/ui/reference/power_slotting_menu_reference.png.

    The bar is the top BAR_H of the row; the disc overlaps its left; the six slots are a FIXED grid
    (FIRST_X..LAST_X) hanging below the bar — tick i lines up row-to-row, only the first `slotCount`
    are visible (slotting one later just flips Visible; positions never re-flow).
]]

local PetBadge = require(script.Parent.PetBadge)

local RING_IMAGE = "rbxassetid://132051312589044" -- round ring frame (slot rim)
local PowerSlotRow = {}

-- fixed 6-slot grid (scale X across the bar) + relative layout fractions (of the row)
local FIRST_X, LAST_X = 0.16, 0.93
local MAX_SLOTS = 6
local BAR_H = 0.6 -- bar height (of row)
local DISC_H = 1.12 -- disc height (× bar height, via aspect); sticks out top/bottom a touch
local DISC_X = -0.005 -- disc horizontal nudge (tuned live)
local SLOT_H = 0.68 -- slot diameter (× row height, via aspect)
local SLOT_Y = 0.66 -- slot-row centre (of row); hangs below the bar

PowerSlotRow.THEMES = {
    blue = {
        bar = Color3.fromRGB(40, 120, 230),
        barGrad = {
            Color3.fromRGB(95, 175, 255),
            Color3.fromRGB(40, 120, 230),
            Color3.fromRGB(20, 80, 190),
        },
        barStroke = Color3.fromRGB(15, 55, 130),
        slotGrad = {
            Color3.fromRGB(140, 187, 244),
            Color3.fromRGB(46, 132, 236),
            Color3.fromRGB(29, 85, 153),
        },
        slotRim = Color3.fromRGB(18, 70, 160),
        slotRimSelected = Color3.fromRGB(120, 205, 255),
        -- power states: dull = pickable-not-picked (lights to full on hover), locked = not yet available
        barGradDull = {
            Color3.fromRGB(96, 120, 150),
            Color3.fromRGB(64, 84, 112),
            Color3.fromRGB(46, 62, 88),
        },
        barStrokeDull = Color3.fromRGB(38, 52, 78),
        barGradLocked = {
            Color3.fromRGB(150, 150, 156),
            Color3.fromRGB(112, 112, 120),
            Color3.fromRGB(82, 82, 90),
        },
        barStrokeLocked = Color3.fromRGB(70, 70, 80),
        nameLocked = Color3.fromRGB(196, 196, 202),
        discLocked = Color3.fromRGB(130, 130, 136),
    },
}

local function corner(o)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = o
end

-- make o a square sized by HEIGHT: pair with a full-width Size box so the height is the binding axis.
local function square(o)
    local a = Instance.new("UIAspectRatioConstraint")
    a.AspectRatio = 1
    a.Parent = o
    return o
end

local function seqOf(colors)
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, colors[1]),
        ColorSequenceKeypoint.new(0.5, colors[2]),
        ColorSequenceKeypoint.new(1, colors[3]),
    })
end

local function vGradient(o, colors)
    local g = Instance.new("UIGradient")
    g.Rotation = 90
    g.Color = seqOf(colors)
    g.Parent = o
    return g
end

-- one slot: a gradient Fill circle framed by a Border ring (square via aspect; size/pos set by caller).
local function buildSlot(theme, selected)
    local s = Instance.new("Frame")
    s.BackgroundTransparency = 1
    square(s)
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.fromScale(0.82, 0.82)
    fill.Position = UDim2.fromScale(0.5, 0.5)
    fill.AnchorPoint = Vector2.new(0.5, 0.5)
    fill.BackgroundColor3 = theme.slotGrad[2]
    fill.Parent = s
    corner(fill)
    vGradient(fill, theme.slotGrad)
    local border = Instance.new("ImageLabel")
    border.Name = "Border"
    border.BackgroundTransparency = 1
    border.Size = UDim2.fromScale(1, 1)
    border.Image = RING_IMAGE
    border.ImageColor3 = selected and theme.slotRimSelected or theme.slotRim
    border.ZIndex = 2
    border.Parent = s
    return s
end

-- the power disc — canonical PetBadge.create inside a square holder so it stays round + consistent.
local function buildDisc(bar, powerId)
    local discH = Instance.new("Frame")
    discH.Name = "Disc"
    discH.Size = UDim2.new(1, 0, DISC_H, 0)
    discH.AnchorPoint = Vector2.new(0, 0.5)
    discH.Position = UDim2.new(DISC_X, 0, 0.5, 0)
    discH.BackgroundTransparency = 1
    discH.ZIndex = 3
    discH.Parent = bar
    square(discH)
    local badge = PetBadge.forPower(powerId)
    local pb
    if badge then
        pb = PetBadge.create(
            discH,
            { element = badge.element, symbol = badge.symbol, ring = badge.ring }
        )
    end
    return discH, pb
end

function PowerSlotRow.create(parent, opts)
    opts = opts or {}
    local theme = opts.theme or PowerSlotRow.THEMES.blue
    local slotCount = math.clamp(tonumber(opts.slotCount) or 6, 1, MAX_SLOTS)
    local state = opts.state or "owned" -- "owned" | "available" | "locked"
    local effSlots = (state == "owned") and slotCount or 0 -- unpicked powers carry no visible slots
    local barGrad3 = (state == "locked" and theme.barGradLocked)
        or (state == "available" and theme.barGradDull)
        or theme.barGrad
    local barStrokeC = (state == "locked" and theme.barStrokeLocked)
        or (state == "available" and theme.barStrokeDull)
        or theme.barStroke

    local root = Instance.new("Frame")
    root.Name = "PowerRow"
    root.Size = opts.size or UDim2.fromOffset(540, 96)
    root.BackgroundTransparency = 1
    root.Parent = parent

    -- bar: round glossy capsule across the top of the row
    local bar = Instance.new("Frame")
    bar.Name = "Bar"
    bar.Size = UDim2.new(1, 0, BAR_H, 0)
    bar.BackgroundColor3 = barGrad3[2]
    bar.Parent = root
    corner(bar)
    local barGradient = vGradient(bar, barGrad3)
    local bs = Instance.new("UIStroke")
    bs.Color = barStrokeC
    bs.Thickness = 2
    bs.Parent = bar

    -- "available" powers light up to full colour on hover (the pick affordance)
    if state == "available" then
        bar.MouseEnter:Connect(function()
            barGradient.Color = seqOf(theme.barGrad)
            bs.Color = theme.barStroke
            bar.BackgroundColor3 = theme.barGrad[2]
        end)
        bar.MouseLeave:Connect(function()
            barGradient.Color = seqOf(barGrad3)
            bs.Color = barStrokeC
            bar.BackgroundColor3 = barGrad3[2]
        end)
    end

    local _, pb = buildDisc(bar, opts.powerId)
    if state == "locked" and pb then -- gray the badge out too
        if pb.disc then
            pb.disc.ImageColor3 = theme.discLocked
        end
        if pb.ring then
            pb.ring.ImageColor3 = theme.discLocked
        end
    end

    -- TWO-LINE text block, PIXEL-anchored just right of the disc (Jason, phone
    -- playtest: names clipped behind the disc and the right-aligned type chip
    -- crushed into them — "we need to be able to read the name of the power and
    -- what it does"). Line 1 = name, line 2 = level + type, both left-anchored at
    -- discRight (the disc is a square of the bar height, so its width in px is
    -- known from rowPx). opts.rowPx = the row's pixel height (callers that size
    -- rows in pixels pass it; default matches the legacy 96px row).
    local rowPx = tonumber(opts.rowPx) or 96
    local discRight = math.floor(rowPx * BAR_H * DISC_H) + 6

    local name = Instance.new("TextLabel")
    name.Name = "PowerName"
    name.BackgroundTransparency = 1
    name.Size = UDim2.new(1, -(discRight + 10), 0.52, 0)
    name.Position = UDim2.new(0, discRight, 0.04, 0)
    name.Text = opts.name or ""
    name.Font = Enum.Font.GothamBold
    name.TextScaled = true
    name.TextColor3 = (state == "locked") and theme.nameLocked or Color3.fromRGB(255, 255, 255)
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.ZIndex = 2
    name.Parent = bar

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.BackgroundTransparency = 1
    subtitle.Size = UDim2.new(1, -(discRight + 10), 0.38, 0)
    subtitle.Position = UDim2.new(0, discRight, 0.56, 0)
    subtitle.Text = opts.subtitle or ""
    subtitle.Font = Enum.Font.GothamMedium
    subtitle.TextScaled = true
    subtitle.TextColor3 = Color3.fromRGB(214, 226, 245)
    subtitle.TextTransparency = 0.08
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Visible = (opts.subtitle ~= nil and opts.subtitle ~= "")
    subtitle.ZIndex = 2
    subtitle.Parent = bar

    -- slots: fixed 6-grid hanging below the bar; first `slotCount` visible
    local slotsFolder = Instance.new("Frame")
    slotsFolder.Name = "Slots"
    slotsFolder.Size = UDim2.fromScale(1, 1)
    slotsFolder.BackgroundTransparency = 1
    slotsFolder.Parent = root

    local slots = {}
    for i = 1, MAX_SLOTS do
        local s = buildSlot(theme, opts.selected == i)
        s.Name = "Slot" .. i
        s.Size = UDim2.new(1, 0, SLOT_H, 0) -- full-width box → height binds the square
        s.AnchorPoint = Vector2.new(0.5, 0.5)
        local fx = FIRST_X + (LAST_X - FIRST_X) * ((i - 1) / (MAX_SLOTS - 1))
        s.Position = UDim2.new(fx, 0, SLOT_Y, 0)
        s.Visible = (i <= effSlots)
        s.Parent = slotsFolder
        slots[i] = s
        -- SLOT CONTENTS (Jason: "there's nothing in the actual power slots"): caller
        -- may pass opts.slotContents[i] = { record, dead } — render the slotted
        -- enhancement badge inside the rim (dead = greyed, the out-of-window state)
        local content = opts.slotContents and opts.slotContents[i]
        if content and content.record then
            PetBadge.createEnhancementBadge(s, {
                record = content.record,
                size = UDim2.fromScale(0.84, 0.84),
                position = UDim2.fromScale(0.5, 0.5),
                anchor = Vector2.new(0.5, 0.5),
                zindex = (s.ZIndex or 1) + 2,
                dead = content.dead == true,
            })
        end
    end

    local handle = { root = root }
    function handle.setName(t)
        name.Text = t or ""
    end
    function handle.setSubtitle(t)
        subtitle.Text = t or ""
        subtitle.Visible = (t ~= nil and t ~= "")
    end
    function handle.setSelected(idx)
        for i, s in ipairs(slots) do
            local b = s:FindFirstChild("Border")
            if b then
                b.ImageColor3 = (i == idx) and theme.slotRimSelected or theme.slotRim
            end
        end
    end
    function handle.destroy()
        root:Destroy()
    end
    return handle
end

return PowerSlotRow
