-- Cosmetic hub guidance history; destination visits are observed on the server after arrival.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local config = require(ReplicatedStorage.Configs.crossroads_tutorial)
local places = require(ReplicatedStorage.Configs.places)
local Introduction = {}
local started = false
function Introduction.start(dataService)
    if started then
        return
    end
    started = true
    local function state(player)
        local data = dataService:GetData(player)
        if not data then
            return nil
        end
        data.GameData = data.GameData or {}
        data.GameData.CrossroadsIntroduction = data.GameData.CrossroadsIntroduction or {}
        return data.GameData.CrossroadsIntroduction
    end
    local function record(player, key)
        local saved = state(player)
        if not saved or saved[key] then
            return
        end
        saved[key] = true
        player:SetAttribute(config.progress.attributes[key], true)
        dataService:RequestSave(player, "crossroads_introduction")
    end
    local function observe(player)
        local saved = state(player)
        if not saved then
            return
        end
        -- Loading successfully in the destination counts; a failed outgoing teleport does not.
        if PlaceRuntime.isRole(game.PlaceId, places, "merge") then
            record(player, "siege_visited")
        end
        if player:GetAttribute("CrossroadsFarmEntered") == true then
            record(player, "farm_visited")
        end
        for key, attribute in pairs(config.progress.attributes) do
            player:SetAttribute(attribute, saved[key] == true)
        end
        player:SetAttribute(config.progress.ready_attribute, true)
    end
    local function watch(player)
        player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
            observe(player)
        end)
        player:GetAttributeChangedSignal("CrossroadsFarmEntered"):Connect(function()
            observe(player)
        end)
        observe(player)
    end
    Signals.CrossroadsIntroCompleted.OnServerEvent:Connect(function(player, key)
        if player:GetAttribute("InCrossroads") ~= true then
            return
        end
        if key == "welcome" or key == "hell_handoff" or key == "heaven_return" then
            record(player, key)
        end
    end)
    Players.PlayerAdded:Connect(watch)
    for _, player in ipairs(Players:GetPlayers()) do
        watch(player)
    end
end
return Introduction
