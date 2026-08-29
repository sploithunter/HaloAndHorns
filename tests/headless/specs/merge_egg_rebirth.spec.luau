local Rebirth = loadModule("src/Shared/Game/MergeEggRebirth.lua")

return function()
    describe("Merge Egg rebirth policy", function()
        local config = {
            enabled = true,
            currency = "hall_coins",
            costs_by_rank = {
                [2] = 50000,
                [3] = 200000,
            },
            allied_damage_bonus_per_rebirth = 1,
            damage_stacking = "additive",
            requirements = {
                minimum_deployed_egg_tier_by_rank = {},
            },
        }

        it("starts free at Rank 1 and uses only the two explicitly authored transitions", function()
            local first = Rebirth.nextCost(config, 0)
            local second = Rebirth.nextCost(config, 1)
            expect(Rebirth.rankForCount(0)).to.equal(1)
            expect(Rebirth.rankForCount(1)).to.equal(2)
            expect(Rebirth.rankForCount(2)).to.equal(3)
            expect(first.amount).to.equal(50000)
            expect(first.rank).to.equal(2)
            expect(first.currency).to.equal("hall_coins")
            expect(second.amount).to.equal(200000)
            expect(second.rank).to.equal(3)
            expect(Rebirth.nextCost(config, 2)).to.equal(nil)
        end)

        it("adds another base damage unit per rebirth without compounding", function()
            expect(Rebirth.damageMultiplier(config, 0)).to.equal(1)
            expect(Rebirth.damageMultiplier(config, 1)).to.equal(2)
            expect(Rebirth.damageMultiplier(config, 2)).to.equal(3)
        end)

        it("keeps future deployed-egg requirements data driven", function()
            local met, required = Rebirth.requirementMet(config, 0, 0)
            expect(met).to.equal(true)
            expect(required).to.equal(nil)

            local gated = table.clone(config)
            gated.requirements = {
                minimum_deployed_egg_tier_by_rank = {
                    [2] = 8,
                    [3] = 16,
                },
            }
            local blocked, firstRequirement = Rebirth.requirementMet(gated, 0, 7)
            expect(blocked).to.equal(false)
            expect(firstRequirement).to.equal(8)
            expect(Rebirth.requirementMet(gated, 0, 8)).to.equal(true)
            expect(Rebirth.requirementMet(gated, 1, 15)).to.equal(false)
            expect(Rebirth.requirementMet(gated, 1, 16)).to.equal(true)
        end)
    end)
end
