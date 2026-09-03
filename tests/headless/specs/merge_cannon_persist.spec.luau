local Persist = loadModule("src/Shared/Game/MergeCannonPersist.lua")

return function()
    describe("Merge cannon persist", function()
        local config = {
            unlock_wave = 10,
            playtest_unlock_enabled = true,
            playtest_unlock_wave = 1,
            maximum_tier = 4,
            currency = "hall_coins",
            action_cost = 1,
            slot_unlock_rebirth_ranks = {
                left = 1,
                right = 1,
                rear_left = 20,
                rear_right = 20,
            },
            visual_catalog_owned = false,
            starter_tier = 1,
            available_roles = {
                "heal",
                "rage",
                "debuff",
                "gravity",
                "repulsor",
                "nullifier",
            },
        }

        it("reads only tower keys and ignores wave or leftover owned blobs", function()
            local state = Persist.read({
                owned = { not_a_cannon = 9 },
                leftFamily = "heal",
                waveIndex = 14,
                tower_owned = { rage = 2 },
                leftTowerFamily = "repulsor",
                leftTowerTier = 2,
            }, {
                maximum_tier = 4,
            })
            expect(state.owned.rage).to.equal(2)
            expect(state.owned.heal).to.equal(nil)
            expect(state.leftFamily).to.equal("repulsor")
            expect(state.leftTier).to.equal(2)
        end)

        it("unlocks then installs without consulting a live wave", function()
            local empty = Persist.read({}, config)
            expect(empty.owned.heal).to.equal(nil)
            expect(empty.leftFamily).to.equal(nil)

            local unlocked, unlockReason = Persist.apply(empty, "unlock", "heal", config, "left")
            expect(unlockReason).to.equal(nil)
            expect(unlocked.owned.heal).to.equal(1)
            expect(unlocked.leftFamily).to.equal(nil)
            expect(unlocked.operation).to.equal("unlocked")
            expect(unlocked.charged).to.equal(true)

            local installed, reason = Persist.apply(unlocked, "select", "heal", config, "left")
            expect(reason).to.equal(nil)
            expect(installed.leftFamily).to.equal("heal")
            expect(installed.leftTier).to.equal(1)
            expect(installed.operation).to.equal("installed")
            expect(installed.charged).to.equal(true)

            local record = { waveIndex = 14, owned = { eggs = true } }
            local progress = {
                playstate = { wave = 14 },
                owned = { onboarding = true },
            }
            Persist.write(record, progress, installed)
            expect(record.leftTowerFamily).to.equal("heal")
            expect(record.leftFamily).to.equal(nil)
            expect(record.owned.eggs).to.equal(true)
            expect(progress.left_tower_family).to.equal("heal")
            expect(progress.tower_owned.heal).to.equal(1)
            expect(progress.playstate.wave).to.equal(14)
            expect(progress.owned.onboarding).to.equal(true)
        end)

        it("writes onto a replaced profile table without needing a signature match", function()
            local unlocked = Persist.apply({}, "unlock", "heal", config, "left")
            local installed = Persist.apply(unlocked, "select", "heal", config, "left")
            local record = {}
            local detached = { tower_owned = {} }
            local live = { playstate = { wave = 3 } }
            Persist.write(record, live, installed)
            expect(detached.tower_owned.heal).to.equal(nil)
            expect(live.left_tower_family).to.equal("heal")
            expect(live.tower_owned.heal).to.equal(1)
            Persist.addSpent(record, live, 0)
            expect(record.towerWaycoinsSpent).to.equal(0)
            expect(live.tower_waycoins_spent).to.equal(0)
        end)

        it("clears placements on rebirth and keeps unlock flags", function()
            local unlocked = Persist.apply({}, "unlock", "heal", config, "left")
            local installed = Persist.apply(unlocked, "select", "heal", config, "left")
            local upgraded = Persist.apply(installed, "upgrade", "heal", config, "left")
            local record = {}
            local progress = {}
            Persist.write(record, progress, upgraded)
            expect(progress.left_tower_family).to.equal("heal")
            expect(progress.left_tower_tier).to.equal(2)
            expect(progress.tower_owned.heal).to.equal(1)

            Persist.resetPlacements(record, progress, config)
            expect(progress.tower_owned.heal).to.equal(1)
            expect(progress.left_tower_family).to.equal(nil)
            expect(progress.left_tower_tier).to.equal(0)
            expect(record.towerOwned.heal).to.equal(1)
            expect(record.leftTowerFamily).to.equal(nil)
            expect(record.leftTowerTier).to.equal(0)
            expect(record.towerSlots.left.family).to.equal(nil)
            expect(record.towerSlots.left.tier).to.equal(0)
        end)
    end)
end
