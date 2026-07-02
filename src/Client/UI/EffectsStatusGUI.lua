--[[
    EffectsStatusGUI - Shows active effects and their remaining time
    
    Features:
    - Real-time effect countdown
    - Effect descriptions and bonuses
    - Auto-refresh when effects change
    - Compact, non-intrusive design
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Get network bridge
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local EffectsStatusGUI = {}

-- Active effects data (updated from server)
local activeEffects = {}
local gui = nil
local effectsFrame = nil
local noEffectsLabel = nil

function EffectsStatusGUI:Init()
    self:CreateGUI()
    self:StartUpdateLoop()
    self:ConnectToNetwork()

    -- Request initial effects data
    self:RequestEffectsUpdate()

    print("⚡ Effects Status GUI loaded!")
end

function EffectsStatusGUI:CreateGUI()
    -- Main ScreenGui
    gui = Instance.new("ScreenGui")
    gui.Name = "EffectsStatusGUI"
    gui.Parent = playerGui

    -- Main frame (top-right corner)
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 300, 0, 200)
    mainFrame.Position = UDim2.new(1, -320, 0, 20) -- Top-right corner
    mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    mainFrame.BackgroundTransparency = 0.3
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 8)
    mainCorner.Parent = mainFrame

    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 30)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "⚡ Active Effects"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = mainFrame

    -- Effects container
    effectsFrame = Instance.new("ScrollingFrame")
    effectsFrame.Size = UDim2.new(1, -10, 1, -40)
    effectsFrame.Position = UDim2.new(0, 5, 0, 35)
    effectsFrame.BackgroundTransparency = 1
    effectsFrame.BorderSizePixel = 0
    effectsFrame.ScrollBarThickness = 4
    effectsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    effectsFrame.Parent = mainFrame

    local effectsLayout = Instance.new("UIListLayout")
    effectsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    effectsLayout.Padding = UDim.new(0, 5)
    effectsLayout.Parent = effectsFrame

    -- No effects label (shown when no effects active)
    noEffectsLabel = Instance.new("TextLabel")
    noEffectsLabel.Size = UDim2.new(1, 0, 1, 0)
    noEffectsLabel.BackgroundTransparency = 1
    noEffectsLabel.Text = "No active effects"
    noEffectsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    noEffectsLabel.TextScaled = true
    noEffectsLabel.Font = Enum.Font.Gotham
    noEffectsLabel.Parent = effectsFrame
    noEffectsLabel.Visible = true
end

function EffectsStatusGUI:UpdateEffectsDisplay()
    -- Clear existing effect displays
    for _, child in ipairs(effectsFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    local effectCount = 0
    for effectId, effectData in pairs(activeEffects) do
        effectCount = effectCount + 1
        self:CreateEffectDisplay(effectId, effectData, effectCount)
    end

    -- Show/hide no effects label
    noEffectsLabel.Visible = (effectCount == 0)

    -- Update canvas size
    effectsFrame.CanvasSize = UDim2.new(0, 0, 0, effectCount * 65)
end

function EffectsStatusGUI:CreateEffectDisplay(effectId, effectData, index)
    local effectFrame = Instance.new("Frame")
    effectFrame.Size = UDim2.new(1, -8, 0, 60)
    effectFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    effectFrame.BorderSizePixel = 0
    effectFrame.LayoutOrder = index
    effectFrame.Parent = effectsFrame

    local effectCorner = Instance.new("UICorner")
    effectCorner.CornerRadius = UDim.new(0, 4)
    effectCorner.Parent = effectFrame

    -- Effect name (configuration-driven)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.7, 0, 0, 20)
    nameLabel.Position = UDim2.new(0, 5, 0, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = effectData.name or effectData.icon .. " " .. effectId -- Use config-driven name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = effectFrame

    -- Time remaining
    local timeLabel = Instance.new("TextLabel")
    timeLabel.Size = UDim2.new(0.3, -5, 0, 20)
    timeLabel.Position = UDim2.new(0.7, 0, 0, 5)
    timeLabel.BackgroundTransparency = 1
    timeLabel.Text = self:FormatTimeRemaining(effectData.timeRemaining)
    timeLabel.TextColor3 = self:GetTimeColor(effectData.timeRemaining)
    timeLabel.TextScaled = true
    timeLabel.Font = Enum.Font.Gotham
    timeLabel.TextXAlignment = Enum.TextXAlignment.Right
    timeLabel.Parent = effectFrame

    -- Effect description
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -10, 0, 35)
    descLabel.Position = UDim2.new(0, 5, 0, 25)
    descLabel.BackgroundTransparency = 1

    local description = effectData.description or "No description"
    if effectData.usesRemaining and effectData.usesRemaining ~= -1 then
        description = description .. string.format(" (%d uses left)", effectData.usesRemaining)
    end
    descLabel.Text = description

    descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    descLabel.TextSize = 11
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.TextWrapped = true
    descLabel.Parent = effectFrame

    -- Store reference for updates
    effectFrame.Name = "Effect_" .. effectId
    effectFrame:SetAttribute("TimeLabel", timeLabel)
