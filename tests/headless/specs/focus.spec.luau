--[[
    Feature 12: Player Character (Spirit Presence) / Focus — [unit] scenarios.
    Run: mise run test-headless
]]

local FocusMath = loadModule("src/Shared/Game/FocusMath.lua")
local config = loadModule("configs/focus.lua")

return function()
    describe("FocusMath.cast", function()
        it("spends Focus when the pool covers the cost", function()
            -- focus 100, Stone Skin costs 20 -> 80
            local r = FocusMath.cast(100, 20)
            expect(r.ok).to.equal(true)
            expect(r.focus).to.equal(80)
        end)

        it("rejects with insufficient_focus and does not spend", function()
            -- focus 10, power costs 20 -> rejected, no cooldown incurred (service)
            local r = FocusMath.cast(10, 20)
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("insufficient_focus")
            expect(r.focus).to.equal(10)
        end)

        it("allows an exact-cost cast to zero", function()
            local r = FocusMath.cast(20, 20)
            expect(r.ok).to.equal(true)
            expect(r.focus).to.equal(0)
        end)
    end)

    describe("FocusMath.canCast", function()
        it("is true at exactly the cost and false just under", function()
            expect(FocusMath.canCast(20, 20)).to.equal(true)
            expect(FocusMath.canCast(19, 20)).to.equal(false)
        end)
    end)

    describe("FocusMath.regen", function()
        it("regenerates at the configured rate over elapsed seconds", function()
            -- derived from config so a regen tuning pass doesn't break the test
            expect(FocusMath.regen(50, 5, config)).to.equal(50 + config.regen_per_second * 5)
        end)

        it("never exceeds focus_max", function()
            -- a big elapsed window always saturates the pool to focus_max
            expect(FocusMath.regen(config.focus_max - 1, 1000, config)).to.equal(config.focus_max)
        end)

        it("regenerates from zero by default (no stun)", function()
            expect(FocusMath.regen(0, 1, config)).to.equal(config.regen_per_second)
        end)

        it("honors regen_pauses_at_zero when a game opts in", function()
            local stunCfg = { focus_max = 100, regen_per_second = 5, regen_pauses_at_zero = true }
            expect(FocusMath.regen(0, 1, stunCfg)).to.equal(0)
            -- but a non-zero pool still regenerates under the stun flag
            expect(FocusMath.regen(10, 1, stunCfg)).to.equal(15)
        end)
    end)

    describe("FocusMath.sunder", function()
        it("drains Focus by the attack amount", function()
            -- focus 100, sundering attack 20 -> 80
            expect(FocusMath.sunder(100, 20, config)).to.equal(80)
        end)

        it("never goes below zero", function()
            -- focus 5, sundering 50 -> 0 (not -45)
            expect(FocusMath.sunder(5, 50, config)).to.equal(0)
        end)
    end)
end
