-- Cosmetic client narration may briefly defer a requested gate, never lock movement.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local config = require(ReplicatedStorage.Configs.crossroads_tutorial)
local Dialogue = {}
local started = false
local pending = setmetatable({}, { __mode = "k" })
local deadlines = setmetatable({}, { __mode = "k" })
local function finish(player, deadline)
    if deadline and deadlines[player] ~= deadline then
        return
    end
    deadlines[player] = nil
    local callback = pending[player]
    pending[player] = nil
    if callback and player.Parent then
        callback()
    end
end
function Dialogue.start()
    if started then
        return
    end
    started = true
    Players.PlayerRemoving:Connect(function(player)
        pending[player], deadlines[player] = nil, nil
    end)
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        for player, deadline in pairs(deadlines) do
            if now >= deadline then
                finish(player, deadline)
            end
        end
    end)
    Signals.CrossroadsDialogueActive.OnServerEvent:Connect(function(player, active)
        if type(active) ~= "boolean" then
            return
        end
        if not active then
            finish(player)
        elseif
            config.enabled
            and player:GetAttribute("InCrossroads") == true
            and not deadlines[player]
        then
            local deadline = os.clock() + config.dialogue_timeout_seconds
            deadlines[player] = deadline
        end
    end)
end
function Dialogue.defer(player, callback)
    local deadline = deadlines[player]
    if deadline and os.clock() < deadline then
        -- One gate intent, never a queue of repeated touch callbacks.
        pending[player] = pending[player] or callback
        return true
    end
    return false
end
return Dialogue
