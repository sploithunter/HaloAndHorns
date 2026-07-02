--[[
    Phase 9: LevelCurve — XP <-> level math (single source of truth for player level).
    Run: mise run test-headless
]]

local LevelCurve = loadModule("src/Shared/Game/LevelCurve.lua")
local config = loadModule("configs/player_progression.lua")

-- Test the curve MATH against a fixed literal cfg, NOT the live game-balance value (so retuning
-- player_progression.xp.per_level never breaks these). The live config is sanity-checked for SHAPE
-- only, below.
local xpCfg = { mode = "linear", per_level = 100, max_level = 50 }

return function()
    describe("LevelCurve (linear, per_level=100)", function()
        it("level 1 needs 0 total XP", function()
            expect(LevelCurve.xpForLevel(1, xpCfg)).to.equal(0)
        end)
        it("step cost rises linearly: 1->2 = 100, 2->3 = 200", function()
            expect(LevelCurve.stepCost(1, xpCfg)).to.equal(100)
            expect(LevelCurve.stepCost(2, xpCfg)).to.equal(200)
        end)
        it("total XP to reach level 3 = 100 + 200 = 300", function()
            expect(LevelCurve.xpForLevel(3, xpCfg)).to.equal(300)
        end)
        it("xpForLevel and levelForXp are inverse", function()
            for level = 1, 20 do
                local xp = LevelCurve.xpForLevel(level, xpCfg)
                expect(LevelCurve.levelForXp(xp, xpCfg)).to.equal(level)
            end
        end)
        it("XP just below a threshold stays at the lower level", function()
            local xp = LevelCurve.xpForLevel(5, xpCfg) - 1
            expect(LevelCurve.levelForXp(xp, xpCfg)).to.equal(4)
        end)
        it("0 XP is level 1", function()
            expect(LevelCurve.levelForXp(0, xpCfg)).to.equal(1)
        end)
    end)

    describe("LevelCurve.progress", function()
        it("reports level, xp-into-level, and fraction", function()
            -- 150 XP: level 2 (300 reaches 3), into = 150-100 = 50, forNext = 200
            local p = LevelCurve.progress(150, xpCfg)
            expect(p.level).to.equal(2)
            expect(p.xpIntoLevel).to.equal(50)
            expect(p.xpForNext).to.equal(200)
            expect(p.fraction).to.equal(0.25)
        end)
    end)

    describe("live player_progression.xp config is well-formed", function()
        it("ships a linear curve with a positive per_level and the level-50 cap", function()
            expect(config.xp.mode).to.equal("linear")
            expect(type(config.xp.per_level)).to.equal("number")
            expect(config.xp.per_level > 0).to.equal(true)
            expect(config.xp.max_level).to.equal(50)
        end)
    end)

    describe("LevelCurve level cap (max_level = 50)", function()
        it("config tops out at level 50", function()
            expect(xpCfg.max_level).to.equal(50)
        end)
        it("earned level saturates at the cap no matter how much XP", function()
            -- XP far past the level-50 threshold still resolves to 50, not higher.
            local hugeXp = LevelCurve.xpForLevel(50, xpCfg) + 10_000_000
            expect(LevelCurve.levelForXp(hugeXp, xpCfg)).to.equal(50)
        end)
        it("reaches exactly 50 at its threshold", function()
            expect(LevelCurve.levelForXp(LevelCurve.xpForLevel(50, xpCfg), xpCfg)).to.equal(50)
        end)
    end)

    describe("LevelCurve flat mode", function()
        it("every level costs the same", function()
            local flat = { mode = "flat", per_level = 50 }
            expect(LevelCurve.xpForLevel(4, flat)).to.equal(150) -- 3 steps * 50
            expect(LevelCurve.levelForXp(150, flat)).to.equal(4)
            expect(LevelCurve.levelForXp(149, flat)).to.equal(3)
        end)
    end)
end
