local Checkpoint = loadModule("src/Shared/Game/MergeEggCheckpoint.lua")

return function()
    describe("Merge Egg durable checkpoint", function()
        local options = { interval = 10, maximumTier = 56, maximumTeams = 9 }

        it("normalizes a profile-safe checkpoint onto the prior wave-ten boundary", function()
            local saved = Checkpoint.normalize({
                wave = 27,
                currency = "hall_coins",
                coins = 9876.9,
                objectiveEggsRemaining = 4,
                baseEggTier = 3,
                eggInventory = { 0, 2, 1 },
                deployedEggTiers = { 3, 5, 0, 7 },
            }, options)
            expect(saved.wave).to.equal(20)
            expect(saved.coins).to.equal(9876)
            expect(saved.objective_eggs).to.equal(4)
            expect(saved.base_egg_tier).to.equal(3)
            expect(saved.egg_inventory[2]).to.equal(2)
            expect(saved.deployed_egg_tiers[4]).to.equal(7)
            expect(Checkpoint.isUsable(saved, options)).to.equal(true)
        end)

        it("extracts only reconstructable progression from runtime state", function()
            local saved = Checkpoint.fromRuntime({
                wave = 30,
                currency = "hall_coins",
                coins = 12000,
                objectiveEggsRemaining = 5,
                eggInventory = { 2, 0, 1 },
                recordState = { baseEggTier = 2 },
            }, {
                { id = 1, eggTier = 4, model = "not persisted" },
                { id = 2, eggTier = 0 },
                { id = 5, eggTier = 8, definition = "not persisted" },
            }, options)
            expect(saved.wave).to.equal(30)
            expect(saved.base_egg_tier).to.equal(2)
            expect(saved.deployed_egg_tiers[1]).to.equal(4)
            expect(saved.deployed_egg_tiers[2]).to.equal(0)
            expect(saved.deployed_egg_tiers[5]).to.equal(8)
            expect(saved.model).to.equal(nil)
        end)
    end)
end
