-- Server-side isolated fixtures. Reads authored spawn positions; never moves real players,
-- claims live bays, or reads/writes ProfileStore. Run after starting Play in the Merge place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = game:GetService("ServerScriptService").Server.Services
local Tracker = require(Services.ZoneTrackerService)
local Merge = require(Services.MergeEggPrototypeService)
local Smoke = {}

function Smoke.run()
    local characters = {}
    local ok, result = pcall(function()
        local configs = ReplicatedStorage.Configs
        local mergeArea = require(configs.places).roles.merge.initial_area
        local function tracker(role)
            local instance = setmetatable({
                _modules = {
                    ConfigLoader = {
                        LoadConfig = function(_, name)
                            if name == "places" then
                                return {
                                    default_role = role,
                                    roles = { [role] = { initial_area = mergeArea } },
                                }
                            end
                            return require(configs[name])
                        end,
                    },
                },
            }, Tracker)
            instance:Init()
            return instance
        end
        local mergeTracker = tracker("merge")
        mergeTracker._resolveByRaycast = function()
            error("Dedicated Merge must not consult Home floor detection")
        end
        local roster = {}
        for id = 1, 3 do
            local character = Instance.new("Model")
            characters[#characters + 1] = character
            local root = Instance.new("Part")
            root.Name = "HumanoidRootPart"
            root.Parent = character
            local attributes = { CurrentArea = mergeArea }
            roster[id] = {
                Name = "EntryFixture" .. id,
                Character = character,
                attributes = attributes,
                GetAttribute = function(_, key)
                    return attributes[key]
                end,
                SetAttribute = function(_, key, value)
                    attributes[key] = value
                end,
            }
        end
        local checked = 0
        for _, spawn in ipairs(workspace:GetDescendants()) do
            if spawn:IsA("BasePart") and spawn.Name == "HatcherSpawn" then
                checked += 1
                roster[3].Character.HumanoidRootPart.Position = spawn.Position
                for _ = 1, 4 do
                    for _, player in ipairs(roster) do
                        mergeTracker:_resolveFor(player)
                        assert(player.attributes.CurrentArea == mergeArea, spawn:GetFullName())
                    end
                end
            end
        end
        assert(checked == 10, "Expected all ten authored bays")
        local player = roster[3]
        player.Character = nil
        player.attributes.CurrentArea = "Lava"
        mergeTracker:_resolveFor(player)
        assert(player.attributes.CurrentArea == mergeArea, "Pending entry/respawn area")
        player.attributes.InMission = true
        player.attributes.MissionTheme = "hell"
        mergeTracker:_resolveFor(player)
        assert(player.attributes.CurrentArea == "mission_hell", "Mission priority")
        player.attributes.InMission = nil
        mergeTracker:_resolveFor(player)
        assert(player.attributes.CurrentArea == mergeArea, "Mission return")

        player.Character = characters[3]
        local mainTracker = tracker("main")
        mainTracker._resolveByRaycast = function()
            return "Lava"
        end
        mainTracker:_resolveFor(player)
        assert(player.attributes.CurrentArea == "Lava", "Farm & Fight detection unchanged")

        local progress = { playstate = { saved = true, coins = 999 }, checkpoint = { wave = 20 } }
        local oldPlaystate, oldCheckpoint = progress.playstate, progress.checkpoint
        local saves = 0
        local merge = setmetatable({
            _economyService = {
                GetCurrency = function()
                    return 100
                end,
            },
            _dataService = {
                RequestSave = function()
                    saves += 1
                end,
            },
            _mergeDefenseProgress = function()
                return progress
            end,
            _earthEggPricing = function()
                return { currency = "test_coins" }
            end,
            _checkpointOptions = function()
                return { interval = 10, maximumTier = 9, maximumTeams = 9 }
            end,
            _eggInventoryTotal = function()
                return 1
            end,
            _initializedHatcherCount = function()
                return 0
            end,
            _baseEggTier = function()
                return 1
            end,
        }, Merge)
        local record = {
            player = player,
            entryInitializing = true,
            encounterSpawned = true,
            checkpointSnapshot = { wave = 0 },
            teams = {},
            eggInventory = { [1] = 1 },
        }
        assert(
            merge:_persistPlaystate(record, "canceled_entry", true) == false,
            "Partial playstate saved"
        )
        assert(merge:_persistCheckpoint(record) == false, "Partial checkpoint saved")
        assert(
            progress.playstate == oldPlaystate and progress.checkpoint == oldCheckpoint,
            "Durable state changed"
        )
        assert(saves == 0, "Canceled entry requested a save")
        record.entryInitializing = false
        assert(
            merge:_persistPlaystate(record, "ready_entry", true) == true,
            "Ready playstate not saved"
        )
        assert(saves == 1 and progress.playstate ~= oldPlaystate, "Ready session must still save")
        return {
            passed = true,
            simultaneousFixtures = #roster,
            authoredBays = checked,
            canceledEntryPreserved = true,
            readySessionSaved = true,
        }
    end)
    for _, character in ipairs(characters) do
        character:Destroy()
    end
    assert(ok, result)
    return result
end

return Smoke
