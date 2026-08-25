--[[
    PetTargeting — damage/power targeting scope resolution (badge ring + future fan-out SSOT).
    Run: mise run test-headless
]]

local PetTargeting = loadModule("src/Shared/Game/PetTargeting.lua")

local ROLES = {
    roles = {
        ranged = { targeting = "single" },
        tank = { targeting = "single" },
        artillery = { targeting = "targeted_aoe" }, -- hypothetical AoE damage role
    },
    aura_targeting_by_kind = {
        empower = "single",
        hold = "single",
        offense = "aura",
        yield = "aura",
    },
}

return function()
    describe("PetTargeting.attackScope (damage targeting -> role badge ring)", function()
        it("uses the role default", function()
            expect(PetTargeting.attackScope(nil, "ranged", ROLES)).to.equal("single")
            expect(PetTargeting.attackScope(nil, "artillery", ROLES)).to.equal("targeted_aoe")
        end)

        it("per-pet explicit override wins over the role default", function()
            expect(PetTargeting.attackScope("aura", "ranged", ROLES)).to.equal("aura")
        end)

        it("falls back to single for unknown role / missing config", function()
            expect(PetTargeting.attackScope(nil, "mystery", ROLES)).to.equal("single")
            expect(PetTargeting.attackScope(nil, "ranged", nil)).to.equal("single")
        end)
    end)

    describe("PetTargeting Huge and periodic-AoE resolution", function()
        it("gives every Huge an area attack while preserving an authored Huge aura", function()
            expect(PetTargeting.mechanicalAttackScope({}, "ranged", ROLES, { huge = true })).to.equal(
                "targeted_aoe"
            )
            expect(
                PetTargeting.mechanicalAttackScope(
                    { huge_attack_targeting = "aura" },
                    "tank",
                    ROLES,
                    { huge = true }
                )
            ).to.equal("aura")
        end)

        it("advertises a real periodic splash without changing ordinary swing geometry", function()
            local pet = { attack_targeting = "single" }
            expect(PetTargeting.mechanicalAttackScope(pet, "ranged", ROLES)).to.equal("single")
            expect(PetTargeting.displayAttackScope(pet, "ranged", ROLES, { hasAreaProc = true })).to.equal(
                "targeted_aoe"
            )
        end)

        it("recognizes every supported area geometry", function()
            expect(PetTargeting.isArea("single")).to.equal(false)
            expect(PetTargeting.isArea("targeted_aoe")).to.equal(true)
            expect(PetTargeting.isArea("aoe")).to.equal(true)
            expect(PetTargeting.isArea("aura")).to.equal(true)
        end)

        it(
            "gives a base-AoE Huge a contagious burn while a base-single Huge gets no burn",
            function()
                local defaults = {
                    fraction = 0.15,
                    tick = 1,
                    duration = 4,
                    spread = { radius = 8, interval = 1.5, max = 4 },
                }
                expect(PetTargeting.hugeAttackDot({}, "ranged", ROLES, defaults)).to.equal(nil)

                local dot = PetTargeting.hugeAttackDot(
                    { attack_targeting = "targeted_aoe" },
                    "ranged",
                    ROLES,
                    defaults
                )
                expect(dot.fraction).to.equal(0.15)
                expect(dot.duration).to.equal(4)
                expect(dot.spread.radius).to.equal(8)
                expect(dot.spread.max).to.equal(4)
            end
        )

        it("preserves an area pet's authored burn and lets huge_attack_dot tune it", function()
            local dot = PetTargeting.hugeAttackDot({
                attack_targeting = "aura",
                attack_dot = {
                    fraction = 0.22,
                    tick = 0.8,
                    duration = 5,
                    spread = { radius = 9, interval = 2, max = 3 },
                },
                huge_attack_dot = { fraction = 0.3, spread = { max = 6 } },
            }, "tank", ROLES, { spread = { radius = 8, interval = 1.5, max = 4 } })
            expect(dot.fraction).to.equal(0.3)
            expect(dot.tick).to.equal(0.8)
            expect(dot.duration).to.equal(5)
            expect(dot.spread.radius).to.equal(9)
            expect(dot.spread.interval).to.equal(2)
            expect(dot.spread.max).to.equal(6)
        end)
    end)

    describe("PetTargeting.auraScope (power targeting -> ability badge ring)", function()
        it("uses the kind default map", function()
            expect(PetTargeting.auraScope({ kind = "empower" }, ROLES)).to.equal("single")
            expect(PetTargeting.auraScope({ kind = "offense" }, ROLES)).to.equal("aura")
        end)

        it("an aura's own targeting overrides the kind default", function()
            expect(PetTargeting.auraScope({ kind = "offense", targeting = "single" }, ROLES)).to.equal(
                "single"
            )
        end)

        it("falls back to single for unknown kind / non-table", function()
            expect(PetTargeting.auraScope({ kind = "mystery" }, ROLES)).to.equal("single")
            expect(PetTargeting.auraScope(nil, ROLES)).to.equal("single")
        end)
    end)

    describe("PetTargeting.isContagious (orthogonal spread modifier on the burn)", function()
        it("a burn with a spread block is contagious — composes with any geometry", function()
            local burn = { fraction = 0.25, duration = 4, spread = { radius = 8, max = 4 } }
            expect(PetTargeting.isContagious(burn, "single")).to.equal(true)
            expect(PetTargeting.isContagious(burn, "targeted_aoe")).to.equal(true) -- AoE-contagion
        end)

        it("a plain burn (no spread) is not contagious", function()
            expect(PetTargeting.isContagious({ fraction = 0.25, duration = 4 }, "targeted_aoe")).to.equal(
                false
            )
            expect(PetTargeting.isContagious(nil, "single")).to.equal(false)
        end)

        it(
            "back-compat: attack_targeting=='contagion' is contagious even without a spread block",
            function()
                expect(PetTargeting.isContagious(nil, "contagion")).to.equal(true)
                expect(PetTargeting.isContagious({ fraction = 0.25 }, "contagion")).to.equal(true)
            end
        )
    end)
end
