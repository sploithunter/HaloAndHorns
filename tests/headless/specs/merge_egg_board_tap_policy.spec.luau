local Policy = loadModule("src/Client/Systems/MergeEggBoardTapPolicy.lua")

return function()
    describe("Merge Egg board two-tap policy", function()
        local selected = {
            sourceSlot = 2,
            sourceTier = 3,
        }

        it("selects only a real board egg on the first tap", function()
            local result = Policy.resolve(nil, { kind = "board_egg", slot = 2, tier = 3 })
            expect(result.kind).to.equal("select")
            expect(result.selection.sourceSlot).to.equal(2)
            expect(result.selection.sourceTier).to.equal(3)
            expect(result.request).to.equal(nil)

            local empty = Policy.resolve(nil, { kind = "deployment", teamId = 1, deployedTier = 0 })
            expect(empty.kind).to.equal("idle")
            expect(empty.selection).to.equal(nil)
        end)

        it("clears when the selected egg is tapped again", function()
            local result = Policy.resolve(selected, { kind = "board_egg", slot = 2, tier = 3 })
            expect(result.kind).to.equal("clear")
            expect(result.selection).to.equal(nil)
            expect(result.request).to.equal(nil)
        end)

        it("combines two distinct equal-tier board eggs and clears selection", function()
            local result = Policy.resolve(selected, { kind = "board_egg", slot = 7, tier = 3 })
            expect(result.kind).to.equal("action")
            expect(result.selection).to.equal(nil)
            expect(result.request.action).to.equal("merge_slots")
            expect(result.request.sourceSlot).to.equal(2)
            expect(result.request.targetSlot).to.equal(7)
        end)

        it("clears unequal board eggs without sending a request", function()
            local result = Policy.resolve(selected, { kind = "board_egg", slot = 7, tier = 4 })
            expect(result.kind).to.equal("clear")
            expect(result.selection).to.equal(nil)
            expect(result.request).to.equal(nil)
        end)

        it("places the selected egg in an empty hatcher", function()
            local result = Policy.resolve(selected, {
                kind = "deployment",
                teamId = 4,
                deployedTier = 0,
            })
            expect(result.kind).to.equal("action")
            expect(result.selection).to.equal(nil)
            expect(result.request.action).to.equal("deploy_to_hatcher")
            expect(result.request.sourceSlot).to.equal(2)
            expect(result.request.teamId).to.equal(4)
        end)

        it("combines onto a deployed equal-tier egg through the placement action", function()
            local result = Policy.resolve(selected, {
                kind = "deployment",
                teamId = 1,
                deployedTier = 3,
            })
            expect(result.kind).to.equal("action")
            expect(result.selection).to.equal(nil)
            expect(result.request.action).to.equal("deploy_to_hatcher")
            expect(result.request.teamId).to.equal(1)
        end)

        it("clears for a mismatched deployed egg", function()
            local result = Policy.resolve(selected, {
                kind = "deployment",
                teamId = 1,
                deployedTier = 2,
            })
            expect(result.kind).to.equal("clear")
            expect(result.selection).to.equal(nil)
            expect(result.request).to.equal(nil)
        end)

        it("clears for an invalid second tap", function()
            local result = Policy.resolve(selected, { kind = "empty_world" })
            expect(result.kind).to.equal("clear")
            expect(result.selection).to.equal(nil)
            expect(result.request).to.equal(nil)
        end)
    end)
end
