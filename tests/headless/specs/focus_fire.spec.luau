local FocusFire = loadModule("src/Shared/Game/FocusFire.lua")
local powers = loadModule("configs/powers.lua")

return function()
    describe("Focus Fire accuracy mark", function()
        it("uses a player-scoped attribute channel", function()
            local a = FocusFire.keys(42)
            local b = FocusFire.keys(99)
            expect(a.untilTime).to.equal("FocusFire_42_Until")
            expect(a.accuracyBonus).to.equal("FocusFire_42_AccuracyBonus")
            expect(a.holdPierce).to.equal("FocusFire_42_HoldPierce")
            expect(a.untilTime == b.untilTime).to.equal(false)
        end)

        it("adds flat accuracy points while active and respects the cap", function()
            local chance, bonus = FocusFire.applyAccuracy(0.72, 0.15, 108, 100, 0.95)
            expect(chance).to.near(0.87)
            expect(bonus).to.near(0.15)

            local capped = FocusFire.applyAccuracy(0.92, 0.15, 108, 100, 0.95)
            expect(capped).to.near(0.95)

            local expired, expiredBonus = FocusFire.applyAccuracy(0.72, 0.15, 100, 100, 0.95)
            expect(expired).to.near(0.72)
            expect(expiredBonus).to.near(0)
        end)

        it("pierces innate immunity only during the mark and below the configured roll", function()
            expect(FocusFire.piercesInnateHold(108, 0.25, 100, 0.249)).to.equal(true)
            expect(FocusFire.piercesInnateHold(108, 0.25, 100, 0.25)).to.equal(false)
            expect(FocusFire.piercesInnateHold(100, 0.25, 100, 0.01)).to.equal(false)
        end)

        it("ships the agreed live tuning without a vulnerability multiplier", function()
            local kind = powers.effect_kinds.focus_fire
            expect(kind.family).to.equal("accuracy_mark")
            expect(kind.magnitude).to.near(0.15)
            expect(kind.duration).to.equal(8)
            expect(kind.hold_pierce).to.near(0.25)
            expect(powers.enemy_targeted_families.accuracy_mark).to.equal(true)
        end)
    end)
end
