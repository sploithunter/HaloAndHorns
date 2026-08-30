local VirtualGridWindow = loadModule("src/Shared/UI/VirtualGridWindow.lua")

return function()
    describe("VirtualGridWindow", function()
        it("fits as many whole cards as the width permits", function()
            expect(VirtualGridWindow.columns(320, 100, 10)).to.equal(3)
            expect(VirtualGridWindow.columns(99, 100, 10)).to.equal(1)
        end)

        it("keeps the full logical height without allocating every card", function()
            expect(VirtualGridWindow.contentHeight(10, 3, 100, 10)).to.equal(430)
            expect(VirtualGridWindow.contentHeight(0, 3, 100, 10)).to.equal(0)
        end)

        it("returns only visible rows plus overscan", function()
            local range = VirtualGridWindow.visibleRange(1000, 4, 100, 10, 550, 220, 1)
            expect(range.first).to.equal(17)
            expect(range.last).to.equal(32)
        end)

        it("returns no cards when the grid is outside the viewport", function()
            expect(VirtualGridWindow.visibleRange(20, 4, 100, 10, -500, 100, 1)).to.equal(nil)
            expect(VirtualGridWindow.visibleRange(20, 4, 100, 10, 1000, 100, 1)).to.equal(nil)
        end)

        it("maps logical indexes to stable card positions", function()
            local x, y = VirtualGridWindow.position(6, 4, 100, 80, 10, 5)
            expect(x).to.equal(110)
            expect(y).to.equal(85)
        end)
    end)
end
