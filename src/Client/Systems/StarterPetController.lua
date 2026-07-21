--[[
    Full-screen first-companion role lesson. The server decides eligibility and grants the pet;
    this controller only renders the four config-authored choices and submits one pet id.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local PetThumbnailResolver = require(ReplicatedStorage.Shared.UI.PetThumbnailResolver)
local PetBadge = require(script.Parent.Parent.UI.PetBadge)
local UIViewportScale = require(script.Parent.Parent.UI.UIViewportScale)

local THUMBNAILS = require(ReplicatedStorage.Configs:WaitForChild("pet_thumbnail_assets"))

local StarterPetController = {}
local started = false
local gui
local panel
local cardButtons = {}
local statusLabel
local pending = false

local COLORS = {
    dim = Color3.fromRGB(8, 10, 18),
    panel = Color3.fromRGB(22, 24, 35),
    card = Color3.fromRGB(37, 40, 55),
    gold = Color3.fromRGB(255, 194, 55),
    white = Color3.fromRGB(247, 248, 252),
    body = Color3.fromRGB(202, 207, 220),
    muted = Color3.fromRGB(184, 190, 206),
    green = Color3.fromRGB(36, 186, 102),
}

local function corner(parent, radius)
    local value = Instance.new("UICorner")
    value.CornerRadius = UDim.new(0, radius)
    value.Parent = parent
end

local function stroke(parent, color, thickness, transparency)
    local value = Instance.new("UIStroke")
    value.Color = color
    value.Thickness = thickness or 2
    value.Transparency = transparency or 0
    value.Parent = parent
    return value
end

local function rgb(value, fallback)
    if type(value) ~= "table" then
        return fallback
    end
    return Color3.fromRGB(
        tonumber(value[1]) or 255,
        tonumber(value[2]) or 255,
        tonumber(value[3]) or 255
    )
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
    value.TextYAlignment = Enum.TextYAlignment.Center
    value.Parent = parent
    return value
end

local function setPending(value)
    pending = value
    for _, button in ipairs(cardButtons) do
        button.Active = not value
        button.AutoButtonColor = not value
    end
    if value and statusLabel then
        statusLabel.Text = "Your companion is joining your squad…"
        statusLabel.TextColor3 = COLORS.gold
    end
end

local function makeCard(parent, choice, index)
    local accent = rgb(choice.accent, COLORS.gold)
    local button = Instance.new("TextButton")
    button.Name = "Choose_" .. tostring(choice.id)
    button.AutoButtonColor = false
    button.Text = ""
    button.Size = UDim2.fromOffset(486, 220)
    button.Position = UDim2.fromOffset(index % 2 == 1 and 20 or 518, index <= 2 and 116 or 348)
    button.BackgroundColor3 = COLORS.card
    corner(button, 15)
    local cardStroke = stroke(button, accent, 3, 0.12)

    local imageBack = Instance.new("Frame")
    imageBack.Size = UDim2.fromOffset(132, 132)
    imageBack.Position = UDim2.fromOffset(14, 17)
    imageBack.BackgroundColor3 = Color3.fromRGB(14, 17, 27)
    corner(imageBack, 14)
    stroke(imageBack, accent, 2, 0.35)
    imageBack.Parent = button

    local fallback =
        label(imageBack, "🐾", UDim2.fromScale(1, 1), nil, Enum.Font.GothamBold, accent, 45)
    fallback.TextXAlignment = Enum.TextXAlignment.Center

    local image = Instance.new("ImageLabel")
    image.Name = "PetImage"
    image.BackgroundTransparency = 1
    image.Size = UDim2.new(1, -10, 1, -10)
    image.Position = UDim2.fromOffset(5, 5)
    image.ScaleType = Enum.ScaleType.Fit
    image.Image = PetThumbnailResolver.resolve(THUMBNAILS, choice.id, "basic", false) or ""
    image.Parent = imageBack

    -- Use the same element + combat-role badge shown on inventory and squad cards. The adjacent
    -- role copy turns this first choice into the player's legend for that icon vocabulary.
    local badgeHolder = Instance.new("Frame")
    badgeHolder.Name = "RoleBadge"
    badgeHolder.BackgroundTransparency = 1
    badgeHolder.Size = UDim2.fromOffset(50, 50)
    badgeHolder.Position = UDim2.fromOffset(3, 6)
    badgeHolder.ZIndex = 6
    badgeHolder.Parent = button
    PetBadge.create(badgeHolder, {
        element = PetBadge.elementForPetType(choice.id),
        role = choice.role,
        zIndex = 6,
    })

    local name = label(
        button,
        tostring(choice.display_name or choice.id),
        UDim2.fromOffset(310, 34),
        UDim2.fromOffset(159, 14),
        Enum.Font.GothamBlack,
        COLORS.white,
        30
    )
    name.TextYAlignment = Enum.TextYAlignment.Bottom

    local role = label(
        button,
        tostring(choice.role_label or choice.role or ""),
        UDim2.fromOffset(310, 22),
        UDim2.fromOffset(159, 50),
        Enum.Font.GothamBold,
        accent,
        18
    )
    role.TextYAlignment = Enum.TextYAlignment.Top

    local summary = label(
        button,
        tostring(choice.summary or ""),
        UDim2.fromOffset(310, 55),
        UDim2.fromOffset(159, 76),
        Enum.Font.GothamMedium,
        COLORS.body,
        20
    )
    summary.TextYAlignment = Enum.TextYAlignment.Top

    local detail = label(
        button,
        tostring(choice.detail or ""),
        UDim2.fromOffset(310, 70),
        UDim2.fromOffset(159, 131),
        Enum.Font.Gotham,
        COLORS.muted,
        18
    )
    detail.TextYAlignment = Enum.TextYAlignment.Top

    local choose = Instance.new("Frame")
    choose.Name = "ChooseButton"
    choose.Size = UDim2.fromOffset(132, 43)
    choose.Position = UDim2.fromOffset(14, 163)
    choose.BackgroundColor3 = COLORS.green
    corner(choose, 10)
    choose.Parent = button
    local chooseText =
        label(choose, "CHOOSE", UDim2.fromScale(1, 1), nil, Enum.Font.GothamBold, COLORS.white, 20)
    chooseText.TextXAlignment = Enum.TextXAlignment.Center

    button.MouseEnter:Connect(function()
        if not pending then
            TweenService
                :Create(cardStroke, TweenInfo.new(0.12), { Thickness = 5, Transparency = 0 })
                :Play()
        end
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(cardStroke, TweenInfo.new(0.12), { Thickness = 3, Transparency = 0.12 })
            :Play()
    end)
    button.Activated:Connect(function()
        if pending then
            return
        end
        setPending(true)
        Signals.StarterPetChoose:FireServer({ petType = choice.id })
    end)
    button.Parent = parent
    cardButtons[#cardButtons + 1] = button
end

local function destroyGui()
    if gui then
        gui:Destroy()
    end
    gui = nil
    panel = nil
    statusLabel = nil
    cardButtons = {}
    pending = false
end

local function show(state)
    if gui then
        destroyGui()
    end
    gui = Instance.new("ScreenGui")
    gui.Name = "StarterPetChoice"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 120

    local dim = Instance.new("Frame")
    dim.Name = "Dim"
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = COLORS.dim
    dim.BackgroundTransparency = 0.18
    dim.Parent = gui

    panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromOffset(1024, 606)
    panel.BackgroundColor3 = COLORS.panel
    corner(panel, 20)
    stroke(panel, COLORS.gold, 4)
    panel.Parent = gui
    UIViewportScale.attach(panel, { min = 0.32 })

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 98)
    header.BackgroundColor3 = Color3.fromRGB(17, 72, 130)
    corner(header, 18)
    header.Parent = panel

    local title = label(
        header,
        "Choose Your First Companion",
        UDim2.new(1, -40, 0, 45),
        UDim2.fromOffset(20, 10),
        Enum.Font.GothamBlack,
        COLORS.white,
        36
    )
    title.TextXAlignment = Enum.TextXAlignment.Center

    local subtitle = label(
        header,
        "Every pet has a combat role. Pick the one that fits how you want to start.",
        UDim2.new(1, -40, 0, 32),
        UDim2.fromOffset(20, 55),
        Enum.Font.GothamMedium,
        Color3.fromRGB(220, 235, 252),
        21
    )
    subtitle.TextXAlignment = Enum.TextXAlignment.Center

    for index, choice in ipairs(state.choices or {}) do
        makeCard(panel, choice, index)
    end

    statusLabel = label(
        panel,
        "Free basic starter • Automatically deployed • Your lucky first egg is still next!",
        UDim2.new(1, -40, 0, 34),
        UDim2.fromOffset(20, 570),
        Enum.Font.GothamMedium,
        COLORS.body,
        19
    )
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center

    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function apply(state)
    if type(state) ~= "table" then
        return
    end
    if state.granted == true then
        destroyGui()
        return
    end
    if state.eligible ~= true then
        destroyGui()
        return
    end
    if state.error and gui then
        setPending(false)
        statusLabel.Text = tostring(state.error)
        statusLabel.TextColor3 = Color3.fromRGB(255, 105, 105)
        return
    end
    if not gui then
        show(state)
    end
end

function StarterPetController.start()
    if started then
        return
    end
    started = true
    Signals.StarterPetState.OnClientEvent:Connect(apply)
    task.spawn(function()
        local player = Players.LocalPlayer
        while player:GetAttribute("ClientUIReady") ~= true do
            player:GetAttributeChangedSignal("ClientUIReady"):Wait()
        end
        Signals.StarterPetStateRequest:FireServer()
    end)
end

return StarterPetController
