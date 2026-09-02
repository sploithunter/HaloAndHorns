local Persist = loadModule("src/Shared/Game/MergeBulwarkPersist.lua")

return function()
    describe("Merge bulwark persist", function()
        local config = {
            unlock_wave = 20,
            playtest_unlock_enabled = true,
            playtest_unlock_wave = 1,
            maximum_tier = 4,
            currency = "hall_coins",
            action_cost = 1,
        }

        it("reads only bulwark keys and ignores wave or leftover owned blobs", function()
            local state = Persist.read({
                owned = { not_a_wall = 9 },
                family = "impaler_palisade",
                waveIndex = 14,
                bulwark_owned = { land_shark = 2 },
                eggBulwarkFamily = "wardstone_barrier",
                eggBulwarkTier = 1,
            }, config)
            expect(state.owned.land_shark).to.equal(2)
            expect(state.owned.impaler_palisade).to.equal(nil)
            expect(state.eggFamily).to.equal("wardstone_barrier")
            expect(state.family).to.equal(nil)
        end)

        it("installs without consulting a live wave", function()
            local unlocked, unlockReason =
                Persist.apply({}, "unlock", "impaler_palisade", config, "lane")
            expect(unlockReason).to.equal(nil)
            expect(unlocked.owned.impaler_palisade).to.equal(1)
            expect(unlocked.family).to.equal(nil)
            expect(unlocked.operation).to.equal("unlocked")

            local installed, reason =
                Persist.apply(unlocked, "select", "impaler_palisade", config, "lane")
            expect(reason).to.equal(nil)
            expect(installed.family).to.equal("impaler_palisade")
            expect(installed.tier).to.equal(1)
            expect(installed.operation).to.equal("installed")
            expect(installed.charged).to.equal(true)

            local record = { waveIndex = 14, owned = { eggs = true } }
            local progress = {
                playstate = { wave = 14 },
                owned = { onboarding = true },
            }
            Persist.write(record, progress, installed)
            expect(record.bulwarkFamily).to.equal("impaler_palisade")
            expect(record.owned.eggs).to.equal(true)
            expect(progress.bulwark_family).to.equal("impaler_palisade")
            expect(progress.bulwark_owned.impaler_palisade).to.equal(1)
            expect(progress.playstate.wave).to.equal(14)
            expect(progress.owned.onboarding).to.equal(true)
        end)

        it("writes onto the live profile table without a signature match", function()
            local unlocked = Persist.apply({}, "unlock", "impaler_palisade", config, "lane")
            local installed = Persist.apply(unlocked, "select", "impaler_palisade", config, "lane")
            local record = {}
            local detached = { bulwark_owned = {} }
            local live = { playstate = { wave = 3 } }
            Persist.write(record, live, installed)
            Persist.addSpent(record, live, 1)
            expect(detached.bulwark_owned.impaler_palisade).to.equal(nil)
            expect(live.bulwark_family).to.equal("impaler_palisade")
            expect(record.bulwarkWaycoinsSpent).to.equal(1)
            expect(live.bulwark_waycoins_spent).to.equal(1)
        end)

        it("clears placements on rebirth and keeps unlock flags", function()
            local unlocked = Persist.apply({}, "unlock", "impaler_palisade", config, "lane")
            local installed = Persist.apply(unlocked, "select", "impaler_palisade", config, "lane")
            local upgraded = Persist.apply(installed, "upgrade", "impaler_palisade", config, "lane")
            local progress = {}
            Persist.write(nil, progress, upgraded)
            expect(progress.bulwark_family).to.equal("impaler_palisade")
            expect(progress.bulwark_tier).to.equal(2)

            Persist.resetPlacements(nil, progress, config)
            expect(progress.bulwark_owned.impaler_palisade).to.equal(1)
            expect(progress.bulwark_family).to.equal(nil)
            expect(progress.bulwark_tier).to.equal(0)
        end)
    end)
end
