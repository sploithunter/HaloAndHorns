local RecordMutationBatch = loadModule("src/Shared/Inventory/RecordMutationBatch.lua")

return function()
    describe("RecordMutationBatch", function()
        it("mutates every record but commits the whole squad once", function()
            local mutations = 0
            local commits = 0
            local committedKeys

            local awarded, results = RecordMutationBatch.run(
                { "pet_a", "pet_b", "pet_c" },
                function(uid)
                    mutations += 1
                    return true, { uid = uid, xp = 7 }
                end,
                function(changed)
                    commits += 1
                    committedKeys = changed
                end
            )

            expect(mutations).to.equal(3)
            expect(commits).to.equal(1)
            expect(awarded).to.equal(3)
            expect(#committedKeys).to.equal(3)
            expect(results.pet_b.xp).to.equal(7)
        end)

        it("does not project or save when no record changed", function()
            local commits = 0
            local awarded = RecordMutationBatch.run({ "not_levelable" }, function()
                return false, "not_levelable"
            end, function()
                commits += 1
            end)

            expect(awarded).to.equal(0)
            expect(commits).to.equal(0)
        end)

        it("keeps separate player batches and award amounts independent", function()
            local commits = 0
            local function awardSquad(playerAmount)
                local balances = {}
                RecordMutationBatch.run({ "pet_a", "pet_b" }, function(uid)
                    balances[uid] = playerAmount
                    return true, playerAmount
                end, function()
                    commits += 1
                end)
                return balances
            end

            local firstMiner = awardSquad(5)
            local secondMiner = awardSquad(13)

            expect(firstMiner.pet_a).to.equal(5)
            expect(firstMiner.pet_b).to.equal(5)
            expect(secondMiner.pet_a).to.equal(13)
            expect(secondMiner.pet_b).to.equal(13)
            expect(commits).to.equal(2)
        end)
    end)
end
