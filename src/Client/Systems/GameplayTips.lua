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
local currentIndex = 0
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
            currentIndex = GameplayTipRotation.nextIndex(currentIndex, #config.tips) or 0
            local tip = config.tips[currentIndex]
            if tip and QuestTrackerStyle.showTip(tip) then
                tipActive = true
                tipElapsed = 0
            end
        end
    end)
end

return GameplayTips
