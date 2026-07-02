--[[
    PetSurvivability — effective-HP arithmetic (the inventory card's ❤ number).
    Run: mise run test-headless
]]

local PetSurvivability = loadModule("src/Shared/Game/PetSurvivability.lua")

return function()
    describe("PetSurvivability.effectiveHp", function()
        -- factor 10, k 100 mirror configs/combat.lua. takenMult 1.0 = element-neutral (today).
        local FACTOR, K = 10, 100

        it("blaster (defense 0): EHP = power * factor (no mitigation)", function()
            expect(PetSurvivability.effectiveHp(42, 0, FACTOR, K, 1)).to.equal(420)
        end)

        it("tank (defense 100, k 100): armor curve halves incoming -> 2x EHP", function()
            expect(PetSurvivability.effectiveHp(42, 100, FACTOR, K, 1)).to.equal(840)
        end)

        it("melee (defense 20): 1 + 20/100 -> 1.2x EHP", function()
            expect(PetSurvivability.effectiveHp(42, 20, FACTOR, K, 1)).to.equal(504)
        end)

        it("buffer (defense 10): 1 + 10/100 -> 1.1x EHP", function()
            expect(PetSurvivability.effectiveHp(40, 10, FACTOR, K, 1)).to.equal(440)
        end)

        it("control (defense 40): 1 + 40/100 -> 1.4x EHP", function()
            expect(PetSurvivability.effectiveHp(50, 40, FACTOR, K, 1)).to.equal(700)
        end)

        it("element durability: takenMult 0.5 (takes half) doubles EHP", function()
            expect(PetSurvivability.effectiveHp(42, 0, FACTOR, K, 0.5)).to.equal(840)
        end)

        it("EHP scales linearly with power (survivability is power-derived)", function()
            local lo = PetSurvivability.effectiveHp(20, 0, FACTOR, K, 1)
            local hi = PetSurvivability.effectiveHp(40, 0, FACTOR, K, 1)
            expect(hi).to.equal(lo * 2)
        end)

        it("zero/invalid takenMult is treated as neutral (no divide-by-zero)", function()
            expect(PetSurvivability.effectiveHp(42, 0, FACTOR, K, 0)).to.equal(420)
        end)
    end)
end
