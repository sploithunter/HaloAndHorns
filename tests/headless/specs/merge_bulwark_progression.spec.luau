local Progression = loadModule("src/Shared/Game/MergeBulwarkProgression.lua")
local mergeConfig = loadModule("configs/merge_egg_prototype.lua")

return function()
    describe("Merge bulwark progression", function()
        local config = {
            unlock_wave = 20,
            playtest_unlock_enabled = true,
            playtest_unlock_wave = 1,
            maximum_tier = 4,
            currency = "hall_coins",
            action_cost = 1,
        }
        local combatConfig = mergeConfig.team.edge_bulwarks

        it(
            "uses the Wave-1 playtest unlock while retaining the Wave-20 production cadence",
            function()
                expect(Progression.unlockWave(config)).to.equal(1)
                expect(Progression.isUnlocked(0, config)).to.equal(true)
                config.playtest_unlock_enabled = false
                expect(Progression.unlockWave(config)).to.equal(20)
                expect(Progression.isUnlocked(19, config)).to.equal(false)
                expect(Progression.isUnlocked(20, config)).to.equal(true)
                config.playtest_unlock_enabled = true
            end
        )

        it("unlocks a family once, then places and upgrades each slot on its own", function()
            local unlocked = Progression.apply(nil, "unlock", "impaler_palisade", 0, config, "lane")
            expect(unlocked.owned.impaler_palisade).to.equal(1)
            expect(unlocked.family).to.equal(nil)
            expect(unlocked.operation).to.equal("unlocked")
            expect(unlocked.charged).to.equal(true)

            local placed, placeReason =
                Progression.apply(nil, "select", "impaler_palisade", 0, config, "lane")
            expect(placed).to.equal(nil)
            expect(placeReason).to.equal("bulwark_not_owned")

            local installed =
                Progression.apply(unlocked, "select", "impaler_palisade", 0, config, "lane")
            expect(installed.family).to.equal("impaler_palisade")
            expect(installed.tier).to.equal(1)
            expect(installed.owned.impaler_palisade).to.equal(1)
            expect(installed.operation).to.equal("installed")
            expect(installed.charged).to.equal(true)

            local upgraded =
                Progression.apply(installed, "upgrade", "impaler_palisade", 1, config, "lane")
            expect(upgraded.family).to.equal("impaler_palisade")
            expect(upgraded.tier).to.equal(2)
            expect(upgraded.owned.impaler_palisade).to.equal(1)
            expect(upgraded.eggFamily).to.equal(nil)

            local sharkUnlock =
                Progression.apply(upgraded, "unlock", "land_shark", 1, config, "lane")
            local switched =
                Progression.apply(sharkUnlock, "select", "land_shark", 1, config, "lane")
            expect(switched.family).to.equal("land_shark")
            expect(switched.tier).to.equal(1)
            expect(switched.owned.impaler_palisade).to.equal(1)
            expect(switched.owned.land_shark).to.equal(1)
            expect(switched.operation).to.equal("replaced")
            expect(switched.charged).to.equal(true)

            local egg = Progression.apply(switched, "select", "impaler_palisade", 1, config, "egg")
            expect(egg.family).to.equal("land_shark")
            expect(egg.tier).to.equal(1)
            expect(egg.eggFamily).to.equal("impaler_palisade")
            expect(egg.eggTier).to.equal(1)
            expect(egg.operation).to.equal("installed")
            expect(egg.charged).to.equal(true)

            local laneUp = Progression.apply(egg, "upgrade", "land_shark", 1, config, "lane")
            expect(laneUp.tier).to.equal(2)
            expect(laneUp.eggFamily).to.equal("impaler_palisade")
            expect(laneUp.eggTier).to.equal(1)

            local menuLane = Progression.menuOwned(laneUp, "lane")
            expect(menuLane.land_shark).to.equal(2)
            expect(menuLane.impaler_palisade).to.equal(1)
            local menuEgg = Progression.menuOwned(laneUp, "egg")
            expect(menuEgg.impaler_palisade).to.equal(1)
            expect(menuEgg.land_shark).to.equal(1)

            local cleared = Progression.clearInstalls(laneUp, 4)
            expect(cleared.owned.land_shark).to.equal(1)
            expect(cleared.owned.impaler_palisade).to.equal(1)
            expect(cleared.family).to.equal(nil)
            expect(cleared.eggFamily).to.equal(nil)
            expect(cleared.tier).to.equal(0)
        end)

        it("upgrades only the chassis sitting on that slot", function()
            local state = {
                family = "saw_blade",
                tier = 2,
                owned = { saw_blade = 1, concertina_line = 1 },
            }
            local refused, reason =
                Progression.apply(state, "upgrade", "concertina_line", 1, config, "lane")
            expect(refused).to.equal(nil)
            expect(reason).to.equal("bulwark_not_installed")

            local upgraded = Progression.apply(state, "upgrade", "saw_blade", 1, config, "lane")
            expect(upgraded.family).to.equal("saw_blade")
            expect(upgraded.tier).to.equal(3)
            expect(upgraded.owned.saw_blade).to.equal(1)
            expect(upgraded.owned.concertina_line).to.equal(1)

            local maxed, maxReason = Progression.apply({
                family = "saw_blade",
                tier = 4,
                owned = { saw_blade = 1 },
            }, "upgrade", "saw_blade", 1, config, "lane")
            expect(maxed).to.equal(nil)
            expect(maxReason).to.equal("bulwark_maxed")

            local missing, missingReason =
                Progression.apply(state, "upgrade", "wardstone_barrier", 1, config, "lane")
            expect(missing).to.equal(nil)
            expect(missingReason).to.equal("bulwark_not_installed")
        end)

        it("charges one configured Waycoin for every mutation", function()
            local price = Progression.actionCost(config)
            expect(price.currency).to.equal("hall_coins")
            expect(price.amount).to.equal(1)
            local unlock =
                Progression.actionCost(mergeConfig.team.edge_bulwarks, "unlock", "impaler_palisade")
            expect(unlock.currency).to.equal("gems")
            expect(unlock.amount).to.equal(1)
            local other =
                Progression.actionCost(mergeConfig.team.edge_bulwarks, "unlock", "concertina_line")
            expect(other.currency).to.equal("hall_coins")
            local families = Progression.families(mergeConfig.tier_art)
            local modelManifest = readFile("scripts/merge_bulwark_model_ids.json")
            local previewManifest = readFile("scripts/merge_bulwark_preview_ids.json")
            local seenPreviewIds = {}
            expect(#families).to.equal(6)
            for _, family in ipairs(families) do
                expect(#family.previewAssetIds).to.equal(4)
                expect(tonumber(family.previewAssetIds[1]) ~= nil).to.equal(true)
                for _, previewAssetId in ipairs(family.previewAssetIds) do
                    expect(seenPreviewIds[previewAssetId]).to.equal(nil)
                    seenPreviewIds[previewAssetId] = true
                    expect(
                        previewManifest:find(
                            '"decalId": "' .. tostring(previewAssetId) .. '"',
                            1,
                            true
                        )
                    ).to.be.ok()
                    expect(
                        modelManifest:find(
                            '"modelAssetId": "' .. tostring(previewAssetId) .. '"',
                            1,
                            true
                        )
                    ).to.equal(nil)
                end
                expect(type(family.role) == "string" and family.role ~= "").to.equal(true)
                expect(type(family.description) == "string" and family.description ~= "").to.equal(
                    true
                )
                expect(#family.upgradeNotes).to.equal(4)
                expect(#family.upgradeNotes[1]).to.equal(3)
                expect(#family.upgradeNotes[2]).to.equal(3)
            end
        end)

        it("treats Impaler Palisade as a no-damage stop shove, one bounce on Tier 1", function()
            local families = Progression.families(mergeConfig.tier_art)
            expect(families[1].id).to.equal("impaler_palisade")
            expect(families[1].role).to.equal("Stop")
            expect(families[1].description:find("No damage", 1, true)).to.be.ok()
            expect(families[1].upgradeNotes[1][3]:find("One bounce", 1, true)).to.be.ok()

            local shark = Progression.combatEffect("land_shark", 1, combatConfig)
            expect(shark.kind).to.equal("hunt_drag")
            expect(shark.sharkCount).to.equal(4)
            expect(shark.biteDamage).to.equal(36)
            expect(shark.huntRangeStuds).to.equal(16)
            expect(shark.grabRangeStuds).to.equal(7)
            expect(shark.sinkStuds).to.equal(8)
            expect(shark.venomDamage).to.equal(0)
            expect(shark.preferBosses).to.equal(false)
            local shark2 = Progression.combatEffect("land_shark", 2, combatConfig)
            expect(shark2.biteDamage).to.equal(90)
            expect(shark2.bitePeriod).to.equal(0.25)
            expect(shark.bitePeriod).to.equal(0.575)
            local shark3 = Progression.combatEffect("land_shark", 3, combatConfig)
            expect(shark3.sharkCount).to.equal(6)
            expect(shark3.venomDamage).to.equal(10)
            expect(shark3.venomPeriod).to.equal(0.35)
            expect(shark3.preferBosses).to.equal(false)
            local shark4 = Progression.combatEffect("land_shark", 4, combatConfig)
            expect(shark4.sharkCount).to.equal(7)
            expect(shark4.biteDamage).to.equal(190)
            expect(shark4.bitePeriod).to.equal(0.175)
            expect(shark4.preferBosses).to.equal(true)
            local t1 = Progression.combatEffect("impaler_palisade", 1, combatConfig)
            expect(t1.kind).to.equal("stop_shove")
            expect(t1.charges).to.equal(1)
            expect(t1.shoveStuds).to.equal(16)
            expect(t1.rootSeconds).to.equal(0.4)
            expect(t1.venomDamage).to.equal(0)
            expect(t1.contagionHops).to.equal(0)
            local t3 = Progression.combatEffect("impaler_palisade", 3, combatConfig)
            expect(t3.charges).to.equal(3)
            expect(t3.venomDamage).to.equal(12)
            expect(t3.venomPermanent).to.equal(true)
            expect(t3.contagionHops).to.equal(0)
            local t4Venom = Progression.combatEffect("impaler_palisade", 4, combatConfig)
            expect(t4Venom.venomDamage).to.equal(18)
            expect(t4Venom.venomPermanent).to.equal(true)
            expect(t4Venom.contagionHops).to.equal(4)
            local t4 = Progression.combatEffect("impaler_palisade", 4, combatConfig)
            expect(t4.charges).to.equal(4)
            expect(t4.shoveStuds).to.equal(28)
        end)

        it("treats Concertina Line as a graded bleed plus slow", function()
            local families = Progression.families(mergeConfig.tier_art)
            expect(families[2].id).to.equal("concertina_line")
            expect(families[2].role).to.equal("Bleed")
            expect(families[2].description:find("bleed and slow", 1, true)).to.be.ok()
            expect(families[2].upgradeNotes[1][2]:find("Bleed and slow", 1, true)).to.be.ok()
            expect(families[2].upgradeNotes[4][2]:find("Bleed stacks", 1, true)).to.be.ok()

            local wire1 = Progression.combatEffect("concertina_line", 1, combatConfig)
            expect(wire1.kind).to.equal("bleed_slow")
            expect(wire1.bleedDamage).to.equal(8)
            expect(wire1.bleedPeriod).to.equal(0.9)
            expect(wire1.slowFactor).to.equal(0.8)
            expect(wire1.lingerSeconds).to.equal(0)
            expect(wire1.bleedPermanent).to.equal(false)
            expect(wire1.bleedStacks).to.equal(false)
            expect(wire1.stripDepthStuds).to.equal(8)
            local wire2 = Progression.combatEffect("concertina_line", 2, combatConfig)
            expect(wire2.bleedDamage).to.equal(14)
            expect(wire2.slowFactor).to.equal(0.7)
            expect(wire2.lingerSeconds).to.equal(1.5)
            local wire3 = Progression.combatEffect("concertina_line", 3, combatConfig)
            expect(wire3.bleedDamage).to.equal(20)
            expect(wire3.bleedPeriod).to.equal(0.55)
            expect(wire3.slowFactor).to.equal(0.58)
            expect(wire3.lingerSeconds).to.equal(3.5)
            expect(wire3.stripDepthStuds).to.equal(10)
            local wire4 = Progression.combatEffect("concertina_line", 4, combatConfig)
            expect(wire4.bleedDamage).to.equal(16)
            expect(wire4.bleedPeriod).to.equal(0.4)
            expect(wire4.slowFactor).to.equal(0.45)
            expect(wire4.bleedPermanent).to.equal(true)
            expect(wire4.bleedStacks).to.equal(true)
            expect(wire4.stackCap).to.equal(4)
            expect(wire4.stripDepthStuds).to.equal(12)
        end)

        it("treats Saw Blade as a rapid no-control shred line", function()
            local families = Progression.families(mergeConfig.tier_art)
            expect(families[4].id).to.equal("saw_blade")
            expect(families[4].role).to.equal("Shred")
            expect(families[4].description:find("no control", 1, true)).to.be.ok()
            expect(families[4].upgradeNotes[1][2]:find("Rapid chew", 1, true)).to.be.ok()

            local saw1 = Progression.combatEffect("saw_blade", 1, combatConfig)
            expect(saw1.kind).to.equal("shred_line")
            expect(saw1.shredDamage).to.equal(16)
            expect(saw1.shredPeriod).to.equal(0.16)
            expect(saw1.stripDepthStuds).to.equal(6)
            expect(saw1.chunkCount).to.equal(6)
            local saw2 = Progression.combatEffect("saw_blade", 2, combatConfig)
            expect(saw2.shredDamage).to.equal(24)
            expect(saw2.shredPeriod).to.equal(0.13)
            local saw3 = Progression.combatEffect("saw_blade", 3, combatConfig)
            expect(saw3.shredDamage).to.equal(30)
            expect(saw3.shredPeriod).to.equal(0.10)
            local saw4 = Progression.combatEffect("saw_blade", 4, combatConfig)
            expect(saw4.shredDamage).to.equal(42)
            expect(saw4.shredPeriod).to.equal(0.08)
            expect(saw4.chunkCount).to.equal(10)
        end)

        it("scales power without widening bulwark combat radii", function()
            local base = Progression.combatEffect("land_shark", 3, combatConfig)
            local scaled = Progression.scaleCombatEffect(base, {
                power = 3,
                radius = 1,
                cadence = 1,
                duration = 1,
                capacity = 1,
                control = 1,
            })
            expect(scaled.biteDamage).to.equal(390)
            expect(scaled.venomDamage).to.equal(30)
            expect(scaled.huntRangeStuds).to.equal(base.huntRangeStuds)
            expect(scaled.grabRangeStuds).to.equal(base.grabRangeStuds)
            expect(scaled.venomRangeStuds).to.equal(base.venomRangeStuds)
            expect(scaled.bitePeriod).to.equal(base.bitePeriod)
            expect(scaled.sharkCount).to.equal(base.sharkCount)
            expect(base.biteDamage).to.equal(130)
        end)

        it("keeps cadence, duration, capacity, and control on independent axes", function()
            local base = Progression.combatEffect("impaler_palisade", 4, combatConfig)
            local scaled = Progression.scaleCombatEffect(base, {
                power = 2,
                radius = 1,
                cadence = 2,
                duration = 2,
                capacity = 2,
                control = 2,
            })
            expect(scaled.venomDamage).to.equal(36)
            expect(scaled.contagionRadius).to.equal(base.contagionRadius)
            expect(scaled.venomPeriod).to.equal(base.venomPeriod / 2)
            expect(scaled.rootSeconds).to.equal(base.rootSeconds * 2)
            expect(scaled.charges).to.equal(base.charges * 2)
            expect(scaled.shoveStuds).to.equal(base.shoveStuds * 2)
        end)

        it("keeps combat planes named and install slots repeatable", function()
            local Slots = Progression.slots
            expect(#Slots.ids()).to.equal(4)
            expect(Slots.get("lane").combatPlane).to.equal("bulwark")
            expect(Slots.get("egg").combatPlane).to.equal("breach")
            expect(Slots.get("mid").combatPlane).to.equal(nil)
            expect(Slots.get("front").combatPlane).to.equal(nil)
            expect(Slots.stripLineName("lane")).to.equal("BulwarkLine")
            expect(Slots.stripLineName("egg")).to.equal("BreachLine")
            local planes = Slots.combatPlanes()
            expect(#planes).to.equal(2)
            expect(planes[1].lineDefault).to.equal("BulwarkLine")
            expect(planes[1].opensCombat).to.equal(true)
            expect(planes[2].lineDefault).to.equal("BreachLine")
            expect(planes[2].countsBreach).to.equal(true)

            expect(Progression.canInstall("wardstone_barrier", "lane")).to.equal(false)
            expect(Progression.canInstall("wardstone_barrier", "mid")).to.equal(false)
            expect(Progression.canInstall("wardstone_barrier", "front")).to.equal(false)
            expect(Progression.canInstall("wardstone_barrier", "egg")).to.equal(true)
            expect(Progression.canInstall("impaler_palisade", "egg")).to.equal(true)

            local forbidden, reason =
                Progression.apply(nil, "select", "wardstone_barrier", 1, config, "lane")
            expect(forbidden).to.equal(nil)
            expect(reason).to.equal("bulwark_slot_forbidden")

            local wardUnlock =
                Progression.apply(nil, "unlock", "wardstone_barrier", 1, config, "egg")
            local egg =
                Progression.apply(wardUnlock, "select", "wardstone_barrier", 1, config, "egg")
            expect(egg.eggFamily).to.equal("wardstone_barrier")
            expect(egg.family).to.equal(nil)
            expect(egg.slots.egg.family).to.equal("wardstone_barrier")

            local sawUnlock = Progression.apply(egg, "unlock", "saw_blade", 1, config, "lane")
            local both = Progression.apply(sawUnlock, "select", "saw_blade", 1, config, "lane")
            expect(both.family).to.equal("saw_blade")
            expect(both.eggFamily).to.equal("wardstone_barrier")

            local copy = Progression.apply(both, "select", "saw_blade", 1, config, "egg")
            expect(copy.family).to.equal("saw_blade")
            expect(copy.eggFamily).to.equal("saw_blade")
            expect(copy.eggTier).to.equal(1)
            expect(copy.owned.saw_blade).to.equal(1)

            local persisted = Progression.persistFields({
                family = "concertina_line",
                tier = 3,
            })
            expect(persisted.bulwark_family).to.equal("concertina_line")
            expect(persisted.egg_bulwark_family).to.equal(nil)
            expect(persisted.bulwark_slots.lane.family).to.equal("concertina_line")
        end)

        it("treats Grasping Hedge as a temporary front-wave root", function()
            local families = Progression.families(mergeConfig.tier_art)
            expect(families[5].id).to.equal("grasping_hedge")
            expect(families[5].role).to.equal("Hold")
            expect(families[5].description:find("Hands stay free", 1, true)).to.be.ok()
            expect(families[5].description:find("break through", 1, true)).to.be.ok()
            expect(families[5].upgradeNotes[1][2]:find("Roots the front", 1, true)).to.be.ok()

            local t1 = Progression.combatEffect("grasping_hedge", 1, combatConfig)
            expect(t1.kind).to.equal("grab_root")
            expect(t1.grabCount).to.equal(1)
            expect(t1.rootSeconds).to.equal(0.9)
            expect(t1.slowFactor).to.equal(0.7)
            expect(t1.venomDamage).to.equal(0)
            expect(t1.stripDepthStuds).to.equal(8)
            expect(t1.exitBufferStuds).to.equal(6)
            local t2 = Progression.combatEffect("grasping_hedge", 2, combatConfig)
            expect(t2.grabCount).to.equal(2)
            expect(t2.rootSeconds).to.equal(1.2)
            local t3 = Progression.combatEffect("grasping_hedge", 3, combatConfig)
            expect(t3.grabCount).to.equal(3)
            expect(t3.venomDamage).to.equal(10)
            expect(t3.venomDuration).to.equal(4)
            local t4 = Progression.combatEffect("grasping_hedge", 4, combatConfig)
            expect(t4.grabCount).to.equal(4)
            expect(t4.rootSeconds).to.equal(2.2)
            expect(t4.venomDamage).to.equal(14)
            expect(t4.slowFactor).to.equal(0.42)
        end)
    end)
end
