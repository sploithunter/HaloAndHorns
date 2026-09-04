-- Compact, purchase-confirmation card for a config-authored live game pass. This intentionally
-- precedes Roblox's native prompt: the player gets context and a cheap exit before Marketplace UI.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationCatalog = require(ReplicatedStorage.Shared.Game.MonetizationCatalog)
local Monetization = require(ReplicatedStorage.Configs:WaitForChild("monetization"))
local UIViewportScale = require(script.Parent.Parent.UIViewportScale)

local GamePassPurchasePrompt = {}

local activeGui = nil

local function rgb(value, key)
    assert(type(value) == "table", key .. " must be an RGB triplet")
    return Color3.fromRGB(
        assert(tonumber(value[1]), key .. "[1] is required"),
        assert(tonumber(value[2]), key .. "[2] is required"),
        assert(tonumber(value[3]), key .. "[3] is required")
    )
end

local function corner(parent, radius)
    local value = Instance.new("UICorner")
    value.CornerRadius = UDim.new(0, radius)
    value.Parent = parent
end

local function stroke(parent, color, thickness)
    local value = Instance.new("UIStroke")
    value.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    value.Color = color
    value.Thickness = thickness
    value.Parent = parent
end

local function findPass(passId)
    for _, entry in ipairs(MonetizationCatalog.livePasses(Monetization)) do
        if entry.id == passId then
            return entry
        end
    end
    return nil
end

function GamePassPurchasePrompt.hide()
    if activeGui then
        activeGui:Destroy()
        activeGui = nil
    end
end

