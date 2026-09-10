local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gate = require(script.Parent.CrossroadsTutorialGate)
local PlaceRuntime = require(script.Parent.PlaceRuntime)
local areas = require(ReplicatedStorage.Configs.areas)
local places = require(ReplicatedStorage.Configs.places)
local Onboarding = {}
function Onboarding.pending(player)
    local cfg = areas.crossroads
    return Gate.pending(
        cfg
            and cfg.enabled
            and (
                workspace:FindFirstChild(cfg.root_name) ~= nil
                or player:GetAttribute("InCrossroads") == true
            ),
        PlaceRuntime.isRole(game.PlaceId, places, "main"),
        player:GetAttribute("InCrossroads"),
        player:GetAttribute("CrossroadsFarmEntered")
    )
end
return Onboarding
