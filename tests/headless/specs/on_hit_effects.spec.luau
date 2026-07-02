--[[
    OnHitEffects — on-hit enemy-effect math (control slow / shred vulnerability / execute reaper).
    Run: mise run test-headless
]]

local OnHitEffects = loadModule("src/Shared/Game/OnHitEffects.lua")

return function()
    describe("OnHitEffects.slowSpeed (control)", function()
        it("scales base move speed by the clamped factor", function()
            expect(OnHitEffects.slowSpeed(12, 0.5)).to.equal(6)
            expect(OnHitEffects.slowSpeed(12, 0)).to.equal(0) -- full stop
        end)

        it("clamps a garbage factor into [0,1]", function()
            expect(OnHitEffects.slowSpeed(12, 1.5)).to.equal(12)
            expect(OnHitEffects.slowSpeed(12, -3)).to.equal(0)
        end)

        it("no factor = unchanged speed (no slow configured)", function()
            expect(OnHitEffects.slowSpeed(12, nil)).to.equal(12)
        end)
    end)

    describe("OnHitEffects.vulnerable (shred)", function()
        it("turns a fraction into a multiplier", function()
            expect(OnHitEffects.vulnerable(1, false, 0.3)).to.equal(1.3)
        end)

        it("keeps the stronger of the active mult and the incoming shred", function()
            expect(OnHitEffects.vulnerable(1.5, true, 0.2)).to.equal(1.5) -- existing bigger -> kept
            expect(OnHitEffects.vulnerable(1.2, true, 0.5)).to.equal(1.5) -- incoming bigger -> wins
        end)

        it("ignores a stale (inactive) current mult", function()
            expect(OnHitEffects.vulnerable(3, false, 0.25)).to.equal(1.25) -- expired -> treat as 1x
        end)
    end)

    describe("OnHitEffects.weaken (curse)", function()
        it("applies a curse mult as-is when no curse is active", function()
            expect(OnHitEffects.weaken(1, false, 0.7)).to.equal(0.7) -- enemy deals -30%
        end)

        it("keeps the STRONGER (lower) of the active mult and the incoming curse", function()
            expect(OnHitEffects.weaken(0.6, true, 0.8)).to.equal(0.6) -- existing harder -> kept
            expect(OnHitEffects.weaken(0.9, true, 0.5)).to.equal(0.5) -- incoming harder -> wins
        end)

        it("ignores a stale (inactive) current mult", function()
            expect(OnHitEffects.weaken(0.2, false, 0.7)).to.equal(0.7) -- expired -> treat as 1x
        end)

        it("clamps into [0,1] — a curse can't buff the enemy", function()
            expect(OnHitEffects.weaken(1, false, 1.5)).to.equal(1) -- >1 clamped (no buff)
            expect(OnHitEffects.weaken(1, false, -0.2)).to.equal(0) -- <0 clamped
        end)
    end)

    describe("OnHitEffects.executeBonus (reaper)", function()
        it("finishes an enemy at or below the threshold", function()
            expect(OnHitEffects.executeBonus(15, 100, 0.15)).to.equal(15) -- 15% -> reap the rest
            expect(OnHitEffects.executeBonus(10, 100, 0.15)).to.equal(10)
        end)

        it("does nothing above the threshold", function()
            expect(OnHitEffects.executeBonus(40, 100, 0.15)).to.equal(0)
        end)

        it("never executes from dead / unknown data", function()
            expect(OnHitEffects.executeBonus(0, 100, 0.15)).to.equal(0)
            expect(OnHitEffects.executeBonus(10, 0, 0.15)).to.equal(0)
            expect(OnHitEffects.executeBonus(10, 100, 0)).to.equal(0)
        end)
    end)
end
