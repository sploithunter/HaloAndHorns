-- Pass isolated fresh-source classes; never call live services, profiles, rewards or analytics.
local Smoke = {}
function Smoke.run(Prototype, Enemy, Refresh, Hotbar)
    local container = Instance.new("Folder")
    local ok, result = pcall(function()
        local function pet(power, parent)
            local model = Instance.new("Model")
            local root = Instance.new("Part")
            root.Name, root.Anchored, root.Parent = "HumanoidRootPart", true, model
            model.PrimaryPart = root
            local value = Instance.new("NumberValue")
            value.Name, value.Value, value.Parent = "Power", power, model
            local slot = Instance.new("IntValue")
            slot.Name, slot.Value, slot.Parent = "PositionNumber", 1, model
            model.Parent = parent
            return model
        end
        local folder = Instance.new("Folder")
        folder.Parent = container
        local old = pet(100, folder)
        old:SetAttribute("CombatDamageTaken", 20)
        old:SetAttribute("NpcCombatPosition", Vector3.new(12, 4, 8))
        local oldDefinition = { pet = "doggy", combatPower = 100, role = "melee" }
        local better = { pet = "dragon", combatPower = 200, role = "melee" }
        local team = {
            id = "test",
            folder = folder,
            units = { old },
            eggTier = 2,
            expectedPets = 1,
            principalModel = pet(1, container),
            config = { squad = { oldDefinition } },
        }
        local record = { player = { Name = "isolated" }, teams = { team } }
        local config = {
            reinforcement = {
                hatch_seconds = 4,
                stronger_refresh = {
                    enabled = true,
                    attempts_per_slot = 1,
                    minimum_power_ratio = 1.1,
                },
            },
        }
        local created, failAssets, active = nil, true, true
        local service = setmetatable({
            _config = config,
            _isRecordActive = function()
                return active
            end,
            _prototypeBaseLevel = function()
                return 1
            end,
            _petDefenseMultiplier = function()
                return 1
            end,
            _recordEggRoll = function() end,
            _publishTeamSlot = function() end,
            _ensurePlayerEscort = function() end,
            _replacementQueueDepth = function()
                return 1
            end,
            _log = function() end,
            _npcPrincipalService = {
                SpawnGhostSquad = function(_, target)
                    if failAssets then
                        return 0, {}
                    end
                    created = pet(200, target)
                    return 1, { created }
                end,
            },
        }, { __index = Prototype })
        local queued = {
            slot = 1,
            definition = better,
            upgradeFrom = old,
            upgradeDefinition = oldDefinition,
            upgradeTier = 2,
        }
        assert(not service:_spawnReplacement(record, team, queued, 1), "Missing asset accepted")
        assert(
            old.Parent == folder and team.config.squad[1] == oldDefinition,
            "Failed asset erased pet"
        )
        failAssets, active = false, false
        assert(not service:_spawnReplacement(record, team, queued, 1), "Stale record accepted")
        assert(old.Parent == folder and created.Parent == nil, "Stale refresh changed roster")
        active = true
        assert(service:_spawnReplacement(record, team, queued, 1), "Stronger swap failed")
        assert(
            old.Parent == nil and team.config.squad[1] == better,
            "Squad definition not committed"
        )
        assert(created:GetAttribute("CombatDamageTaken") == 40, "Refresh healed pet")
        assert(created:GetPivot().Position == Vector3.new(12, 4, 8), "Refresh teleported pet")
        team.units = { created }
        local rolls = 0
        service._draftRollsForEggTier = function()
            return 1
        end
        service._rollPrototypePet = function()
            rolls += 1
            return oldDefinition
        end
        service._recordDraftCandidate = function() end
        service._syncTeamState = function() end
        Refresh.schedule(service, team)
        team.replacementQueue = { { slot = 2 } }
        Refresh.step(service, record, team, os.clock() + 10)
        assert(rolls == 0, "Refresh competed with missing-slot reinforcements")
        team.replacementQueue = {}
        Refresh.step(service, record, team, os.clock() + 10)
        assert(rolls == 1 and team.strongerRefreshRemaining == 0, "Wrong refresh budget")
        Refresh.step(service, record, team, os.clock() + 100)
        assert(
            rolls == 1 and created.Parent == folder,
            "Weaker roll displaced survivor or repeated forever"
        )

        local trained = false
        local player = {
            Parent = true,
            Name = "isolated",
            GetAttribute = function(_, key)
                if key == "MergeEggPlayerCombatMode" then
                    return "full"
                end
                if key == "CombatTutorialDone" then
                    return trained
                end
            end,
        }
        Enemy._actors[5] = player
        local enemyModel = pet(1, container)
        enemyModel:SetAttribute("MergeEggPrototypeEnemy", true)
        enemyModel:SetAttribute("MergeEggPlayerPetKillUserId", 5)
        enemyModel:SetAttribute("MergeEggCombatXpMultiplier", 1)
        enemyModel:SetAttribute("Level", 3)
        enemyModel:SetAttribute("EnemyTier", "minion")
        local counts = { potions = 0, enhancements = 0, xp = 0, loot = 0 }
        local entry = {
            model = enemyModel,
            rewardPolicy = "none",
            enemyId = "test",
            pos = Vector3.new(100, 4, 200),
            def = { element = "ice" },
        }
        local enemyService = setmetatable({
            _enemies = { [1] = entry },
            _enemiesConfig = { enemies = {} },
            _clearEnemyFromPetThreat = function() end,
            _mergeXpParticipants = function()
                return {}, 0
            end,
            _releasePets = function() end,
            _playDefeatDeath = function() end,
            _eventModifier = function()
                return 0
            end,
            _combatService = function()
                return {
                    AwardExperience = function()
                        counts.xp += 1
                    end,
                    AwardLoot = function()
                        counts.loot += 1
                    end,
                }
            end,
            _dropService = {
                TrySpawnEnhancementDrop = function(_, who, source, position, opts)
                    assert(
                        who == player and source == "enemy" and position == entry.pos,
                        "Wrong enhancement owner/site"
                    )
                    assert(
                        opts.enemy_origin_locked and opts.enemy_element == "ice",
                        "Wrong defeated origin"
                    )
                    counts.enhancements += 1
                end,
                TrySpawnPotionDrop = function(_, who, source, position)
                    assert(
                        who == player and source == "enemy" and position == entry.pos,
                        "Wrong potion owner/site"
                    )
                    counts.potions += 1
                end,
            },
        }, { __index = Enemy })
        enemyService:_onDefeated(1)
        assert(
            counts.potions == 1 and counts.enhancements == 1 and counts.xp == 1 and counts.loot == 0,
            "Untrained drops/XP missing or wider loot leaked"
        )
        trained = true
        enemyService._enemies[1] = entry
        enemyService:_onDefeated(1)
        assert(
            counts.potions == 2 and counts.enhancements == 2 and counts.xp == 1 and counts.loot == 1,
            "Trained rewards changed or doubled"
        )
        enemyService:_onDefeated(1)
        assert(counts.potions == 2, "Duplicate death rolled extra drops")
        local data = {
            Hotbar = { ["1"] = { type = "power", target = "magnet" } },
            HotbarInitialized = true,
            RallyBarSeeded = true,
        }
        local saves, overlay = 0, false
        local bar = setmetatable({
            _config = require(game.ReplicatedStorage.Configs.hotbar),
            _potionBindSeen = {},
            _challengeBinds = { [player] = {} },
            _overlayActive = function()
                return overlay
            end,
            _dataService = {
                GetData = function()
                    return data
                end,
                RequestSave = function()
                    saves += 1
                end,
            },
            _potionService = {
                GetState = function()
                    return {
                        potions = {
                            { id = "fortune_flask", count = 2 },
                            { id = "swift_tonic", count = 3 },
                            { id = "berserk_brew", count = 1 },
                            { id = "weakening_vial", count = 2 },
                        },
                    }
                end,
            },
        }, { __index = Hotbar })
        local state = bar:GetState(player)
        assert(
            state.ok and saves == 1 and data.Hotbar["1"].target == "magnet",
            "Potion repair displaced a power"
        )
        for slot = 17, 20 do
            assert(data.Hotbar[tostring(slot)].type == "potion", "Potion binding absent")
        end
        bar:GetState(player)
        assert(saves == 1, "Potion repair repeats writes")
        overlay = true
        assert(
            next(bar:GetState(player).hotbar) == nil and data.Hotbar["20"] ~= nil,
            "Overlay leaked into save"
        )
        return {
            passed = true,
            profilesChanged = 0,
            coverage = "stronger-only swap, health/position, asset/stale guards, bounded refresh, trained/untrained drop routing, origin, dedup",
        }
    end)
    container:Destroy()
    assert(ok, result)
    return result
end
return Smoke
