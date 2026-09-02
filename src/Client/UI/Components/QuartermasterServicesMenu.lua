-- Responsive two-service menu owned by the Merge Quartermaster.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local UIViewportScale = require(script.Parent.Parent.UIViewportScale)

local QuartermasterServicesMenu = {}

local activeGui = nil

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

local function serviceButton(parent, name, titleText, bodyText, color, position)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Position = position
    button.Size = UDim2.new(1, -52, 0, 92)
    button.BackgroundColor3 = color
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Selectable = true
    button.Text = ""
    button.ZIndex = 5
    corner(button, 15)
    stroke(button, color:Lerp(Color3.new(1, 1, 1), 0.5), 2)

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Position = UDim2.fromOffset(22, 11)
    title.Size = UDim2.new(1, -44, 0, 32)
    title.BackgroundTransparency = 1
    title.Text = titleText
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 23
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 6
    title.Parent = button

    local body = Instance.new("TextLabel")
    body.Name = "Description"
    body.Position = UDim2.fromOffset(22, 44)
    body.Size = UDim2.new(1, -44, 0, 34)
    body.BackgroundTransparency = 1
    body.Text = bodyText
    body.TextColor3 = Color3.fromRGB(229, 237, 247)
    body.TextSize = 17
    body.Font = Enum.Font.GothamMedium
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.ZIndex = 6
    body.Parent = button

    local selection = Instance.new("Frame")
    selection.Name = "RoundedSelection"
    selection.BackgroundTransparency = 1
    corner(selection, 15)
    stroke(selection, Color3.fromRGB(255, 219, 70), 4)
    button.SelectionImageObject = selection
    button.Parent = parent
    return button
end

function QuartermasterServicesMenu.hide()
    if activeGui then
        activeGui:Destroy()
        activeGui = nil
    end
end

function QuartermasterServicesMenu.show(payload, respond)
    payload = type(payload) == "table" and payload or {}
    QuartermasterServicesMenu.hide()

    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return
    end
    local priorSelection = GuiService.SelectedObject
    local gui = Instance.new("ScreenGui")
    gui.Name = "QuartermasterServicesMenu"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 1160
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    activeGui = gui

    local scrim = Instance.new("TextButton")
    scrim.Name = "Scrim"
    scrim.Size = UDim2.fromScale(1, 1)
    scrim.BackgroundColor3 = Color3.new(0, 0, 0)
    scrim.BackgroundTransparency = 0.42
    scrim.BorderSizePixel = 0
    scrim.Text = ""
    scrim.AutoButtonColor = false
    scrim.Active = true
    scrim.Modal = true
    scrim.Selectable = false
    scrim.ZIndex = 1
    scrim.Parent = gui

    local panel = Instance.new("Frame")
    panel.Name = "Services"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromOffset(680, 410)
    panel.BackgroundColor3 = Color3.fromRGB(20, 25, 36)
    panel.BorderSizePixel = 0
    panel.ZIndex = 2
    corner(panel, 22)
    stroke(panel, Color3.fromRGB(255, 190, 55), 4)
    panel.Parent = gui

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 76)
    header.BackgroundColor3 = Color3.fromRGB(156, 104, 25)
    header.BorderSizePixel = 0
    header.ZIndex = 3
    corner(header, 18)
    header.Parent = panel

    local mask = Instance.new("Frame")
    mask.Size = UDim2.new(1, 0, 0, 20)
    mask.Position = UDim2.new(0, 0, 1, -20)
    mask.BackgroundColor3 = header.BackgroundColor3
    mask.BorderSizePixel = 0
    mask.ZIndex = 3
    mask.Parent = header

    local title = Instance.new("TextLabel")
    title.Position = UDim2.fromOffset(24, 0)
    title.Size = UDim2.new(1, -88, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = tostring(payload.title or "QUARTERMASTER")
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 29
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 4
    title.Parent = header

    local close = Instance.new("TextButton")
    close.Name = "Close"
    close.AnchorPoint = Vector2.new(1, 0.5)
    close.Position = UDim2.new(1, -18, 0.5, 0)
    close.Size = UDim2.fromOffset(42, 42)
    close.BackgroundColor3 = Color3.fromRGB(118, 54, 44)
    close.BorderSizePixel = 0
    close.Text = "×"
    close.TextColor3 = Color3.new(1, 1, 1)
    close.TextSize = 31
    close.Font = Enum.Font.GothamBlack
    close.ZIndex = 5
    corner(close, 12)
    close.Parent = header

    local body = Instance.new("TextLabel")
    body.Position = UDim2.fromOffset(26, 88)
    body.Size = UDim2.new(1, -52, 0, 42)
    body.BackgroundTransparency = 1
    body.Text = tostring(payload.body or payload.greeting or "Choose a service.")
    body.TextColor3 = Color3.fromRGB(218, 226, 240)
    body.TextSize = 18
    body.Font = Enum.Font.GothamMedium
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.ZIndex = 3
    body.Parent = panel

    local potions = serviceButton(
        panel,
        "BrowsePotions",
        tostring(payload.potionsLabel or "BROWSE POTIONS"),
        tostring(payload.potionsBody or "Buy supplies for your own pets."),
        Color3.fromRGB(40, 151, 86),
        UDim2.fromOffset(26, 138)
    )
    local training = serviceButton(
        panel,
        "CombatTraining",
        tostring(payload.trainingLabel or "COMBAT TRAINING"),
        tostring(payload.trainingBody or "Learn powers, targeting, healing, and team tactics."),
        Color3.fromRGB(42, 112, 181),
        UDim2.fromOffset(26, 240)
    )

    local notNow = Instance.new("TextButton")
    notNow.Name = "NotNow"
    notNow.AnchorPoint = Vector2.new(0.5, 1)
    notNow.Position = UDim2.new(0.5, 0, 1, -14)
    notNow.Size = UDim2.fromOffset(210, 48)
    notNow.BackgroundColor3 = Color3.fromRGB(68, 76, 92)
    notNow.BorderSizePixel = 0
    notNow.Text = tostring(payload.closeLabel or "NOT NOW")
    notNow.TextColor3 = Color3.fromRGB(235, 239, 247)
    notNow.TextSize = 18
    notNow.Font = Enum.Font.GothamBold
    notNow.ZIndex = 5
    corner(notNow, 13)
    notNow.Parent = panel

    local closed = false
    local function resolve(choice)
        if closed then
            return
        end
        closed = true
        if type(respond) == "function" and choice then
            respond(choice)
        end
        QuartermasterServicesMenu.hide()
        if priorSelection and priorSelection.Parent then
            GuiService.SelectedObject = priorSelection
        else
            GuiService.SelectedObject = nil
        end
    end

    close.Activated:Connect(function()
        resolve(nil)
    end)
    notNow.Activated:Connect(function()
        resolve(nil)
    end)
    scrim.Activated:Connect(function()
        resolve(nil)
    end)
    potions.Activated:Connect(function()
        resolve("potions")
    end)
    training.Activated:Connect(function()
        resolve("combat_training")
    end)

    gui.Parent = playerGui
    UIViewportScale.attach(panel, { min = 0.5 })
    if player:GetAttribute("InputMode") == "gamepad" then
        GuiService.SelectedObject = potions
    end
end

return QuartermasterServicesMenu
