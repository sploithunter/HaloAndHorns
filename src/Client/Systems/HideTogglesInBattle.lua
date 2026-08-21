-- HideTogglesInBattle — persist whether the left pass/toggle column hides
-- while EnemyHud has engaged foes. Default ON.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideTogglesInBattle = {}
local player = Players.LocalPlayer
local started = false
local enabled = true
local userChanged = false

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

local function applyEnabled(value)
    enabled = value ~= false
    player:SetAttribute("HideTogglesInBattle", enabled)
end

function HideTogglesInBattle.isEnabled()
    return enabled
end

function HideTogglesInBattle.setEnabled(value)
    userChanged = true
    applyEnabled(value)
    task.spawn(function()
        callBus("settings.set", { hideTogglesInBattle = enabled })
    end)
end

function HideTogglesInBattle.start()
    if started then
        return
    end
    started = true
    applyEnabled(true)
    task.spawn(function()
        local result = callBus("settings.get")
        if type(result) == "table" and result.ok ~= false and not userChanged then
            applyEnabled(result.hideTogglesInBattle ~= false)
        end
    end)
end

return HideTogglesInBattle
