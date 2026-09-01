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
            visual_catalog_owned = true,
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

        it("installs from the catalog without consulting a live wave", function()
            local granted = Persist.read({}, config)
            expect(granted.owned.heal).to.equal(1)
            expect(granted.leftFamily).to.equal(nil)

            local installed, reason = Persist.apply(granted, "select", "heal", config, "left")
            expect(reason).to.equal(nil)
            expect(installed.leftFamily).to.equal("heal")
            expect(installed.operation).to.equal("equipped")
            expect(installed.charged).to.equal(false)

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
            local granted = Persist.read({}, config)
            local installed = Persist.apply(granted, "select", "heal", config, "left")
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
    end)
end
