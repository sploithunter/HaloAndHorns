-- QuestDisplayState — persisted Full Bar / Compact Pill / Progress Ring preference.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestDisplayMode = require(ReplicatedStorage.Shared.Game.QuestDisplayMode)

local QuestDisplayState = {}
local player = Players.LocalPlayer
local started = false

local function callBus(name, args)
    local remote = ReplicatedStorage:WaitForChild("GameAPICommand")
    local ok, envelope = pcall(function()
        return remote:InvokeServer(name, args or {})
    end)
    if ok and type(envelope) == "table" then
        return envelope.result
    end
    return nil
end

function QuestDisplayState.start()
    if started then
        return
    end
    started = true
    if player:GetAttribute("QuestDisplayMode") == nil then
        player:SetAttribute("QuestDisplayMode", "full")
    end

    task.spawn(function()
        local result = callBus("settings.get")
        if result and result.ok then
            player:SetAttribute(
                "QuestDisplayMode",
                QuestDisplayMode.normalize(result.questDisplayMode)
            )
        end
    end)
end

function QuestDisplayState.getPreference()
    return QuestDisplayMode.normalize(player:GetAttribute("QuestDisplayMode"))
end

function QuestDisplayState.setPreference(mode)
    mode = QuestDisplayMode.normalize(mode)
    player:SetAttribute("QuestDisplayMode", mode)
    task.spawn(function()
        callBus("settings.set", { questDisplayMode = mode })
    end)
end

return QuestDisplayState
