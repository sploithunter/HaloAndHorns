--[[
    XpReward.fromValue — [unit] activity XP from a reward magnitude.
    Run: mise run test-headless
]]

local XpReward = loadModule("src/Shared/Game/XpReward.lua")

return function()
    describe("XpReward.fromValue", function()
        it("scales XP by per_value (floored)", function()
            expect(XpReward.fromValue(100, { per_value = 0.5, min = 1 })).to.equal(50)
            expect(XpReward.fromValue(7, { per_value = 0.5, min = 1 })).to.equal(3) -- floor(3.5)
        end)

        it("applies the floor (min) for small positive values", function()
            -- value 1 * 0.5 = 0.5 -> floor 0 -> min 1
            expect(XpReward.fromValue(1, { per_value = 0.5, min = 1 })).to.equal(1)
        end)

        it("grants nothing for zero/negative value (no min freebie)", function()
            expect(XpReward.fromValue(0, { per_value = 0.5, min = 1 })).to.equal(0)
            expect(XpReward.fromValue(-5, { per_value = 0.5, min = 1 })).to.equal(0)
        end)

        it("defaults safely with missing config", function()
            expect(XpReward.fromValue(100, {})).to.equal(0) -- per_value defaults 0
            expect(XpReward.fromValue(100, nil)).to.equal(0)
        end)
    end)

    describe("XpReward.fromEnemyLevel (combat)", function()
        it("scales XP by effective level × per_level (floored)", function()
            -- shipped calibration: 2.0/level, trash rank ×1 -> level-21 kill = 42 XP
            expect(XpReward.fromEnemyLevel(21, 2.0, 1.0)).to.equal(42)
            expect(XpReward.fromEnemyLevel(5, 2.0, 1.0)).to.equal(10)
        end)

        it("applies the rank multiplier (lieutenant / boss premium)", function()
            expect(XpReward.fromEnemyLevel(20, 2.0, 1.6)).to.equal(64) -- lieutenant: floor(2*20*1.6)
            expect(XpReward.fromEnemyLevel(22, 2.0, 3.0)).to.equal(132) -- boss: floor(2*22*3)
        end)

        it("floors at 1 so any kill ticks the bar", function()
            expect(XpReward.fromEnemyLevel(1, 0, 1)).to.equal(1) -- zero rate still grants 1
            expect(XpReward.fromEnemyLevel(0, 2.0, 1)).to.equal(1)
        end)

        it("defaults safely with missing args", function()
            expect(XpReward.fromEnemyLevel(nil, nil, nil)).to.equal(1) -- 1 × 0 × 1 -> floor 0 -> min 1
        end)
    end)
end
