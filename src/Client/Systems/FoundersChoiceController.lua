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
    header = Color3.fromRGB(53, 37, 102),
    card = Color3.fromRGB(39, 43, 58),
    white = Color3.fromRGB(248, 249, 253),
    body = Color3.fromRGB(205, 211, 226),
    gold = Color3.fromRGB(255, 198, 55),
    green = Color3.fromRGB(38, 192, 106),
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
    blocker.ZIndex = 30
    blocker.Parent = parent

    local box = Instance.new("Frame")
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Position = UDim2.fromScale(0.5, 0.5)
    box.Size = UDim2.fromOffset(570, 255)
    box.BackgroundColor3 = COLORS.panel
    box.ZIndex = 31
    box.Parent = blocker
    corner(box, 18)
    PanelChrome.pillBorder(box, "citrine", 34, 0)

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
    cancel.ZIndex = 33
    cancel.Parent = box
    PanelChrome.pillPanel(cancel, "sapphire", 32)
    PanelChrome.pillBorder(cancel, "sapphire", 34, 0)
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
    confirm.ZIndex = 33
    confirm.Parent = box
    PanelChrome.pillPanel(confirm, "emerald", 32)
    PanelChrome.pillBorder(confirm, "emerald", 34, 0)
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

    local panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromOffset(980, 650)
    panel.BackgroundColor3 = COLORS.panel
    panel.Parent = gui
    corner(panel, 20)
    PanelChrome.pillBorder(panel, "citrine", 4, 0)
    UIViewportScale.attach(panel, { min = 0.34 })

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 112)
    header.BackgroundColor3 = COLORS.header
    header.Parent = panel
    corner(header, 18)
    local title = label(
        header,
        "🎁 FOUNDER'S CHOICE",
        UDim2.new(1, -120, 0, 48),
        UDim2.fromOffset(24, 12),
        Enum.Font.GothamBlack,
        COLORS.white,
        34
    )
    title.TextXAlignment = Enum.TextXAlignment.Center
    local subtitle = label(
        header,
        "Launch Founder #"
            .. tostring(state.claimNumber or "—")
            .. " • Pick one permanent benefit",
        UDim2.new(1, -120, 0, 34),
        UDim2.fromOffset(24, 62),
        Enum.Font.GothamMedium,
        Color3.fromRGB(226, 218, 255),
        19
    )
    subtitle.TextXAlignment = Enum.TextXAlignment.Center

    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.fromOffset(48, 48)
    closeButton.Position = UDim2.new(1, -62, 0, 15)
    closeButton.BackgroundTransparency = 1
    closeButton.Text = "✕"
    closeButton.TextColor3 = COLORS.white
    closeButton.TextSize = 28
    closeButton.Font = Enum.Font.GothamBlack
    closeButton.ZIndex = 6
    closeButton.Parent = header
    PanelChrome.pillPanel(closeButton, "ruby", 5)
    PanelChrome.pillBorder(closeButton, "ruby", 7, 0)
    closeButton.Activated:Connect(close)

    local note = label(
        panel,
        "No Robux price. Benefits do not stack with the same pass, and the shop will block duplicate purchases.",
        UDim2.new(1, -40, 0, 36),
        UDim2.fromOffset(20, 118),
        Enum.Font.GothamMedium,
        COLORS.body,
        16
    )
    note.TextXAlignment = Enum.TextXAlignment.Center

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -34, 1, -206)
    scroll.Position = UDim2.fromOffset(17, 158)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 7
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new()
    scroll.Parent = panel
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(290, 220)
    grid.CellPadding = UDim2.fromOffset(14, 14)
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = scroll

    for order, choice in ipairs(state.choices or {}) do
        local card = Instance.new("Frame")
        card.Name = "Choice_" .. tostring(choice.id)
        card.LayoutOrder = order
        card.BackgroundColor3 = COLORS.card
        card.Parent = scroll
        corner(card, 14)

        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.fromOffset(68, 68)
        icon.Position = UDim2.fromOffset(12, 12)
        icon.BackgroundTransparency = 1
        icon.Image = tostring(choice.icon or "")
        icon.ScaleType = Enum.ScaleType.Fit
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
        choose.Parent = card
        local key = choice.unavailable and "amethyst" or "emerald"
        PanelChrome.pillPanel(choose, key, 2)
        PanelChrome.pillBorder(choose, key, 4, 0)
        if not choice.unavailable then
            choose.Activated:Connect(function()
                confirmation(panel, choice)
            end)
        end
    end

    local status = label(
        panel,
        state.error and tostring(state.error) or "You can close this and return from the Pet Shop.",
        UDim2.new(1, -40, 0, 34),
        UDim2.new(0, 20, 1, -40),
        Enum.Font.GothamBold,
        state.error and COLORS.red or COLORS.gold,
        16
    )
    status.TextXAlignment = Enum.TextXAlignment.Center
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
