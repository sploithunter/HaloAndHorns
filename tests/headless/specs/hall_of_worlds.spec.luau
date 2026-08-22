local ArchLightning = loadModule("src/Shared/Game/ArchLightning.lua")
local HallOfWorldsLogic = loadModule("src/Shared/Game/HallOfWorldsLogic.lua")
local HallEggStand = loadModule("src/Shared/Game/HallEggStand.lua")
local BreakableDensity = loadModule("src/Shared/Game/BreakableDensity.lua")
local breakables = loadModule("configs/breakables.lua")
local drops = loadModule("configs/drops.lua")
local hall = loadModule("configs/hall_of_worlds.lua")
local pets = loadModule("configs/pets.lua")
local roles = loadModule("configs/pet_roles.lua")
local currencies = loadModule("configs/currencies.lua")

return function()
    describe("HallOfWorldsLogic", function()
        it("keeps Waycoins on dormant Hall tiles but not Homeworld challenge runs", function()
            local modes = loadModule("configs/challenge_runs.lua").modes
            expect(hall.entry_enabled).to.equal(false)
            expect(HallOfWorldsLogic.isHallAreaId("Hall_2")).to.equal(true)
            expect(HallOfWorldsLogic.isHallAreaId("hall_3")).to.equal(true)
            expect(HallOfWorldsLogic.isHallAreaId("mission_earth")).to.equal(false)
            expect(HallOfWorldsLogic.usesHallCurrencyHud("Hall_2", nil, modes)).to.equal(true)
            expect(HallOfWorldsLogic.usesHallCurrencyHud("mission_earth", "range", modes)).to.equal(
                false
            )
            expect(HallOfWorldsLogic.usesHallCurrencyHud("mission_earth", "training_ground", modes)).to.equal(
                false
            )
            expect(HallOfWorldsLogic.usesHallCurrencyHud("mission_earth", nil, modes)).to.equal(
                false
            )
            expect(HallOfWorldsLogic.usesHallCurrencyHud("Lava", nil, modes)).to.equal(false)
        end)

        it("forces Hall resumes to Home without touching owned player data", function()
            local pets = { items = { pet_1 = { id = "doggy" } } }
            local gameData = {
                LastArea = "Hall_3",
                UnlockedAreas = { "Hall_1", "Hall_3", "Spawn", "Heaven_1" },
                HallOfWorlds = { highest_stage = 3 },
                InventorySentinel = pets,
            }
            local normalized, changed = HallOfWorldsLogic.forceHomeResume(gameData, {
                Hall_1 = true,
                Hall_2 = true,
                Hall_3 = true,
                Hall_4 = true,
            }, "Spawn")

            expect(changed).to.equal(true)
            expect(normalized).to.equal(gameData)
            expect(normalized.LastArea).to.equal("Spawn")
            expect(normalized.UnlockedAreas[1]).to.equal("Heaven_1")
            expect(normalized.UnlockedAreas[2]).to.equal("Spawn")
            expect(#normalized.UnlockedAreas).to.equal(2)
            expect(normalized.HallOfWorlds.highest_stage).to.equal(3)
            expect(normalized.InventorySentinel).to.equal(pets)

            local _, changedAgain = HallOfWorldsLogic.forceHomeResume(normalized, {
                Hall_1 = true,
                Hall_2 = true,
                Hall_3 = true,
                Hall_4 = true,
            }, "Spawn")
            expect(changedAgain).to.equal(false)
        end)

        it("labels the disabled Hall entry as coming soon", function()
            local source = readFile("src/Server/Services/ZoneService.lua")
            expect(source:find("HALL OF WORLDS\\nCOMING SOON", 1, true)).to.be.ok()
        end)

        it("keeps the disabled entry barrier inside its round-topped arch", function()
            local source = readFile("src/Server/Services/ZoneService.lua")
            local barrier = hall.entry_barrier
            expect(barrier.width_fraction < 0.7).to.equal(true)
            expect(barrier.curve_segments >= 11).to.equal(true)
            expect(source:find("HallEntryArchCap", 1, true)).to.be.ok()
            expect(source:find("math.sqrt", 1, true)).to.be.ok()
        end)

        it("returns a locked Hall entry to the previous unlocked tile", function()
            local route = { "Hall_1", "Hall_2", "Hall_3", "Hall_4" }
            expect(
                HallOfWorldsLogic.lockedEntryReturn(
                    { "Hall_1", "Hall_2", "Hall_3" },
                    route,
                    "Hall_4"
                )
            ).to.equal("Hall_3")
            expect(HallOfWorldsLogic.lockedEntryReturn({ "Hall_1" }, route, "Hall_3")).to.equal(
                "Hall_1"
            )
        end)

        it("keeps the Plaza wall on the Hall_3 side of the Hall_4 volume", function()
            local areas = loadModule("configs/areas.lua")
            local hall3 = areas.zones.Hall_3.synthetic
            local hall4 = areas.zones.Hall_4.synthetic
            local wallZ = 558
            expect(hall3.center.z + hall3.size.z / 2 > wallZ - 4).to.equal(true)
            expect(hall4.center.z - hall4.size.z / 2 > wallZ).to.equal(true)
        end)

        it("starts fresh players at their furthest Hall checkpoint", function()
            local route = { "Hall_1", "Hall_2", "Hall_3", "Hall_4" }
            expect(HallOfWorldsLogic.initialArea(false, { "Hall_1" }, route, "Hall_1", "Spawn")).to.equal(
                "Hall_1"
            )
            expect(
                HallOfWorldsLogic.initialArea(
                    false,
                    { "Hall_1", "Hall_2", "Hall_3" },
                    route,
                    "Hall_1",
                    "Spawn"
                )
            ).to.equal("Hall_3")
        end)

        it("preserves Crystal World entry once the final Hall gate is used", function()
            expect(
                HallOfWorldsLogic.initialArea(
                    true,
                    { "Hall_1", "Hall_2", "Hall_3", "Hall_4", "Spawn" },
                    { "Hall_1", "Hall_2", "Hall_3", "Hall_4" },
                    "Hall_1",
                    "Spawn"
                )
            ).to.equal("Spawn")
        end)

        it(
            "resumes the last Hall tile and collapses Crystal/Heaven/Hell/trials to Spawn",
            function()
                local route = { "Hall_1", "Hall_2", "Hall_3", "Hall_4" }
                local hallAreas = { Hall_1 = true, Hall_2 = true, Hall_3 = true, Hall_4 = true }
                local unlocked = { "Hall_1", "Hall_2", "Hall_3", "Hall_4", "Spawn", "Heaven_1" }

                expect(HallOfWorldsLogic.normalizeResumeArea("Hall_3", hallAreas, "Spawn")).to.equal(
                    "Hall_3"
                )
                expect(HallOfWorldsLogic.normalizeResumeArea("Heaven_2", hallAreas, "Spawn")).to.equal(
                    "Spawn"
                )
                expect(HallOfWorldsLogic.normalizeResumeArea("mission_hell", hallAreas, "Spawn")).to.equal(
                    "Spawn"
                )

                expect(
                    HallOfWorldsLogic.initialArea(
                        true,
                        unlocked,
                        route,
                        "Hall_1",
                        "Spawn",
                        "Hall_3",
                        hallAreas
                    )
                ).to.equal("Hall_3")
                expect(
                    HallOfWorldsLogic.initialArea(
                        true,
                        unlocked,
                        route,
                        "Hall_1",
                        "Spawn",
                        "Heaven_1",
                        hallAreas
                    )
                ).to.equal("Spawn")
                expect(
                    HallOfWorldsLogic.initialArea(
                        true,
                        unlocked,
                        route,
                        "Hall_1",
                        "Spawn",
                        "mission_grass",
                        hallAreas
                    )
                ).to.equal("Spawn")
                -- A new Hall player must not inherit Crystal World Spawn from a stale LastArea.
                expect(
                    HallOfWorldsLogic.initialArea(
                        false,
                        { "Hall_1", "Spawn" },
                        route,
                        "Hall_1",
                        "Spawn",
                        "Spawn",
                        hallAreas
                    )
                ).to.equal("Hall_1")
            end
        )

        it("requires both tutorial completion and the configured level", function()
            local unlock = { tutorial_required = true, required_level = 2 }
            local ok, reason = HallOfWorldsLogic.meetsUnlock(2, false, unlock)
            expect(ok).to.equal(false)
            expect(reason).to.equal("tutorial_required")

            ok, reason = HallOfWorldsLogic.meetsUnlock(1, true, unlock)
            expect(ok).to.equal(false)
            expect(reason).to.equal("level_required")

            expect(HallOfWorldsLogic.meetsUnlock(2, true, unlock)).to.equal(true)
        end)

        it("accepts current tutorial completion while retaining the legacy saved flag", function()
            expect(HallOfWorldsLogic.isTutorialCompleted({}, { done = true })).to.equal(true)
            expect(
                HallOfWorldsLogic.isTutorialCompleted(
                    { TutorialCompleted = true },
                    { done = false }
                )
            ).to.equal(true)
            expect(HallOfWorldsLogic.isTutorialCompleted({}, { done = false })).to.equal(false)
        end)

        it("gates Hall tutorial completion only for track 2 new profiles", function()
            local unlock = { tutorial_required = true, required_level = 2 }
            expect(HallOfWorldsLogic.hasHallTutorialTrack({ track = 2 })).to.equal(true)
            expect(HallOfWorldsLogic.hasHallTutorialTrack({ version = 3 })).to.equal(false)
            expect(HallOfWorldsLogic.hasHallTutorialTrack(nil)).to.equal(false)

            -- Legacy: no track, so the Hall tutorial wall does not apply.
            expect(HallOfWorldsLogic.tutorialRequirementMet({}, { done = false }, unlock)).to.equal(
                true
            )
            expect(HallOfWorldsLogic.meetsUnlock(2, false, unlock, { done = false })).to.equal(true)

            -- Post-update new player: track 2, must finish the tutorial.
            expect(
                HallOfWorldsLogic.tutorialRequirementMet({}, { track = 2, done = false }, unlock)
            ).to.equal(false)
            local ok, reason =
                HallOfWorldsLogic.meetsUnlock(2, false, unlock, { track = 2, done = false })
            expect(ok).to.equal(false)
            expect(reason).to.equal("tutorial_required")
            expect(HallOfWorldsLogic.meetsUnlock(2, false, unlock, { track = 2, done = true })).to.equal(
                true
            )

            -- Incomplete track 2 must not persist Crystal World Spawn.
            local route = { "Hall_1", "Hall_2", "Hall_3", "Hall_4" }
            local hallAreas = { Hall_1 = true, Hall_2 = true, Hall_3 = true, Hall_4 = true }
            expect(
                HallOfWorldsLogic.initialArea(
                    false,
                    { "Hall_1", "Spawn" },
                    route,
                    "Hall_1",
                    "Spawn",
                    "Spawn",
                    hallAreas,
                    { track = 2, done = false },
                    {}
                )
            ).to.equal("Hall_1")
        end)

        it("keeps fresh players in Hall except through the authored exit", function()
            local hallAreas = { Hall_1 = true, Hall_2 = true, Hall_3 = true, Hall_4 = true }
            expect(HallOfWorldsLogic.canLeaveHall(false, "Hall_2", hallAreas, false)).to.equal(true)
            expect(HallOfWorldsLogic.canLeaveHall(false, "Spawn", hallAreas, false)).to.equal(false)
            expect(HallOfWorldsLogic.canLeaveHall(false, "Spawn", hallAreas, true)).to.equal(true)
            expect(HallOfWorldsLogic.canLeaveHall(true, "Spawn", hallAreas, false)).to.equal(true)
        end)

        it("opens the Hall 1 Archpad return only after Crystal World membership", function()
            local hallAreas = { Hall_1 = true, Hall_2 = true, Hall_3 = true, Hall_4 = true }
            -- Archpad is not HallExitToCrystalWorld, so a new player cannot skip Hall.
            expect(HallOfWorldsLogic.canLeaveHall(false, "Spawn", hallAreas, false)).to.equal(false)
            -- Legacy / Plaza-finished players already have entered_crystal_world.
            expect(HallOfWorldsLogic.canLeaveHall(true, "Spawn", hallAreas, false)).to.equal(true)
            -- Plaza first exit still lets a new player leave and become a member.
            expect(HallOfWorldsLogic.canLeaveHall(false, "Spawn", hallAreas, true)).to.equal(true)
            expect(hall.crystal_world_return.pad_name).to.equal("Archpad")
            expect(hall.crystal_world_return.source_area).to.equal("Hall_1")
            expect(hall.crystal_world_return.target_area).to.equal("Spawn")
        end)

        it("uses mineable Waycoin targets while reserving loose coins for pickups", function()
            local loosePickupNames = {
                WaycoinPile = true,
                WaycoinCache = true,
            }

            for _, areaId in ipairs({ "Hall_1", "Hall_2", "Hall_3", "Hall_4" }) do
                local world = breakables.worlds[areaId]
                expect(world).to.be.ok()

                for _, entry in ipairs(world.spawn_table) do
                    expect(loosePickupNames[entry.name]).never.to.equal(true)
                    local definition = breakables.crystals[entry.name]
                    expect(definition).to.be.ok()
                    expect(definition.currency).to.equal("hall_coins")
                    expect(definition.spawn.method).to.equal("drop")
                    expect(definition.spawn.height > 0).to.equal(true)
                    expect(definition.spawn.duration > 0).to.equal(true)
                end

                expect(world.spawn_settings.respawn_max_seconds <= 6).to.equal(true)
            end

            expect(breakables.crystals.WaycoinBag).to.be.ok()
            expect(breakables.crystals.GoldFernNugget).to.be.ok()
            expect(breakables.crystals.WaycoinTrove).to.be.ok()
            expect(breakables.crystals.GildedWaycache).to.be.ok()

            local pickup = drops.currency_pickups.hall_coins
            expect(pickup).to.be.ok()
            expect(pickup.mesh).to.be.ok()
            expect(pickup.texture).to.be.ok()
            -- The pickup mesh imports horizontal already. Corrections belong to template prep,
            -- never the runtime pop/spin/magnet path; a 90-degree correction made every clone roll.
            expect(pickup.orientation.x).to.equal(0)
            expect(pickup.spin).never.to.equal(false)
        end)

        it("sizes Hall populations from shared field-area density", function()
            for _, areaId in ipairs({ "Hall_1", "Hall_2", "Hall_3", "Hall_4" }) do
                expect(breakables.worlds[areaId].spawn_settings.targets_per_1000_studs).to.equal(
                    2.6
                )
            end
            -- 304×304 cap field. 2.6/1000 restores the old 100-in-195×195 look.
            expect(BreakableDensity.count(92416, 2.6, { min = 80, max = 250 })).to.equal(240)
            expect(BreakableDensity.count(38228, 2.6)).to.equal(99)
            expect(BreakableDensity.count(41556, 2.6, { min = 40, max = 160 })).to.equal(108)
        end)

        it("uses every baked green-field marker instead of a synthetic Hall circle", function()
            local expected = {
                Hall_1 = { area = "Hall_1", tile = "Tile01_cap" },
                Hall_1_B = { area = "Hall_1", tile = "Tile02_corridor" },
                Hall_2_A = { area = "Hall_2", tile = "Tile03_playfield" },
                Hall_2_B = { area = "Hall_2", tile = "Tile04_corner" },
                Hall_3_C = { area = "Hall_3", tile = "Tile05_corridor" },
                Hall_3_A = { area = "Hall_3", tile = "Tile06_playfield" },
                Hall_3_B = { area = "Hall_3", tile = "Tile07_corner" },
                Hall_4_B = { area = "Hall_4", tile = "Tile08_corridor" },
                Hall_4 = { area = "Hall_4", tile = "Tile09_cap" },
            }
            local count = 0
            for key, contract in pairs(expected) do
                local playArea = hall.play_areas[key]
                count += 1
                expect(playArea).to.be.ok()
                expect(playArea.area_id).to.equal(contract.area)
                expect(playArea.tile_name).to.equal(contract.tile)
                expect(playArea.marker_name).to.equal("SpawnZone")
                expect(playArea.center).never.to.be.ok()
                expect(playArea.size).never.to.be.ok()
            end
            expect(count).to.equal(9)

            expect(breakables.worlds.Hall_1.spawn_area.size.x).to.equal(195.52)
            expect(breakables.worlds.Hall_4.spawn_area.position.z).to.equal(982)
        end)

        it("fires dragon bolts across Training Ground lightning markers", function()
            local fx = hall.arch_lightning
            expect(fx).to.be.ok()
            expect(fx.enabled).to.equal(true)
            expect(fx.part_prefix).to.equal("lightning")
            expect(fx.adopt_workspace_parts).to.equal(true)
            expect(fx.host_names[1]).to.equal("TrainingGroundPadGateVisual")
            expect(fx.host_names[2]).to.equal("RangePadGateVisual")
            expect(fx.host_names[5]).to.equal("HallOfWorldsGateVisual")
            expect(fx.host_names[6]).to.equal("HellFaceGateTest")
            local sampled = ArchLightning.sampleArchPoints(26, 36, 9)
            expect(#sampled >= 18).to.equal(true)
            local mid = 0
            for _, point in ipairs(sampled) do
                if math.abs(point.z) < 1 then
                    mid += 1
                end
            end
            expect(mid).to.equal(0)
            local cols = {
                { x = 0, y = 4, z = 0 },
                { x = 0, y = 8, z = 0 },
                { x = 0, y = 4, z = 16 },
                { x = 0, y = 8, z = 16 },
            }
            local i2, j2 = ArchLightning.pickPair(cols, true, 0.1, 8)
            expect(i2).to.be.ok()
            expect(j2).to.be.ok()
            expect(math.abs(cols[i2].z - cols[j2].z) >= 8).to.equal(true)

            local acrossX = {
                { x = 0, y = 4, z = 10 },
                { x = 0, y = 8, z = 10 },
                { x = 16, y = 4, z = 10 },
                { x = 16, y = 8, z = 10 },
            }
            local ix, jx = ArchLightning.pickPair(acrossX, true, 0.1, 8)
            expect(math.abs(acrossX[ix].x - acrossX[jx].x) >= 8).to.equal(true)
            expect(ArchLightning.openingWidth({ X = 25.9, Y = 36, Z = 6.8 })).to.equal(25.9)
            expect(fx.bolt.colors[1][3]).to.equal(255)
            expect(ArchLightning.isMarkerName("lightning19", "lightning")).to.equal(true)
            expect(ArchLightning.isMarkerName("HellFace", "lightning")).to.equal(false)

            local left = { x = 0, y = 10, z = 0 }
            local right = { x = 0, y = 10, z = 16 }
            local i, j = ArchLightning.pickPair({ left, right }, true, 0.1)
            expect(i).to.be.ok()
            expect(j).to.be.ok()
            expect(i == j).to.equal(false)

            local clusters = ArchLightning.clusterLoose({
                { id = 1, x = 0, y = 0, z = 0 },
                { id = 2, x = 2, y = 0, z = 2 },
                { id = 3, x = 200, y = 0, z = 200 },
                { id = 4, x = 202, y = 0, z = 201 },
            }, 48)
            expect(#clusters).to.equal(2)
            expect(#clusters[1]).to.equal(2)
            expect(#clusters[2]).to.equal(2)
        end)

        it("authors frosted ice progression walls", function()
            local look = hall.gate_appearance
            expect(look).to.be.ok()
            expect(look.material).to.equal("Ice")
            expect(look.transparency > 0.15).to.equal(true)
            expect(look.transparency < 0.45).to.equal(true)
            expect(hall.gate_prompt.surface).to.equal(true)
        end)

        it("closes the last Plaza endcap with a Coming Soon wall", function()
            local coming = hall.coming_soon
            expect(coming).to.be.ok()
            expect(coming.text).to.equal("Coming Soon")
            local wall = coming.walls[1]
            expect(wall.name).to.equal("Hall4EndcapComingSoon")
            expect(wall.position[3] > 680).to.equal(true)
            expect(wall.position[3] < 720).to.equal(true)
            expect(wall.size[1] >= 220).to.equal(true)
            for _, gate in ipairs(hall.progression_gates) do
                expect(gate.name ~= wall.name).to.equal(true)
            end
        end)

        it("spans every Hall wall to the side barriers", function()
            local byName = {}
            for _, gate in ipairs(hall.progression_gates) do
                byName[gate.name] = gate
            end
            expect(byName.Level2Barrier.size[1]).to.equal(220)
            expect(byName.WaycoinBarrier750.size[3]).to.equal(240)
            expect(byName.WaycoinBarrier2500.size[1]).to.equal(220)
        end)

        it("seats the Plaza wall in the pillar line", function()
            local plaza
            for _, gate in ipairs(hall.progression_gates) do
                if gate.name == "WaycoinBarrier2500" then
                    plaza = gate
                end
            end
            expect(plaza).to.be.ok()
            expect(plaza.position[3] > 550).to.equal(true)
        end)

        it("labels Hall walls from live route costs, not baked SurfaceGuis", function()
            expect(HallOfWorldsLogic.formatUnlockAmount(6000)).to.equal("6,000")
            expect(HallOfWorldsLogic.gateButtonText(hall.route[2].unlock)).to.equal(
                "3,000 Waycoins"
            )
            expect(HallOfWorldsLogic.gateButtonText(hall.route[3].unlock)).to.equal(
                "6,000 Waycoins"
            )
            expect(HallOfWorldsLogic.gateButtonText(hall.route[4].unlock)).to.equal(
                "10,000 Waycoins"
            )
            expect(hall.gate_prompt.pill_key).to.equal("citrine")
        end)

        it("starts a new player with enough Waycoins for the first Hall egg", function()
            local wayfinder = pets.egg_sources.wayfinder_egg
            local hallCoins
            for _, currency in ipairs(currencies) do
                if currency.id == "hall_coins" then
                    hallCoins = currency
                end
            end
            expect(wayfinder).to.be.ok()
            expect(hallCoins).to.be.ok()
            expect(wayfinder.currency).to.equal("hall_coins")
            expect(hallCoins.defaultAmount >= wayfinder.cost).to.equal(true)
        end)

        it("binds Gilded Gallery to a complete live five-pet hatcher", function()
            local routeEgg = hall.route[2].egg
            local source = pets.egg_sources[routeEgg.egg_id]
            expect(routeEgg.egg_id).to.equal("hall_gilded_egg")
            expect(source).to.be.ok()
            expect(source.world_placeable).to.equal(true)
            expect(source.currency).to.equal("hall_coins")
            expect(source.cost).to.equal(routeEgg.cost)

            local count = 0
            for petType in pairs(source.pet_weights) do
                count += 1
                local pet = pets.pets[petType]
                expect(pet).to.be.ok()
                expect(pet.category).to.equal("hall")
                expect(pet.realm).to.equal("hall")
                expect(pet.origin).to.equal("hall")
                expect(roles.by_type[petType]).to.be.ok()
            end
            expect(count).to.equal(5)
            expect(roles.support_auras.fortune_wisp.kind).to.equal("heal")
            expect(roles.support_auras.lockbox_imp.kind).to.equal("root")
        end)

        it("binds Vanguard Walk to a complete live five-pet hatcher", function()
            local routeEgg = hall.route[3].egg
            local source = pets.egg_sources[routeEgg.egg_id]
            expect(routeEgg.egg_id).to.equal("vanguard_egg")
            expect(source).to.be.ok()
            expect(source.world_placeable).to.equal(true)
            expect(source.currency).to.equal("hall_coins")
            expect(source.cost).to.equal(routeEgg.cost)

            local count = 0
            for petType in pairs(source.pet_weights) do
                count += 1
                local pet = pets.pets[petType]
                expect(pet).to.be.ok()
                expect(pet.category).to.equal("hall")
                expect(pet.realm).to.equal("hall")
                expect(pet.origin).to.equal("hall")
                expect(roles.by_type[petType]).to.be.ok()
            end
            expect(count).to.equal(5)
            expect(roles.support_auras.banner_hare.kind).to.equal("offense")
            expect(roles.support_auras.chain_serpent.kind).to.equal("root")
        end)

        it("binds Worlds Plaza to a complete live five-pet hatcher", function()
            local routeEgg = hall.route[4].egg
            local source = pets.egg_sources[routeEgg.egg_id]
            expect(routeEgg.egg_id).to.equal("worldheart_egg")
            expect(source).to.be.ok()
            expect(source.stand_yaw_degrees).to.equal(180)
            expect(source.world_placeable).to.equal(true)
            expect(source.currency).to.equal("hall_coins")
            expect(source.cost).to.equal(routeEgg.cost)

            local count = 0
            for petType in pairs(source.pet_weights) do
                count += 1
                local pet = pets.pets[petType]
                expect(pet).to.be.ok()
                expect(pet.category).to.equal("hall")
                expect(pet.realm).to.equal("hall")
                expect(pet.origin).to.equal("hall")
                expect(roles.by_type[petType]).to.be.ok()
            end
            expect(count).to.equal(5)
            expect(roles.support_auras.star_moth.kind).to.equal("heal")
            expect(roles.support_auras.clockwork_spider.kind).to.equal("root")
        end)

        it("treats standing at a Hall pedestal as in-range even when UIanchor is high", function()
            expect(HallEggStand.distanceToAabb(0, 3, 0, 0, 4, 0, 6, 8, 6)).to.equal(0)
            expect(HallEggStand.distanceToAabb(10, 3, 0, 0, 4, 0, 6, 8, 6)).to.be.near(7, 0.001)
            -- Player at the stand, UIanchor 34 studs above: 3D is 31, ground-plane and AABB are 0.
            expect(HallEggStand.hatcherDistance(2348, 3, 380, 2348, 34, 380, {
                x = 2348,
                y = 6,
                z = 380,
                sx = 8,
                sy = 12,
                sz = 8,
            })).to.equal(0)
        end)

        it("scales Hall stand eggs to fill the authored pedestal cup", function()
            expect(hall.egg_stand.egg_scale).to.equal(8)
            expect(hall.egg_stand.egg_target_max_dimension).to.equal(8)
            expect(hall.egg_stand.prompt_height).to.equal(4.8)
            local x, y, z = HallEggStand.cupPosition(1818.9, -317.9, 6.0, 1.25)
            expect(x).to.equal(1818.9)
            expect(z).to.equal(-317.9)
            expect(y).to.equal(7.25)
            local mx, mz = HallEggStand.visualXZ(2099.2, 212.4, 1872, 208)
            expect(mx).to.equal(2099.2)
            expect(mz).to.equal(212.4)
            local fx, fz = HallEggStand.visualXZ(nil, nil, 1872, 208)
            expect(fx).to.equal(1872)
            expect(fz).to.equal(208)
        end)

        it("uses random field-outline slots on every Hall play area", function()
            for _, areaId in ipairs({ "Hall_1", "Hall_2", "Hall_3", "Hall_4" }) do
                expect(breakables.worlds[areaId].spawn_settings.slot_layout).to.equal("random")
            end
        end)

        it("scales Hall pets to the established ~3-stud world silhouette", function()
            local count = 0
            for _, pet in pairs(pets.pets) do
                if pet.category == "hall" then
                    count += 1
                    expect(pet.asset_transform).to.be.ok()
                    expect(pet.asset_transform.scale).to.equal(3.2)
                end
            end
            expect(count).to.equal(20)
        end)

        it("seats Hall stands on the authored nook floor, not a marker top", function()
            -- Tile01/09 NookPad top is -2.10; a 6.91-tall stand whose AABB center is 4.96
            -- was sitting on the invisible HallEggBay top at 1.50 and floating.
            expect(HallEggStand.floorYFromNook(-2.10, -2.10)).to.equal(-2.10)
            expect(HallEggStand.floorYFromNook(nil, -2.10)).to.equal(-2.10)
            expect(HallEggStand.deltaYToSit(4.96, 6.91, -2.10)).to.be.near(-3.605, 0.001)
            expect(HallEggStand.deltaYToSit(1.50 + 6.91 * 0.5, 6.91, -2.10)).to.be.near(
                -3.60,
                0.001
            )
        end)
    end)
end
