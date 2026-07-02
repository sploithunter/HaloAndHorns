--[[
    Evasion — true-avoidance math (clamp + roll verdict). Run: mise run test-headless
]]

local Evasion = loadModule("src/Shared/Game/Evasion.lua")

return function()
    describe("Evasion.chance", function()
        it("passes a normal chance through", function()
            expect(Evasion.chance(0.5)).to.equal(0.5)
        end)

        it("clamps to the cap (never 100% immune)", function()
            expect(Evasion.chance(0.99, 0.95)).to.equal(0.95)
            expect(Evasion.chance(1.5)).to.equal(Evasion.DEFAULT_MAX)
        end)

        it("floors negative / nil at zero", function()
            expect(Evasion.chance(-1)).to.equal(0)
            expect(Evasion.chance(nil)).to.equal(0)
        end)
    end)

    describe("Evasion.evaded", function()
        it("avoids when the roll lands under the chance", function()
            expect(Evasion.evaded(0.5, 0.2)).to.equal(true)
        end)

        it("takes the hit when the roll is at/over the chance", function()
            expect(Evasion.evaded(0.5, 0.5)).to.equal(false)
            expect(Evasion.evaded(0.5, 0.9)).to.equal(false)
        end)

        it("respects the cap — a 0.99 chance still lets a high roll through", function()
            -- chance clamps to 0.95, so a 0.97 roll is a HIT
            expect(Evasion.evaded(0.99, 0.97, 0.95)).to.equal(false)
        end)

        it("never avoids with no buff (chance 0)", function()
            expect(Evasion.evaded(0, 0.0)).to.equal(false)
        end)
    end)
end
