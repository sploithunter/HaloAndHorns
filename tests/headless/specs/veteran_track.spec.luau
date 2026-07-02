--[[
    VeteranTrack — post-cap XP track math (docs/VETERAN_LEVELS.md).
    Run: mise run test-headless
]]

local VeteranTrack = loadModule("src/Shared/Game/VeteranTrack.lua")

local CFG = {
    enabled = true,
    xp_per_level = 2000,
    rewards = {
        rolls_per_level = 1,
        premium_every = 5,
        premium_bonus_rolls = 1,
        announce_every = 10,
    },
}

local CAP_XP = 34300 -- total XP at which level 50 was earned (LevelCurve.xpForLevel(50))

return function()
    describe("VeteranTrack.level", function()
        it("is 0 at or below the cap", function()
            expect(VeteranTrack.level(0, CAP_XP, CFG)).to.equal(0)
            expect(VeteranTrack.level(CAP_XP, CAP_XP, CFG)).to.equal(0)
        end)

        it("counts one vet level per xp_per_level past the cap", function()
            expect(VeteranTrack.level(CAP_XP + 1999, CAP_XP, CFG)).to.equal(0)
            expect(VeteranTrack.level(CAP_XP + 2000, CAP_XP, CFG)).to.equal(1)
            expect(VeteranTrack.level(CAP_XP + 10500, CAP_XP, CFG)).to.equal(5)
        end)

        it("is 0 when disabled or with no step (safe defaults)", function()
            expect(
                VeteranTrack.level(CAP_XP + 9999, CAP_XP, { enabled = false, xp_per_level = 2000 })
            ).to.equal(0)
            expect(VeteranTrack.level(CAP_XP + 9999, CAP_XP, { enabled = true })).to.equal(0)
            expect(VeteranTrack.level(CAP_XP + 9999, CAP_XP, nil)).to.equal(0)
        end)
    end)

    describe("VeteranTrack.progress", function()
        it("reports level + XP into the next vet level (the bar numbers)", function()
            local p = VeteranTrack.progress(CAP_XP + 5240, CAP_XP, CFG)
            expect(p.level).to.equal(2)
            expect(p.into).to.equal(1240)
            expect(p.step).to.equal(2000)
        end)

        it("clamps below the cap to an empty track", function()
            local p = VeteranTrack.progress(100, CAP_XP, CFG)
            expect(p.level).to.equal(0)
            expect(p.into).to.equal(0)
        end)
    end)

    describe("VeteranTrack.rollsFor (reward beats)", function()
        it("pays the base roll every level", function()
            expect(VeteranTrack.rollsFor(1, CFG)).to.equal(1)
            expect(VeteranTrack.rollsFor(4, CFG)).to.equal(1)
        end)

        it("pays the premium bonus every premium_every-th level", function()
            expect(VeteranTrack.rollsFor(5, CFG)).to.equal(2)
            expect(VeteranTrack.rollsFor(10, CFG)).to.equal(2)
        end)
    end)

    describe("VeteranTrack.isMilestone (status beat)", function()
        it("marks every announce_every-th level", function()
            expect(VeteranTrack.isMilestone(10, CFG)).to.equal(true)
            expect(VeteranTrack.isMilestone(20, CFG)).to.equal(true)
            expect(VeteranTrack.isMilestone(5, CFG)).to.equal(false)
            expect(VeteranTrack.isMilestone(0, CFG)).to.equal(false)
        end)
    end)
end
