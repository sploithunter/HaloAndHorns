local Assignment = loadModule("src/Shared/Game/MergeEggDefenseAssignment.lua")

return function()
    describe("MergeEggDefenseAssignment", function()
        it("keeps at most one reserve while attack groups are below team capacity", function()
            expect(Assignment.reserveCount(4, 1, false, 1)).to.equal(1)
            expect(Assignment.reserveCount(4, 3, false, 1)).to.equal(1)
            expect(Assignment.reserveCount(4, 4, false, 1)).to.equal(0)
        end)

        it("commits every team after a Bulwark release", function()
            expect(Assignment.reserveCount(4, 1, true, 1)).to.equal(0)
            expect(Assignment.reserveCount(1, 0, false, 1)).to.equal(0)
        end)

        it("picks boss then lieutenant then tank before ordinary targets", function()
            local hardest = Assignment.pickHardest({
                { id = "tank", rank = "tank", maxHealth = 5000, currentHealth = 5000 },
                { id = "boss", rank = "boss", maxHealth = 3000, currentHealth = 1000 },
                { id = "lieutenant", rank = "lieutenant", maxHealth = 7000 },
            })
            expect(hardest.id).to.equal("boss")
        end)

        it("uses durability and a stable spawn order within one rank", function()
            local durable = Assignment.pickHardest({
                { id = "later", rank = "boss", maxHealth = 1000, spawnIndex = 2 },
                { id = "harder", rank = "boss", maxHealth = 2000, spawnIndex = 3 },
                { id = "first", rank = "boss", maxHealth = 1000, spawnIndex = 1 },
            })
            expect(durable.id).to.equal("harder")

            local stable = Assignment.pickHardest({
                { id = "later", rank = "trash", maxHealth = 100, spawnIndex = 2 },
                { id = "first", rank = "trash", maxHealth = 100, spawnIndex = 1 },
            })
            expect(stable.id).to.equal("first")
        end)
    end)
end
