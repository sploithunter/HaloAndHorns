--[[
    PrologueCinematics — the cold open's two client beats (docs/PROLOGUE.md).

    Pure attribute renderer, same contract as AllianceBanner:
      • PrologueVictory set   -> giant floating VICTORY! over the battle (Jason: "once the
        battle is over... display a giant, like, floating victory above it")
      • InPrologue true -> nil -> the journey-begins hard cut: black flash + caption, selling
        the Future Self preview snapping back to the player's real beginning

    The going-IN caption ("YOUR FUTURE SELF") is NOT here — it lives on the boot screen
    (ReplicatedFirst/BootLoader), which is already black and already up on first runs.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local M = {}

local function captions()
    local ok, cfg = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("prologue", 5))
    end)
    return (ok and type(cfg) == "table" and cfg.caption) or {}
end

local function gui()
    local g = Instance.new("ScreenGui")
    g.Name = "PrologueCinematics"
    g.IgnoreGuiInset = true
    g.ResetOnSpawn = false
    g.DisplayOrder = 900000 -- above the HUD, below the boot screen
    g.Parent = localPlayer:WaitForChild("PlayerGui")
    return g
end

-- Giant gold VICTORY: punches in oversized, settles, floats up and fades.
local function playVictory(text)
    local g = gui()
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(0.85, 0.2)
    label.Position = UDim2.fromScale(0.5, 0.34)
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBlack
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(255, 214, 90)
    label.TextStrokeColor3 = Color3.fromRGB(60, 40, 0)
    label.TextStrokeTransparency = 0.4
    label.TextTransparency = 1
    label.Text = text
    label.Rotation = -4
    label.Parent = g

    local scale = Instance.new("UIScale")
    scale.Scale = 1.6
    scale.Parent = label

    TweenService:Create(
        label,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { TextTransparency = 0, Rotation = 0 }
    ):Play()
    TweenService:Create(
        scale,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    ):Play()
    task.delay(1.6, function()
        TweenService:Create(label, TweenInfo.new(0.9), {
            TextTransparency = 1,
            TextStrokeTransparency = 1,
            Position = UDim2.fromScale(0.5, 0.22), -- the float
        }):Play()
        task.delay(1, function()
            g:Destroy()
        end)
    end)
end

-- The journey-begins cut: a black flash carrying the caption, then a fade into now.
-- `hold` stretches the black — the mid-session ENTRY flash runs long because the warp to
-- the room stalls the client for a beat and wall-clock tweens play through frozen frames.
local function playLanding(text, hold)
    local g = gui()
    local black = Instance.new("Frame")
    black.Size = UDim2.fromScale(1, 1)
    black.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    black.BackgroundTransparency = 1
    black.BorderSizePixel = 0
    black.Parent = g

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(0.9, 0.14)
    label.Position = UDim2.fromScale(0.5, 0.48)
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBlack
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(240, 240, 248)
    label.TextTransparency = 1
    label.Text = text
    label.Parent = black

    TweenService:Create(black, TweenInfo.new(0.15), { BackgroundTransparency = 0 }):Play()
    TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
    task.delay(tonumber(hold) or 1.6, function()
        TweenService:Create(black, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
        task.delay(0.9, function()
            g:Destroy()
        end)
    end)
end

function M.start()
    local cap = captions()
    local wasIn = localPlayer:GetAttribute("InPrologue") == true

    localPlayer:GetAttributeChangedSignal("PrologueVictory"):Connect(function()
        if localPlayer:GetAttribute("PrologueVictory") then
            playVictory(tostring(cap.victory or "VICTORY!"))
        end
    end)

    localPlayer:GetAttributeChangedSignal("InPrologue"):Connect(function()
        local nowIn = localPlayer:GetAttribute("InPrologue") == true
        if wasIn and not nowIn then
            playLanding(tostring(cap.land or "YOUR JOURNEY BEGINS"))
        elseif nowIn and not wasIn then
            -- MID-SESSION ENTRY (admin Reset to Beginning): no boot screen to carry the
            -- title card, so the same black-flash beat plays it — "it should just blank
            -- you out and throw you into the reset."
            playLanding(tostring(cap.cut or "YOUR FUTURE SELF"), 3.4)
        end
        wasIn = nowIn
    end)
end

return M
