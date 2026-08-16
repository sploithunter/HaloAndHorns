--[[
    GameplayTips (client) — briefly borrow the compact quest tracker for one learning point.

    A tip starts once per configured interval, remains for the configured display window, and then
    restores the live quest/mission layers. The preference is profile-backed through settings.get /
    settings.set and defaults on for new players.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
local GameplayTipRotation = require(ReplicatedStorage.Shared.Game.GameplayTipRotation)
local QuestTrackerStyle = require(script.Parent.QuestTrackerStyle)

local GameplayTips = {}
local started = false
local enabled = true
local userChanged = false
local loadResolved = false
local loadBusy = false
local loadAttempts = 0
local nextLoadAttemptAt = 0
local random = Random.new()
local tipOrder = {}
local tipCursor = 0
local lastTipIndex = nil
local cycleElapsed = 0
local tipElapsed = 0
local tipActive = false

local config = ConfigLoader:LoadConfig("gameplay_tips") or {}
local validConfig = GameplayTipRotation.validate(config)

local function callBus(name, args)
    local remote = ReplicatedStorage:FindFirstChild("GameAPICommand")
    if not remote then
        return nil
    end
    local ok, envelope = pcall(function()
        return remote:InvokeServer(name, args or {})
    end)
    if not ok or type(envelope) ~= "table" then
        return nil
    end
    return envelope.result or envelope.data or envelope
end

local function hideTip()
    if tipActive then
        QuestTrackerStyle.hideTip()
    end
    tipActive = false
    tipElapsed = 0
end

local function applyEnabled(value)
    enabled = value ~= false
    cycleElapsed = 0
    if not enabled then
        hideTip()
    end
end

local function nextTip()
    if tipCursor >= #tipOrder then
        tipOrder = GameplayTipRotation.shuffledIndices(#config.tips, function(minimum, maximum)
            return random:NextInteger(minimum, maximum)
        end)
        -- A deck boundary should not repeat the tip that just finished the prior deck.
        if #tipOrder > 1 and tipOrder[1] == lastTipIndex then
            tipOrder[1], tipOrder[2] = tipOrder[2], tipOrder[1]
        end
        tipCursor = 0
    end
    tipCursor += 1
    lastTipIndex = tipOrder[tipCursor]
    return lastTipIndex and config.tips[lastTipIndex] or nil
end

local function requestLoad()
    if loadResolved or loadBusy or loadAttempts >= 30 then
        return
    end
    loadBusy = true
    loadAttempts += 1
    task.spawn(function()
        local result = callBus("settings.get")
        loadBusy = false
        if type(result) == "table" and result.ok ~= false then
            loadResolved = true
            if not userChanged then
                applyEnabled(result.displayTips ~= false)
            end
            return
        end
        local retrySeconds = loadAttempts <= 5 and 0.5 or 2
        nextLoadAttemptAt = os.clock() + retrySeconds
    end)
end

function GameplayTips.isEnabled()
    return enabled
end

function GameplayTips.setEnabled(value)
    userChanged = true
    applyEnabled(value)
    task.spawn(function()
        callBus("settings.set", { displayTips = enabled })
    end)
end

function GameplayTips.start()
    if started then
        return
    end
    started = true
    if not validConfig then
        return
    end

    requestLoad()
    RunService.Heartbeat:Connect(function(dt)
        if not loadResolved and not loadBusy and os.clock() >= nextLoadAttemptAt then
            requestLoad()
        end
        if not enabled then
            return
        end

        -- Never cover or delay a quest reward. While a claim is available, cancel any active tip
        -- and pause the one-minute rotation so the next tip does not appear immediately after the
        -- player claims it.
        if QuestTrackerStyle.isClaimAvailable() then
            hideTip()
            return
        end

        cycleElapsed += dt
        if tipActive then
            tipElapsed += dt
            local displaySeconds = tonumber(config.display_seconds) or 10
            QuestTrackerStyle.setTipProgress(1 - (tipElapsed / displaySeconds))
            if tipElapsed >= displaySeconds then
                hideTip()
            end
        end

        local intervalSeconds = tonumber(config.interval_seconds) or 60
        if not tipActive and cycleElapsed >= intervalSeconds then
            cycleElapsed %= intervalSeconds
            local tip = nextTip()
            if tip and QuestTrackerStyle.showTip(tip) then
                tipActive = true
                tipElapsed = 0
            end
        end
    end)
end

return GameplayTips
