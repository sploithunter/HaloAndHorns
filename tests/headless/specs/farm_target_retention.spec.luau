local FarmTargetRetention = loadModule("src/Shared/Game/FarmTargetRetention.lua")

return function()
    describe("FarmTargetRetention.shouldKeep", function()
        it("keeps an unfinished crystal during automatic farming", function()
            expect(FarmTargetRetention.shouldKeep({
                automatic = true,
                targetType = "Crystals",
                targetId = 42,
                targetHp = 99,
            })).to.equal(true)
        end)

        it("releases a finished or missing crystal for the next poll", function()
            expect(FarmTargetRetention.shouldKeep({
                automatic = true,
                targetType = "Crystals",
                targetId = 42,
                targetHp = 0,
            })).to.equal(false)
            expect(FarmTargetRetention.shouldKeep({
                automatic = true,
                targetType = "Crystals",
                targetId = 0,
                targetHp = 99,
            })).to.equal(false)
        end)

        it("never blocks a deliberate manual retarget", function()
            expect(FarmTargetRetention.shouldKeep({
                automatic = false,
                targetType = "Crystals",
                targetId = 42,
                targetHp = 99,
            })).to.equal(false)
        end)

        it("does not classify combat targets as retained mining work", function()
            expect(FarmTargetRetention.shouldKeep({
                automatic = true,
                targetType = "Enemy",
                targetId = 42,
                targetHp = 99,
            })).to.equal(false)
        end)
    end)
end
