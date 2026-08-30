local config = loadModule("configs/merge_egg_prototype.lua")
local areas = loadModule("configs/areas.lua")
local network = loadModule("configs/network.lua")
local pets = loadModule("configs/pets.lua")
local petRoles = loadModule("configs/pet_roles.lua")
local currencies = loadModule("configs/currencies.lua")
local drops = loadModule("configs/drops.lua")
local places = loadModule("configs/places.lua")
local draft = loadModule("src/Shared/Game/MergeEggDraft.lua")
local enemyRoster = loadModule("src/Shared/Game/MergeEggEnemyRoster.lua")
local placeRuntime = loadModule("src/Shared/Game/PlaceRuntime.lua")
local pricing = loadModule("src/Shared/Game/MergeEggPricing.lua")

return function()
    describe("Merge an Egg Phase 5", function()
        it("binds one permanent authored Studio realm with no tile-system dependency", function()
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local authoring = readFile("scripts/studio/build_merge_egg_prototype_world.luau")
            local bake = readFile("scripts/studio/bake_merge_egg_realm.luau")
            local realmBuilder = readFile("src/Server/Services/MergeEggRealmBuilder.lua")

            expect(config.world.maps_root).to.equal("Maps")
            expect(config.world.model_name).to.equal("MergeEggPrototype")
            expect(config.realm_layout.authored).to.equal(true)
            expect(config.realm_layout.root_name).to.equal("MergeEggRealm")
            expect(config.realm_layout.source_model_name).to.equal("MergeEggPrototype")
            expect(config.realm_layout.primary_bay_id).to.equal("heaven_01")
            expect(config.realm_layout.authoring_bay.enabled).to.equal(true)
            expect(config.realm_layout.authoring_bay.side).to.equal("heaven")
            expect(config.realm_layout.authoring_bay.column).to.equal(1)
            expect(config.world.area_id).to.equal("MergeEggPrototype")
            expect(areas.zones.MergeEggPrototype.kind).to.equal("area")
            expect(areas.zones.MergeEggPrototype.synthetic.center.x).to.equal(-16000)
            expect(areas.zones.MergeEggPrototype.synthetic.center.z).to.equal(-325)
            expect(areas.zones.MergeEggPrototype.synthetic.size.x).to.equal(1320)
            expect(areas.zones.MergeEggPrototype.synthetic.size.z).to.equal(920)
            expect(config.realm_layout.bay_pitch).to.equal(136)
            expect(config.realm_layout.corridor_gap).to.equal(180)
            expect(config.realm_layout.mall_length).to.equal(680)
            expect(config.realm_layout.mall_width).to.equal(180)
            expect(config.realm_layout.mall_drop).to.equal(10)
            expect(config.realm_layout.river_width).to.equal(18)
            expect(config.realm_layout.river_bridge_count).to.equal(4)
            expect(config.realm_layout.bay_stair_steps).to.equal(10)
            expect(config.realm_layout.lane_visible_wall_height).to.equal(4)
            expect(authoring:find('world.Name = "MergeEggPrototype"', 1, true)).to.be.ok()
            expect(authoring:find('world:SetAttribute("UsesTileSystem", false)', 1, true)).to.be.ok()
            expect(
                authoring:find("world.ModelStreamingMode = Enum.ModelStreamingMode.Atomic", 1, true)
            ).to.be.ok()
            expect(authoring:find("Vector3.new(96, 2, 300)", 1, true)).to.be.ok()
            expect(authoring:find("Vector3.new(0, 0, -150)", 1, true)).to.be.ok()
            expect(authoring:find('anchor("EnemySpawnArea", Vector3.new(0, 2, -5)', 1, true)).to.be.ok()
            expect(bake:find("builder:Bake(source)", 1, true)).to.be.ok()
            expect(bake:find("Workspace:FindFirstChild", 1, true)).to.be.ok()
            expect(service:find("self._realm:Ensure(maps)", 1, true)).to.be.ok()
            expect(service:find("configuredAuthoringBayId", 1, true)).to.be.ok()
            expect(service:find('string.format("%s_%02d", side, column)', 1, true)).to.be.ok()
            expect(service:find('realmConfig.primary_bay_id or "heaven_01"', 1, true)).to.be.ok()
            local ensureAt =
                realmBuilder:find("function MergeEggRealmBuilder:Ensure(mapsOrTemplate)", 1, true)
            local bakeAt =
                realmBuilder:find("function MergeEggRealmBuilder:Bake(template)", 1, true)
            expect(ensureAt ~= nil and bakeAt ~= nil and ensureAt < bakeAt).to.equal(true)
            local runtimeBinding = realmBuilder:sub(ensureAt, bakeAt - 1)
            expect(runtimeBinding:find(":Clone()", 1, true)).to.equal(nil)
            expect(runtimeBinding:find("_buildHall", 1, true)).to.equal(nil)
            expect(runtimeBinding:find("_styleBay", 1, true)).to.equal(nil)
            expect(realmBuilder:find("local function authoredClaimFixtures", 1, true)).to.be.ok()
            expect(realmBuilder:find("claimFixtures = claimFixtures", 1, true)).to.be.ok()
            expect(realmBuilder:find("for _, fixture in ipairs(bay.claimFixtures or {})", 1, true)).to.be.ok()
            expect(config.world.bounds.center_z).to.equal(-150)
            expect(config.world.bounds.half_z).to.equal(149)
            expect(config.world.bounds.inset).to.equal(1)
            expect(service:find("TileKitBuilder", 1, true)).to.equal(nil)
            expect(service:find("MissionInstanceService:", 1, true)).to.equal(nil)
        end)

        it("routes the restricted Coming Soon gate to the dedicated Merge place", function()
            expect(placeRuntime.placeIdForRole(places, "merge")).to.equal(84544653387905)
            expect(config.gate.hook_name).to.equal("HallOfWorldsPortal")
            expect(config.gate.title).to.equal("COMING SOON")
            expect(config.gate.access.internal_accounts).to.equal(true)
            expect(config.gate.access.additional_user_ids[1]).to.equal(536245038)
            expect(config.gate.access.studio_bypass).to.equal(false)
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local server = readFile("src/Server/init.server.lua")
            expect(
                server:find(
                    'appendIfEnabled(requiredModules, "map_binding", "MergeEggPrototypeService")',
                    1,
                    true
                )
            ).to.be.ok()
            expect(server:find("local mergeEggPrototypeDeps = {", 1, true)).to.be.ok()
            expect(server:find('table.insert(mergeEggPrototypeDeps, "AutomationService")', 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_hasPreviewAccess", 1, true)).to.be.ok()
            expect(
                service:find("function MergeEggPrototypeService:_bindRestrictedHallGate", 1, true)
            ).to.be.ok()
            expect(service:find('return false, "coming_soon"', 1, true)).to.be.ok()
            local enterAt =
                service:find("function MergeEggPrototypeService:_enterFromHall", 1, true)
            local returnAt = service:find(
                "function MergeEggPrototypeService:_returnToFarmAndFight",
                enterAt,
                true
            )
            expect(enterAt ~= nil and returnAt ~= nil and enterAt < returnAt).to.equal(true)
            local enterBody = service:sub(enterAt, returnAt - 1)
            expect(enterBody:find('self:_teleportToRole(player, "merge")', 1, true)).to.be.ok()
            expect(enterBody:find("RunService:IsStudio()", 1, true)).to.equal(nil)
            expect(enterBody:find("self:_begin(player)", 1, true)).to.equal(nil)
            expect(service:find("player:RequestStreamAroundAsync", 1, true)).to.be.ok()
            local beginAt = service:find("function MergeEggPrototypeService:_begin", 1, true)
            local streamAt =
                service:find("player:RequestStreamAroundAsync(target.Position", beginAt, true)
            local pivotAt = service:find("character:PivotTo(target)", beginAt, true)
            local insideAt =
                service:find('player:SetAttribute("InMergeEggPrototype", true)', beginAt, true)
            local locationAt =
                service:find("self:_setPlayerArea(player, self:_prototypeAreaId())", beginAt, true)
            expect(service:find("self._enteringRecordByPlayer[player] = record", beginAt, true)).to.be.ok()
            expect(streamAt ~= nil and pivotAt ~= nil and locationAt ~= nil and insideAt ~= nil).to.equal(
                true
            )
            expect(streamAt < pivotAt and pivotAt < locationAt and locationAt < insideAt).to.equal(
                true
            )
            expect(
                service:find("function MergeEggPrototypeService:_reconcileStaleSession", 1, true)
            ).to.be.ok()
            expect(service:find('GetAttributeChangedSignal("CurrentArea")', beginAt, true)).to.be.ok()
        end)

        it("keeps the dedicated-place return door public and independent of a session", function()
            local returnRoute = config.gate.return_route
            expect(returnRoute.hook_name).to.equal("HallOfWorldsPortal")
            expect(returnRoute.destination_role).to.equal("main")
            expect(returnRoute.public).to.equal(true)
            expect(returnRoute.object_text).to.equal("Farm & Fight")

            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local returnAt =
                service:find("function MergeEggPrototypeService:_returnToFarmAndFight", 1, true)
            local bindAt = service:find(
                "function MergeEggPrototypeService:_bindPublicReturnGate",
                returnAt,
                true
            )
            expect(returnAt ~= nil and bindAt ~= nil and returnAt < bindAt).to.equal(true)
            local returnBody = service:sub(returnAt, bindAt - 1)
            expect(returnBody:find("self:_recordFor", 1, true)).to.equal(nil)
            expect(returnBody:find("self:_teleportToRole(player", 1, true)).to.be.ok()
            expect(service:find('hook:SetAttribute("MergeEggPublicReturnDoor", true)', 1, true)).to.be.ok()
            expect(service:find("self:_bindPublicReturnGate()", 1, true)).to.be.ok()
        end)

        it("arms on entry and validates five purchases, one merge, and one deployment", function()
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local observer = readFile("src/Client/Systems/MergeEggPrototypeObserver.lua")
            local beginAt = service:find("function MergeEggPrototypeService:_begin", 1, true)
            local movementAt =
                service:find("function MergeEggPrototypeService:_movementLeash", beginAt, true)
            local beginBody = service:sub(beginAt, movementAt - 1)

            expect(config.tutorial.enabled).to.equal(true)
            expect(config.tutorial.auto_collector_attribute).to.equal("AutoCollectorEnabled")
            expect(config.tutorial.required_eggs).to.equal(5)
            expect(config.tutorial.click_cue_purchase_count).to.equal(3)
            expect(config.tutorial.disable_after_rebirth).to.equal(true)
            expect(config.tutorial.steps.collect_setup.target).to.equal("coins")
            expect(config.tutorial.steps.create_five.target).to.equal("buy_egg")
            expect(config.tutorial.steps.combine_once.target).to.equal("board_egg")
            expect(config.tutorial.steps.deploy_one.target).to.equal("board_egg")
            expect(beginBody:find("self:_hatch(player)", 1, true)).to.be.ok()
            expect(beginBody:find("self:_startTutorial(record)", 1, true)).to.be.ok()
            expect(service:find('FindFirstChild("MergeEggPrototypeHatchPrompt")', 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_updateTutorial", 1, true)).to.be.ok()
            expect(
                service:find("function MergeEggPrototypeService:_tutorialHasCombination", 1, true)
            ).to.be.ok()
            expect(service:find("(record.eggsMerged or 0) > 0", 1, true)).to.be.ok()
            expect(service:find("self:_initializedHatcherCount(record) >= 1", 1, true)).to.be.ok()
            expect(service:find("record.tutorialActive ~= true", 1, true)).to.be.ok()
            expect(service:find("progress.tutorial_completed = true", 1, true)).to.be.ok()
            expect(observer:find("MergeEggTutorialPath", 1, true)).to.be.ok()
            expect(observer:find("WorldChevron.create", 1, true)).to.be.ok()
            expect(observer:find("local travel = (os.clock() * 8)", 1, true)).to.be.ok()
            expect(observer:find("Vector3.new(host.Size.X / 3", 1, true)).to.be.ok()
            expect(observer:find("MergeEggTutorialUsesAutoCollector", 1, true)).to.be.ok()
            expect(observer:find("CREATE %d MORE EARTH EGG%s", 1, true)).to.be.ok()
            expect(observer:find("MergeEggTutorialClickHere", 1, true)).to.be.ok()
            expect(observer:find("TutorialClickPulse", 1, true)).to.be.ok()
            expect(observer:find('callout.Text = "CLICK HERE', 1, true)).to.be.ok()
            expect(observer:find("setTutorialClickCueTarget", 1, true)).to.be.ok()
            expect(observer:find("tutorialBuyEggCueAllowed", 1, true)).to.be.ok()
            expect(observer:find("eggsCreated < cuePurchaseCount", 1, true)).to.be.ok()
            expect(service:find("tutorial.disable_after_rebirth == true", 1, true)).to.be.ok()
            expect(service:find("MergeEggRebirth.normalizeCount(progress.rebirths) > 0", 1, true)).to.be.ok()
        end)

        it("admin reset returns all Merge Defense state to first-visit defaults", function()
            local admin = readFile("src/Server/Services/AdminToolsService.lua")
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local settings = readFile("src/Server/Services/SettingsService.lua")
            local liveResetAt = admin:find(
                "self._mergeEggPrototypeService:ResetForBeginning(targetPlayer)",
                1,
                true
            )
            local currencyResetAt = admin:find("-- 2) Currencies", 1, true)

            expect(liveResetAt).to.be.ok()
            expect(currencyResetAt).to.be.ok()
            expect(liveResetAt < currencyResetAt).to.equal(true)
            expect(
                admin:find(
                    "playerData.GameData.MergeDefense = MergeEggPlayerCombat.normalizeOnboarding(nil)",
                    1,
                    true
                )
            ).to.be.ok()
            expect(admin:find('playerData.Settings.MergeDefenseMode = "full"', 1, true)).to.be.ok()
            expect(admin:find("ResetMergeDefenseForBeginning(targetPlayer)", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:ResetForBeginning", 1, true)).to.be.ok()
            expect(service:find("self:_end(activeRecord, true, false)", 1, true)).to.be.ok()
            expect(service:find('player:SetAttribute("MergeDefenseRebirths", 0)', 1, true)).to.be.ok()
            expect(settings:find("function SettingsService:ResetMergeDefenseForBeginning", 1, true)).to.be.ok()
            expect(
                settings:find(
                    "data.GameData.MergeDefense = MergeEggPlayerCombat.normalizeOnboarding(nil)",
                    1,
                    true
                )
            ).to.be.ok()
        end)

        it("supports automatic Simple combat and real-pet Full combat", function()
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local enemyService = readFile("src/Server/Services/EnemyService.lua")
            local settings = readFile("src/Server/Services/SettingsService.lua")
            local follow = readFile("src/Client/Systems/PetFollowController.lua")
            local observer = readFile("src/Client/Systems/MergeEggPrototypeObserver.lua")
            local notice = readFile("src/Client/UI/Components/MergeDefenseModeNotice.lua")
            local hatching = readFile("src/Shared/Services/EggHatchingService.lua")
            local rules = config.player_reserve.full_mode

            expect(rules.default_mode).to.equal("full")
            expect(rules.minimum_level).to.equal(10)
            expect(rules.unlock_area_by_egg.aurora_egg).to.equal("Heaven_1_Ice")
            expect(rules.unlock_area_by_egg.hell3_desert_egg).to.equal("Hell_3_Desert")
            expect(service:find("function MergeEggPrototypeService:_awardFullModeHatch", 1, true)).to.be.ok()
            expect(service:find('source = "merge_defense_hatch"', 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_isPrototypeHugeTier", 1, true)).to.be.ok()
            expect(service:find("local playerDeployedTier =", 1, true)).to.be.ok()
            expect(service:find("prototypeHuge = prototypeHuge", 1, true)).to.be.ok()
            expect(service:find("naturalHuge = naturalHuge", 1, true)).to.be.ok()
            expect(service:find("FillEmptyPetSlots", 1, true)).to.be.ok()
            expect(service:find('record.playerCombatMode == "full"', 1, true)).to.be.ok()
            expect(
                service:find("function MergeEggPrototypeService:_setFullModeTargetOpen", 1, true)
            ).to.be.ok()
            expect(service:find('folder:SetAttribute(\n        "CombatTargetOpen"', 1, true)).to.be.ok()
            expect(service:find("record.playerPetFolderTargetOpenOriginal", 1, true)).to.be.ok()
            expect(enemyService:find("function EnemyService:_petCombatTargetOpen", 1, true)).to.be.ok()
            expect(enemyService:find("pet.Parent:GetAttribute", 1, true)).to.be.ok()
            expect(follow:find('GetAttribute("MergeEggPlayerCombatMode") == "full"', 1, true)).to.be.ok()
            expect(observer:find("MergeEggPrototypePlayerHatch", 1, true)).to.be.ok()
            expect(observer:find("MergeEggPrototypeModeNotice", 1, true)).to.be.ok()
            expect(settings:find("function SettingsService:RecordMergeDefenseEntry", 1, true)).to.be.ok()
            expect(settings:find("function SettingsService:ResolveMergeDefenseModeNotice", 1, true)).to.be.ok()
            expect(notice:find('resolve("stay_simple")', 1, true)).to.be.ok()
            expect(notice:find('resolve("switch_full")', 1, true)).to.be.ok()
            expect(hatching:find("local passive = firstOptions.passive == true", 1, true)).to.be.ok()
        end)

        it("authors nine positions while exposing only the four owned hatcher slots", function()
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            expect(config.version).to.equal(6)
            expect(#config.teams).to.equal(9)
            expect(config.station_layout.total_positions).to.equal(9)
            expect(config.station_layout.spacing).to.equal(8)
            expect(config.station_layout.roster_panel.gap).to.equal(0.5)
            expect(config.station_layout.roster_panel.logical_slots).to.equal(6)
            expect(config.station_layout.deployment_pads.size).to.equal(6.6)
            expect(config.station_layout.deployment_pads.egg_offset).to.equal(3)
            expect(config.station_layout.captain_front_offset).to.equal(4.5)
            expect(config.station_layout.stand_cup_inset).to.equal(0.25)
            expect(config.world.hatcher_control_position.x).to.equal(-38)
            expect(table.concat(config.station_layout.initial_position_slots, ",")).to.equal(
                "2,4,6,8"
            )
            expect(table.concat(config.station_layout.unlock_position_slots, ",")).to.equal(
                "5,3,7,1,9"
            )
            for index, team in ipairs(config.teams) do
                expect(team.id).to.equal(index)
                expect(team.position_slot).to.equal(index)
            end
            expect(config.team.starts_with_egg).to.equal(false)
            expect(config.team.egg_id).to.equal(nil)
            expect(table.concat(config.team.positions_by_egg_tier, ",")).to.equal("3,3,3,3")
            expect(#config.team.egg_progression).to.equal(4)
            expect(config.team.egg_progression[1]).to.equal("grass_egg")
            expect(config.team.egg_progression[2]).to.equal("ice_egg")
            expect(config.team.egg_progression[3]).to.equal("lava_egg")
            expect(config.team.egg_progression[4]).to.equal("desert_egg")
            expect(#config.squad).to.equal(0)
            expect(service:find("function MergeEggPrototypeService:_activeTeamConfigs", 1, true)).to.be.ok()
            expect(service:find("self:_activeTeamConfigs(record)", 1, true)).to.be.ok()
            expect(service:find("#teamConfigs > 0", 1, true)).to.be.ok()
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
            local expectedX = { -32, -24, -16, -8, 0, 8, 16, 24, 32 }
            for id, team in ipairs(config.teams) do
                expect(team.id).to.equal(id)
                expect(team.position_slot).to.equal(id)
                expect(team.spawn_offset.x).to.equal(nil)
                local derivedX = (team.position_slot - 5) * config.station_layout.spacing
                expect(derivedX).to.equal(expectedX[id])
                expect(team.squad).to.equal(nil)
                expect(names[team.principal_name]).to.equal(nil)
                names[team.principal_name] = true
            end
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local server = readFile("src/Server/init.server.lua")
            expect(service:find("SpawnStationary", 1, true)).to.be.ok()
            expect(service:find("_placeCaptainAtStation", 1, true)).to.be.ok()
            expect(service:find("_ensureHatcherStands", 1, true)).to.be.ok()
            expect(service:find("_authoredHatcherStand", 1, true)).to.be.ok()
            expect(service:find("SpawnGhostSquad", 1, true)).to.be.ok()
            expect(service:find("BuildPlayerHatchData", 1, true)).to.be.ok()
            expect(service:find("self._petsConfig.simulateHatch", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_rollPrototypeSquad", 1, true)).to.be.ok()
            expect(service:find("variant = tostring(result.variant", 1, true)).to.be.ok()
            expect(service:find("huge = result.huge == true", 1, true)).to.be.ok()
            expect(server:find('"PetFollowService",\n        "EggService",', 1, true)).to.be.ok()
            expect(service:find("for index, teamCfg in ipairs(teamConfigs)", 1, true)).to.be.ok()
            expect(service:find("MergeEggPrototypeTeam = true", 1, true)).to.be.ok()
            expect(service:find("local function stationXOffset", 1, true)).to.be.ok()
            expect(service:find("MergeEggPositionSlot = positionSlot", 1, true)).to.be.ok()
            expect(service:find("MergeEggTeamState", 1, true)).to.be.ok()
            expect(service:find("definition.squad = {}", 1, true)).to.be.ok()
            expect(service:find('state = "NoEgg"', 1, true)).to.be.ok()
            expect(service:find("initialized = false", 1, true)).to.be.ok()
            expect(service:find("eggTier = 0", 1, true)).to.be.ok()
            expect(service:find("or team.initialized ~= true", 1, true)).to.be.ok()
            expect(service:find('EphemeralDownPolicy = "destroy"', 1, true)).to.be.ok()
            local hatchAt = service:find(
                "function MergeEggPrototypeService:_hatch(player, appendOwnedSlots)",
                1,
                true
            )
            local nearestDropAt = service:find(
                "function MergeEggPrototypeService:_nearestPrototypeCoinDrop",
                hatchAt,
                true
            )
            local hatchBody = service:sub(hatchAt, nearestDropAt - 1)
            expect(hatchBody:find('self:_setWorldState("AwaitingFirstEgg"', 1, true)).to.be.ok()
            expect(hatchBody:find("self:_spawnNextWave(record)", 1, true)).to.equal(nil)
        end)

        it("uses world capacity and retains the weakest expanded draft for the player", function()
            local loop = config.progression_loop
            local home = loop.stages.home
            local heaven = loop.stages.heaven_1
            expect(loop.default_stage).to.equal("home")
            expect(table.concat(loop.order, ",")).to.equal("home,heaven_1")
            expect(home.team_positions).to.equal(3)
            expect(#home.team_positions_by_egg_tier).to.equal(56)
            expect(home.team_positions_by_egg_tier[1]).to.equal(3)
            expect(home.team_positions_by_egg_tier[5]).to.equal(4)
            expect(home.team_positions_by_egg_tier[13]).to.equal(5)
            expect(home.team_positions_by_egg_tier[21]).to.equal(6)
            expect(home.team_positions_by_egg_tier[29]).to.equal(6)
            expect(home.team_positions_by_egg_tier[33]).to.equal(6)
            expect(home.team_positions_by_egg_tier[56]).to.equal(6)
            expect(heaven.team_positions).to.equal(4)
            expect(#home.draft_rolls_by_tier).to.equal(56)
            expect(#heaven.draft_rolls_by_tier).to.equal(12)
            expect(#home.egg_progression).to.equal(56)
            expect(home.egg_progression[1]).to.equal("grass_egg")
            expect(home.egg_progression[8]).to.equal("gilded_egg")
            expect(home.egg_progression[9]).to.equal("blight_egg")
            expect(home.egg_progression[28]).to.equal("hell3_desert_egg")
            expect(home.egg_progression[29]).to.equal("grass_egg")
            expect(home.egg_progression[56]).to.equal("hell3_desert_egg")
            expect(config.team.prototype_huge_progression.start_tier).to.equal(29)
            expect(config.team.prototype_huge_progression.counts_as_real_huge).to.equal(false)
            expect(config.team.prototype_huge_progression.design_horizon_wave).to.equal(140)
            expect(config.rebirth.enabled).to.equal(true)
            expect(config.rebirth.currency).to.equal("hall_coins")
            expect(config.rebirth.costs_by_rank[1]).to.equal(nil)
            expect(config.rebirth.costs_by_rank[2]).to.equal(50000)
            expect(config.rebirth.costs_by_rank[3]).to.equal(200000)
            expect(config.rebirth.costs_by_rank[4]).to.equal(nil)
            expect(config.rebirth.cost_multiplier_per_rebirth).to.equal(1)
            expect(config.rebirth.allied_damage_bonus_per_rebirth).to.equal(1)
            expect(config.rebirth.damage_stacking).to.equal("additive")
            expect(config.rebirth.management_damage_stacking).to.equal("additive")
            expect(config.rebirth.cost_divisor_per_rebirth).to.equal(nil)
            expect(config.rebirth.minimum_cost).to.equal(1)
            expect(config.rebirth.minimum_drop).to.equal(1)
            expect(config.rebirth.denomination_scale).to.equal(1000000000)
            expect(home.combat_layers[1].through_wave).to.equal(10)
            expect(home.combat_layers[2].id).to.equal("heaven_1")
            expect(home.combat_layers[2].through_wave).to.equal(20)
            expect(home.combat_layers[3].id).to.equal("heaven_2")
            expect(home.combat_layers[3].through_wave).to.equal(30)
            expect(home.combat_layers[4].id).to.equal("heaven_3")
            expect(#heaven.egg_progression).to.equal(12)
            expect(heaven.egg_progression[12]).to.equal("heaven3_desert_egg")
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
            expect(draft.weakest({ blaster, support, tank })).to.equal(tank)

            local melee = { pet = "melee", role = "melee", combatPower = 20 }
            local control = { pet = "control", role = "control", combatPower = 50 }
            local three, threeReserve =
                draft.composePlayerRoster({ control, support, melee, tank, blaster }, 3)
            expect(three[1]).to.equal(tank)
            expect(three[2]).to.equal(blaster)
            expect(three[3]).to.equal(melee)
            expect(threeReserve[1]).to.equal(control)
            local four, fourReserve =
                draft.composePlayerRoster({ control, support, melee, tank, blaster }, 4)
            expect(four[4]).to.equal(support)
            expect(fourReserve[1]).to.equal(control)
            expect(draft.selectPlayerReplacement(threeReserve, "support")).to.equal(support)
            local sparse, sparseReserve = draft.composePlayerRoster({ tank, melee, support }, 3)
            expect(sparse[1]).to.equal(tank)
            expect(sparse[2]).to.equal(nil)
            expect(sparse[3]).to.equal(melee)
            expect(sparseReserve[1]).to.equal(support)
            expect(draft.selectPlayerReplacement(sparseReserve, "ranged", "non_support")).to.equal(
                nil
            )

            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            expect(service:find("MergeEggDraft.select", 1, true)).to.be.ok()
            expect(service:find("MergeEggDraft.weakest", 1, true)).to.be.ok()
            expect(service:find("MergeEggDraft.composePlayerRoster", 1, true)).to.be.ok()
            expect(service:find("MergeEggDraft.selectPlayerReplacement", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_draftRollsForEggTier", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_combatLayerForWave", 1, true)).to.be.ok()
            expect(service:find("stage.team_positions_by_egg_tier", 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("CombatLayerId"', 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("ProgressionStageId"', 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("PrototypeDraftCandidateRolls"', 1, true)).to.be.ok()
        end)

        it("crafts base eggs, merges equal tiers, and enforces physical board access", function()
            expect(config.team.earth_egg_pricing.currency).to.equal("hall_coins")
            expect(config.team.earth_egg_pricing.base_amount).to.equal(100)
            expect(config.team.earth_egg_pricing.growth).to.equal(2)
            expect(config.progression_loop.stages.home.starting_coins).to.equal(100)
            expect(config.opening_economy.wallet_amount).to.equal(0)
            expect(config.opening_economy.currency).to.equal("hall_coins")
            expect(config.opening_economy.pickup_amount).to.equal(120)
            expect(#config.opening_economy.pickup_offsets).to.equal(5)
            expect(config.opening_economy.pickup_amount * #config.opening_economy.pickup_offsets).to.equal(
                600
            )
            for _, offset in ipairs(config.opening_economy.pickup_offsets) do
                expect(offset.z > 0).to.equal(true)
            end
            expect(pricing.eggTierCost(100, 2, 0)).to.equal(100)
            expect(pricing.eggTierCost(100, 2, 1)).to.equal(200)
            expect(pricing.eggTierCost(100, 2, 2)).to.equal(400)
            expect(pricing.eggTierCost(100, 2, 3)).to.equal(800)
            expect(config.team.base_egg_generator.slow_growth_after_tier).to.equal(nil)
            expect(config.team.base_egg_generator.late_egg_cost_growth).to.equal(nil)
            expect(config.team.base_egg_generator.late_upgrade_cost_growth).to.equal(nil)
            local priorCost = 100
            for tier = 2, 56 do
                local cost = pricing.doublingTierCost(250, 2, tier, 2)
                if tier == 2 then
                    expect(cost).to.equal(250)
                else
                    expect(cost).to.equal(priorCost * 2)
                end
                priorCost = cost
            end
            expect(pricing.doublingTierCost(250, 1.25, 4, 2)).to.equal(1000)
            expect(pricing.totalInitialPositionCost(100, 4)).to.equal(400)
            expect(config.team.build_access.minimum_bulwark_depth).to.equal(4)
            expect(config.team.build_access.maximum_hatcher_distance).to.equal(18)
            expect(config.team.merge_board.merge_ratio).to.equal(2)
            expect(config.team.merge_board.station_use_distance).to.equal(16)
            expect(config.team.merge_board.rows).to.equal(4)
            expect(config.team.merge_board.columns).to.equal(4)
            expect(#config.team.merge_board.slot_colors).to.equal(6)
            expect(config.team.merge_board.forward_offset).to.equal(24)
            expect(config.team.merge_board.anchor_to_start_platform_back_edge).to.equal(true)
            expect(config.team.merge_board.authored_management_placement).to.equal(nil)
            expect(config.team.merge_board.board_use_distance).to.equal(36)
            expect(config.team.merge_board.equip_best_size.x).to.equal(7)
            expect(config.team.merge_board.equip_best_size.z).to.equal(12)
            expect(config.team.merge_board.equip_best_rotation_degrees).to.equal(90)
            expect(config.team.merge_board.equip_best_text_rotation_degrees).to.equal(180)
            expect(config.team.base_egg_generator.initial_tier).to.equal(1)
            expect(config.team.base_egg_generator.first_upgraded_egg_cost).to.equal(250)
            expect(config.team.base_egg_generator.egg_cost_growth).to.equal(2)
            expect(config.team.base_egg_generator.first_upgrade_cost).to.equal(1000)
            expect(config.team.base_egg_generator.upgrade_cost_growth).to.equal(2)
            expect(config.team.merge_board.slot_colors[1][1]).to.equal(87)
            expect(config.team.merge_board.slot_colors[1][2]).to.equal(210)
            expect(config.team.merge_board.slot_colors[2][1]).to.equal(76)
            expect(config.team.merge_board.slot_colors[2][3]).to.equal(245)
            expect(config.world.egg_create_control).to.equal("EggCreateControl")
            expect(config.world.egg_base_upgrade_control).to.equal("EggBaseUpgradeControl")
            expect(config.world.egg_merge_control).to.equal("EggMergeControl")
            expect(config.world.equip_best_control).to.equal("EquipBestControl")
            expect(config.world.merge_board).to.equal("MergeBoard")
            expect(config.world.containment_walls.enabled).to.equal(true)
            expect(config.world.containment_walls.height).to.equal(64)
            expect(config.world.containment_walls.close_player_entrance).to.equal(false)
            expect(config.management_upgrades.definitions.coin_value.step).to.equal(0.05)
            expect(config.management_upgrades.definitions.damage.step).to.equal(0.05)
            expect(config.management_upgrades.definitions.fire_rate.step).to.equal(0.05)
            expect(config.management_upgrades.definitions.egg_health.step).to.equal(0.05)

            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local observer = readFile("src/Client/Systems/MergeEggPrototypeObserver.lua")
            local authoring = readFile("scripts/studio/build_merge_egg_prototype_world.luau")
            expect(service:find("function MergeEggPrototypeService:_canUseHatcher", 1, true)).to.be.ok()
            expect(
                service:find("function MergeEggPrototypeService:_prepareSessionCurrency", 1, true)
            ).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_resetSessionCurrency", 1, true)).to.be.ok()
            expect(
                service:find("function MergeEggPrototypeService:_restoreSessionCurrency", 1, true)
            ).to.be.ok()
            expect(service:find('"merge_egg_session_setup"', 1, true)).to.be.ok()
            expect(service:find('"merge_egg_session_reset"', 1, true)).to.be.ok()
            expect(service:find('"merge_egg_session_restore"', 1, true)).to.be.ok()
            expect(
                service:find("function MergeEggPrototypeService:_spawnOpeningCoinDrops", 1, true)
            ).to.be.ok()
            expect(service:find('"merge_egg_opening_pickup_fallback"', 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_canUseEggStation", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:CreateBaseEgg", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:MergeBoardEggs", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_mergeableEggTier", 1, true)).to.be.ok()
            expect(service:find('return false, "behind_bulwark_required"', 1, true)).to.be.ok()
            expect(service:find('return false, "hatcher_too_far"', 1, true)).to.be.ok()
            expect(service:find('return false, "egg_station_too_far"', 1, true)).to.be.ok()
            expect(service:find("fromBulwark:Dot(towardFinish.Unit)", 1, true)).to.be.ok()
            expect(service:find("self._economyService:Transact", 1, true)).to.be.ok()
            expect(service:find('reason = "merge_egg_create_base_egg"', 1, true)).to.be.ok()
            expect(service:find('return false, "insufficient_currency"', 1, true)).to.be.ok()
            expect(service:find('return false, "egg_not_crafted"', 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("EggInventoryTotal"', 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("NextEarthEggCost"', 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_ensureMergeBoard", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_syncMergeBoardEggs", 1, true)).to.be.ok()
            expect(service:find('local eggs = models and models:FindFirstChild("Eggs")', 1, true)).to.be.ok()
            expect(service:find('return false, "merge_board_full"', 1, true)).to.be.ok()
            expect(service:find('visual:SetAttribute("MergeEggBoardEgg", true)', 1, true)).to.be.ok()
            expect(service:find('signs.Name = "EggSigns"', 1, true)).to.be.ok()
            expect(service:find("local colorIndex = (tier - 1)", 1, true)).to.be.ok()
            expect(service:find("sign.Color = signColor", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:MergeBoardSlots", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:ToggleAutoCombine", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:PurchaseRebirth", 1, true)).to.be.ok()
            expect(service:find('"merge_defense_management_upgrade"', 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:HandleBoardAction", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:EquipBestHatchers", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_equipBestPlan", 1, true)).to.be.ok()
            expect(service:find("MergeEggEquipBest.plan", 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("EquipBestAvailable"', 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("EquipBestActionCount"', 1, true)).to.be.ok()
            expect(service:find('action == "equip_best"', 1, true)).to.be.ok()
            expect(service:find('action == "rebirth"', 1, true)).to.be.ok()
            expect(service:find('reason = "merge_egg_rebirth_"', 1, true)).to.be.ok()
            expect(service:find('"merge_defense_rebirth"', 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:UpgradeBaseEgg", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_baseEggCreationCost", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_baseEggUpgradeCost", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_raiseBoardToBaseTier", 1, true)).to.be.ok()
            expect(
                service:find("function MergeEggPrototypeService:_raiseHatchersToBaseTier", 1, true)
            ).to.be.ok()
            expect(service:find("record.eggInventory[tier] = nil", 1, true)).to.be.ok()
            expect(service:find("team.eggTier = minimumTier", 1, true)).to.be.ok()
            expect(
                service:find(
                    "self:_expandTeamForEggTier(record, team, source, minimumTier)",
                    1,
                    true
                )
            ).to.be.ok()
            expect(service:find('action == "upgrade_base"', 1, true)).to.be.ok()
            expect(service:find('reason = "merge_egg_upgrade_base_egg"', 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_ensureDeploymentPads", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_syncDeploymentPad", 1, true)).to.be.ok()
            expect(service:find('action == "deploy_to_hatcher"', 1, true)).to.be.ok()
            expect(service:find("if tierBefore == 0 then", 1, true)).to.be.ok()
            expect(service:find("elseif boardTier ~= requiredTier then", 1, true)).to.be.ok()
            expect(authoring:find('board.Name = "MergeBoard"', 1, true)).to.be.ok()
            expect(authoring:find('"EquipBestControl"', 1, true)).to.be.ok()
            expect(authoring:find("CFrame.Angles(0, math.rad(90), 0)", 1, true)).to.be.ok()
            expect(authoring:find('"EggBaseUpgradeControl"', 1, true)).to.be.ok()
            expect(authoring:find('deploymentPads.Name = "MergeEggDeploymentPads"', 1, true)).to.be.ok()
            expect(authoring:find("for slot = 1, 9 do", 1, true)).to.be.ok()
            expect(authoring:find("-271.1", 1, true)).to.be.ok()
            expect(authoring:find("for row = 1, 4 do", 1, true)).to.be.ok()
            expect(authoring:find("for column = 1, 4 do", 1, true)).to.be.ok()
            expect(observer:find("local function rotateBoardEggs", 1, true)).to.be.ok()
            expect(observer:find("local function beginBoardDrag", 1, true)).to.be.ok()
            expect(observer:find("local function finishBoardDrag", 1, true)).to.be.ok()
            expect(observer:find("local function deploymentTeamFromInstance", 1, true)).to.be.ok()
            expect(observer:find("local function groundPanelCenterBehindEgg", 1, true)).to.be.ok()
            expect(observer:find('action = "upgrade_base"', 1, true)).to.be.ok()
            expect(observer:find('action = "deploy_to_hatcher"', 1, true)).to.be.ok()
            expect(observer:find('action = "equip_best"', 1, true)).to.be.ok()
            expect(observer:find('action = "rebirth"', 1, true)).to.be.ok()
            expect(observer:find("CONFIRM REBIRTH", 1, true)).to.be.ok()
            expect(observer:find('GetAttribute("EquipBestAvailable") == true', 1, true)).to.be.ok()
            expect(observer:find("local function setManagementCard", 1, true)).to.be.ok()
            expect(observer:find("MANAGEMENT_PRICE_THEME", 1, true)).to.be.ok()
            expect(observer:find("AMETHYST_GEM_ICON", 1, true)).to.be.ok()
            expect(observer:find("WAYCOIN_ICON", 1, true)).to.be.ok()
            expect(observer:find('pricePill.Name = "PricePill"', 1, true)).to.be.ok()
            expect(observer:find("MergeEggCostFormat.format(cost)", 1, true)).to.be.ok()
            expect(observer:find("MergeEggCostFormat.format(slotCost)", 1, true)).to.be.ok()
            expect(observer:find("MergeEggCostFormat.format(spawnCost)", 1, true)).to.be.ok()
            expect(observer:find("MergeEggCostFormat.format(buyCost)", 1, true)).to.be.ok()
            expect(observer:find("MergeEggCostFormat.format(rebirthCost)", 1, true)).to.be.ok()
            expect(observer:find("level * step", 1, true)).never.to.be.ok()
            expect(service:find("1 + level * math.max", 1, true)).to.be.ok()
            expect(observer:find("local function setDragTarget", 1, true)).to.be.ok()
            expect(observer:find("local function preferredDropTarget", 1, true)).to.be.ok()
            expect(observer:find("local function createCompatibleMergeSquares", 1, true)).to.be.ok()
            expect(observer:find("mergeSnapRadius", 1, true)).to.be.ok()
            expect(observer:find('name = "MergeEggDropChevron"', 1, true)).to.be.ok()
            expect(observer:find("MergeEggPrototypeBoardAction:FireServer", 1, true)).to.be.ok()
            expect(observer:find("surface.Adornee = host", 1, true)).to.be.ok()
            expect(observer:find("surface.Parent = playerGui", 1, true)).to.be.ok()
            expect(observer:find("MergeEggPrototypeBoardResult.OnClientEvent", 1, true)).to.be.ok()
            expect(service:find("MergeEggPrototypeBoardResult:FireClient", 1, true)).to.be.ok()
            expect(network.packets.MergeEggPrototypeBoardAction.authorization).to.equal("player")
            expect(network.packets.MergeEggPrototypeBoardAction.environments.production).to.equal(
                true
            )
            expect(network.packets.MergeEggPrototypeBoardResult.direction).to.equal(
                "server_to_client"
            )
            expect(network.packets.MergeEggPrototypeBoardResult.environments.production).to.equal(
                true
            )
            expect(network.packets.MergeEggPrototypePlayerHatch.environments.production).to.equal(
                true
            )
            expect(pets.serials.census_enabled).to.equal(false)
            local petIndexService = readFile("src/Server/Services/PetIndexService.lua")
            expect(petIndexService:find("_rememberDiscoveredHuges", 1, true)).to.be.ok()
        end)

        it("uses the entering player's level as the shared combat baseline", function()
            expect(config.combat_level.source).to.equal("active_player_effective_level")
            expect(config.combat_level.freeze_for_run).to.equal(true)
            expect(config.combat_level.rank_tiers.trash).to.equal("trash_mob")
            expect(config.combat_level.rank_tiers.tank).to.equal("trash_mob")
            expect(config.combat_level.rank_tiers.lieutenant).to.equal("mid_tier")
            expect(config.combat_level.rank_tiers.boss).to.equal("boss")

            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            expect(service:find("local function playerCombatLevel", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_prototypeBaseLevel", 1, true)).to.be.ok()
            expect(service:find("baseCombatLevel = playerCombatLevel", 1, true)).to.be.ok()
            expect(service:find("definition.level = self:_prototypeBaseLevel(record)", 1, true)).to.be.ok()
            expect(service:find("PrincipalLevel = self:_prototypeBaseLevel(record)", 1, true)).to.be.ok()
            expect(service:find("Level = self:_prototypeBaseLevel(record)", 1, true)).to.be.ok()
            expect(service:find("(self._config.combat_level or {}).rank_tiers", 1, true)).to.be.ok()
            expect(service:find('model:SetAttribute("MergeEggBaseCombatLevel"', 1, true)).to.be.ok()
            expect(service:find('"PrototypeBaseCombatLevel"', 1, true)).to.be.ok()
        end)

        it("varies Home attackers and mirrors Heaven eggs with their Hell counterparts", function()
            local progression = config.progression_loop.stages.home.egg_progression
            local rosters = config.enemy.rosters
            local earthEgg = enemyRoster.defenderEgg(progression, 1, 1)
            local promotedEgg = enemyRoster.defenderEgg(progression, 0, 5)
            expect(earthEgg).to.equal("grass_egg")
            expect(enemyRoster.opposingEgg(rosters, earthEgg)).to.equal(nil)
            expect(promotedEgg).to.equal("bloom_egg")
            expect(enemyRoster.opposingEgg(rosters, "bloom_egg")).to.equal("blight_egg")
            expect(enemyRoster.opposingEgg(rosters, "aurora_egg")).to.equal("black_ice_egg")
            expect(enemyRoster.opposingEgg(rosters, "solar_egg")).to.equal("infernal_egg")
            expect(enemyRoster.opposingEgg(rosters, "gilded_egg")).to.equal("ash_egg")
            expect(enemyRoster.opposingEgg(rosters, "infernal_egg")).to.equal("solar_egg")
            expect(enemyRoster.opposingEgg(rosters, "heaven2_grass_egg")).to.equal(
                "hell2_grass_egg"
            )
            expect(enemyRoster.opposingEgg(rosters, "hell3_desert_egg")).to.equal(
                "heaven3_desert_egg"
            )
            expect(enemyRoster.homeEnemyId(rosters, "whelp", 0)).to.equal("lava_imp")
            expect(enemyRoster.homeEnemyId(rosters, "whelp", 0.999)).to.equal("murder_crow")

            local hellRoll =
                enemyRoster.eggPetCandidates(pets, petRoles, rosters, "infernal_egg", "whelp")
            expect(#hellRoll).to.equal(5)
            expect(hellRoll[1].id).to.equal("abyssal_wyrm")
            expect(hellRoll[1].weight).to.equal(0.025)
            expect(hellRoll[5].id).to.equal("cinderling_imp")
            local firstPosition =
                enemyRoster.eggPet(pets, petRoles, rosters, "infernal_egg", "whelp", 0)
            local lieutenantPosition =
                enemyRoster.eggPet(pets, petRoles, rosters, "infernal_egg", "brute", 0.5)
            local sameRollDifferentRank =
                enemyRoster.eggPet(pets, petRoles, rosters, "infernal_egg", "boss", 0.5)
            expect(firstPosition.id).to.equal("abyssal_wyrm")
            expect(lieutenantPosition.id).to.equal("brimstone_salamander")
            expect(sameRollDifferentRank.id).to.equal(lieutenantPosition.id)
            expect(config.enemy.archetypes.lieutenant.hp > config.enemy.archetypes.whelp.hp).to.equal(
                true
            )
            expect(config.enemy.rank_presentation.lieutenant.hp_mult).to.equal(2)
            expect(config.enemy.rank_presentation.lieutenant.dmg_mult).to.equal(1)
            expect(config.enemy.rank_presentation.boss.hp_mult).to.equal(6)
            expect(config.enemy.rank_presentation.boss.dmg_mult).to.equal(1)
            expect(config.enemy.rank_presentation.boss.use_huge_scale).to.equal(true)
            expect(config.enemy.rank_presentation.boss.role).to.equal(nil)
            expect(config.enemy.rank_presentation.villain.scale_mult).to.equal(4)
            expect(config.enemy.rank_presentation.villain.dmg_mult).to.equal(1)
            expect(config.enemy.rank_presentation.archvillain.scale_mult).to.equal(6)
            expect(config.enemy.rank_presentation.archvillain.dmg_mult).to.equal(1)

            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            expect(service:find("function MergeEggPrototypeService:_resolveWaveEnemy", 1, true)).to.be.ok()
            expect(service:find("MergeEggEnemyRoster.defenderEgg", 1, true)).to.be.ok()
            expect(service:find("MergeEggEnemyRoster.opposingEgg", 1, true)).to.be.ok()
            expect(service:find("self._enemyService:SynthesizePetEnemy", 1, true)).to.be.ok()
            expect(service:find("spawnSource.hp = enemyDef.hp", 1, true)).to.be.ok()
            expect(service:find("enemyDef.attack and enemyDef.attack.damage", 1, true)).to.be.ok()
            expect(service:find('"MergeEggAttackerEgg"', 1, true)).to.be.ok()
            expect(service:find('"MergeEggEnemyPetId"', 1, true)).to.be.ok()

            local enemyService = readFile("src/Server/Services/EnemyService.lua")
            local followService = readFile("src/Server/Services/PetFollowService.lua")
            local combatApplication = readFile("src/Server/CombatApplication.lua")
            expect(enemyService:find("pet_control = petDef.attack_control", 1, true)).to.be.ok()
            expect(enemyService:find("pet_dot = petDef.attack_dot", 1, true)).to.be.ok()
            expect(enemyService:find("pet_auras = petAuras", 1, true)).to.be.ok()
            expect(enemyService:find("PetAbilityRuntime.resolve", 1, true)).to.be.ok()
            expect(enemyService:find("function EnemyService:_enemyPetDotPass", 1, true)).to.be.ok()
            expect(enemyService:find("function EnemyService:_petEnemyAuraPass", 1, true)).to.be.ok()
            expect(followService:find('"EnemyCurseUntil"', 1, true)).to.be.ok()
            expect(followService:find('"EnemyArmorBuffUntil"', 1, true)).to.be.ok()
            expect(combatApplication:find('"EnemyHealSuppressedUntil"', 1, true)).to.be.ok()
        end)

        it("uses capped composition-authored waves scoped to assigned NPC folders", function()
            expect(#config.waves).to.equal(20)
            expect(config.waves[1].gap_after).to.equal(8)
            expect(#config.waves[1].groups).to.equal(1)
            expect(config.waves[1].groups[1].units[1].archetype).to.equal("whelp")
            expect(config.waves[1].groups[1].units[1].count).to.equal(3)
            expect(config.waves[2].gap_after).to.equal(8)
            expect(#config.waves[2].groups).to.equal(1)
            expect(config.waves[2].groups[1].units[1].archetype).to.equal("brute")
            expect(config.waves[2].groups[1].units[1].count).to.equal(1)
            expect(config.waves[3].gap_after).to.equal(6)
            expect(#config.waves[3].groups).to.equal(2)
            expect(config.waves[3].groups[1].units[1].archetype).to.equal("brute")
            expect(config.waves[3].groups[1].units[2].count).to.equal(3)
            expect(config.waves[3].groups[2].units[1].archetype).to.equal("whelp")
            expect(config.waves[3].groups[2].units[1].count).to.equal(4)
            local waveCounts = {}
            for _, wave in ipairs(config.waves) do
                local waveEnemies = 0
                for _, group in ipairs(wave.groups) do
                    for _, unit in ipairs(group.units) do
                        waveEnemies += unit.count
                    end
                end
                waveCounts[#waveCounts + 1] = waveEnemies
            end
            expect(table.concat(waveCounts, ",")).to.equal(
                "3,1,8,12,16,16,20,24,20,13,8,16,24,24,19,28,28,32,32,27"
            )
            expect(config.endurance.stop_when_all_teams_defeated).to.equal(false)
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            expect(service:find('rewardPolicy = "none"', 1, true)).to.be.ok()
            local combatApplication = readFile("src/Server/CombatApplication.lua")
            expect(combatApplication:find('source:GetAttribute("PetRecordKey")', 1, true)).to.be.ok()
            local enemyService = readFile("src/Server/Services/EnemyService.lua")
            expect(enemyService:find('model:GetAttribute("MergeEggPlayerPetKillUserId")', 1, true)).to.be.ok()
            expect(enemyService:find('killer:GetAttribute("AscensionUnlocked") == true', 1, true)).to.be.ok()
            expect(enemyService:find("combat:AwardExperience(", 1, true)).to.be.ok()
            local combatService = readFile("src/Server/Services/CombatService.lua")
            expect(combatService:find("function CombatService:AwardExperience", 1, true)).to.be.ok()
            expect(combatService:find('progression:AddExperience(player, xp, "combat")', 1, true)).to.be.ok()
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
            expect(config.enemy.archetypes.whelp.id).to.equal("lava_imp")
            expect(config.enemy.archetypes.brute.id).to.equal("ember_brute")
            expect(config.enemy.archetypes.lieutenant.id).to.equal("ember_acolyte")
            expect(config.enemy.archetypes.boss.id).to.equal("infernal_boss")
            expect(config.enemy.archetypes.heaven_melee.id).to.equal("zealous_cherub")
            expect(config.enemy.archetypes.heaven_boss.id).to.equal("celestial_archon")
            expect(config.enemy.opposition_by_defender_realm.heaven).to.equal("hell")
            expect(config.enemy.opposition_by_defender_realm.hell).to.equal("heaven")
            expect(config.enemy.maximum_wave_enemies).to.equal(32)
            for _, waveEnemies in ipairs(waveCounts) do
                expect(waveEnemies <= config.enemy.maximum_wave_enemies).to.equal(true)
            end
            expect(config.waves[2].groups[1].units[1].archetype).to.equal("brute")
            expect(config.waves[3].groups[1].units[2].count).to.equal(3)
            expect(config.waves[6].groups[1].units[3].archetype).to.equal("lieutenant")
            expect(config.waves[10].groups[1].units[1].archetype).to.equal("boss")
            expect(config.waves[11].attacker_realm).to.equal("hell")
            expect(#config.waves[11].groups).to.equal(1)
            expect(#config.waves[12].groups).to.equal(2)
            expect(#config.waves[13].groups).to.equal(3)
            expect(config.waves[11].gap_after).to.equal(8)
            expect(config.waves[12].gap_after).to.equal(8)
            expect(config.waves[13].gap_after).to.equal(6)
            expect(config.world.bulwark_line).to.equal("BulwarkLine")
            expect(config.world.breach_line).to.equal("BreachLine")
            expect(config.enemy.bulwark_threat).to.equal(250)
            expect(config.enemy.bulwark_reengage_seconds).to.equal(0.5)
            expect(config.enemy.bulwark_contact_padding).to.equal(1)
            expect(config.enemy.idle_reinforcement_grace_seconds).to.equal(2)
            expect(config.enemy.maximum_reserve_teams).to.equal(1)
            expect(config.enemy.breach_overrun_enemy_per_active_pet).to.equal(1)
            expect(config.enemy.breach_overrun_minimum).to.equal(4)
            expect(config.combat.attack_cadence_multiplier).to.equal(4)
            expect(service:find("MergeEggNextDefenseAlertAt", 1, true)).to.be.ok()
            expect(service:find("not engaged and now >= nextAlertAt", 1, true)).to.be.ok()
            expect(service:find("if team.initialized == true then", 1, true)).to.be.ok()
            expect(service:find('local authoredGroups = type(wave.groups) == "table"', 1, true)).to.be.ok()
            expect(service:find("local function configuredWaveEnemyCount", 1, true)).to.be.ok()
            expect(service:find('local archetypeKey = tostring(unit.archetype or "")', 1, true)).to.be.ok()
            expect(service:find('return false, "wave_enemy_limit_exceeded"', 1, true)).to.be.ok()
            expect(service:find('groupKind == "tank" and groupOrdinal == 1', 1, true)).to.be.ok()
            expect(service:find("local teamOrdinal =", 1, true)).to.be.ok()
            expect(service:find('model:SetAttribute("MergeEggAttackGroup"', 1, true)).to.be.ok()
            expect(service:find('spec.compositionRole or "melee"', 1, true)).to.be.ok()
            expect(service:find('model:SetAttribute("MergeEggArchetype"', 1, true)).to.be.ok()
            expect(service:find('model:SetAttribute("MergeEggFaction"', 1, true)).to.be.ok()
            expect(service:find('model:SetAttribute("MergeEggRank"', 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("WaveConfigId"', 1, true)).to.be.ok()
            expect(service:find("resolvedWave.gap_after", 1, true)).to.be.ok()
            expect(service:find("enemy_tank_config_missing", 1, true)).to.be.ok()
            expect(service:find('model:SetAttribute("CombatTargetOpen", true)', 1, true)).to.be.ok()
            expect(service:find("for _, team in ipairs(record.teams or {})", 1, true)).to.be.ok()
            expect(service:find("MergeEggReserveAlertedPets", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_sustainBulwarkTarget", 1, true)).to.be.ok()
            expect(service:find("MergeEggNextBulwarkAlertAt", 1, true)).to.be.ok()
            expect(service:find("MergeEggBulwarkAlertCount", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_reinforceIdleTeams", 1, true)).to.be.ok()
            expect(service:find("MergeEggDefenseAssignment.pickHardest", 1, true)).to.be.ok()
            expect(service:find("MergeEggDefenseAssignment.reserveCount", 1, true)).to.be.ok()
            expect(service:find('team.folder:SetAttribute("CombatTargetOpen", true)', 1, true)).to.be.ok()
            expect(service:find("team.isReserve = false", 1, true)).to.be.ok()
            expect(service:find("record.waveReserveReleased = true", 1, true)).to.be.ok()
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
            expect(service:find('model:SetAttribute("MergeEggCanAttackObjective", true)', 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("EnemiesPastBreachLine"', 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("BreachPressureHits"', 1, true)).to.be.ok()
            expect(service:find("Merge Egg prototype sustained overrun damaged eggs", 1, true)).to.equal(
                nil
            )
            expect(service:find('world:SetAttribute("FirstBreachWave"', 1, true)).to.be.ok()
            expect(service:find('"CombatCadenceMultiplier"', 1, true)).to.be.ok()
            expect(petFollow:find("CombatCadence.interval", 1, true)).to.be.ok()
            expect(enemyService:find("CombatCadence.interval", 1, true)).to.be.ok()
            expect(service:find("FirstPetLossWave", 1, true)).to.be.ok()
            expect(service:find("PeakActiveEnemies", 1, true)).to.be.ok()
            expect(service:find('self:_setWorldState("ObjectiveLost"', 1, true)).to.be.ok()
            expect(service:find('record.runId .. ":" .. stageId .. ":wave:" .. waveIndex', 1, true)).to.be.ok()
        end)

        it("banks ten-wave checkpoints and restarts into authored recovery ramps", function()
            expect(config.checkpoints.interval).to.equal(10)
            expect(config.checkpoints.intermission_seconds).to.equal(8)
            expect(config.checkpoints.restart_delay_seconds).to.equal(3)
            expect(config.checkpoints.recovery_wave_count).to.equal(3)
            expect(config.checkpoints.gameplay_restore_mode).to.equal("retain_progress")
            expect(config.checkpoints.test_restore_mode).to.equal("checkpoint_snapshot")
            expect(config.checkpoints.auto_restart_gameplay).to.equal(true)
            for waveIndex = 11, 13 do
                local wave = config.waves[waveIndex]
                expect(#wave.groups).to.equal(waveIndex - 10)
                for _, group in ipairs(wave.groups) do
                    expect(#group.units).to.equal(1)
                    expect(group.units[1].archetype).to.equal("whelp")
                    expect(group.units[1].count).to.equal(8)
                end
            end

            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            expect(service:find("function MergeEggPrototypeService:_captureCheckpoint", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_restoreCheckpoint", 1, true)).to.be.ok()
            expect(
                service:find(
                    "function MergeEggPrototypeService:_restartCheckpointKeepingProgress",
                    1,
                    true
                )
            ).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_canRestartCheckpoint", 1, true)).to.be.ok()
            expect(
                service:find(
                    "function MergeEggPrototypeService:RestoreCheckpointSnapshotForTest",
                    1,
                    true
                )
            ).to.be.ok()
            expect(service:find('"merge_egg_checkpoint_restore"', 1, true)).to.be.ok()
            expect(service:find('"CheckpointIntermission"', 1, true)).to.be.ok()
            expect(service:find('self:_setWorldState("CheckpointRestarting"', 1, true)).to.be.ok()
            expect(service:find("waveIndex > pendingCheckpoint", 1, true)).to.be.ok()
            expect(service:find("self:_captureCheckpoint(record, pendingCheckpoint)", 1, true)).to.be.ok()
            expect(service:find('self:_restoreCheckpoint(record, "coin_runner")', 1, true)).to.be.ok()
            expect(
                service:find(
                    'self:_restartCheckpointKeepingProgress(record, "reset_prompt")',
                    1,
                    true
                )
            ).to.be.ok()
            expect(service:find("record.checkpointSnapshot = bankedSnapshot", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_persistCheckpoint", 1, true)).to.be.ok()
            expect(
                service:find("function MergeEggPrototypeService:_restoreDurableCheckpoint", 1, true)
            ).to.be.ok()
            expect(service:find('"merge_defense_checkpoint"', 1, true)).to.be.ok()
            expect(service:find("critical = true", 1, true)).to.be.ok()
            expect(service:find("advanceUpgradeExperiment = false", 1, true)).to.be.ok()
            expect(service:find("preserveDrops = true", 1, true)).to.be.ok()
            expect(service:find("team.resetEggTier = destroyedTier", 1, true)).to.be.ok()
            expect(service:find("team.resetEggTier = minimumTier", 1, true)).to.be.ok()
            expect(service:find("record.objectiveEggsStarting", 1, true)).to.be.ok()
            expect(
                service:find(
                    'self:_restartCheckpointKeepingProgress(record, "gameplay_auto")',
                    1,
                    true
                )
            ).to.be.ok()
            expect(service:find('world:SetAttribute("CheckpointWave"', 1, true)).to.be.ok()
            expect(service:find('world:SetAttribute("CheckpointRestarts"', 1, true)).to.be.ok()
        end)

        it("uses five reserve eggs as defeat and random per-team replacement FIFOs", function()
            expect(config.objective.starting_eggs).to.equal(5)
            expect(config.objective.damage_per_escape).to.equal(1)
            expect(config.objective.hatcher_egg_max_health).to.equal(5000)
            expect(config.objective.hatcher_egg_threat).to.equal(120)
            expect(config.reinforcement.enabled).to.equal(true)
            expect(config.reinforcement.hatch_seconds).to.equal(4)
            expect(config.reinforcement.damage_production_lock_seconds).to.equal(5)
            expect(config.reinforcement.queue_policy).to.equal("per_team_fifo_random_egg_roll")
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local enemyService = readFile("src/Server/Services/EnemyService.lua")
            local observer = readFile("src/Client/Systems/MergeEggPrototypeObserver.lua")
            local followController = readFile("src/Client/Systems/PetFollowController.lua")
            expect(service:find("function MergeEggPrototypeService:_damageObjective", 1, true)).to.be.ok()
            expect(
                service:find(
                    "function MergeEggPrototypeService:_damageInstalledHatcherEgg",
                    1,
                    true
                )
            ).to.be.ok()
            expect(
                service:find("function MergeEggPrototypeService:_spawnHatcherEggObjective", 1, true)
            ).to.be.ok()
            expect(service:find('model:SetAttribute("MergeEggObjective", true)', 1, true)).to.be.ok()
            expect(service:find('model:SetAttribute("NoPetOffense", true)', 1, true)).to.be.ok()
            expect(service:find('model:SetAttribute("NoPetSupport", true)', 1, true)).to.be.ok()
            expect(service:find('model:SetAttribute("NoNaturalRegen", true)', 1, true)).to.be.ok()
            expect(service:find("self:_damageObjective(record)", 1, true)).to.be.ok()
            expect(service:find("MergeEggNeedsRebuild", 1, true)).to.be.ok()
            expect(service:find("MergeEggInstalledDamageTaken", 1, true)).to.be.ok()
            expect(enemyService:find('pet:GetAttribute("MergeEggObjective") == true', 1, true)).to.be.ok()
            expect(
                enemyService:find(
                    'entry.model:GetAttribute("MergeEggCanAttackObjective") == true',
                    1,
                    true
                )
            ).to.be.ok()
            expect(enemyService:find('pet:GetAttribute("NoNaturalRegen") ~= true', 1, true)).to.be.ok()
            expect(enemyService:find('ally:GetAttribute("NoPetSupport") ~= true', 1, true)).to.be.ok()
            expect(observer:find('"%s • %d/%d HP • %d PICK%s%s"', 1, true)).to.be.ok()
            expect(observer:find('pet:GetAttribute("MergeEggObjective") ~= true', 1, true)).to.be.ok()
            expect(followController:find('m:GetAttribute("MergeEggObjective") ~= true', 1, true)).to.be.ok()
            expect(service:find("HatcherEggsDestroyed", 1, true)).to.be.ok()
            expect(service:find("HatcherEggsRebuilt", 1, true)).to.be.ok()
            expect(service:find("ObjectiveEggsRemaining", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_queueMissingPets", 1, true)).to.be.ok()
            expect(
                service:find(
                    "function MergeEggPrototypeService:_interruptHatcherProduction",
                    1,
                    true
                )
            ).to.be.ok()
            expect(
                service:find("function MergeEggPrototypeService:_processReplacementQueues", 1, true)
            ).to.be.ok()
            expect(service:find("MergeEggProductionLockRemaining", 1, true)).to.be.ok()
            expect(observer:find("PRODUCTION JAMMED", 1, true)).to.be.ok()
            expect(service:find("positionOffset = queued.slot - 1", 1, true)).to.be.ok()
            expect(service:find("queued.definition", 1, true)).to.be.ok()
            expect(service:find("self:_rollDraftedPrototypePet(", 1, true)).to.be.ok()
            expect(service:find("self:_publishTeamSlot(team, queued.slot", 1, true)).to.be.ok()
            expect(service:find("MergeEggReplacementSlots", 1, true)).to.be.ok()
            expect(service:find("PeakReplacementQueueDepth", 1, true)).to.be.ok()
        end)

        it("fields a session-only three-or-four-pet player reserve roster", function()
            local reserve = config.player_reserve
            expect(reserve.enabled).to.equal(true)
            expect(reserve.base_slots).to.equal(3)
            expect(reserve.maximum_slots).to.equal(4)
            expect(reserve.extra_slot_feature).to.equal("extra_equip_slots")
            expect(reserve.replacement_seconds).to.equal(30)
            expect(reserve.castoff_policy).to.equal("weakest_draft_candidate")
            expect(table.concat(reserve.roles, ",")).to.equal("tank,ranged,melee,support")

            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local server = readFile("src/Server/init.server.lua")
            expect(service:find("function MergeEggPrototypeService:_playerReserveSlots", 1, true)).to.be.ok()
            expect(service:find("GetFeature(record.player, featureName)", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_addPlayerCastoff", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_ensurePlayerEscort", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_syncPlayerEscort", 1, true)).to.be.ok()
            expect(
                service:find(
                    "function MergeEggPrototypeService:_processPlayerReplacementQueue",
                    1,
                    true
                )
            ).to.be.ok()
            expect(service:find("MergeEggPlayerReserveUnit", 1, true)).to.be.ok()
            expect(service:find("CombatTargetOpen = true", 1, true)).to.be.ok()
            expect(service:find("MergeEggReserveRosterBench", 1, true)).to.be.ok()
            expect(service:find("checkpoint_player_escort_assets_missing", 1, true)).to.be.ok()
            expect(server:find('"EconomyService",\n        "DataService",', 1, true)).to.be.ok()
        end)

        it("drops Hall Waycoins and rank-scaled Gems with the game-wide player magnet", function()
            expect(config.rewards.currency).to.equal("hall_coins")
            expect(config.rewards.trash_amount).to.equal(40)
            expect(config.rewards.tank_amount).to.equal(120)
            expect(config.rewards.lieutenant_amount).to.equal(180)
            expect(config.rewards.pickup_visual_scale).to.equal(2)
            expect(config.rewards.pickup_despawn_seconds).to.equal(600)
            expect(config.rewards.contain_pickups_to_world).to.equal(true)
            expect(config.rewards.pickup_wall_inset).to.equal(2)
            expect(config.rewards.magnet).never.to.be.ok()
            expect(config.rewards.boss_amount).to.equal(2400)
            expect(config.rewards.gem_drop.currency).to.equal("gems")
            expect(config.rewards.gem_drop.amount).to.equal(1)
            expect(config.rewards.gem_drop.base_chance).to.equal(0.02)
            expect(config.rewards.gem_drop.rank_chance_multiplier.trash).to.equal(1)
            expect(config.rewards.gem_drop.rank_chance_multiplier.tank).to.equal(1)
            expect(config.rewards.gem_drop.rank_chance_multiplier.lieutenant).to.equal(3)
            expect(config.rewards.gem_drop.rank_chance_multiplier.boss).to.equal(10)
            expect(drops.collect_radius).to.equal(11)
            expect(drops.currency_pickups.hall_coins.mesh).to.be.ok()
            expect(drops.currency_pickups.hall_coins.texture).to.be.ok()
            expect(drops.currency_pickups.gems.mesh).to.equal("rbxassetid://96648542072137")
            expect(drops.currency_pickups.gems.texture).to.equal("rbxassetid://102124881592196")

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
            local enemyHud = readFile("src/Client/Systems/EnemyHud.lua")
            local server = readFile("src/Server/init.server.lua")
            expect(service:find("function MergeEggPrototypeService:_dropEnemyCoins", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_dropEnemyGems", 1, true)).to.be.ok()
            expect(service:find("record.lootRandom:NextNumber()", 1, true)).to.be.ok()
            expect(service:find('rewardPolicy = "none"', 1, true)).to.be.ok()
            expect(service:find("usePlayerModifiers = true", 1, true)).to.be.ok()
            expect(service:find("MergeEggMagnetRadius", 1, true)).never.to.be.ok()
            expect(service:find('source = "merge_egg_prototype"', 1, true)).to.be.ok()
            expect(service:find("containmentBounds =", 1, true)).to.be.ok()
            expect(
                service:find("function MergeEggPrototypeService:_ensureContainmentWalls", 1, true)
            ).to.be.ok()
            expect(service:find("self:_prototypeCoinDropOptions(record)", 1, true)).to.be.ok()
            expect(service:find("visualScale =", 1, true)).to.be.ok()
            expect(service:find('"MergeEggCoinReward"', 1, true)).to.be.ok()
            expect(service:find('"PrototypeCoinsDropped"', 1, true)).to.be.ok()
            expect(service:find('"PrototypeGemsDropped"', 1, true)).to.be.ok()
            expect(dropService:find("function DropService:SpawnCoinDrop", 1, true)).to.be.ok()
            expect(dropService:find("local function containedDropTarget", 1, true)).to.be.ok()
            expect(dropService:find("model:ScaleTo(visualScale)", 1, true)).to.be.ok()
            expect(dropService:find('model:SetAttribute("DropDespawnSeconds"', 1, true)).to.be.ok()
            expect(dropService:find('model:SetAttribute("DropBouncedInside"', 1, true)).to.be.ok()
            expect(dropService:find("rec.collectRadiusAttribute", 1, true)).to.be.ok()
            expect(dropService:find("rec.usePlayerModifiers == false", 1, true)).to.be.ok()
            expect(dropService:find("function DropService:DiscardDrops", 1, true)).to.be.ok()
            expect(dropService:find("function DropService:_stepAutoCollectors", 1, true)).to.be.ok()
            expect(dropService:find('model:SetAttribute("AutoCollectorPet", true)', 1, true)).to.be.ok()
            expect(dropService:find('player:GetAttribute("Eff_Speed")', 1, true)).to.be.ok()
            expect(dropService:find("and rec.kind == nil", 1, true)).to.be.ok()
            expect(dropService:find("self:_collect(target)", 1, true)).to.be.ok()
            expect(
                currencyStack:find('player:GetAttribute("InMergeEggPrototype") == true', 1, true)
            ).to.be.ok()
            expect(currencyStack:find('GetAttributeChangedSignal("InMergeEggPrototype")', 1, true)).to.be.ok()
            expect(enemyHud:find("local ENEMY_COLUMNS = 2", 1, true)).to.be.ok()
            expect(enemyHud:find('Instance.new("UIGridLayout")', 1, true)).to.be.ok()
            expect(
                enemyHud:find('localPlayer:GetAttribute("InMergeEggPrototype") == true', 1, true)
            ).to.be.ok()
            expect(enemyHud:find("moneyStack.Visible = true", 1, true)).to.be.ok()
            expect(
                server:find(
                    '"EggService",\n        "DropService",\n        "EconomyService",',
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
                local observer = readFile("src/Client/Systems/MergeEggPrototypeObserver.lua")
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
                expect(service:find("for _, team in ipairs(record.teams or {})", 1, true)).to.be.ok()
                expect(service:find("for _, model in ipairs(record.playerUnits or {})", 1, true)).to.be.ok()
                expect(follow:find("MergeEggDamageScope.playerPetMultiplier", 1, true)).to.be.ok()
                expect(service:find("MergeEggDamageScope.additiveUpgradeMultiplier", 1, true)).to.be.ok()
                expect(follow:find('"MergeDefenseManagementDamageMultiplier"', 1, true)).to.be.ok()
                expect(service:find('"MergeDefenseAlliedDamageMultiplier"', 1, true)).to.be.ok()
                expect(service:find('"MergeDefenseNextAlliedDamageMultiplier"', 1, true)).to.be.ok()
                expect(observer:find("formatDamageMultiplier", 1, true)).to.be.ok()
                expect(observer:find("%s TOTAL DAMAGE", 1, true)).to.be.ok()
                expect(follow:find('player:GetAttribute("InMergeEggPrototype")', 1, true)).to.be.ok()
                expect(follow:find('player:GetAttribute("MergeEggPlayerCombatMode")', 1, true)).to.be.ok()
                expect(follow:find('pet:GetAttribute("MergeEggUnit")', 1, true)).to.be.ok()
                expect(follow:find('pet:GetAttribute("MergeEggPlayerReserveUnit")', 1, true)).to.be.ok()
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
            expect(packet.authorization).to.equal("player")
            expect(packet.environments.production).to.equal(true)
            expect(packet.environments.studio).to.equal(true)
            expect(packet.environments.test).to.equal(true)
            expect(service:find("function MergeEggPrototypeService:AdvanceHatcherEgg", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_spawnInitialTeam", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_expandTeamForEggTier", 1, true)).to.be.ok()
            expect(service:find("self:_positionsForEggTier(1, record)", 1, true)).to.be.ok()
            expect(service:find('folder:SetAttribute("MergeEggExpectedPets", desired)', 1, true)).to.be.ok()
            expect(service:find("local team = record.teamById[teamId]", 1, true)).to.be.ok()
            expect(
                service:find("function MergeEggPrototypeService:_deployedEggTransaction", 1, true)
            ).to.be.ok()
            expect(
                service:find(
                    "local requiredTier = currentTier > 0 and currentTier or baseTier",
                    1,
                    true
                )
            ).to.be.ok()
            expect(
                service:find(
                    "local resultTier = currentTier > 0 and (currentTier + 1) or baseTier",
                    1,
                    true
                )
            ).to.be.ok()
            expect(
                service:find(
                    "record.eggInventory[requiredTier] = self:_eggInventoryCount(record, requiredTier) - 1",
                    1,
                    true
                )
            ).to.be.ok()
            expect(service:find("self:_rollDraftedPrototypePet(", 1, true)).to.be.ok()
            expect(service:find("queued.definition = nil", 1, true)).to.be.ok()
            expect(service:find("self:_publishTeamEggSource(team)", 1, true)).to.be.ok()
            local advanceAt =
                service:find("function MergeEggPrototypeService:AdvanceHatcherEgg", 1, true)
            local resetAt =
                service:find("function MergeEggPrototypeService:_reset", advanceAt, true)
            local advanceBody = service:sub(advanceAt, resetAt - 1)
            expect(advanceBody:find("record.waveIndex == 0", 1, true)).to.be.ok()
            expect(advanceBody:find("and addedUnits > 0", 1, true)).to.be.ok()
            expect(advanceBody:find("and record.tutorialActive ~= true", 1, true)).to.be.ok()
            expect(advanceBody:find("self:_spawnNextWave(record)", 1, true)).to.be.ok()
            expect(service:find("Signals.MergeEggPrototypeUpgrade.OnServerEvent", 1, true)).to.be.ok()
            expect(observer:find('Instance.new("BillboardGui")', 1, true)).to.be.ok()
            expect(observer:find("billboard.Active = false", 1, true)).to.be.ok()
            expect(
                observer:find('billboard.Parent = localPlayer:WaitForChild("PlayerGui")', 1, true)
            ).to.be.ok()
            expect(observer:find('billboard.Name = "MergeEggHatcherHealth_"', 1, true)).to.be.ok()
            expect(observer:find('frame.Name = "EggHealthBar"', 1, true)).to.be.ok()
            expect(observer:find("local function hatcherEggObjective", 1, true)).to.be.ok()
            expect(observer:find('folder:GetAttribute("MergeEggInstalledHealth")', 1, true)).to.be.ok()
            expect(observer:find("control.fill.Size = UDim2.fromScale(fraction, 1)", 1, true)).to.be.ok()
            expect(observer:find("control.label.Text", 1, true)).to.be.ok()
            expect(observer:find('button.Name = "AdvanceEggButton"', 1, true)).to.equal(nil)
            expect(
                observer:find(
                    '.. (waitingForFirstEgg and "INSTALL FIRST EGG" or "READY TO HATCH")',
                    1,
                    true
                )
            ).to.be.ok()
            expect(observer:find('world:GetAttribute("ProgressionStageName")', 1, true)).to.be.ok()
            expect(observer:find('attackGroups == 1 and "FRONT" or "FRONTS"', 1, true)).to.be.ok()
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

        it("keeps edge cannons in the spawnable model library", function()
            local towers = config.team.edge_towers
            local factory = readFile("src/Shared/Game/MergeTowerModels.lua")
            local prebake = readFile("scripts/prebake/add_merge_cannon_assets.luau")
            local modelsProject = readFile("models.project.json")

            expect(towers.model_folder_name).to.equal("MergeCannons")
            expect(towers.model_tier_count).to.equal(4)
            expect(towers.current_art_tier).to.equal(2)
            expect(towers.tier_1_scale).to.equal(0.85)
            expect(#towers.available_roles).to.equal(6)
            expect(factory:find('models:FindFirstChild("MergeCannons")', 1, true)).to.be.ok()
            expect(factory:find("template:Clone()", 1, true)).to.be.ok()
            expect(factory:find('FindFirstChild("TowerAnchor", true)', 1, true)).to.be.ok()
            expect(factory:find("model:GetBoundingBox()", 1, true)).to.be.ok()
            expect(prebake:find("{ tier = 1, scale = manifest.tiering.tier1Scale }", 1, true)).to.be.ok()
            expect(prebake:find("{ tier = 2, scale = 1 }", 1, true)).to.be.ok()
            expect(modelsProject:find('"$path": "assets/place/Models.rbxm"', 1, true)).to.be.ok()
        end)

        it("activates egg-local anti-heal fields on breaches and damage", function()
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local powerService = readFile("src/Server/Services/PowerService.lua")
            local server = readFile("src/Server/init.server.lua")
            local denial = config.objective.heal_denial

            expect(denial.enabled).to.equal(true)
            expect(denial.radius).to.equal(12)
            expect(denial.active_seconds).to.equal(30)
            expect(denial.recharge_seconds).to.equal(30)
            expect(service:find("function MergeEggPrototypeService:_triggerEggHealDenial", 1, true)).to.be.ok()
            expect(service:find("function MergeEggPrototypeService:_applyEggHealDenial", 1, true)).to.be.ok()
            expect(service:find('self:_triggerAllEggHealDenial(record, "breach", now)', 1, true)).to.be.ok()
            expect(service:find('self:_triggerEggHealDenial(record, team, "egg_damage"', 1, true)).to.be.ok()
            expect(service:find("HealingSuppression.extend(", 1, true)).to.be.ok()
            expect(service:find("self._powerService:SpawnGroundRune(", 1, true)).to.be.ok()
            expect(service:find("floor_y = floorY", 1, true)).to.be.ok()
            expect(powerService:find("tonumber(opts.floor_y)", 1, true)).to.be.ok()
            expect(service:find("team.healDenialActiveUntil + rechargeSeconds", 1, true)).to.be.ok()
            expect(server:find('"PowerService",', 1, true)).to.be.ok()
        end)

        it("holds the temporary player escort at the breach-line formation", function()
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local follow = readFile("src/Client/Systems/PetFollowController.lua")

            expect(config.player_reserve.hold_at_breach_line).to.equal(true)
            expect(
                service:find("function MergeEggPrototypeService:_playerEscortAnchorCFrame", 1, true)
            ).to.be.ok()
            expect(service:find("MergeEggEscortAnchorPosition = anchor.Position", 1, true)).to.be.ok()
            expect(follow:find('pet:GetAttribute("MergeEggEscortAnchorPosition")', 1, true)).to.be.ok()
            expect(follow:find("allEscortAnchored", 1, true)).to.be.ok()
            expect(follow:find("playerBeyondBreach", 1, true)).to.be.ok()
            expect(follow:find("fromBreach:Dot(towardEnemy) >= 0", 1, true)).to.be.ok()
            expect(follow:find("cf = CFrame.lookAt(", 1, true)).to.be.ok()
        end)

        it("alerts the player escort when an enemy crosses the Bulwark", function()
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local alert = service:find(
                "function MergeEggPrototypeService:_alertTeamsToBulwarkTarget",
                1,
                true
            )
            local open =
                service:find("function MergeEggPrototypeService:_openBulwarkTarget", alert, true)

            expect(alert ~= nil).to.equal(true)
            expect(open ~= nil and open > alert).to.equal(true)
            expect(service:find("local playerFolder = record.petFolder", alert, true)).to.be.ok()
            expect(service:find("playerFolder,", alert, true)).to.be.ok()
            expect(service:find("enemy.targetId,", alert, true)).to.be.ok()
            expect(service:find("MergeEggPlayerAlertedPets", open, true)).to.be.ok()
        end)

        it("provides repeatable reset and exit cleanup", function()
            local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local clear = service:find("function MergeEggPrototypeService:_clearEncounter", 1, true)
            local reset = service:find("function MergeEggPrototypeService:_reset(player)", 1, true)
            local exit = service:find("function MergeEggPrototypeService:_exit(player)", 1, true)
            expect(clear ~= nil).to.equal(true)
            expect(reset ~= nil and reset > clear).to.equal(true)
            expect(exit ~= nil and exit > reset).to.equal(true)
            expect(service:find("self._npcPrincipalService:Despawn", clear, true)).to.be.ok()
            expect(service:find("self:_restoreOwnedPets(record)", clear, true)).to.be.ok()
            expect(service:find("disconnect(record.areaChanged)", clear, true)).to.be.ok()
        end)

        it("fits owned floor displays inside the fixed nine-position station contract", function()
            local observer = readFile("src/Client/Systems/MergeEggPrototypeObserver.lua")
            local client = readFile("src/Client/init.client.lua")

            expect(observer:find("MergeEggPrototypeTeam", 1, true)).to.be.ok()
            expect(observer:find("for order, teamCfg in ipairs(activeTeamConfigs())", 1, true)).to.be.ok()
            expect(observer:find("OwnedHatcherSlots", 1, true)).to.be.ok()
            expect(observer:find("local function createGroundTeamPanels", 1, true)).to.be.ok()
            expect(observer:find("local function stationXOffset", 1, true)).to.be.ok()
            expect(observer:find("stationXOffset(teamCfg, order)", 1, true)).to.be.ok()
            expect(observer:find("local function groundPanelDimensions", 1, true)).to.be.ok()
            expect(observer:find("spacing - gap", 1, true)).to.be.ok()
            expect(observer:find("panelCfg.minimum_depth", 1, true)).to.be.ok()
            expect(observer:find("Enum.SurfaceGuiSizingMode.FixedSize", 1, true)).to.be.ok()
            expect(observer:find("surface.CanvasSize", 1, true)).to.be.ok()
            expect(observer:find("raycastParams.RespectCanCollide = true", 1, true)).to.be.ok()
            expect(observer:find("local floorHit = Workspace:Raycast", 1, true)).to.be.ok()
            expect(observer:find("surface.ZOffset = 0", 1, true)).to.be.ok()
            expect(observer:find("math.rad(-90)", 1, true)).to.be.ok()
            expect(observer:find('Instance.new("SurfaceGui")', 1, true)).to.be.ok()
            expect(observer:find("Enum.NormalId.Top", 1, true)).to.be.ok()
            expect(observer:find('displayFolder.Name = "MergeEggClientTeamDisplays"', 1, true)).to.be.ok()
            expect(observer:find("candidate:FindFirstChild(hatcherName, true)", 1, true)).to.be.ok()
            expect(observer:find("MergeEggAssignedEnemies", 1, true)).to.be.ok()
            expect(observer:find("MergeEggPeakAssignedEnemies", 1, true)).to.be.ok()
            expect(observer:find("MergeEggFirstLossWave", 1, true)).to.be.ok()
            expect(observer:find("COMBAT_CADENCE_MULTIPLIER", 1, true)).to.be.ok()
            expect(observer:find('frame.Name = "WaveMeter"', 1, true)).to.be.ok()
            expect(observer:find('waveGui.Name = "MergeWaveBar"', 1, true)).to.be.ok()
            expect(observer:find("UDim2.new(1, -4, 0, 14)", 1, true)).to.be.ok()
            expect(observer:find("UDim2.new(0.5, -215, 0, 88)", 1, true)).to.equal(nil)
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
