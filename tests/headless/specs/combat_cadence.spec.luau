local CombatCadence = loadModule("src/Shared/Game/CombatCadence.lua")

return function()
    describe("CombatCadence", function()
        it("leaves actors without an override at ordinary speed", function()
            expect(CombatCadence.interval(2, nil)).to.equal(2)
        end)

        it("turns a four-times multiplier into one-quarter intervals", function()
            expect(CombatCadence.interval(1, 4)).to.equal(0.25)
            expect(CombatCadence.interval(2, 4)).to.equal(0.5)
        end)

        it("fails safe and bounds authored multipliers", function()
            expect(CombatCadence.multiplier(0)).to.equal(1)
            expect(CombatCadence.multiplier("bad")).to.equal(1)
            expect(CombatCadence.multiplier(99)).to.equal(8)
            expect(CombatCadence.interval(0.2, 8)).to.equal(0.05)
        end)
    end)
end
