-- Isolated profiles: exercise the production publication/completion seams without changing saves.
local RS = game:GetService("ReplicatedStorage")
local Merge = require(game.ServerScriptService.Server.Services.MergeEggPrototypeService)
local People = require(RS.Shared.Game.PeopleList)
local config = require(RS.Configs.people_list)
local Smoke = {}

function Smoke.run()
    local first, second = Instance.new("Folder"), Instance.new("Folder")
    local ok, result = pcall(function()
        local profiles = {
            [first] = { GameData = { MergeDefense = { checkpoint = { wave = 120 } } } },
            [second] = { GameData = { MergeDefense = { highest_completed_wave = 37 } } },
        }
        local service = setmetatable({
            _dataService = {
                GetData = function(_, player)
                    return profiles[player]
                end,
            },
            _waveAwardCatalog = require(RS.Configs.achievement_banners).awards,
        }, Merge)
        service:_mergeDefenseProgress(first)
        service:_mergeDefenseProgress(second)
        service:_recordCompletedWave({ player = first, waveIndex = 121 })
        assert(first:GetAttribute("MergeHighestCompletedWave") == 121)
        assert(
            second:GetAttribute("MergeHighestCompletedWave") == 37,
            "Other player's best changed"
        )
        local progress = profiles[first].GameData.MergeDefense
        progress.checkpoint = {}
        progress.playstate = {}
        progress.rebirths = 10
        service:_recordCompletedWave({ player = first, waveIndex = 1 })
        assert(first:GetAttribute("MergeHighestCompletedWave") == 121, "Rebirth lowered best")
        local row = People.row(config, {}, {
            inMergePlace = true,
            chosenTitle = "Legend",
            mergeHighestCompletedWave = first:GetAttribute("MergeHighestCompletedWave"),
        })
        assert(row.status == "Wave 121" and row.inspect.title == row.status)
        return {
            passed = true,
            first = row.status,
            second = second:GetAttribute("MergeHighestCompletedWave"),
        }
    end)
    first:Destroy()
    second:Destroy()
    assert(ok, result)
    return result
end

return Smoke
