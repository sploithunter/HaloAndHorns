local config = loadModule("configs/merge_egg_prototype.lua")
local network = loadModule("configs/network.lua")
local pets = loadModule("configs/pets.lua")
local petRoles = loadModule("configs/pet_roles.lua")
local currencies = loadModule("configs/currencies.lua")
local drops = loadModule("configs/drops.lua")
local draft = loadModule("src/Shared/Game/MergeEggDraft.lua")
local pricing = loadModule("src/Shared/Game/MergeEggPricing.lua")

return function()
    describe("Merge an Egg Phase 5", function()
        it("is one authored Studio map with no tile-system dependency", function()
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local authoring = readFile("scripts/studio/build_merge_egg_prototype_world.luau")

            expect(config.world.maps_root).to.equal("Maps")
            expect(config.world.model_name).to.equal("MergeEggPrototype")
            expect(authoring:find('world.Name = "MergeEggPrototype"', 1, true)).to.be.ok()
            expect(authoring:find('world:SetAttribute("UsesTileSystem", false)', 1, true)).to.be.ok()
            expect(
                authoring:find("world.ModelStreamingMode = Enum.ModelStreamingMode.Atomic", 1, true)
            ).to.be.ok()
            expect(authoring:find("Vector3.new(96, 2, 300)", 1, true)).to.be.ok()
            expect(authoring:find("Vector3.new(0, 0, -150)", 1, true)).to.be.ok()
            expect(authoring:find('anchor("EnemySpawnArea", Vector3.new(0, 2, -5)', 1, true)).to.be.ok()
            expect(config.world.bounds.center_z).to.equal(-150)
            expect(config.world.bounds.half_z).to.equal(149)
            expect(config.world.bounds.inset).to.equal(1)
            expect(service:find("TileKitBuilder", 1, true)).to.equal(nil)
            expect(service:find("MissionInstanceService:", 1, true)).to.equal(nil)
        end)

        it("routes the disabled Home Hall gate directly into the strip", function()
            expect(config.gate.hook_name).to.equal("HallOfWorldsPortal")
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            expect(service:find('child:GetAttribute("HallEntryArchCap")', 1, true)).to.be.ok()
            expect(service:find("hook.CanCollide = false", 1, true)).to.be.ok()
            expect(service:find("player:RequestStreamAroundAsync", 1, true)).to.be.ok()
            local beginAt = service:find("function MergeEggPrototypeService:_begin", 1, true)
            local streamAt =
                service:find("player:RequestStreamAroundAsync(target.Position", beginAt, true)
            local pivotAt = service:find("character:PivotTo(target)", beginAt, true)
            local insideAt =
                service:find('player:SetAttribute("InMergeEggPrototype", true)', beginAt, true)
            expect(service:find("self._enteringRecord = record", beginAt, true)).to.be.ok()
            expect(streamAt ~= nil and pivotAt ~= nil and insideAt ~= nil).to.equal(true)
            expect(streamAt < pivotAt and pivotAt < insideAt).to.equal(true)
        end)

        it("deploys four empty hatcher positions before the first Grass Egg", function()
            expect(config.version).to.equal(6)
            expect(#config.teams).to.equal(4)
            expect(config.team.starts_with_egg).to.equal(false)
            expect(config.team.egg_id).to.equal(nil)
            expect(table.concat(config.team.positions_by_egg_tier, ",")).to.equal("3,3,3,3")
            expect(#config.team.egg_progression).to.equal(4)
            expect(config.team.egg_progression[1]).to.equal("grass_egg")
            expect(config.team.egg_progression[2]).to.equal("ice_egg")
            expect(config.team.egg_progression[3]).to.equal("lava_egg")
            expect(config.team.egg_progression[4]).to.equal("desert_egg")
            expect(#config.squad).to.equal(0)
            local egg = pets.egg_sources.grass_egg
            expect(egg.name).to.equal("Earth Egg")
            expect(egg.pet_weights.bear).to.be.ok()
            expect(egg.pet_weights.bunny).to.be.ok()
            expect(egg.pet_weights.doggy).to.be.ok()
            expect(egg.pet_weights.kitty).to.be.ok()
            expect(egg.pet_weights.dragon).to.be.ok()
            expect(egg.rarity_rates.golden_chance).to.equal(0.05)
            expect(egg.rarity_rates.rainbow_chance).to.equal(0.005)
            expect(egg.huge.chance).to.equal(0.00002)
            expect(type(pets.simulateHatch)).to.equal("function")
            expect(petRoles.by_type.bear).to.equal("tank")
            expect(petRoles.by_type.dragon).to.equal("ranged")
            local names = {}
            for id, team in ipairs(config.teams) do
                expect(team.id).to.equal(id)
                expect(team.squad).to.equal(nil)
                expect(names[team.principal_name]).to.equal(nil)
                names[team.principal_name] = true
            end
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local server = readFile("src/Server/init.server.lua")
            expect(service:find("SpawnStationary", 1, true)).to.be.ok()
            expect(service:find("SpawnGhostSquad", 1, true)).to.be.ok()
            expect(service:find("BuildPlayerHatchData", 1, true)).to.be.ok()
            expect(service:find("self._petsConfig.simulateHatch", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_rollPrototypeSquad", 1, true)).to.be.ok()
            expect(service:find("variant = tostring(result.variant", 1, true)).to.be.ok()
            expect(service:find("huge = result.huge == true", 1, true)).to.be.ok()
            expect(server:find('"PetFollowService",\n                "EggService",', 1, true)).to.be.ok()
            expect(service:find("for index, teamCfg in ipairs(teamConfigs)", 1, true)).to.be.ok()
            expect(service:find("MergeEggPrototypeTeam = true", 1, true)).to.be.ok()
            expect(service:find("MergeEggTeamState", 1, true)).to.be.ok()
            expect(service:find("definition.squad = {}", 1, true)).to.be.ok()
            expect(service:find('state = "NoEgg"', 1, true)).to.be.ok()
            expect(service:find("initialized = false", 1, true)).to.be.ok()
            expect(service:find("eggTier = 0", 1, true)).to.be.ok()
            expect(service:find("or team.initialized ~= true", 1, true)).to.be.ok()
            expect(service:find('EphemeralDownPolicy = "destroy"', 1, true)).to.be.ok()
            local hatchAt = service:find("function MergeEggPrototypeService:_hatch", 1, true)
            local advanceAt =
                service:find("function MergeEggPrototypeService:AdvanceHatcherEgg", 1, true)
            local hatchBody = service:sub(hatchAt, advanceAt - 1)
            expect(hatchBody:find('self:_setWorldState("AwaitingFirstEgg"', 1, true)).to.be.ok()
            expect(hatchBody:find("self:_spawnNextWave(record)", 1, true)).to.equal(nil)
        end)

        it("uses world capacity and composition-aware best-of-N egg drafts", function()
            local loop = config.progression_loop
            local home = loop.stages.home
            local heaven = loop.stages.heaven_1
            expect(loop.default_stage).to.equal("home")
            expect(table.concat(loop.order, ",")).to.equal("home,heaven_1")
            expect(home.team_positions).to.equal(3)
            expect(heaven.team_positions).to.equal(4)
            expect(table.concat(home.draft_rolls_by_tier, ",")).to.equal("1,2,3,4")
            expect(table.concat(heaven.draft_rolls_by_tier, ",")).to.equal("1,2,3,4")
            expect(table.concat(heaven.egg_progression, ",")).to.equal(
                "bloom_egg,aurora_egg,solar_egg,gilded_egg"
            )
            expect(heaven.egg_pricing.base_amount).to.equal(1600)
            expect(heaven.independent_starting_coins).to.equal(6400)
            expect(pets.egg_sources.bloom_egg).to.be.ok()
            expect(pets.egg_sources.aurora_egg).to.be.ok()
            expect(pets.egg_sources.solar_egg).to.be.ok()
            expect(pets.egg_sources.gilded_egg).to.be.ok()

            local tank = { pet = "tank", role = "tank", combatPower = 10 }
            local support = { pet = "support", role = "support", combatPower = 12 }
            local blaster = { pet = "blaster", role = "ranged", combatPower = 40 }
            expect(draft.select({ blaster, support, tank }, {})).to.equal(tank)
            expect(draft.select({ blaster, support }, { tank })).to.equal(support)
            expect(draft.select({ support, blaster }, { tank, support })).to.equal(blaster)

            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            expect(service:find("MergeEggDraft.select", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_draftRollsForEggTier", 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("ProgressionStageId"', 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("PrototypeDraftCandidateRolls"', 1, true)).to.be.ok()
        end)

        it(
            "prices each position from its own egg tier and enforces the physical build zone",
            function()
                expect(config.team.earth_egg_pricing.currency).to.equal("hall_coins")
                expect(config.team.earth_egg_pricing.base_amount).to.equal(100)
                expect(config.team.earth_egg_pricing.growth).to.equal(2)
                expect(pricing.eggTierCost(100, 2, 0)).to.equal(100)
                expect(pricing.eggTierCost(100, 2, 1)).to.equal(200)
                expect(pricing.eggTierCost(100, 2, 2)).to.equal(400)
                expect(pricing.eggTierCost(100, 2, 3)).to.equal(800)
                expect(pricing.totalInitialPositionCost(100, 4)).to.equal(400)
                expect(config.team.build_access.minimum_bulwark_depth).to.equal(4)
                expect(config.team.build_access.maximum_hatcher_distance).to.equal(18)

                local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
                expect(service:find("function MergeEggPrototypeService:_canUseHatcher", 1, true)).to.be.ok()
                expect(service:find('return false, "behind_bulwark_required"', 1, true)).to.be.ok()
                expect(service:find('return false, "hatcher_too_far"', 1, true)).to.be.ok()
                expect(service:find("fromBulwark:Dot(towardFinish.Unit)", 1, true)).to.be.ok()
                expect(service:find("self._economyService:Transact", 1, true)).to.be.ok()
                expect(service:find('reason = "merge_egg_core_progression"', 1, true)).to.be.ok()
                expect(service:find('return false, "insufficient_currency"', 1, true)).to.be.ok()
                expect(service:find('world:SetAttribute("NextEarthEggCost"', 1, true)).to.be.ok()
            end
        )

        it("keeps escalating Waycoin march waves scoped to assigned NPC folders", function()
            expect(#config.waves).to.equal(20)
            expect(config.waves[1].count).to.equal(3)
            expect(config.waves[2].count).to.equal(5)
            expect(config.waves[3].count).to.equal(8)
            expect(config.waves[1].gap_after).to.equal(8)
            expect(#config.waves[1].groups).to.equal(1)
            expect(config.waves[1].groups[1].kind).to.equal("trash")
            expect(config.waves[1].groups[1].count).to.equal(3)
            expect(config.waves[2].gap_after).to.equal(8)
            expect(#config.waves[2].groups).to.equal(2)
            expect(config.waves[2].groups[1].kind).to.equal("tank")
            expect(config.waves[2].groups[1].count).to.equal(1)
            expect(config.waves[2].groups[2].kind).to.equal("trash")
            expect(config.waves[2].groups[2].count).to.equal(4)
            expect(config.waves[3].gap_after).to.equal(6)
            expect(#config.waves[3].groups).to.equal(2)
            expect(config.waves[3].groups[1].kind).to.equal("tank")
            expect(config.waves[3].groups[1].count).to.equal(4)
            expect(config.waves[3].groups[2].kind).to.equal("trash")
            expect(config.waves[3].groups[2].count).to.equal(4)
            expect(config.waves[4].count).to.equal(12)
            expect(config.waves[5].count).to.equal(16)
            expect(config.waves[6].count).to.equal(24)
            expect(config.waves[7].count).to.equal(32)
            expect(config.waves[8].count).to.equal(48)
            expect(config.waves[9].count).to.equal(56)
            expect(config.waves[12].count).to.equal(80)
            expect(config.waves[16].count).to.equal(144)
            expect(config.waves[20].count).to.equal(208)
            for index = 2, #config.waves do
                expect(config.waves[index].count > config.waves[index - 1].count).to.equal(true)
            end
            expect(config.endurance.stop_when_all_teams_defeated).to.equal(false)
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            expect(service:find('rewardPolicy = "none"', 1, true)).to.be.ok()
            expect(service:find("marchGoal = {", 1, true)).to.be.ok()
            expect(service:find("AlertPetFolderToEnemy", 1, true)).to.be.ok()
            expect(service:find("AlertSquadToEnemy", 1, true)).to.equal(nil)
            expect(service:find("FocusSquadOnEnemy", 1, true)).to.equal(nil)
            expect(service:find("MergeEggAssignedTeamId", 1, true)).to.be.ok()
            expect(service:find('model:SetAttribute("CombatTargetGroup"', 1, true)).to.be.ok()
            expect(service:find("team.folder,", 1, true)).to.be.ok()
            expect(service:find("record.teamById[enemy.teamId]", 1, true)).to.be.ok()
            expect(config.enemy.engagement_distance).to.equal(260)
            expect(config.enemy.engagement_threat).to.equal(250)
            expect(config.enemy.reengage_seconds).to.equal(1)
            expect(config.enemy.tank.id).to.equal("ember_brute")
            expect(config.enemy.tank.hp > config.enemy.hp).to.equal(true)
            expect(config.world.bulwark_line).to.equal("BulwarkLine")
            expect(config.world.breach_line).to.equal("BreachLine")
            expect(config.enemy.bulwark_threat).to.equal(250)
            expect(config.enemy.bulwark_reengage_seconds).to.equal(0.5)
            expect(config.enemy.bulwark_contact_padding).to.equal(1)
            expect(config.enemy.breach_overrun_enemy_per_active_pet).to.equal(1)
            expect(config.enemy.breach_overrun_minimum).to.equal(4)
            expect(config.combat.attack_cadence_multiplier).to.equal(4)
            expect(service:find("MergeEggNextDefenseAlertAt", 1, true)).to.be.ok()
            expect(service:find("not engaged and now >= nextAlertAt", 1, true)).to.be.ok()
            expect(service:find("if team.initialized == true then", 1, true)).to.be.ok()
            expect(service:find('local authoredGroups = type(wave.groups) == "table"', 1, true)).to.be.ok()
            expect(service:find('groupKind == "tank" and groupOrdinal == 1', 1, true)).to.be.ok()
            expect(service:find("local teamOrdinal =", 1, true)).to.be.ok()
            expect(service:find('model:SetAttribute("MergeEggAttackGroup"', 1, true)).to.be.ok()
            expect(service:find('spec.compositionRole or "melee"', 1, true)).to.be.ok()
            expect(service:find("resolvedWave.gap_after", 1, true)).to.be.ok()
            expect(service:find("enemy_tank_config_missing", 1, true)).to.be.ok()
            expect(service:find('model:SetAttribute("CombatTargetOpen", true)', 1, true)).to.be.ok()
            expect(service:find("for _, team in ipairs(record.teams or {})", 1, true)).to.be.ok()
            expect(service:find("MergeEggReserveAlertedPets", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_sustainBulwarkTarget", 1, true)).to.be.ok()
            expect(service:find("MergeEggNextBulwarkAlertAt", 1, true)).to.be.ok()
            expect(service:find("MergeEggBulwarkAlertCount", 1, true)).to.be.ok()
            local petFollow = readFile("src/Server/Services/PetFollowService.lua")
            local enemyService = readFile("src/Server/Services/EnemyService.lua")
            expect(config.debug.trace_bulwark_aggro).to.equal(true)
            expect(config.debug.bulwark_trace_seconds).to.equal(2)
            expect(service:find("function MergeEggPrototypeService:_traceBulwarkAggro", 1, true)).to.be.ok()
            expect(service:find("TracePetFolderAggro", 1, true)).to.be.ok()
            expect(enemyService:find("function EnemyService:TracePetFolderAggro", 1, true)).to.be.ok()
            expect(enemyService:find('"[BulwarkAggro]', 1, true)).to.be.ok()
            expect(service:find("local function leadingBoundsPoint", 1, true)).to.be.ok()
            expect(service:find("model:GetBoundingBox()", 1, true)).to.be.ok()
            expect(service:find('typeof(position) == "Vector3" and position', 1, true)).to.be.ok()
            expect(service:find("MergeEggBulwarkLeadingDistance", 1, true)).to.be.ok()
            expect(service:find("MergeEggBulwarkMovementDistance", 1, true)).to.be.ok()
            expect(service:find("leadingDistance + contactPadding >= 0", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_ensureBreachLine", 1, true)).to.be.ok()
            expect(service:find('model:SetAttribute("MergeEggBreachLineCrossed", true)', 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("EnemiesPastBreachLine"', 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("FirstBreachWave"', 1, true)).to.be.ok()
            expect(service:find('"CombatCadenceMultiplier"', 1, true)).to.be.ok()
            expect(petFollow:find("CombatCadence.interval", 1, true)).to.be.ok()
            expect(enemyService:find("CombatCadence.interval", 1, true)).to.be.ok()
            expect(service:find("FirstPetLossWave", 1, true)).to.be.ok()
            expect(service:find("PeakActiveEnemies", 1, true)).to.be.ok()
            expect(service:find('self:_setWorldState("ObjectiveLost"', 1, true)).to.be.ok()
            expect(service:find('record.runId .. ":" .. stageId .. ":wave:" .. waveIndex', 1, true)).to.be.ok()
        end)

        it("uses five reserve eggs as defeat and random per-team replacement FIFOs", function()
            expect(config.objective.starting_eggs).to.equal(5)
            expect(config.objective.damage_per_escape).to.equal(1)
            expect(config.objective.hatcher_egg_health).to.equal(1)
            expect(config.objective.hatcher_egg_damage_per_arrival).to.equal(1)
            expect(config.reinforcement.enabled).to.equal(true)
            expect(config.reinforcement.hatch_seconds).to.equal(4)
            expect(config.reinforcement.queue_policy).to.equal("per_team_fifo_random_egg_roll")
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            expect(service:find("function MergeEggPrototypeService:_damageObjective", 1, true)).to.be.ok()
            expect(
                service:find(
                    "function MergeEggPrototypeService:_damageInstalledHatcherEgg",
                    1,
                    true
                )
            ).to.be.ok()
            expect(service:find("MergeEggNeedsRebuild", 1, true)).to.be.ok()
            expect(service:find("HatcherEggsDestroyed", 1, true)).to.be.ok()
            expect(service:find("HatcherEggsRebuilt", 1, true)).to.be.ok()
            expect(service:find("ObjectiveEggsRemaining", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_queueMissingPets", 1, true)).to.be.ok()
            expect(
                service:find("function MergeEggPrototypeService:_processReplacementQueues", 1, true)
            ).to.be.ok()
            expect(service:find("positionOffset = queued.slot - 1", 1, true)).to.be.ok()
            expect(service:find("queued.definition", 1, true)).to.be.ok()
            expect(service:find("self:_rollDraftedPrototypePet(", 1, true)).to.be.ok()
            expect(service:find("self:_publishTeamSlot(team, queued.slot", 1, true)).to.be.ok()
            expect(service:find("MergeEggReplacementSlots", 1, true)).to.be.ok()
            expect(service:find("PeakReplacementQueueDepth", 1, true)).to.be.ok()
        end)

        it("drops Hall Waycoins with a prototype-owned ten-stud magnet", function()
            expect(config.rewards.currency).to.equal("hall_coins")
            expect(config.rewards.trash_amount).to.equal(40)
            expect(config.rewards.tank_amount).to.equal(120)
            expect(config.rewards.magnet.base_radius).to.equal(10)
            expect(config.rewards.magnet.use_player_modifiers).to.equal(false)
            expect(drops.collect_radius).to.equal(11)
            expect(drops.currency_pickups.hall_coins.mesh).to.be.ok()
            expect(drops.currency_pickups.hall_coins.texture).to.be.ok()

            local waycoin
            for _, currency in ipairs(currencies) do
                if currency.id == "hall_coins" then
                    waycoin = currency
                    break
                end
            end
            expect(waycoin).to.be.ok()
            expect(waycoin.name).to.equal("Waycoins")
            expect(waycoin.icon).to.equal("rbxassetid://124447234465235")

            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local dropService = readFile("src/Server/Services/DropService.lua")
            local currencyStack = readFile("src/Client/Systems/CurrencyStack.lua")
            local server = readFile("src/Server/init.server.lua")
            expect(service:find("function MergeEggPrototypeService:_dropEnemyCoins", 1, true)).to.be.ok()
            expect(service:find('rewardPolicy = "none"', 1, true)).to.be.ok()
            expect(service:find('collectRadiusAttribute = "MergeEggMagnetRadius"', 1, true)).to.be.ok()
            expect(service:find('source = "merge_egg_prototype"', 1, true)).to.be.ok()
            expect(service:find('"MergeEggCoinReward"', 1, true)).to.be.ok()
            expect(service:find('"PrototypeCoinsDropped"', 1, true)).to.be.ok()
            expect(dropService:find("function DropService:SpawnCoinDrop", 1, true)).to.be.ok()
            expect(dropService:find("rec.collectRadiusAttribute", 1, true)).to.be.ok()
            expect(dropService:find("rec.usePlayerModifiers == false", 1, true)).to.be.ok()
            expect(dropService:find("function DropService:DiscardDrops", 1, true)).to.be.ok()
            expect(
                currencyStack:find('player:GetAttribute("InMergeEggPrototype") == true', 1, true)
            ).to.be.ok()
            expect(currencyStack:find('GetAttributeChangedSignal("InMergeEggPrototype")', 1, true)).to.be.ok()
            expect(
                server:find(
                    '"EggService",\n                "DropService",\n                "EconomyService",',
                    1,
                    true
                )
            ).to.be.ok()
        end)

        it(
            "runs a no-GUI upper-bound collector against real movement and purchase rules",
            function()
                expect(config.automation.coin_runner.starting_coins).to.equal(100)
                expect(config.automation.coin_runner.target_hatchers).to.equal(4)
                expect(config.automation.coin_runner.sequential_stages).to.equal(true)
                expect(table.concat(config.team.positions_by_egg_tier, ",")).to.equal("3,3,3,3")
                local experiments = config.team.balance_experiments
                expect(experiments.default).to.equal("world_draft")
                expect(experiments.modes.world_draft.stage_positions).to.equal(true)
                expect(experiments.modes.world_draft.draft_quality).to.equal(true)
                expect(table.concat(experiments.modes.positions.positions_by_egg_tier, ",")).to.equal(
                    "3,4,5,6"
                )
                expect(table.concat(experiments.modes.origin_10.positions_by_egg_tier, ",")).to.equal(
                    "4,4,4,4"
                )
                expect(experiments.modes.origin_10.origin_power_per_tier).to.equal(0.10)
                expect(experiments.modes.origin_20.origin_power_per_tier).to.equal(0.20)
                expect(table.concat(experiments.modes.origin_20.positions_by_egg_tier, ",")).to.equal(
                    "4,4,4,4"
                )

                local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
                local automation = readFile("src/Server/Services/AutomationService.lua")
                local follow = readFile("src/Server/Services/PetFollowService.lua")
                expect(service:find("function MergeEggPrototypeService:StartCoinRunner", 1, true)).to.be.ok()
                expect(service:find("function MergeEggPrototypeService:_runCoinRunner", 1, true)).to.be.ok()
                expect(
                    service:find(
                        "function MergeEggPrototypeService:_completeCoinRunnerStage",
                        1,
                        true
                    )
                ).to.be.ok()
                expect(
                    service:find(
                        "function MergeEggPrototypeService:_transitionProgressionStage",
                        1,
                        true
                    )
                ).to.be.ok()
                expect(
                    service:find(
                        "function MergeEggPrototypeService:_nearestPrototypeCoinDrop",
                        1,
                        true
                    )
                ).to.be.ok()
                expect(service:find('request.automation == "coin_runner"', 1, true)).to.be.ok()
                expect(service:find('return false, "unknown_balance_experiment"', 1, true)).to.be.ok()
                expect(service:find("OriginProgressionMultiplier", 1, true)).to.be.ok()
                expect(follow:find('pet:GetAttribute("OriginProgressionMultiplier")', 1, true)).to.be.ok()
                expect(service:find('model:GetAttribute("DropOwner") == player.UserId', 1, true)).to.be.ok()
                expect(
                    service:find(
                        'model:GetAttribute("DropSource") == "merge_egg_prototype"',
                        1,
                        true
                    )
                ).to.be.ok()
                expect(service:find("self._automationService:NavigateTo", 1, true)).to.be.ok()
                expect(service:find("self:AdvanceHatcherEgg(record.player", 1, true)).to.be.ok()
                expect(service:find('"AllProgressionStagesComplete"', 1, true)).to.be.ok()
                expect(service:find('"InsufficientNextStageReserve"', 1, true)).to.be.ok()
                expect(service:find('"SweepingStageDrops"', 1, true)).to.be.ok()
                expect(service:find('return false, "unknown_progression_stage"', 1, true)).to.be.ok()
                expect(service:find("local requestedStartWave =", 1, true)).to.be.ok()
                expect(service:find("local requestedFocusTeamId =", 1, true)).to.be.ok()
                expect(service:find("record.nextWaveOverride =", 1, true)).to.be.ok()
                expect(service:find("record.waveFocusTeamId = requestedFocusTeamId", 1, true)).to.be.ok()
                expect(service:find('world:SetAttribute("CoinRunnerStartWave"', 1, true)).to.be.ok()
                expect(service:find('world:SetAttribute("WaveFocusTeamId"', 1, true)).to.be.ok()
                local runnerAt =
                    service:find("function MergeEggPrototypeService:_runCoinRunner", 1, true)
                local startAt = service:find(
                    "function MergeEggPrototypeService:StartCoinRunner",
                    runnerAt,
                    true
                )
                local runnerBody = service:sub(runnerAt, startAt - 1)
                expect(
                    runnerBody:find(
                        'self:_finishCoinRunner(record, generation, "EnemyEscapedBeforeAllSandEggs")',
                        1,
                        true
                    )
                ).to.equal(nil)
                expect(service:find('world:SetAttribute("CoinRunnerCoinsEarned"', 1, true)).to.be.ok()
                expect(service:find('world:SetAttribute("CoinRunnerCoinsSpent"', 1, true)).to.be.ok()
                expect(service:find('"CoinRunnerFirstEscapeHatchers"', 1, true)).to.be.ok()
                expect(service:find('"merge_egg_coin_runner_restore"', 1, true)).to.be.ok()
                expect(
                    automation:find("function AutomationService:SetPlayerControlsEnabled", 1, true)
                ).to.be.ok()
                expect(automation:find("opts.keepControlsDisabled ~= true", 1, true)).to.be.ok()
            end
        )

        it("keeps Home at three slots while egg tiers improve future draft quality", function()
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local observer = readFile("src/Client/Systems/MergeEggPrototypeObserver.lua")
            local packet = network.packets.MergeEggPrototypeUpgrade

            expect(pets.egg_sources.ice_egg.name).to.equal("Ice Egg")
            expect(pets.egg_sources.lava_egg.name).to.equal("Ember Egg")
            expect(pets.egg_sources.desert_egg.name).to.equal("Sand Egg")
            expect(packet.transport).to.equal("reliable_event")
            expect(packet.direction).to.equal("client_to_server")
            expect(packet.authorization).to.equal("studio")
            expect(packet.environments.studio).to.equal(true)
            expect(packet.environments.test).to.equal(true)
            expect(packet.environments.production).to.equal(nil)
            expect(service:find("function MergeEggPrototypeService:AdvanceHatcherEgg", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_spawnInitialTeam", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_expandTeamForEggTier", 1, true)).to.be.ok()
            expect(service:find("self:_positionsForEggTier(1, record)", 1, true)).to.be.ok()
            expect(service:find('folder:SetAttribute("MergeEggExpectedPets", desired)', 1, true)).to.be.ok()
            expect(service:find("local team = record.teamById[teamId]", 1, true)).to.be.ok()
            expect(service:find("if team.initialized ~= true and nextTier ~= 1 then", 1, true)).to.be.ok()
            expect(service:find("nextTier ~= 1", 1, true)).to.be.ok()
            expect(service:find("self:_rollDraftedPrototypePet(", 1, true)).to.be.ok()
            expect(service:find("queued.definition = nil", 1, true)).to.be.ok()
            expect(service:find("self:_publishTeamEggSource(team)", 1, true)).to.be.ok()
            local advanceAt =
                service:find("function MergeEggPrototypeService:AdvanceHatcherEgg", 1, true)
            local resetAt =
                service:find("function MergeEggPrototypeService:_reset", advanceAt, true)
            local advanceBody = service:sub(advanceAt, resetAt - 1)
            expect(advanceBody:find("record.waveIndex == 0 and addedUnits > 0", 1, true)).to.be.ok()
            expect(advanceBody:find("self:_spawnNextWave(record)", 1, true)).to.be.ok()
            expect(service:find("Signals.MergeEggPrototypeUpgrade.OnServerEvent", 1, true)).to.be.ok()
            expect(observer:find('Instance.new("BillboardGui")', 1, true)).to.be.ok()
            expect(observer:find("billboard.Active = true", 1, true)).to.be.ok()
            expect(
                observer:find('billboard.Parent = localPlayer:WaitForChild("PlayerGui")', 1, true)
            ).to.be.ok()
            expect(observer:find('current.Text = "CURRENT: NO EGG"', 1, true)).to.be.ok()
            expect(observer:find('button.Text = "CREATE → EARTH EGG"', 1, true)).to.be.ok()
            expect(
                observer:find(
                    '.. (waitingForFirstEgg and "INSTALL FIRST EGG" or "READY TO HATCH")',
                    1,
                    true
                )
            ).to.be.ok()
            expect(observer:find('world:GetAttribute("ProgressionStageName")', 1, true)).to.be.ok()
            expect(observer:find('folder:GetAttribute("MergeEggNextDraftRolls")', 1, true)).to.be.ok()
            expect(observer:find('attackGroups == 1 and "FRONT" or "FRONTS"', 1, true)).to.be.ok()
            expect(observer:find("button.Activated:Connect", 1, true)).to.be.ok()
            expect(observer:find("Signals.MergeEggPrototypeUpgrade:FireServer", 1, true)).to.be.ok()
        end)

        it("gives every enemy one random spawn-to-finish vector", function()
            expect(config.world.enemy_spawn_area).to.equal("EnemySpawnArea")
            expect(config.world.enemy_finish_line).to.equal("EnemyFinishLine")
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local spawn = service:find("function MergeEggPrototypeService:_spawnWaveEnemy", 1, true)
            expect(service:find("spec.spawnArea", spawn, true)).to.be.ok()
            expect(service:find("destination = destination", spawn, true)).to.be.ok()
            expect(service:find("self:_onEnemyReachedFinish", spawn, true)).to.be.ok()
            expect(service:find('self:_resolveEnemy(record, "escaped"', 1, true)).to.be.ok()
        end)

        it("opens a temporary enemy portal only while a wave is deploying", function()
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local authoring = readFile("scripts/studio/build_merge_egg_prototype_world.luau")
            expect(config.world.enemy_portal_visual).to.equal("EnemyPortalVisual")
            expect(config.enemy.portal_spawn_interval).to.equal(0.15)
            expect(authoring:find('portal.Name = "EnemyPortalVisual"', 1, true)).to.be.ok()
            expect(authoring:find('Instance.new("ParticleEmitter")', 1, true)).to.be.ok()
            expect(authoring:find('"SouthEndWall"', 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_setPortalVisible", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_processWaveSpawns", 1, true)).to.be.ok()
            expect(service:find('self:_setWorldState("WaveDeploying"', 1, true)).to.be.ok()
            expect(service:find("self:_setPortalVisible(record, false)", 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("WaveEnemiesPending"', 1, true)).to.be.ok()
        end)

        it("draws distinct bulwark and breach lines before the hatchers", function()
            local authoring = readFile("scripts/studio/build_merge_egg_prototype_world.luau")
            expect(authoring:find('"BulwarkLine"', 1, true)).to.be.ok()
            expect(authoring:find('"BULWARK  •  ALL TEAMS ENGAGE"', 1, true)).to.be.ok()
            expect(authoring:find("Vector3.new(0, 1.15, -175)", 1, true)).to.be.ok()
            expect(authoring:find('"BreachLine"', 1, true)).to.be.ok()
            expect(authoring:find('"BREACH  •  EGGS EXPOSED"', 1, true)).to.be.ok()
            expect(authoring:find("Vector3.new(0, 1.16, -205)", 1, true)).to.be.ok()
            expect(authoring:find('Instance.new("SurfaceGui")', 1, true)).to.be.ok()
            expect(authoring:find('Instance.new("BillboardGui")', 1, true)).to.equal(nil)
            expect(authoring:find('"BulwarkGroundLabel"', 1, true)).to.be.ok()
            expect(authoring:find('anchor("HatcherSpawn", Vector3.new(0, 2, -218)', 1, true)).to.be.ok()
        end)

        it("provides repeatable reset and exit cleanup", function()
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local clear = service:find("function MergeEggPrototypeService:_clearEncounter", 1, true)
            local reset = service:find("function MergeEggPrototypeService:_reset", 1, true)
            local exit = service:find("function MergeEggPrototypeService:_exit", 1, true)
            expect(clear ~= nil).to.equal(true)
            expect(reset ~= nil and reset > clear).to.equal(true)
            expect(exit ~= nil and exit > reset).to.equal(true)
            expect(service:find("self._npcPrincipalService:Despawn", clear, true)).to.be.ok()
            expect(service:find("self:_restoreOwnedPets(record)", clear, true)).to.be.ok()
        end)

        it("provides four read-only combat columns", function()
            local observer = readFile("src/Client/Systems/MergeEggPrototypeObserver.lua")
            local client = readFile("src/Client/init.client.lua")

            expect(observer:find("MergeEggPrototypeTeam", 1, true)).to.be.ok()
            expect(observer:find("for order, teamCfg in ipairs(CONFIG.teams", 1, true)).to.be.ok()
            expect(observer:find("MergeEggAssignedEnemies", 1, true)).to.be.ok()
            expect(observer:find("MergeEggPeakAssignedEnemies", 1, true)).to.be.ok()
            expect(observer:find("MergeEggFirstLossWave", 1, true)).to.be.ok()
            expect(observer:find("COMBAT_CADENCE_MULTIPLIER", 1, true)).to.be.ok()
            expect(observer:find('frame.Name = "WaveMeter"', 1, true)).to.be.ok()
            expect(observer:find('.. " • WAVE " .. waveWord(wave)', 1, true)).to.be.ok()
            expect(observer:find('world:GetAttribute("ActiveEnemies")', 1, true)).to.be.ok()
            expect(observer:find('world:GetAttribute("ObjectiveEggsRemaining")', 1, true)).to.be.ok()
            expect(observer:find('world:GetAttribute("ReplacementQueueDepth")', 1, true)).to.be.ok()
            expect(observer:find('world:GetAttribute("EnemyPortalVisible")', 1, true)).to.be.ok()
            expect(observer:find('world:GetAttribute("PrototypeEggRolls")', 1, true)).to.be.ok()
            expect(observer:find('"Golden " .. displayName', 1, true)).to.be.ok()
            expect(observer:find('"Rainbow " .. displayName', 1, true)).to.be.ok()
            expect(observer:find('folder:GetAttribute("MergeEggSlotPet" .. slot)', 1, true)).to.be.ok()
            expect(observer:find('card.note.Text = queued and "QUEUED"', 1, true)).to.be.ok()
            expect(observer:find("announceUntil = os.clock() + 2.5", 1, true)).to.be.ok()
            expect(observer:find("PetEndurance.healthFraction", 1, true)).to.be.ok()
            expect(observer:find("TargetID", 1, true)).to.be.ok()
            expect(observer:find("CombatAssistTarget:FireServer", 1, true)).to.equal(nil)
            expect(client:find("MergeEggPrototypeObserver", 1, true)).to.be.ok()
        end)
    end)
end
