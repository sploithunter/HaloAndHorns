local Rebirth = loadModule("src/Shared/Game/MergeEggRebirth.lua")

return function()
    describe("Merge Egg rebirth policy", function()
        local config = {
            enabled = true,
            currency = "hall_coins",
            max_rank = 50,
            indexed_egg_value_multiplier = 400,
            damage_stacking = "additive",
            per_rebirth_factors = {
                stacking = "additive",
                pets = { power = 2, defense = 2 },
                cannons = { power = 2, radius = 1, cadence = 1 },
                bulwarks = {
                    power = 2,
                    radius = 1,
                    cadence = 1,
                    duration = 1,
                    capacity = 1,
                    control = 1,
                },
                coins = { amount = 2 },
                gems = { amount = 2, chance = 1 },
            },
            requirements = {
                minimum_deployed_egg_tier_by_rank = {},
            },
        }

        it("indexes the proposed rank to its egg value and applies one constant", function()
            local first = Rebirth.nextCost(config, 0, 250)
            local second = Rebirth.nextCost(config, 1, 500)
            expect(Rebirth.rankForCount(0)).to.equal(1)
            expect(Rebirth.rankForCount(1)).to.equal(2)
            expect(Rebirth.rankForCount(2)).to.equal(3)
            expect(first.amount).to.equal(100000)
            expect(first.rank).to.equal(2)
            expect(first.indexedEggTier).to.equal(2)
            expect(first.indexedEggValue).to.equal(250)
            expect(first.eggValueMultiplier).to.equal(400)
            expect(first.currency).to.equal("hall_coins")
            expect(second.amount).to.equal(200000)
            expect(second.rank).to.equal(3)
        end)

        it("quotes Rank 10 from Black Ice without consulting live Spawn Level state", function()
            local price = Rebirth.nextCost(config, 8, 64000)
            expect(price.rank).to.equal(10)
            expect(price.indexedEggTier).to.equal(10)
            expect(price.indexedEggValue).to.equal(64000)
            expect(price.amount).to.equal(25600000)
        end)

        it("stops after the configured maximum rank", function()
            expect(Rebirth.nextCost(config, 48, 1).rank).to.equal(50)
            expect(Rebirth.nextCost(config, 49, 1)).to.equal(nil)
        end)

        it("adds another base damage unit per rebirth without compounding", function()
            expect(Rebirth.damageMultiplier(config, 0)).to.equal(1)
            expect(Rebirth.damageMultiplier(config, 1)).to.equal(2)
            expect(Rebirth.damageMultiplier(config, 2)).to.equal(3)
        end)

        it("scales defenses and currency while keeping radii fixed at one", function()
            for count = 0, 2 do
                local growing = count + 1
                expect(Rebirth.scalingMultiplier(config, count, "cannons", "power")).to.equal(
                    growing
                )
                expect(Rebirth.scalingMultiplier(config, count, "pets", "defense")).to.equal(
                    growing
                )
                expect(Rebirth.scalingMultiplier(config, count, "bulwarks", "power")).to.equal(
                    growing
                )
                expect(Rebirth.scalingMultiplier(config, count, "coins", "amount")).to.equal(
                    growing
                )
                expect(Rebirth.scalingMultiplier(config, count, "gems", "amount")).to.equal(growing)
                expect(Rebirth.scalingMultiplier(config, count, "cannons", "radius")).to.equal(1)
                expect(Rebirth.scalingMultiplier(config, count, "bulwarks", "radius")).to.equal(1)
                expect(Rebirth.scalingMultiplier(config, count, "gems", "chance")).to.equal(1)
            end
        end)

        it("supports multiplicative factors and requires every live axis", function()
            local multiplied = table.clone(config)
            multiplied.per_rebirth_factors = table.clone(config.per_rebirth_factors)
            multiplied.per_rebirth_factors.stacking = "multiplicative"
            expect(Rebirth.scalingMultiplier(multiplied, 2, "bulwarks", "power")).to.equal(4)
            local knownSystemMissingAxis = pcall(function()
                Rebirth.scalingMultiplier(config, 2, "cannons", "unknown")
            end)
            local missingSystem = pcall(function()
                Rebirth.scalingMultiplier(config, 2, "unknown", "power")
            end)
            expect(knownSystemMissingAxis).to.equal(false)
            expect(missingSystem).to.equal(false)
            expect(Rebirth.scalingMultiplier({}, 2, "unknown", "power")).to.equal(1)
        end)

        it("keeps the legacy pet damage field compatible", function()
            local legacy = {
                allied_damage_bonus_per_rebirth = 1,
                damage_stacking = "additive",
            }
            expect(Rebirth.damageMultiplier(legacy, 2)).to.equal(3)
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
