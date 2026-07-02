--[[
    QuantitySelector — a reusable modal popover for picking an integer amount from a
    stack (1..max) with a drag slider, −/＋ steppers, and Half/Max shortcuts.

    Built because both delete-mode (how many of a stack to delete) and trading (how
    many copies to offer — Jason: "a slider, trade 50-100 at a time, not a window full
    of individual cards") need the SAME control. One widget, two callers.

    Reuses the slider drag mechanic from SettingsPanel:_createSliderSetting (track +
    fill + knob, click-or-drag to set) rather than forking a parallel slider.

    Usage:
        local QuantitySelector = require(Locations.ClientUIComponents.QuantitySelector)
        QuantitySelector.prompt({
            parent = self.frame,        -- modal scrim fills this; click-off cancels
            title = "Delete how many?",
            subtitle = "Natural Health",
            iconText = "⚙️",            -- or icon = "rbxassetid://..."
            accent = Color3.fromRGB(231, 76, 60),
            min = 1, max = 8, default = 8,
            confirmText = "Delete",     -- button reads "Delete 8"
            onConfirm = function(amount) ... end,
            onCancel = function() end,  -- optional
        })

    Returns a handle with :Destroy() (the scrim Cancel / Confirm tear themselves down).
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local QuantitySelector = {}

local TEXT = Color3.fromRGB(245, 248, 255)
local PANEL = Color3.fromRGB(40, 40, 50)
local TRACK = Color3.fromRGB(60, 60, 72)
local CHIP = Color3.fromRGB(70, 70, 84)

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = inst
    return c
end

local function clampInt(n, lo, hi)
    n = math.floor((tonumber(n) or lo) + 0.5)
    if n < lo then
        n = lo
    end
    if n > hi then
        n = hi
    end
    return n
end

-- opts: parent, title, subtitle, icon, iconText, accent, min, max, default,
-- confirmText, onConfirm(amount), onCancel
function QuantitySelector.prompt(opts)
    opts = opts or {}
    local parent = opts.parent
    if not parent then
        return nil
    end
    local accent = opts.accent or Color3.fromRGB(0, 150, 210)
    local lo = math.max(0, math.floor(tonumber(opts.min) or 1))
    local hi = math.max(lo, math.floor(tonumber(opts.max) or 1))
    local value = clampInt(opts.default or hi, lo, hi)
    local confirmText = opts.confirmText or "OK"

    -- Modal scrim — eats clicks behind the popover; click-off = cancel.
    local scrim = Instance.new("TextButton")
    scrim.Name = "QuantitySelector"
    scrim.Text = ""
    scrim.AutoButtonColor = false
    scrim.Size = UDim2.new(1, 0, 1, 0)
    scrim.Position = UDim2.new(0, 0, 0, 0)
    scrim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    scrim.BackgroundTransparency = 0.45
    scrim.BorderSizePixel = 0
    scrim.ZIndex = 600
    scrim.Parent = parent

    local handle = {}
    local closed = false
    local dragConn
    local endConn
    function handle:Destroy()
        if closed then
            return
        end
        closed = true
        if dragConn then
            dragConn:Disconnect()
            dragConn = nil
        end
        if endConn then
            endConn:Disconnect()
            endConn = nil
        end
        scrim:Destroy()
    end
    local function cancel()
        if closed then
            return
        end
        handle:Destroy()
        if opts.onCancel then
            opts.onCancel()
        end
    end
    scrim.Activated:Connect(cancel)

    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 340, 0, 230)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.BackgroundColor3 = PANEL
    card.BorderSizePixel = 0
    card.ZIndex = 601
    card.Parent = scrim
    corner(card, 14)
    local stroke = Instance.new("UIStroke")
    stroke.Color = accent
    stroke.Thickness = 2
    stroke.Parent = card
    -- swallow click-through so a click ON the card doesn't bubble to the scrim/cancel
    local eat = Instance.new("TextButton")
    eat.Text = ""
    eat.AutoButtonColor = false
    eat.BackgroundTransparency = 1
    eat.Size = UDim2.new(1, 0, 1, 0)
    eat.ZIndex = 601
    eat.Parent = card

    -- header: optional icon + title + subtitle
    local hasIcon = opts.icon ~= nil or opts.iconText ~= nil
    if hasIcon then
        if opts.icon then
            local img = Instance.new("ImageLabel")
            img.Size = UDim2.new(0, 44, 0, 44)
            img.Position = UDim2.new(0, 14, 0, 14)
            img.BackgroundTransparency = 1
            img.ScaleType = Enum.ScaleType.Fit
            img.Image = opts.icon
            img.ZIndex = 602
            img.Parent = card
        else
            local em = Instance.new("TextLabel")
            em.Size = UDim2.new(0, 44, 0, 44)
            em.Position = UDim2.new(0, 14, 0, 14)
            em.BackgroundTransparency = 1
            em.Text = opts.iconText
            em.TextScaled = true
            em.ZIndex = 602
            em.Parent = card
        end
    end

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, hasIcon and -72 or -28, 0, 26)
    title.Position = UDim2.new(0, hasIcon and 66 or 14, 0, 14)
    title.BackgroundTransparency = 1
    title.Text = opts.title or "How many?"
    title.TextColor3 = TEXT
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.ZIndex = 602
    title.Parent = card

    if opts.subtitle then
        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, hasIcon and -72 or -28, 0, 18)
        sub.Position = UDim2.new(0, hasIcon and 66 or 14, 0, 40)
        sub.BackgroundTransparency = 1
        sub.Text = opts.subtitle
        sub.TextColor3 = Color3.fromRGB(190, 196, 210)
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.TextSize = 13
        sub.Font = Enum.Font.Gotham
        sub.ZIndex = 602
        sub.Parent = card
    end

    -- big live number ("12 / 50")
    local numLabel = Instance.new("TextLabel")
    numLabel.Size = UDim2.new(1, -28, 0, 40)
    numLabel.Position = UDim2.new(0, 14, 0, 70)
    numLabel.BackgroundTransparency = 1
    numLabel.Text = ""
    numLabel.TextColor3 = TEXT
    numLabel.TextScaled = true
    numLabel.Font = Enum.Font.GothamBlack
    numLabel.ZIndex = 602
    numLabel.Parent = card
    local numC = Instance.new("UITextSizeConstraint")
    numC.MaxTextSize = 34
    numC.Parent = numLabel

    -- slider track + fill + knob
    local trackHolder = Instance.new("Frame")
    trackHolder.Size = UDim2.new(1, -88, 0, 24)
    trackHolder.Position = UDim2.new(0, 44, 0, 120)
    trackHolder.BackgroundTransparency = 1
    trackHolder.ZIndex = 602
    trackHolder.Parent = card

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 8)
    track.Position = UDim2.new(0, 0, 0.5, -4)
    track.BackgroundColor3 = TRACK
    track.BorderSizePixel = 0
    track.ZIndex = 602
    track.Parent = trackHolder
    corner(track, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 603
    fill.Parent = track
    corner(fill, 4)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = TEXT
    knob.BorderSizePixel = 0
    knob.ZIndex = 604
    knob.Parent = trackHolder
    corner(knob, 10)

    local confirmBtn -- forward ref (label updates with value)
    local function applyValue(v, animate)
        value = clampInt(v, lo, hi)
        local span = math.max(1, hi - lo)
        local pct = (value - lo) / span
        numLabel.Text = ("%d / %d"):format(value, hi)
        if animate then
            TweenService:Create(fill, TweenInfo.new(0.08), { Size = UDim2.new(pct, 0, 1, 0) })
                :Play()
        else
            fill.Size = UDim2.new(pct, 0, 1, 0)
        end
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        if confirmBtn then
            confirmBtn.Text = ("%s %d"):format(confirmText, value)
        end
    end

    -- click / drag anywhere on the track -> value from x fraction
    local function valueFromInput(input)
        local rel = (input.Position.X - track.AbsolutePosition.X)
            / math.max(1, track.AbsoluteSize.X)
        rel = math.clamp(rel, 0, 1)
        applyValue(lo + rel * (hi - lo), true)
    end
    local function beginDrag(input)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            valueFromInput(input)
            if dragConn then
                dragConn:Disconnect()
            end
            dragConn = UserInputService.InputChanged:Connect(function(moved)
                if
                    moved.UserInputType == Enum.UserInputType.MouseMovement
                    or moved.UserInputType == Enum.UserInputType.Touch
                then
                    valueFromInput(moved)
                end
            end)
        end
    end
    track.InputBegan:Connect(beginDrag)
    knob.InputBegan:Connect(beginDrag)
    trackHolder.InputBegan:Connect(beginDrag)
    endConn = UserInputService.InputEnded:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            if dragConn then
                dragConn:Disconnect()
                dragConn = nil
            end
        end
    end)

    -- −/＋ stepper buttons flanking the track
    local function stepper(text, x, delta)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 32, 0, 32)
        b.Position = UDim2.new(x, x == 0 and 6 or -38, 0, 116)
        b.AnchorPoint = Vector2.new(0, 0)
        b.BackgroundColor3 = CHIP
        b.Text = text
        b.TextColor3 = TEXT
        b.TextSize = 22
        b.Font = Enum.Font.GothamBold
        b.ZIndex = 603
        b.Parent = card
        corner(b, 8)
        b.Activated:Connect(function()
            applyValue(value + delta, true)
        end)
        return b
    end
    stepper("−", 0, -1)
    stepper("+", 1, 1)

    -- quick chips: Half + Max (the common "all of it" is one tap)
    local chipRow = Instance.new("Frame")
    chipRow.Size = UDim2.new(1, -28, 0, 28)
    chipRow.Position = UDim2.new(0, 14, 0, 152)
    chipRow.BackgroundTransparency = 1
    chipRow.ZIndex = 602
    chipRow.Parent = card
    local chipLayout = Instance.new("UIListLayout")
    chipLayout.FillDirection = Enum.FillDirection.Horizontal
    chipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    chipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    chipLayout.Padding = UDim.new(0, 8)
    chipLayout.Parent = chipRow
    local function chip(text, toValue, order)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 70, 0, 24)
        b.BackgroundColor3 = CHIP
        b.Text = text
        b.TextColor3 = TEXT
        b.TextSize = 13
        b.Font = Enum.Font.GothamBold
        b.LayoutOrder = order
        b.ZIndex = 603
        b.Parent = chipRow
        corner(b, 6)
        b.Activated:Connect(function()
            applyValue(toValue, true)
        end)
    end
    chip("Half", math.max(lo, math.floor(hi / 2)), 1)
    chip("Max", hi, 2)

    -- Cancel (default/left, neutral) + Confirm (right, accent). "Every chance to not".
    local buttons = Instance.new("Frame")
    buttons.Size = UDim2.new(1, -28, 0, 38)
    buttons.Position = UDim2.new(0, 14, 1, -48)
    buttons.BackgroundTransparency = 1
    buttons.ZIndex = 602
    buttons.Parent = card
    local bLayout = Instance.new("UIListLayout")
    bLayout.FillDirection = Enum.FillDirection.Horizontal
    bLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    bLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bLayout.Padding = UDim.new(0, 10)
    bLayout.Parent = buttons

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0, 110, 1, 0)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
    cancelBtn.Text = "Cancel"
    cancelBtn.TextColor3 = TEXT
    cancelBtn.TextSize = 15
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.LayoutOrder = 1
    cancelBtn.ZIndex = 603
    cancelBtn.Parent = buttons
    corner(cancelBtn, 8)
    cancelBtn.Activated:Connect(cancel)

    confirmBtn = Instance.new("TextButton")
    confirmBtn.Size = UDim2.new(0, 150, 1, 0)
    confirmBtn.BackgroundColor3 = accent
    confirmBtn.Text = confirmText
    confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirmBtn.TextSize = 15
    confirmBtn.Font = Enum.Font.GothamBold
    confirmBtn.LayoutOrder = 2
    confirmBtn.ZIndex = 603
    confirmBtn.Parent = buttons
    corner(confirmBtn, 8)
    confirmBtn.Activated:Connect(function()
        local chosen = value
        handle:Destroy()
        if opts.onConfirm then
            opts.onConfirm(chosen)
        end
    end)

    applyValue(value, false)

    -- pop-in (same back-ease as the inventory/hatch confirms)
    card.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(
        card,
        TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 340, 0, 230) }
    ):Play()

    return handle
end

return QuantitySelector
