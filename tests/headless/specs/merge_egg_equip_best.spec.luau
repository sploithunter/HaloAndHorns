local MergeEggEquipBest = loadModule("src/Shared/Game/MergeEggEquipBest.lua")

return function()
    describe("Merge Egg Equip Best", function()
        it("does not advertise low-tier board eggs against higher deployed hatchers", function()
            local plan = MergeEggEquipBest.plan({
                maximumTier = 4,
                inventory = { [1] = 3, [2] = 1 },
                teams = {
                    { id = 1, tier = 4 },
                    { id = 2, tier = 4 },
                    { id = 3, tier = 3 },
                    { id = 4, tier = 3 },
                },
            })

            expect(#plan).to.equal(0)
        end)

        it("fills empty hatchers with strongest eggs before matching upgrades", function()
            local plan = MergeEggEquipBest.plan({
                maximumTier = 4,
                inventory = { [1] = 1, [2] = 1, [3] = 1 },
                teams = {
                    { id = 1, tier = 0 },
                    { id = 2, tier = 1 },
                    { id = 3, tier = 2 },
                },
            })

            expect(#plan).to.equal(3)
            expect(plan[1].teamId).to.equal(1)
            expect(plan[1].sourceTier).to.equal(3)
            expect(plan[2].teamId).to.equal(2)
            expect(plan[2].sourceTier).to.equal(1)
            expect(plan[3].teamId).to.equal(3)
            expect(plan[3].sourceTier).to.equal(2)
        end)

        it("skips unavailable hatchers and never advances one twice", function()
            local plan = MergeEggEquipBest.plan({
                maximumTier = 4,
                inventory = { [1] = 3 },
                teams = {
                    { id = 1, tier = 0 },
                    { id = 2, tier = 1, available = false },
                },
            })

            expect(#plan).to.equal(1)
            expect(plan[1].teamId).to.equal(1)
        end)
    end)
end
