-- CombatHitFX.resolveKind — the ONE rule both pets and enemies use to pick a swing's projectile.
local CombatHitFX = loadModule("src/Shared/Effects/CombatHitFX.lua")

return function()
    describe("CombatHitFX.resolveKind", function()
        it("is melee when not ranged (impact at the target)", function()
            expect(CombatHitFX.resolveKind({ ranged = false, kind = "plasma" })).to.equal("melee")
        end)

        it("uses an explicit kind for a ranged swing (enemy bolt_kind)", function()
            expect(CombatHitFX.resolveKind({ ranged = true, kind = "poison" })).to.equal("poison")
        end)

        it("falls back to the by_type override (pet PetType) when no explicit kind", function()
            local kind = CombatHitFX.resolveKind({
                ranged = true,
                byType = "crow",
                byTypeMap = { crow = "frost" },
                element = "grass",
                elementKind = { grass = "lightning" },
            })
            expect(kind).to.equal("frost")
        end)

        it("falls back to the element map when no kind / by_type", function()
            local kind = CombatHitFX.resolveKind({
                ranged = true,
                element = "lava",
                elementKind = { lava = "fireball" },
            })
            expect(kind).to.equal("fireball")
        end)

        it("falls back to the config default last", function()
            expect(CombatHitFX.resolveKind({ ranged = true, defaultKind = "plasma" })).to.equal(
                "plasma"
            )
            expect(CombatHitFX.resolveKind({ ranged = true })).to.equal("lightning")
        end)

        it("treats an empty-string kind as unset (falls through)", function()
            local kind = CombatHitFX.resolveKind({
                ranged = true,
                kind = "",
                defaultKind = "plasma",
            })
            expect(kind).to.equal("plasma")
        end)
    end)
end
