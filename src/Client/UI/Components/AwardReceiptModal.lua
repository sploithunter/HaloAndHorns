--[[
    AwardReceiptModal — click-through confirmation for durable server awards.

    The server has already granted and saved the bundle before this appears. This
    client surface only makes that delivery impossible to miss. Receipts queue so
    multiple offline awards are acknowledged one at a time without overwriting.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIViewportScale = require(script.Parent.Parent.UIViewportScale)

local petsConfig = require(ReplicatedStorage.Configs:WaitForChild("pets"))
local thumbnails = require(ReplicatedStorage.Configs:WaitForChild("pet_thumbnail_assets"))

local AwardReceiptModal = {}

local queue = {}
local active = false
local seen = {}

local GOLD = Color3.fromRGB(255, 204, 66)
local DEEP_GOLD = Color3.fromRGB(173, 105, 8)
local PANEL = Color3.fromRGB(20, 20, 28)
local PANEL_INSET = Color3.fromRGB(31, 31, 43)
local TEXT = Color3.fromRGB(250, 250, 255)
local DIM = Color3.fromRGB(196, 196, 211)

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
end

local function addStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = thickness
    stroke.Parent = parent
    return stroke
end

local function firstEgg(granted)
    local items = type(granted) == "table" and granted.items or nil
    for _, item in ipairs(type(items) == "table" and items or {}) do
        if type(item) == "table" and item.bucket == "eggs" then
            return tostring(item.id or ""), math.max(1, math.floor(tonumber(item.qty) or 1))
        end
    end
    return nil, nil
end

local function eggDisplay(eggId, quantity)
    if not eggId then
        return "Rewards added", ""
    end
    local egg = petsConfig.egg_sources and petsConfig.egg_sources[eggId]
    local name = egg and egg.name or "Award Item"
    if quantity and quantity > 1 then
        name = string.format("%s ×%d", name, quantity)
    end
    return name, thumbnails.eggs and thumbnails.eggs[eggId] or ""
end

local function showNext()
    if active or #queue == 0 then
        return
    end
    active = true
    local ctx = table.remove(queue, 1)
    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        active = false
        task.defer(showNext)
        return
    end

    local priorSelection = GuiService.SelectedObject
    local gui = Instance.new("ScreenGui")
    gui.Name = "AwardReceiptModal"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 1100
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local scrim = Instance.new("TextButton")
    scrim.Name = "Scrim"
    scrim.Size = UDim2.fromScale(1, 1)
    scrim.BackgroundColor3 = Color3.new(0, 0, 0)
    scrim.BackgroundTransparency = 0.32
    scrim.BorderSizePixel = 0
    scrim.Text = ""
    scrim.AutoButtonColor = false
    scrim.Active = true
    scrim.Modal = true
    scrim.Selectable = false
    scrim.ZIndex = 1
    scrim.Parent = gui

    local card = Instance.new("Frame")
    card.Name = "Receipt"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(620, 390)
    card.BackgroundColor3 = PANEL
    card.BorderSizePixel = 0
    card.ZIndex = 2
    addCorner(card, 22)
    addStroke(card, GOLD, 4)
    card.Parent = gui

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 86)
    header.BackgroundColor3 = DEEP_GOLD
    header.BorderSizePixel = 0
    header.ZIndex = 3
    addCorner(header, 18)
    local headerMask = Instance.new("Frame")
    headerMask.Size = UDim2.new(1, 0, 0, 24)
    headerMask.Position = UDim2.new(0, 0, 1, -24)
    headerMask.BackgroundColor3 = DEEP_GOLD
    headerMask.BorderSizePixel = 0
    headerMask.ZIndex = 3
    headerMask.Parent = header
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 186, 24)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(145, 73, 4)),
    })
    gradient.Rotation = 90
    gradient.Parent = header
    header.Parent = card

    local trophy = Instance.new("TextLabel")
    trophy.Size = UDim2.fromOffset(68, 68)
    trophy.Position = UDim2.fromOffset(18, 8)
    trophy.BackgroundTransparency = 1
    trophy.Text = "🏆"
    trophy.TextScaled = true
    trophy.ZIndex = 4
    trophy.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -112, 1, 0)
    title.Position = UDim2.fromOffset(88, 0)
    title.BackgroundTransparency = 1
    title.Text = tostring(ctx.title or "Award Received!")
    title.TextColor3 = TEXT
    title.TextSize = 34
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 4
    title.Parent = header

    local eggId, eggQuantity = firstEgg(ctx.granted)
    local itemName, image = eggDisplay(eggId, eggQuantity)

    local iconFrame = Instance.new("Frame")
    iconFrame.Size = UDim2.fromOffset(174, 174)
    iconFrame.Position = UDim2.fromOffset(30, 112)
    iconFrame.BackgroundColor3 = PANEL_INSET
    iconFrame.BorderSizePixel = 0
    iconFrame.ZIndex = 3
    addCorner(iconFrame, 20)
    addStroke(iconFrame, GOLD, 2)
    iconFrame.Parent = card

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(1, -18, 1, -18)
    icon.Position = UDim2.fromOffset(9, 9)
    icon.BackgroundTransparency = 1
    icon.Image = image
    icon.ScaleType = Enum.ScaleType.Fit
    icon.ZIndex = 4
    icon.Parent = iconFrame

    local itemLabel = Instance.new("TextLabel")
    itemLabel.Size = UDim2.new(1, -236, 0, 54)
    itemLabel.Position = UDim2.fromOffset(224, 116)
    itemLabel.BackgroundTransparency = 1
    itemLabel.Text = itemName
    itemLabel.TextColor3 = GOLD
    itemLabel.TextSize = 25
    itemLabel.Font = Enum.Font.GothamBlack
    itemLabel.TextWrapped = true
    itemLabel.TextXAlignment = Enum.TextXAlignment.Left
    itemLabel.ZIndex = 3
    itemLabel.Parent = card

    local summary = Instance.new("TextLabel")
    summary.Size = UDim2.new(1, -248, 0, 112)
    summary.Position = UDim2.fromOffset(224, 174)
    summary.BackgroundTransparency = 1
    summary.Text = tostring(ctx.name or "Your award has been added to your inventory.")
    summary.TextColor3 = DIM
    summary.TextSize = 20
    summary.Font = Enum.Font.Gotham
    summary.TextWrapped = true
    summary.TextXAlignment = Enum.TextXAlignment.Left
    summary.TextYAlignment = Enum.TextYAlignment.Top
    summary.ZIndex = 3
    summary.Parent = card

    local confirm = Instance.new("TextButton")
    confirm.Name = "Confirm"
    confirm.AnchorPoint = Vector2.new(0.5, 1)
    confirm.Position = UDim2.new(0.5, 0, 1, -24)
    confirm.Size = UDim2.fromOffset(260, 62)
    confirm.BackgroundColor3 = Color3.fromRGB(32, 205, 83)
    confirm.BorderSizePixel = 0
    confirm.Text = "Got it!"
    confirm.TextColor3 = Color3.new(1, 1, 1)
    confirm.TextSize = 22
    confirm.TextStrokeTransparency = 1
    confirm.Font = Enum.Font.GothamBold
    confirm.AutoButtonColor = true
    confirm.Selectable = true
    confirm.ZIndex = 4
    addCorner(confirm, 18)
    addStroke(confirm, Color3.fromRGB(122, 255, 151), 3)
    local selectionImage = Instance.new("Frame")
    selectionImage.Name = "RoundedSelection"
    selectionImage.BackgroundTransparency = 1
    addCorner(selectionImage, 18)
    addStroke(selectionImage, GOLD, 4)
    confirm.SelectionImageObject = selectionImage
    confirm.Parent = card

    local closed = false
    local function close()
        if closed then
            return
        end
        closed = true
        gui:Destroy()
        active = false
        if priorSelection and priorSelection.Parent then
            GuiService.SelectedObject = priorSelection
        else
            GuiService.SelectedObject = nil
        end
        task.defer(showNext)
    end
    confirm.Activated:Connect(close)

    gui.Parent = playerGui
    UIViewportScale.attach(card, { min = 0.55 })
    if player:GetAttribute("InputMode") == "gamepad" then
        GuiService.SelectedObject = confirm
    end
end

function AwardReceiptModal.show(ctx)
    ctx = type(ctx) == "table" and ctx or {}
    local awardId = type(ctx.awardId) == "string" and ctx.awardId or nil
    if awardId and seen[awardId] then
        return
    end
    if awardId then
        seen[awardId] = true
    end
    queue[#queue + 1] = ctx
    showNext()
end

return AwardReceiptModal
