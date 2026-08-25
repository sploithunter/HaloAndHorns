--[[
    CombatTutorialRedoPrompt — Yes/No for combat-training cave prompts.

    Redo: E at the Earth cave after they already finished the track.
    Leave: Continue later on the frost-door SurfaceGui — leave without completing?

    Styled like RealmTravelPrompt (dark rounded panel, gold stroke, Gotham).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local CombatTutorialRedoPrompt = {}
local started = false

function CombatTutorialRedoPrompt.start()
    if started then
        return
    end
    started = true

    local player = Players.LocalPlayer

    local gui = Instance.new("ScreenGui")
    gui.Name = "CombatTutorialRedoPrompt"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 60
    gui.Enabled = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.Size = UDim2.fromOffset(380, 176)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = frame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 200, 90)
    stroke.Thickness = 2
    stroke.Transparency = 0.15
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -24, 0, 30)
    title.Position = UDim2.fromOffset(12, 14)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "Combat Training"
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local body = Instance.new("TextLabel")
    body.Name = "Body"
    body.Size = UDim2.new(1, -24, 0, 48)
    body.Position = UDim2.fromOffset(12, 48)
    body.BackgroundTransparency = 1
    body.Font = Enum.Font.Gotham
    body.TextSize = 16
    body.TextColor3 = Color3.fromRGB(225, 225, 225)
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.Text = ""
    body.Parent = frame

    local function makeButton(name, text, xScale, color)
        local button = Instance.new("TextButton")
        button.Name = name
        button.AnchorPoint = Vector2.new(0.5, 1)
        button.Position = UDim2.new(xScale, 0, 1, -14)
        button.Size = UDim2.new(0.5, -18, 0, 40)
        button.BackgroundColor3 = color
        button.TextColor3 = Color3.new(1, 1, 1)
        button.Font = Enum.Font.GothamBold
        button.TextSize = 17
        button.AutoButtonColor = true
        button.Text = text
        button.Parent = frame
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 10)
        buttonCorner.Parent = button
        return button
    end
    local noBtn = makeButton("No", "Not now", 0.28, Color3.fromRGB(90, 90, 100))
    local yesBtn = makeButton("Yes", "Redo", 0.72, Color3.fromRGB(46, 140, 80))

    local function close()
        gui.Enabled = false
    end

    local function answer(accepted)
        close()
        Signals.CombatTutorialRedoAnswer:FireServer(accepted == true)
    end

    Signals.CombatTutorialRedoOffer.OnClientEvent:Connect(function(payload)
        if type(payload) ~= "table" then
            return
        end
        title.Text = tostring(payload.title or "Combat Training")
        body.Text = tostring(payload.body or "You've already finished this. Redo the training?")
        yesBtn.Text = tostring(payload.yes_text or "Redo")
        noBtn.Text = tostring(payload.no_text or "Not now")
        gui.Enabled = true
    end)

    yesBtn.Activated:Connect(function()
        answer(true)
    end)
    noBtn.Activated:Connect(function()
        answer(false)
    end)

    player.CharacterAdded:Connect(close)
end

return CombatTutorialRedoPrompt
