local DamageScope = loadModule("src/Shared/Game/MergeEggDamageScope.lua")

return function()
    describe("Merge Egg allied damage scope", function()
        it("adds Gem and rebirth damage on the same base for Full-mode pets", function()
            expect(math.abs(DamageScope.additiveUpgradeMultiplier(1.45, 2) - 2.45) < 0.0001).to.equal(
                true
            )
            local multiplier = DamageScope.playerPetMultiplier({
                inMergeDefense = true,
                mode = "full",
                managementDamageMultiplier = 1.45,
                rebirthDamageMultiplier = 2,
            })
            expect(math.abs(multiplier - 2.45) < 0.0001).to.equal(true)
        end)

        it("never carries the multiplier outside Merge Defense", function()
            expect(DamageScope.playerPetMultiplier({
                inMergeDefense = false,
                mode = "full",
                managementDamageMultiplier = 1.45,
                rebirthDamageMultiplier = 3,
            })).to.equal(1)
        end)

        it("leaves Simple-mode reserve pets on their existing stamped path", function()
            expect(DamageScope.playerPetMultiplier({
                inMergeDefense = true,
                mode = "simple",
                managementDamageMultiplier = 1.45,
                rebirthDamageMultiplier = 3,
            })).to.equal(1)
            expect(DamageScope.playerPetMultiplier({
                inMergeDefense = true,
                mode = "full",
                simpleReserveUnit = true,
                managementDamageMultiplier = 1.45,
                rebirthDamageMultiplier = 3,
            })).to.equal(1)
        end)

        it("does not double-apply the multiplier to hatcher NPC pets", function()
            expect(DamageScope.playerPetMultiplier({
                inMergeDefense = true,
                mode = "full",
                mergeNpcUnit = true,
                managementDamageMultiplier = 1.45,
                rebirthDamageMultiplier = 3,
            })).to.equal(1)
        end)

        it("uses a safe neutral multiplier for malformed state", function()
            expect(DamageScope.playerPetMultiplier()).to.equal(1)
            expect(DamageScope.playerPetMultiplier({
                inMergeDefense = true,
                mode = "full",
                managementDamageMultiplier = "not-a-number",
                rebirthDamageMultiplier = "not-a-number",
            })).to.equal(1)
        end)
    end)
end