end

function EffectsStatusGUI:StartUpdateLoop()
    -- No client-side timers needed - server sends real-time updates
    -- This method kept for compatibility but does nothing
    print("⚡ Effects GUI using server-authoritative timers")
end

function EffectsStatusGUI:UpdateTimerDisplays()
    for effectId, effectData in pairs(activeEffects) do
        local effectFrame = effectsFrame:FindFirstChild("Effect_" .. effectId)
        if effectFrame then
            local timeLabel = effectFrame:FindFirstChild("TextLabel")
            if timeLabel and timeLabel.TextXAlignment == Enum.TextXAlignment.Right then
                timeLabel.Text = self:FormatTimeRemaining(effectData.timeRemaining)
                timeLabel.TextColor3 = self:GetTimeColor(effectData.timeRemaining)
            end
        end
    end

    -- Check if we need to rebuild (expired effects)
    local hasExpired = false
    for effectId, effectData in pairs(activeEffects) do
        if effectData.timeRemaining <= 0 and effectData.expiresAt ~= -1 then
            hasExpired = true
            break
        end
    end

    if hasExpired then
        self:UpdateEffectsDisplay()
    end
end

function EffectsStatusGUI:ConnectToNetwork()
    -- Connect to ActiveEffects RemoteEvent
    Signals.ActiveEffects.OnClientEvent:Connect(function(packetData)
        self:UpdateFromServer(packetData)
    end)
end

function EffectsStatusGUI:RequestEffectsUpdate()
    -- Request effect data from server using the new packet
    Signals.ActiveEffects:FireServer({ request = true })
end

function EffectsStatusGUI:UpdateFromServer(packetData)
    -- Handle unified effects message from server player clock
    local effectsData = packetData.effects or packetData -- Backward compatibility

    print("🔧 EffectsStatusGUI:UpdateFromServer called with:", effectsData)

    -- Server sends authoritative data with calculated timeRemaining
    activeEffects = {}

    for effectId, effectInfo in pairs(effectsData or {}) do
        activeEffects[effectId] = {
            id = effectInfo.id or effectId,
            name = effectInfo.name or effectId, -- Configuration-driven display name
            description = effectInfo.description or "Effect active",
            multiplier = effectInfo.multiplier or 1.0,
            actions = effectInfo.actions or {},
            usesRemaining = effectInfo.usesRemaining or -1,
            timeRemaining = effectInfo.timeRemaining or -1, -- Server calculates this
            permanent = effectInfo.permanent or false,
            icon = effectInfo.icon or "✨",
        }
    end

    print("🔧 Processed activeEffects:", activeEffects)

    self:UpdateEffectsDisplay()

    -- Debug log for unified player clock
    if packetData.playerClock then
        print("⏰ Player clock update:", next(effectsData) and "has effects" or "no effects")
    end
end

-- Helper functions

function EffectsStatusGUI:FormatTimeRemaining(timeRemaining)
    if timeRemaining == -1 then
        return "Permanent"
    elseif timeRemaining <= 0 then
        return "Expired"
    elseif timeRemaining < 60 then
        return string.format("%ds", math.ceil(timeRemaining))
    elseif timeRemaining < 3600 then
        return string.format(
            "%dm %ds",
            math.floor(timeRemaining / 60),
            math.ceil(timeRemaining % 60)
        )
    else
        return string.format(
            "%dh %dm",
            math.floor(timeRemaining / 3600),
            math.floor((timeRemaining % 3600) / 60)
        )
    end
end

function EffectsStatusGUI:GetTimeColor(timeRemaining)
    if timeRemaining == -1 then
        return Color3.fromRGB(100, 255, 100) -- Green for permanent
    elseif timeRemaining <= 0 then
        return Color3.fromRGB(150, 150, 150) -- Gray for expired
    elseif timeRemaining < 30 then
        return Color3.fromRGB(255, 100, 100) -- Red for expiring soon
    elseif timeRemaining < 120 then
        return Color3.fromRGB(255, 255, 100) -- Yellow for low time
    else
        return Color3.fromRGB(100, 255, 100) -- Green for good time
    end
end

-- DISABLED: Auto-initialization removed to prevent UI overlap with new MenuManager system
-- EffectsStatusGUI:Init()

-- Make globally accessible for packet handlers (but no longer auto-initialized)
_G.EffectsStatusGUI = EffectsStatusGUI

return EffectsStatusGUI
