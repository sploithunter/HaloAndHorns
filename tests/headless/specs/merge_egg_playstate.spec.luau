local Playstate = loadModule("src/Shared/Game/MergeEggPlaystate.lua")

return function()
    describe("Merge Egg durable logout playstate", function()
        local options = { interval = 10, maximumTier = 56, maximumTeams = 9 }

        it("treats Wave 0 possessions as a valid saved session", function()
            local saved = Playstate.normalize({
                saved = true,
                wave = 1,
                currency = "hall_coins",
                coins = 100,
                base_egg_tier = 1,
                egg_inventory = { 2 },
                deployed_egg_tiers = { 1, 1, 1, 1 },
            }, options)
            expect(saved.saved).to.equal(true)
            expect(saved.wave).to.equal(0)
            expect(saved.coins).to.equal(100)
            expect(saved.egg_inventory[1]).to.equal(2)
            expect(saved.deployed_egg_tiers[4]).to.equal(1)
            expect(Playstate.isUsable(saved, options)).to.equal(true)
        end)

        it("extracts current possessions but rewinds only the wave boundary", function()
            local saved = Playstate.fromRuntime({
                wave = 14,
                currency = "hall_coins",
                coins = 4321,
                objectiveEggsRemaining = 5,
                eggInventory = { 0, 3, 1 },
                recordState = { baseEggTier = 2 },
            }, {
                { id = 1, eggTier = 4, model = "not persisted" },
                { id = 5, eggTier = 7 },
            }, options)
            expect(saved.saved).to.equal(true)
            expect(saved.wave).to.equal(10)
            expect(saved.coins).to.equal(4321)
            expect(saved.base_egg_tier).to.equal(2)
            expect(saved.deployed_egg_tiers[1]).to.equal(4)
            expect(saved.deployed_egg_tiers[5]).to.equal(7)
            expect(saved.model).to.equal(nil)
        end)

        it("persists the last-good egg identity when logout follows a defeat", function()
            local saved = Playstate.fromRuntime({
                wave = 43,
                currency = "hall_coins",
                coins = 9000,
                objectiveEggsRemaining = 0,
                eggInventory = {},
                recordState = { baseEggTier = 3 },
            }, {
                { id = 1, eggTier = 0, resetEggTier = 7 },
                { id = 2, eggTier = 8, resetEggTier = 6 },
            }, options)
            expect(saved.wave).to.equal(40)
            expect(saved.deployed_egg_tiers[1]).to.equal(7)
            expect(saved.deployed_egg_tiers[2]).to.equal(8)
        end)

        it("repairs legacy empty deployment slots from the same-wave checkpoint", function()
            local repaired = Playstate.recoverCheckpointDeployments({
                saved = true,
                wave = 47,
                currency = "hall_coins",
                coins = 12000,
                deployed_egg_tiers = { 0, 9, 0 },
            }, {
                wave = 40,
                deployed_egg_tiers = { 7, 8, 6 },
            }, options)
            expect(repaired.wave).to.equal(40)
            expect(repaired.coins).to.equal(12000)
            expect(repaired.deployed_egg_tiers[1]).to.equal(7)
            expect(repaired.deployed_egg_tiers[2]).to.equal(9)
            expect(repaired.deployed_egg_tiers[3]).to.equal(6)

            local mismatched = Playstate.recoverCheckpointDeployments({
                saved = true,
                wave = 37,
                deployed_egg_tiers = { 0 },
            }, {
                wave = 20,
                deployed_egg_tiers = { 7 },
            }, options)
            expect(mismatched.wave).to.equal(30)
            expect(mismatched.deployed_egg_tiers[1]).to.equal(0)
        end)
    end)
end
