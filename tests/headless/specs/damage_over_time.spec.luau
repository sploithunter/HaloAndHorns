--[[
    DamageOverTime — DoT tick arithmetic (the burn/poison/bleed pet-attack axis).
    Run: mise run test-headless
]]

local DamageOverTime = loadModule("src/Shared/Game/DamageOverTime.lua")

return function()
    describe("DamageOverTime.perTick", function()
        it("is a fraction of the triggering hit, floored", function()
            expect(DamageOverTime.perTick(100, 0.3)).to.equal(30)
            expect(DamageOverTime.perTick(45, 0.5)).to.equal(23) -- 22.5 -> 23
        end)

        it("is 0 for no fraction / no damage", function()
            expect(DamageOverTime.perTick(100, 0)).to.equal(0)
            expect(DamageOverTime.perTick(0, 0.5)).to.equal(0)
            expect(DamageOverTime.perTick(nil, nil)).to.equal(0)
        end)
    end)

    describe("DamageOverTime.ticksDue", function()
        -- DoT started at t=0: nextTick=1, interval=1, expire=4 (so 4 ticks total, at t=1,2,3,4).
        it("returns one tick when exactly one interval has elapsed", function()
            local n, nextAt = DamageOverTime.ticksDue(1, 1, 4, 1)
            expect(n).to.equal(1)
            expect(nextAt).to.equal(2)
        end)

        it("catches up multiple ticks if the loop stepped slowly", function()
            local n, nextAt = DamageOverTime.ticksDue(1, 1, 4, 3.5)
            expect(n).to.equal(3) -- ticks at 1, 2, 3
            expect(nextAt).to.equal(4)
        end)

        it("never ticks past expiry (exactly duration/interval ticks)", function()
            local n = DamageOverTime.ticksDue(1, 1, 4, 99) -- way past expiry
            expect(n).to.equal(4) -- ticks at 1,2,3,4 only
        end)

        it("returns zero before the next tick is due", function()
            local n, nextAt = DamageOverTime.ticksDue(1, 1, 4, 0.5)
            expect(n).to.equal(0)
            expect(nextAt).to.equal(1)
        end)

        it("guards a zero interval (no divide / no infinite loop)", function()
            expect((DamageOverTime.ticksDue(1, 0, 4, 99))).to.equal(0)
        end)
    end)

    describe("DamageOverTime.isExpired", function()
        it("is true only past the expiry time", function()
            expect(DamageOverTime.isExpired(4, 3.9)).to.equal(false)
            expect(DamageOverTime.isExpired(4, 4)).to.equal(false)
            expect(DamageOverTime.isExpired(4, 4.1)).to.equal(true)
        end)
    end)
end
