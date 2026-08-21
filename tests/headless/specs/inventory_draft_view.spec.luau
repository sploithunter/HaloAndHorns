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

        it("normalizes the equipped slot suffix without dropping stack identity", function()
            local cardRef = "stack|bunny:rainbow:luck_copper"
            local deployedRef = "stack|bunny:rainbow:luck_copper|1"
            local counts = View.stackCounts(0, cardRef, { deployedRef }, {})
            expect(counts.deployed).to.equal(1)
            expect(counts.available).to.equal(1)
        end)

        it("does not decrement sibling stacks with different enchants", function()
            local tactics = "stack|radiant_sprite:rainbow:tactics_silver"
            local luck = "stack|radiant_sprite:rainbow:luck_copper"
            local counts = View.stackCounts(2, tactics, {}, { luck })
            expect(counts.drafted).to.equal(0)
            expect(counts.owned).to.equal(2)
            expect(counts.available).to.equal(2)
        end)
    end)

    describe("InventoryPanel open reset", function()
        it("opens the inventory by reseeding the draft from the deployed squad", function()
            local source = readFile("src/Client/UI/Menus/InventoryPanel.lua")
            local showAt = source:find("function InventoryPanel:Show", 1, true)
            local resetAt = source:find("function InventoryPanel:_resetDraftToDeployed", 1, true)
            expect(showAt).to.be.ok()
            expect(resetAt).to.be.ok()
            expect(source:find("self:_resetDraftToDeployed()", showAt, true)).to.be.ok()
            expect(source:find("self:_seedDraftFromEquipped()", resetAt, true)).to.be.ok()
            expect(source:find("self._draftRefs = nil", 1, true)).to.be.ok()
        end)
    end)
end
