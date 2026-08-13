-- SquadDisplayState — persisted Classic / Bar / Circle squad HUD preference.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SquadDisplayMode = require(ReplicatedStorage.Shared.Game.SquadDisplayMode)

local SquadDisplayState = {}
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

function SquadDisplayState.start()
    if started then
        return
    end
    started = true
    if player:GetAttribute("SquadDisplayMode") == nil then
        player:SetAttribute("SquadDisplayMode", "classic")
    end

    task.spawn(function()
        local result = callBus("settings.get")
        if result and result.ok then
            player:SetAttribute(
                "SquadDisplayMode",
                SquadDisplayMode.normalize(result.squadDisplayMode)
            )
        end
    end)
end

function SquadDisplayState.getPreference()
    return SquadDisplayMode.normalize(player:GetAttribute("SquadDisplayMode"))
end

function SquadDisplayState.setPreference(mode)
    mode = SquadDisplayMode.normalize(mode)
    player:SetAttribute("SquadDisplayMode", mode)
    task.spawn(function()
        callBus("settings.set", { squadDisplayMode = mode })
    end)
end

return SquadDisplayState
