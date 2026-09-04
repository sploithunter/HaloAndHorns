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
        local service = setmetatable(
            {
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
            },
            { __index = Service }
        )
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
