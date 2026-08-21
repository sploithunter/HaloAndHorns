local Scoring = loadModule("src/Shared/Game/LeaderboardScoring.lua")

return function()
    local data

    describe("LeaderboardScoring", function()
        beforeEach(function()
            data = {
                Stats = { Counters = { breakables_broken = 42, enemies_defeated = 9 } },
                Inventory = {
                    pets = {
                        items = {
                            dragon_stack = { id = "dragon", variant = "basic", quantity = 3 },
                            wyrm = { id = "abyssal_wyrm", variant = "rainbow", power = 100 },
                            bunny_stack = { id = "bunny", variant = "basic", quantity = 8 },
                        },
                    },
                },
            }
        end)

        it("counts configured taxonomy members including stack quantities", function()
            expect(Scoring.countTaxonomy(data, { "dragon", "abyssal_wyrm" })).to.equal(4)
        end)

        it("reads lifetime counters without mutating them", function()
            expect(Scoring.counter(data, "breakables_broken")).to.equal(42)
            expect(Scoring.counter(data, "missing")).to.equal(0)
        end)

        it("sums only the strongest legal squad", function()
            local powerById = { dragon = 10, abyssal_wyrm = 100, bunny = 2 }
            local score = Scoring.strongestLegalSquad(data, 4, function(record)
                return powerById[record.id]
            end)
            expect(score).to.equal(130)
        end)

        it(
            "hides internal accounts from display without dropping them from the list when hide is off",
            function()
                local rows = {
                    { userId = 1, value = 40 },
                    { userId = 873359641, value = 39 },
                    { userId = 2, value = 12 },
                }
                local hidden = { [873359641] = true }
                expect(#Scoring.visibleEntries(rows, hidden, false)).to.equal(3)
                local shown = Scoring.visibleEntries(rows, hidden, true)
                expect(#shown).to.equal(2)
                expect(shown[1].userId).to.equal(1)
                expect(shown[2].userId).to.equal(2)
            end
        )

        it("pays the same unexcluded top 10 that the board shows", function()
            local rows = {
                { userId = 873359641, value = 99 },
                { userId = 11, value = 40 },
                { userId = 12, value = 30 },
            }
            local hidden = { [873359641] = true }
            local testing = Scoring.rewardRoster(rows, hidden, false, 10)
            expect(testing[1].userId).to.equal(873359641)
            expect(testing[1].rank).to.equal(1)

            local live = Scoring.rewardRoster(rows, hidden, true, 10)
            expect(#live).to.equal(2)
            expect(live[1].userId).to.equal(11)
            expect(live[1].rank).to.equal(1)
            expect(live[2].userId).to.equal(12)
            expect(live[2].rank).to.equal(2)
            local displayed = Scoring.publicTop(rows, hidden, true, 10)
            expect(displayed[1].userId).to.equal(live[1].userId)
            expect(displayed[2].userId).to.equal(live[2].userId)
        end)

        it("can decrease after ownership changes because it is a replacement score", function()
            local powerById = { dragon = 10, abyssal_wyrm = 100, bunny = 2 }
            data.Inventory.pets.items.wyrm = nil
            local score = Scoring.strongestLegalSquad(data, 4, function(record)
                return powerById[record.id]
            end)
            expect(score).to.equal(32)
        end)
    end)
end
