--[[
    Level-difference damage scaling + difficulty colour tiers. Run: mise run test-headless
]]

local LevelScale = loadModule("src/Shared/Game/LevelScale.lua")

return function()
    describe("LevelScale.factor", function()
        it("is 1.0 at equal levels", function()
            expect(LevelScale.factor(5, 5, { per_level = 0.08 })).to.near(1, 1e-6)
        end)

        it("raises damage when the attacker is higher level", function()
            expect(LevelScale.factor(8, 5, { per_level = 0.1 })).to.near(1.3, 1e-6) -- +3 levels @ 0.1
        end)

        it("lowers damage when the attacker is lower level", function()
            expect(LevelScale.factor(3, 5, { per_level = 0.1 })).to.near(0.8, 1e-6) -- -2 levels
        end)

        it("clamps to min and max", function()
            expect(LevelScale.factor(50, 1, { per_level = 0.1, max = 2.5 })).to.equal(2.5)
            expect(LevelScale.factor(1, 50, { per_level = 0.1, min = 0.3 })).to.equal(0.3)
        end)
    end)

    describe("LevelScale.effectiveLevel", function()
        it("adds the rank offset to the base level", function()
            expect(LevelScale.effectiveLevel(5, 0)).to.equal(5) -- standard
            expect(LevelScale.effectiveLevel(5, 1)).to.equal(6) -- lieutenant
            expect(LevelScale.effectiveLevel(5, 2)).to.equal(7) -- boss
        end)
    end)

    describe("LevelScale.tier", function()
        it("maps level difference to the difficulty colour key", function()
            expect(LevelScale.tier(0)).to.equal("white")
            expect(LevelScale.tier(1)).to.equal("yellow")
            expect(LevelScale.tier(2)).to.equal("red")
            expect(LevelScale.tier(3)).to.equal("purple")
            expect(LevelScale.tier(5)).to.equal("purple") -- caps
            expect(LevelScale.tier(-1)).to.equal("blue")
            expect(LevelScale.tier(-2)).to.equal("green")
            expect(LevelScale.tier(-3)).to.equal("gray")
            expect(LevelScale.tier(-9)).to.equal("gray") -- caps
        end)
    end)
end