function GamePassPurchasePrompt.show(options, respond)
    options = type(options) == "table" and options or {}
    local passId = tostring(options.passId or "")
    local entry = assert(findPass(passId), "live game pass is required for purchase prompt")
    local presentation = assert(options.presentation, "purchase prompt presentation is required")
    local palette = assert(presentation.palette, "purchase prompt palette is required")
    local size = assert(presentation.panel_size, "purchase prompt panel_size is required")

    GamePassPurchasePrompt.hide()
    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return
    end

    local priorSelection = GuiService.SelectedObject
    local gui = Instance.new("ScreenGui")
    gui.Name = "GamePassPurchasePrompt_" .. passId
    gui.IgnoreGuiInset = true
    gui.ScreenInsets = Enum.ScreenInsets.None
    gui.ClipToDeviceSafeArea = false
    gui.ResetOnSpawn = false
    gui.DisplayOrder =
        assert(tonumber(presentation.display_order), "purchase prompt display_order is required")
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    activeGui = gui

    local scrim = Instance.new("TextButton")
    scrim.Name = "Scrim"
    scrim.Size = UDim2.fromScale(1, 1)
    scrim.BackgroundColor3 = rgb(palette.scrim, "purchase_menu.palette.scrim")
    scrim.BackgroundTransparency = 0.48
    scrim.BorderSizePixel = 0
    scrim.Text = ""
    scrim.AutoButtonColor = false
    scrim.Active = true
    scrim.Modal = true
    scrim.Selectable = false
    scrim.ZIndex = 1
    scrim.Parent = gui

    local panel = Instance.new("Frame")
    panel.Name = "PurchaseCard"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.48)
    panel.Size = UDim2.fromOffset(
        assert(tonumber(size.x), "purchase prompt panel_size.x is required"),
        assert(tonumber(size.y), "purchase prompt panel_size.y is required")
    )
    panel.BackgroundColor3 = rgb(palette.panel, "purchase_menu.palette.panel")
    panel.BorderSizePixel = 0
    panel.ZIndex = 2
    corner(panel, 22)
    stroke(panel, rgb(palette.accent, "purchase_menu.palette.accent"), 4)
    panel.Parent = gui

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 74)
    header.BackgroundColor3 = rgb(palette.header, "purchase_menu.palette.header")
    header.BorderSizePixel = 0
    header.ZIndex = 3
    corner(header, 18)
    header.Parent = panel

    local headerMask = Instance.new("Frame")
    headerMask.Size = UDim2.new(1, 0, 0, 20)
    headerMask.Position = UDim2.new(0, 0, 1, -20)
    headerMask.BackgroundColor3 = header.BackgroundColor3
    headerMask.BorderSizePixel = 0
    headerMask.ZIndex = 3
    headerMask.Parent = header

    local icon = Instance.new("ImageLabel")
    icon.Name = "PassIcon"
    icon.Position = UDim2.fromOffset(22, 14)
    icon.Size = UDim2.fromOffset(46, 46)
    icon.BackgroundTransparency = 1
    icon.Image = tostring(entry.config.icon or "")
    icon.ScaleType = Enum.ScaleType.Fit
    icon.ZIndex = 5
    icon.Parent = header

    local eyebrow = Instance.new("TextLabel")
    eyebrow.Name = "Eyebrow"
    eyebrow.Position = UDim2.fromOffset(80, 9)
    eyebrow.Size = UDim2.new(1, -102, 0, 21)
    eyebrow.BackgroundTransparency = 1
    eyebrow.Text = tostring(presentation.eyebrow)
    eyebrow.TextColor3 = rgb(palette.body, "purchase_menu.palette.body")
    eyebrow.TextSize = 13
    eyebrow.Font = Enum.Font.GothamBold
    eyebrow.TextXAlignment = Enum.TextXAlignment.Left
    eyebrow.ZIndex = 5
    eyebrow.Parent = header

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Position = UDim2.fromOffset(80, 27)
    title.Size = UDim2.new(1, -102, 0, 39)
    title.BackgroundTransparency = 1
    title.Text = tostring(presentation.title or entry.config.name)
    title.TextColor3 = rgb(palette.text, "purchase_menu.palette.text")
    title.TextSize = 28
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 5
    title.Parent = header

    local benefitCard = Instance.new("Frame")
    benefitCard.Name = "Benefit"
    benefitCard.Position = UDim2.fromOffset(22, 94)
    benefitCard.Size = UDim2.new(1, -44, 0, 128)
    benefitCard.BackgroundColor3 = rgb(palette.card, "purchase_menu.palette.card")
    benefitCard.BorderSizePixel = 0
    benefitCard.ZIndex = 3
    corner(benefitCard, 16)
    benefitCard.Parent = panel

    local description = Instance.new("TextLabel")
    description.Name = "Description"
    description.Position = UDim2.fromOffset(20, 15)
    description.Size = UDim2.new(1, -40, 0, 61)
    description.BackgroundTransparency = 1
    description.Text = tostring(presentation.description or entry.config.description)
    description.TextColor3 = rgb(palette.body, "purchase_menu.palette.body")
    description.TextSize = 18
    description.Font = Enum.Font.GothamMedium
    description.TextWrapped = true
    description.TextXAlignment = Enum.TextXAlignment.Center
    description.TextYAlignment = Enum.TextYAlignment.Center
    description.ZIndex = 4
    description.Parent = benefitCard

    local priority = Instance.new("TextLabel")
    priority.Name = "Priority"
    priority.AnchorPoint = Vector2.new(0.5, 1)
    priority.Position = UDim2.new(0.5, 0, 1, -14)
    priority.Size = UDim2.new(1, -40, 0, 30)
    priority.BackgroundTransparency = 1
    priority.Text = tostring(presentation.priority_copy)
    priority.TextColor3 = rgb(palette.accent, "purchase_menu.palette.accent")
    priority.TextSize = 17
    priority.Font = Enum.Font.GothamBlack
    priority.ZIndex = 4
    priority.Parent = benefitCard

    local closed = false
    local function resolve(purchase)
        if closed then
            return
        end
        closed = true
        GamePassPurchasePrompt.hide()
        if priorSelection and priorSelection.Parent then
            GuiService.SelectedObject = priorSelection
        else
            GuiService.SelectedObject = nil
        end
        if type(respond) == "function" then
            respond(purchase == true, entry)
        end
    end

    local cancel = Instance.new("TextButton")
    cancel.Name = "Cancel"
    cancel.AnchorPoint = Vector2.new(0, 1)
    cancel.Position = UDim2.new(0, 22, 1, -20)
    cancel.Size = UDim2.new(0.36, 0, 0, 58)
    cancel.BackgroundColor3 = rgb(palette.cancel, "purchase_menu.palette.cancel")
    cancel.BorderSizePixel = 0
    cancel.AutoButtonColor = true
    cancel.Selectable = true
    cancel.Text = tostring(presentation.cancel_label)
    cancel.TextColor3 = rgb(palette.text, "purchase_menu.palette.text")
    cancel.TextSize = 18
    cancel.Font = Enum.Font.GothamBold
    cancel.ZIndex = 4
    corner(cancel, 15)
    cancel.Parent = panel

    local buy = Instance.new("TextButton")
    buy.Name = "Buy"
    buy.AnchorPoint = Vector2.new(1, 1)
    buy.Position = UDim2.new(1, -22, 1, -20)
    buy.Size = UDim2.new(0.56, 0, 0, 58)
    buy.BackgroundColor3 = rgb(palette.buy, "purchase_menu.palette.buy")
    buy.BorderSizePixel = 0
    buy.AutoButtonColor = true
    buy.Selectable = true
    buy.Text = string.format(
        tostring(presentation.buy_label_format),
        assert(tonumber(entry.config.price_robux), "game pass price_robux is required")
    )
    buy.TextColor3 = rgb(palette.text, "purchase_menu.palette.text")
    buy.TextSize = 20
    buy.Font = Enum.Font.GothamBlack
    buy.ZIndex = 4
    corner(buy, 15)
    stroke(buy, rgb(palette.accent, "purchase_menu.palette.accent"), 2)
    buy.Parent = panel

    scrim.Activated:Connect(function()
        resolve(false)
    end)
    cancel.Activated:Connect(function()
        resolve(false)
    end)
    buy.Activated:Connect(function()
        resolve(true)
    end)

    gui.Parent = playerGui
    UIViewportScale.attach(panel, {
        min = assert(
            tonumber(presentation.minimum_scale),
            "purchase prompt minimum_scale is required"
        ),
    })
    if player:GetAttribute("InputMode") == "gamepad" then
        GuiService.SelectedObject = buy
    end
end

return GamePassPurchasePrompt
