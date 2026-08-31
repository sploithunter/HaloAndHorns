local Progression = loadModule("src/Shared/Game/MergeBulwarkProgression.lua")

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

        it("installs and replaces a family at Tier 1", function()
            local installed = Progression.apply(nil, "select", "impaler_palisade", 0, config)
            expect(installed.family).to.equal("impaler_palisade")
            expect(installed.tier).to.equal(1)
            expect(installed.operation).to.equal("installed")

            local replaced = Progression.apply(installed, "select", "land_shark", 1, config)
            expect(replaced.family).to.equal("land_shark")
            expect(replaced.tier).to.equal(1)
            expect(replaced.operation).to.equal("replaced")
        end)

        it("upgrades the installed family without passing Tier 4", function()
            local upgraded = Progression.apply({
                family = "saw_blade",
                tier = 3,
            }, "upgrade", nil, 1, config)
            expect(upgraded.family).to.equal("saw_blade")
            expect(upgraded.tier).to.equal(4)
            expect(upgraded.operation).to.equal("upgraded")

            local maxed, reason = Progression.apply(upgraded, "upgrade", nil, 1, config)
            expect(maxed).to.equal(nil)
            expect(reason).to.equal("bulwark_maxed")
        end)

        it("charges one configured Waycoin for every mutation", function()
            local price = Progression.actionCost(config)
            expect(price.currency).to.equal("hall_coins")
            expect(price.amount).to.equal(1)
            expect(#Progression.families()).to.equal(6)
        end)
    end)
end
