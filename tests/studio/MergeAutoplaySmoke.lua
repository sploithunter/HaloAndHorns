-- Isolated actors/wallets; never touches live profiles or grants entitlements to real players.
local RS = game:GetService("ReplicatedStorage")
local Service = require(game.ServerScriptService.Server.Services.MergeAutoplayService)
local Config = require(RS.Configs.merge_autoplay)
local Smoke = {}

function Smoke.run()
    local container = Instance.new("Folder")
    local ok, result = pcall(function()
        local owned, wallets, records, executed = {}, {}, {}, {}
        local function actor(name)
            local attrs = Instance.new("Folder")
            attrs.Parent = container
            local character = Instance.new("Model")
            character.Parent = container
            local root = Instance.new("Part")
            root.Name = "HumanoidRootPart"
            root.Parent = character
            local humanoid = Instance.new("Humanoid")
            humanoid.Parent = character
            local player = { Name = name, Character = character }
            function player:SetAttribute(key, value)
                attrs:SetAttribute(key, value)
            end
            function player:GetAttribute(key)
                return attrs:GetAttribute(key)
            end
            owned[player], wallets[player] = true, 100
            records[player] = { player = player, encounterSpawned = true, waveIndex = 30 }
            return player, root
        end
        local first, root = actor("first")
        local second = actor("second")
        local merge = {
            _recordFor = function(_, player)
                return records[player]
            end,
            _isRecordActive = function(_, record)
                return records[record.player] == record
            end,
            _allowsGameplayActions = function()
                return true
            end,
            _nearestPrototypeCoinDrop = function()
                return nil
            end,
        }
        local service = setmetatable({
            _modules = {
                ConfigLoader = {
                    LoadConfig = function()
                        return Config
                    end,
                },
                MergeEggPrototypeService = merge,
                DataService = {
                    GetFeature = function(_, player)
                        return owned[player]
                    end,
                },
                EconomyService = {
                    GetCurrency = function(_, player)
                        return wallets[player]
                    end,
                },
                Logger = { Info = function() end },
            },
        }, { __index = Service })
        service:Init()
        local host = Instance.new("Part")
        host.Position = Vector3.new(100, 0, 0)
        host.Parent = container
        local currency = Config.currency
        function service:_candidates()
            return {
                {
                    key = "create",
                    kind = "create",
                    category = "eggs",
                    amount = 10,
                    currency = currency,
                    host = host,
                },
            }
        end
        function service:_execute(player)
            executed[player] = (executed[player] or 0) + 1
            wallets[player] -= 10
            return true
        end
        owned[first] = false
        assert(service:_begin(first) == false, "Non-owner started autoplay")
        owned[first] = true
        service:HandleToggle(
            first,
            { enabled = true, testing = true, allowReplacement = true, strategy = "control" }
        )
        assert(service._states[first].testing == false, "Production accepted test options")
        assert(service:_begin(second), "Second player could not start")
        service:_tick(first, service._states[first])
        assert(executed[first] == nil, "Bought from far away")
        root.Position = host.Position
        service:_tick(first, service._states[first])
        assert(executed[first] == 1 and wallets[first] == 90, "Near purchase failed")
        assert(wallets[second] == 100, "Changed another player's wallet")
        currency = "gems"
        service._states[first].nextAction = 0
        service:_tick(first, service._states[first])
        assert(executed[first] == 1, "Gem purchase escaped whitelist")
        local stale = service._states[first]
        records[first] = { player = first, encounterSpawned = true }
        service:_tick(first, stale)
        assert(service._states[first] == nil, "Stale bay session kept running")
        assert(service._states[second] ~= nil, "Stopped another player's session")
        service:HandleToggle(second, { enabled = false })
        assert(service._states[second] == nil, "Stop request failed")
        assert(first:GetAttribute("MergeAutoplayTarget") == nil, "Stop left navigation target")
        -- Production defense planning uses only owned families, preserves the installed one,
        -- and sends the same ordinary workshop requests as the UI.
        local world = Instance.new("Folder")
        world.Parent = container
        local towerFolder = Instance.new("Folder")
        towerFolder.Name = "MergeEggTowers"
        towerFolder.Parent = world
        local cannon = Instance.new("Part")
        cannon:SetAttribute("MergeVendorPosted", true)
        cannon.Parent = towerFolder
        local bulwarkFolder = Instance.new("Folder")
        bulwarkFolder.Name = "MergeEggBulwarks"
        bulwarkFolder.Parent = world
        local engineer = Instance.new("Part")
        engineer:SetAttribute("MergeBulwarkSlot", "lane")
        engineer:SetAttribute("MergeVendorPosted", true)
        engineer.Parent = bulwarkFolder
        local gameConfig = require(RS.Configs.merge_egg_prototype)
        function merge:_edgeTowerConfig()
            return gameConfig.team.edge_towers
        end
        function merge:_edgeBulwarkConfig()
            return gameConfig.team.edge_bulwarks
        end
        function merge:_findArtilleryCommander(_, slot)
            return slot == "left" and cannon or nil
        end
        function merge:_tutorialVendorsReady()
            return true
        end
        function merge:_cannonMenuState()
            return {
                family = "heal",
                tier = 1,
                owned = { heal = 1, gravity = 1 },
                maximumTier = 4,
                slotUnlocked = true,
            }
        end
        function merge:_bulwarkMenuState()
            return {
                tier = 0,
                owned = { impaler_palisade = 1 },
                maximumTier = 4,
                slotUnlocked = true,
            }
        end
        local candidateState = { record = { world = world }, strategy = "control" }
        local candidates = {}
        service:_defenses(candidateState, candidates, "cannon")
        service:_defenses(candidateState, candidates, "bulwark")
        assert(#candidates == 2, "Missing defense candidates")
        assert(
            candidates[1].family == "heal" and candidates[1].operation == "upgrade",
            "Production replaced a cannon"
        )
        assert(
            candidates[2].family == "impaler_palisade" and candidates[2].operation == "select",
            "Did not select owned bulwark"
        )
        for _, candidate in ipairs(candidates) do
            assert(
                candidate.currency == Config.currency and not candidate.replacing,
                "Unsafe defense candidate"
            )
        end
        function merge:PurchaseCannonAction(_, request)
            assert(
                request.cannonAction == "upgrade"
                    and request.family == "heal"
                    and request.slot == "left",
                "Bad cannon dispatch"
            )
            return true
        end
        function merge:PurchaseBulwarkAction(_, request)
            assert(
                request.bulwarkAction == "select"
                    and request.family == "impaler_palisade"
                    and request.slot == "lane",
                "Bad bulwark dispatch"
            )
            return true
        end
        assert(Service._execute(service, first, candidates[1]), "Cannon dispatch failed")
        assert(Service._execute(service, first, candidates[2]), "Bulwark dispatch failed")
        function merge:CreateBaseEgg(_, request)
            assert(
                request.managementBoard == true and request.automation == nil,
                "Bad egg purchase dispatch"
            )
            return true
        end
        function merge:UpgradeBaseEgg(_, request)
            assert(request.managementBoard == true, "Bad egg production dispatch")
            return true
        end
        function merge:EquipBestHatchers()
            return true
        end
        function merge:MergeBoardEggs()
            return true
        end
        for _, kind in ipairs({ "create", "upgrade_base", "place", "merge" }) do
            assert(Service._execute(service, first, { kind = kind }), "Missing ordinary egg action")
        end
        assert(
            Service._execute(service, first, { kind = "rebirth" }) == false,
            "Production dispatcher rebirthed"
        )
        local rebirthCalled = false
        function merge:_rebirthStatus()
            return { price = { currency = "gems", amount = 1 } }
        end
        function merge:PurchaseRebirth(_, request)
            rebirthCalled = request.confirm == true
            return true
        end
        assert(
            service:StudioControl(first, { action = "rebirth" }) == false,
            "Test rebirth did not require opt-in"
        )
        assert(
            service:StudioControl(first, { action = "rebirth", confirmRebirth = true }) == false,
            "Test rebirth spent Gems"
        )
        assert(not rebirthCalled, "Unsafe test rebirth reached gameplay")
        return {
            passed = true,
            farPurchaseBlocked = true,
            gemsBlocked = true,
            sessionIsolation = true,
            productionTestFlagsIgnored = true,
        }
    end)
    container:Destroy()
    assert(ok, result)
    return result
end

return Smoke
