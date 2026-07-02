--[[
    AggroLeash — pure-decay aggro persistence (enemy bleeds interest as you flee; one hard cutoff).
    Run: mise run test-headless
]]

local AggroLeash = loadModule("src/Shared/Game/AggroLeash.lua")

local CFG = {
    decay_start_range = 90,
    give_up_range = 300,
    chase_decay_mult = 3,
    leave_area_decay_mult = 6,
}

return function()
    describe("AggroLeash.decayMult", function()
        it("is 1x while close (within decay_start_range), in territory", function()
            expect(AggroLeash.decayMult(0, true, CFG)).to.equal(1)
            expect(AggroLeash.decayMult(90, true, CFG)).to.equal(1)
        end)

        it("ramps to chase_decay_mult once past decay_start_range", function()
            expect(AggroLeash.decayMult(91, true, CFG)).to.equal(3)
            expect(AggroLeash.decayMult(299, true, CFG)).to.equal(3)
        end)

        it("uses leave_area_decay_mult (the larger) once out of the home area", function()
            expect(AggroLeash.decayMult(0, false, CFG)).to.equal(6) -- close but out of area
            expect(AggroLeash.decayMult(200, false, CFG)).to.equal(6) -- max(3, 6)
        end)

        it("falls back to sane defaults when cfg is missing", function()
            expect(AggroLeash.decayMult(0, true, nil)).to.equal(1)
            expect(AggroLeash.decayMult(99999, true, nil)).to.equal(3) -- default chase_decay_mult
        end)
    end)

    describe("AggroLeash.shouldDrop", function()
        it("keeps engaged while a threat target remains within give_up_range", function()
            expect(AggroLeash.shouldDrop(10, true, CFG)).to.equal(false)
            expect(AggroLeash.shouldDrop(299, true, CFG)).to.equal(false)
        end)

        it("drops when threat has bled out (no target), even up close", function()
            expect(AggroLeash.shouldDrop(10, false, CFG)).to.equal(true)
        end)

        it("drops past give_up_range even with a live target (teleport / new world)", function()
            expect(AggroLeash.shouldDrop(301, true, CFG)).to.equal(true)
            expect(AggroLeash.shouldDrop(9999, true, CFG)).to.equal(true)
        end)
    end)
end
