--[[
    XpReward.fromValue — [unit] activity XP from a reward magnitude.
    Run: mise run test-headless
]]

local XpReward = loadModule("src/Shared/Game/XpReward.lua")
local leveling = loadModule("configs/leveling.lua")

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

    describe("XpReward.applyOnramp", function()
        it("uses configured source multipliers for the shipped level-3 targets", function()
            local smallOre = XpReward.fromValue(20, leveling.xp_rewards.mining)
            local mediumOre = XpReward.fromValue(100, leveling.xp_rewards.mining)
            local largeOre = XpReward.fromValue(400, leveling.xp_rewards.mining)
            local evenMinion = XpReward.fromEnemyLevel(3, leveling.combat_xp.xp_per_level, 1)

            expect(XpReward.applyOnramp(smallOre, 3, leveling.onramp, "mining")).to.equal(5)
            expect(XpReward.applyOnramp(mediumOre, 3, leveling.onramp, "mining")).to.equal(25)
            expect(XpReward.applyOnramp(largeOre, 3, leveling.onramp, "mining")).to.equal(100)
            expect(XpReward.applyOnramp(evenMinion, 3, leveling.onramp, "combat")).to.equal(15)
        end)

        it("uses the fallback for other sources and stops boosting at level 5", function()
            expect(XpReward.applyOnramp(10, 3, leveling.onramp, "egg")).to.equal(15)
            expect(XpReward.applyOnramp(10, 5, leveling.onramp, "mining")).to.equal(10)
            expect(XpReward.applyOnramp(10, 50, leveling.onramp, "combat")).to.equal(10)
        end)

        it("handles missing config and non-positive amounts safely", function()
            expect(XpReward.applyOnramp(10, 3, nil, "mining")).to.equal(10)
            expect(XpReward.applyOnramp(0, 3, leveling.onramp, "mining")).to.equal(0)
            expect(XpReward.applyOnramp(-10, 3, leveling.onramp, "mining")).to.equal(0)
        end)
    end)
end
