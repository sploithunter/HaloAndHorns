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
