--[[
    Feature 8: Stacked pet pool (token bucket) — [unit] scenarios.
    Run: mise run test-headless
]]

local StackPool = loadModule("src/Shared/Game/StackPool.lua")

return function()
    describe("StackPool", function()
        it("a new stack defaults to fully ready", function()
            local s = StackPool.newStack(5, 1000)
            expect(s.total_count).to.equal(5)
            expect(s.ready_count).to.equal(5)
        end)

        it("refreshes ready_count lazily: 24 + floor(1500/300) = 29", function()
            local s = StackPool.refresh(
                { total_count = 30, ready_count = 24, last_update = 0 },
                1500,
                300
            )
            expect(s.ready_count).to.equal(29)
            expect(s.last_update).to.equal(1500)
        end)

        it("caps refreshed ready_count at total", function()
            local s = StackPool.refresh(
                { total_count = 10, ready_count = 9, last_update = 0 },
                10000,
                300
            )
            expect(s.ready_count).to.equal(10)
        end)

        it("downing decrements ready_count and stamps last_update", function()
            local s = StackPool.down({ total_count = 30, ready_count = 30, last_update = nil }, 500)
            expect(s.ready_count).to.equal(29)
            expect(s.last_update).to.equal(500)
        end)

        it("downing an empty stack is a no-op (never negative)", function()
            local s = StackPool.down({ total_count = 30, ready_count = 0, last_update = 100 }, 500)
            expect(s.ready_count).to.equal(0)
        end)

        it("linear contribution scales by ready/total: 100 x 24/30 = 80", function()
            local c = StackPool.contribution({ total_count = 30, ready_count = 24 }, 100, "linear")
            expect(c).to.equal(80)
        end)

        it("sqrt-diminishing contribution: 100 x sqrt(24)/sqrt(30) ~= 89.4", function()
            local c = StackPool.contribution(
                { total_count = 30, ready_count = 24 },
                100,
                "sqrt_diminishing"
            )
            expect(c).to.near(89.44, 0.1)
        end)

        it("cooldown of 0 refills instantly", function()
            local s =
                StackPool.refresh({ total_count = 30, ready_count = 20, last_update = 0 }, 100, 0)
            expect(s.ready_count).to.equal(30)
        end)

        it("adding pets raises total and ready, leaves last_update", function()
            local s = StackPool.add({ total_count = 10, ready_count = 5, last_update = 100 }, 3)
            expect(s.total_count).to.equal(13)
            expect(s.ready_count).to.equal(8)
            expect(s.last_update).to.equal(100)
        end)

        it("removing pulls from ready first", function()
            local s = StackPool.remove({ total_count = 30, ready_count = 25, last_update = 0 }, 10)
            expect(s.total_count).to.equal(20)
            expect(s.ready_count).to.equal(15)
        end)

        it("removing more than ready falls through to non-ready (floored at 0)", function()
            local s = StackPool.remove({ total_count = 30, ready_count = 5, last_update = 0 }, 10)
            expect(s.total_count).to.equal(20)
            expect(s.ready_count).to.equal(0)
        end)
    end)
end
