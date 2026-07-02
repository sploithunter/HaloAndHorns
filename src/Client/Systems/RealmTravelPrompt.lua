--[[
    RealmTravelPrompt — client yes/no confirmation for realm portals.

    When you TOUCH a realm portal whose realm is built, the server (RealmPortalService) sends a
    Signals.RealmTravelOffer { layer, label }. This shows a centre-screen confirm with the label
    (e.g. "Travel to Heaven 1?" / "Return to Home?") and Yes/No buttons. Yes fires
    Signals.RealmTravelConfirm { layer } back; the server validates it against the offer it sent and
    teleports via LayerService. No (or touching away / a new offer) just dismisses.

    Styled to match ZoneUnlockPrompt (the in-world prompt look Jason has accepted) — dark rounded
    panel, gold stroke, Gotham. Single live offer at a time.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local RealmTravelPrompt = {}
local started = false

function RealmTravelPrompt.start()
    if started then
        return
    end
    started = true

    local player = Players.LocalPlayer

    local gui = Instance.new("ScreenGui")
    gui.Name = "RealmTravelPrompt"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 60 -- above the unlock prompt
    gui.Enabled = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.Size = UDim2.fromOffset(360, 150)
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
    title.Size = UDim2.new(1, -24, 0, 30)
    title.Position = UDim2.fromOffset(12, 14)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "🌀 Travel"
    title.Parent = frame

    local body = Instance.new("TextLabel")
    body.Name = "Body"
    body.Size = UDim2.new(1, -24, 0, 30)
    body.Position = UDim2.fromOffset(12, 48)
    body.BackgroundTransparency = 1
    body.Font = Enum.Font.Gotham
    body.TextSize = 16
    body.TextColor3 = Color3.fromRGB(225, 225, 225)
    body.Text = ""
    body.Parent = frame

    local function makeButton(name, text, xScale, color)
        local b = Instance.new("TextButton")
        b.Name = name
        b.AnchorPoint = Vector2.new(0.5, 1)
        b.Position = UDim2.new(xScale, 0, 1, -14)
        b.Size = UDim2.new(0.5, -18, 0, 40)
        b.BackgroundColor3 = color
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 17
        b.AutoButtonColor = true
        b.Text = text
        b.Parent = frame
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 10)
        c.Parent = b
        return b
    end
    -- Yes on the left, No on the right (each fills its half).
    local yesBtn = makeButton("Yes", "Travel", 0.27, Color3.fromRGB(70, 170, 90))
    local noBtn = makeButton("No", "Cancel", 0.74, Color3.fromRGB(90, 90, 100))

    local activeLayer = nil
    local function close()
        gui.Enabled = false
        activeLayer = nil
    end

    Signals.RealmTravelOffer.OnClientEvent:Connect(function(payload)
        if type(payload) ~= "table" or type(payload.layer) ~= "string" then
            return
        end
        activeLayer = payload.layer
        body.Text = tostring(payload.label or "Travel here?")
        -- A `locked` offer (level too low) is informational — hide the Travel button so it's a
        -- dismiss-only "Reach Level N" notice, not a Yes/No the server would just reject.
        yesBtn.Visible = payload.locked ~= true
        gui.Enabled = true
    end)

    yesBtn.Activated:Connect(function()
        if not activeLayer then
            return
        end
        Signals.RealmTravelConfirm:FireServer({ layer = activeLayer })
        close()
    end)
    noBtn.Activated:Connect(close)

    -- Dismiss if the character respawns (e.g. just after travelling) so a stale prompt doesn't linger.
    player.CharacterAdded:Connect(close)
end

return RealmTravelPrompt
