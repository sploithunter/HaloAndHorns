--[[
    Inventory draft stack counts — [unit].

    Replicated stack Quantity is UNEQUIPPED availability. These tests pin the
    reconciliation between that projection, the live squad, and the local draft.
]]

local View = loadModule("src/Client/UI/Menus/InventoryDraftView.lua")

return function()
    describe("InventoryDraftView.stackCounts", function()
        it("prefers a live projected zero over a stale cached one", function()
            expect(View.unequippedCount(1, 0)).to.equal(0)
            expect(View.unequippedCount(1, nil)).to.equal(1)
        end)

        it("returns a fully deployed one-pet stack to the grid when removed from draft", function()
            local ref = "stack|bunny:basic"
            local counts = View.stackCounts(0, ref, { ref }, {})
            expect(counts.owned).to.equal(1)
            expect(counts.available).to.equal(1)
        end)

        it("hides a fully deployed one-pet stack while it remains drafted", function()
            local ref = "stack|bunny:basic"
            local counts = View.stackCounts(0, ref, { ref }, { ref })
            expect(counts.owned).to.equal(1)
            expect(counts.available).to.equal(0)
        end)

        it("does not subtract the deployed draft twice from unequipped availability", function()
            local ref = "stack|bear:golden"
            local counts = View.stackCounts(2, ref, { ref }, { ref })
            expect(counts.owned).to.equal(3)
            expect(counts.available).to.equal(2)
        end)

        it("tracks local additions and removals against the same owned total", function()
            local ref = "stack|bear:golden"
            local added = View.stackCounts(2, ref, { ref }, { ref, ref })
            local removed = View.stackCounts(2, ref, { ref }, {})
            expect(added.available).to.equal(1)
            expect(removed.available).to.equal(3)
        end)

        it("matches an equipped stack when only its area suffix drifted", function()
            local cardRef = "stack|bunny:rainbow:grass"
            local deployedRef = "stack|bunny:rainbow:spawn|1"
            local counts = View.stackCounts(0, cardRef, { deployedRef }, {})
            expect(counts.deployed).to.equal(1)
            expect(counts.available).to.equal(1)
        end)
    end)
end
