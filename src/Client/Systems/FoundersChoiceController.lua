--[[
    Founder's Choice launch reward. The server owns cohort membership, entitlement sources, and
    selection validation; this controller presents only the server-authored eligible catalog.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PanelChrome = require(script.Parent.Parent.UI.Components.PanelChrome)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local UIViewportScale = require(script.Parent.Parent.UI.UIViewportScale)

local Controller = {}
local started = false
local gui

local COLORS = {
    dim = Color3.fromRGB(7, 9, 16),
    panel = Color3.fromRGB(22, 24, 35),
    card = Color3.fromRGB(39, 43, 58),
    white = Color3.fromRGB(248, 249, 253),
    body = Color3.fromRGB(205, 211, 226),
    red = Color3.fromRGB(255, 110, 110),
}

local function corner(parent, radius)
    local value = Instance.new("UICorner")
    value.CornerRadius = UDim.new(0, radius)
    value.Parent = parent
end

local function label(parent, text, size, position, font, color, textSize)
    local value = Instance.new("TextLabel")
    value.BackgroundTransparency = 1
    value.Text = text
    value.Size = size
    value.Position = position or UDim2.new()
    value.Font = font or Enum.Font.Gotham
    value.TextColor3 = color or COLORS.white
    value.TextSize = textSize or 18
    value.TextWrapped = true
    value.TextXAlignment = Enum.TextXAlignment.Left
    value.ZIndex = math.max(2, parent.ZIndex + 1)
    value.Parent = parent
    return value
end

local function close()
    if gui then
        gui:Destroy()
        gui = nil
    end
end

local function confirmation(parent, choice)
    local blocker = Instance.new("Frame")
    blocker.Name = "Confirmation"
    blocker.Size = UDim2.fromScale(1, 1)
    blocker.BackgroundColor3 = COLORS.dim
    blocker.BackgroundTransparency = 0.12
    blocker.ZIndex = 140
    blocker.Parent = parent

    local box = Instance.new("Frame")
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Position = UDim2.fromScale(0.5, 0.5)
    box.Size = UDim2.fromOffset(570, 255)
    box.BackgroundColor3 = COLORS.panel
    box.ZIndex = 141
    box.Parent = blocker
    corner(box, 18)
    PanelChrome.pillBorder(box, "citrine", 145, 0, 0.07)

    local title = label(
        box,
        "Choose " .. tostring(choice.name) .. "?",
        UDim2.new(1, -36, 0, 48),
        UDim2.fromOffset(18, 20),
        Enum.Font.GothamBlack,
        COLORS.white,
        28
    )
    title.TextXAlignment = Enum.TextXAlignment.Center
    local body = label(
        box,
        "This permanently grants the same gameplay benefit as the pass. You can still buy a different pass later.",
        UDim2.new(1, -54, 0, 72),
        UDim2.fromOffset(27, 75),
        Enum.Font.GothamMedium,
        COLORS.body,
        18
    )
    body.TextXAlignment = Enum.TextXAlignment.Center

    local cancel = Instance.new("TextButton")
    cancel.Size = UDim2.fromOffset(215, 48)
    cancel.Position = UDim2.fromOffset(50, 176)
    cancel.BackgroundTransparency = 1
    cancel.Text = "NOT YET"
    cancel.TextColor3 = COLORS.white
    cancel.TextSize = 18
    cancel.Font = Enum.Font.GothamBold
    cancel.ZIndex = 144
    cancel.Parent = box
    PanelChrome.pillPanel(cancel, "sapphire", 142)
    PanelChrome.pillBorder(cancel, "sapphire", 143, 0, 0.08)
    cancel.Activated:Connect(function()
        blocker:Destroy()
    end)

    local confirm = Instance.new("TextButton")
    confirm.Size = UDim2.fromOffset(215, 48)
    confirm.Position = UDim2.fromOffset(305, 176)
    confirm.BackgroundTransparency = 1
    confirm.Text = "YES — CLAIM"
    confirm.TextColor3 = Color3.fromRGB(23, 58, 28)
    confirm.TextSize = 18
    confirm.Font = Enum.Font.GothamBold
    confirm.ZIndex = 144
    confirm.Parent = box
    PanelChrome.pillPanel(confirm, "emerald", 142)
    PanelChrome.pillBorder(confirm, "emerald", 143, 0, 0.08)
    confirm.Activated:Connect(function()
        confirm.Active = false
        confirm.Text = "CLAIMING…"
        Signals.FoundersChoiceSelect:FireServer({ passId = choice.id })
    end)
end

local function show(state)
    close()
    gui = Instance.new("ScreenGui")
    gui.Name = "FoundersChoice"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 125

    local dim = Instance.new("Frame")
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = COLORS.dim
    dim.BackgroundTransparency = 0.15
    dim.Parent = gui

    -- Use the same shell as the rest of the game's menus. This supplies the standard thin
    -- area-colored border, covered corners, and the image-backed X offset over the top-right corner.
    local shell = PanelChrome.build(gui, {
        name = "FoundersChoicePanel",
        title = "🎁 FOUNDER'S CHOICE",
        size = UDim2.fromOffset(980, 650),
        onClose = close,
    })
    local panel = shell.frame
    UIViewportScale.attach(panel, { min = 0.34 })

    -- Clip every scrolling/status child inside the shared chrome so no footer copy can leak through
    -- the bottom pill border. The shell's close button remains outside this clipped content frame.
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -28, 0.88, -10)
    content.Position = UDim2.new(0, 14, 0.11, 0)
    content.BackgroundTransparency = 1
    content.ClipsDescendants = true
    content.ZIndex = 101
    content.Parent = panel

    local subtitle = label(
        content,
        "Launch Founder #"
            .. tostring(state.claimNumber or "—")
            .. " • Pick one permanent benefit",
        UDim2.new(1, -32, 0, 34),
        UDim2.fromOffset(16, 2),
        Enum.Font.GothamMedium,
        Color3.fromRGB(226, 218, 255),
        19
    )
    subtitle.TextXAlignment = Enum.TextXAlignment.Center

    local note = label(
        content,
        "No Robux price. Benefits do not stack with the same pass, and the shop will block duplicate purchases.",
        UDim2.new(1, -32, 0, 32),
        UDim2.fromOffset(16, 38),
        Enum.Font.GothamMedium,
        state.error and COLORS.red or COLORS.body,
        16
    )
    if state.error then
        note.Text = tostring(state.error)
    end
    note.TextXAlignment = Enum.TextXAlignment.Center

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Choices"
    scroll.Size = UDim2.new(1, -18, 1, -82)
    scroll.Position = UDim2.fromOffset(9, 76)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 7
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new()
    scroll.ClipsDescendants = true
    scroll.ZIndex = 102
    scroll.Parent = content
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(290, 214)
    grid.CellPadding = UDim2.fromOffset(14, 14)
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = scroll

    for order, choice in ipairs(state.choices or {}) do
        local card = Instance.new("Frame")
        card.Name = "Choice_" .. tostring(choice.id)
        card.LayoutOrder = order
        card.BackgroundColor3 = COLORS.card
        card.BorderSizePixel = 0
        card.ZIndex = 103
        card.Parent = scroll
        corner(card, 14)

        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.fromOffset(68, 68)
        icon.Position = UDim2.fromOffset(12, 12)
        icon.BackgroundTransparency = 1
        icon.Image = tostring(choice.icon or "")
        icon.ScaleType = Enum.ScaleType.Fit
        icon.ZIndex = 104
        icon.Parent = card

        label(
            card,
            tostring(choice.name or choice.id),
            UDim2.new(1, -94, 0, 54),
            UDim2.fromOffset(88, 16),
            Enum.Font.GothamBold,
            COLORS.white,
            21
        )
        local description = label(
            card,
            tostring(choice.description or ""),
            UDim2.new(1, -24, 0, 72),
            UDim2.fromOffset(12, 86),
            Enum.Font.GothamMedium,
            COLORS.body,
            15
        )
        description.TextYAlignment = Enum.TextYAlignment.Top

        local choose = Instance.new("TextButton")
        choose.Size = UDim2.new(1, -24, 0, 42)
        choose.Position = UDim2.new(0, 12, 1, -54)
        choose.BackgroundTransparency = 1
        choose.Text = choice.unavailable and "ALREADY ACTIVE" or "CHOOSE"
        choose.TextColor3 = choice.unavailable and COLORS.body or Color3.fromRGB(24, 57, 30)
        choose.TextSize = 17
        choose.Font = Enum.Font.GothamBold
        choose.Active = not choice.unavailable
        choose.AutoButtonColor = false
        choose.ZIndex = 107
        choose.Parent = card
        local key = choice.unavailable and "amethyst" or "emerald"
        -- The TextButton must sit above both 9-slice images; the previous ordering put the opaque
        -- green panel over the TextButton's own text, which produced the blank buttons in live UI.
        PanelChrome.pillPanel(choose, key, 105)
        PanelChrome.pillBorder(choose, key, 106, 0, 0.08)
        if not choice.unavailable then
            choose.Activated:Connect(function()
                confirmation(panel, choice)
            end)
        end
    end

    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function apply(state)
    if type(state) ~= "table" then
        return
    end
    if (state.selectedPassId and state.selectedPassId ~= "") or state.eligible ~= true then
        close()
    elseif (state.canChoose == true and state.show == true) or (state.error and gui) then
        show(state)
    end
end

function Controller.start()
    if started then
        return
    end
    started = true
    Signals.FoundersChoiceState.OnClientEvent:Connect(apply)
    task.spawn(function()
        local player = Players.LocalPlayer
        while player:GetAttribute("ClientUIReady") ~= true do
            player:GetAttributeChangedSignal("ClientUIReady"):Wait()
        end
        Signals.FoundersChoiceStateRequest:FireServer({ open = false })
    end)
end

return Controller
