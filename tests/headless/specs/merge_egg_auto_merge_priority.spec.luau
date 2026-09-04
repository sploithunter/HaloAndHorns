local Priority = loadModule("src/Shared/Game/MergeEggAutoMergePriority.lua")

return function()
    describe("Merge Egg Auto Merge priority", function()
        it("always feeds the frontline before combining an available board pair", function()
            local action = Priority.nextAction({
                linePlan = { { teamId = 3, sourceTier = 2 } },
                inventory = { [1] = 8, [2] = 1 },
                maximumTier = 8,
                mergeRatio = 2,
            })

            expect(action.kind).to.equal("line")
            expect(action.teamId).to.equal(3)
            expect(action.sourceTier).to.equal(2)
        end)

        it("combines only the lowest available board tier when the line cannot advance", function()
            local action = Priority.nextAction({
                linePlan = {},
                inventory = { [1] = 1, [2] = 4, [3] = 2 },
                maximumTier = 8,
                mergeRatio = 2,
            })

            expect(action.kind).to.equal("board")
            expect(action.sourceTier).to.equal(2)
        end)

        it("stops when neither the line nor the board can move", function()
            expect(Priority.nextAction({
                linePlan = {},
                inventory = { [1] = 1, [2] = 1 },
                maximumTier = 8,
                mergeRatio = 2,
            })).never.to.be.ok()
        end)
    end)
end
