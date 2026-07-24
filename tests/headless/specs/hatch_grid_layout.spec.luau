local HatchGridLayout = loadModule("src/Shared/Game/HatchGridLayout.lua")

local POLICY = {
    padding = 20,
    minEggSize = 100,
    compactMinEggSize = 70,
    compactThreshold = 37,
    maxEggSize = 300,
    safeMargin = 16,
    resultFooterBase = 4,
    resultFooterScale = 0.4,
}

local function expectBounded(count, width, height)
    local grid = HatchGridLayout.resolve(count, width, height, POLICY)
    local positions = HatchGridLayout.positions(count, grid)
    expect(#positions).to.equal(count)
    for _, position in ipairs(positions) do
        expect(position.x >= grid.safeMargin - 0.001).to.equal(true)
        expect(position.y >= grid.safeMargin - 0.001).to.equal(true)
        expect(position.x + position.size <= width - grid.safeMargin + 0.001).to.equal(true)
        expect(position.y + position.size + grid.resultFooter <= height - grid.safeMargin + 0.001).to.equal(
            true
        )
    end
    return grid, positions
end

return function()
    describe("HatchGridLayout viewport bounds", function()
        it("keeps the reported 10-12 hatch composition inside a short Studio viewport", function()
            local ten = expectBounded(10, 1320, 830)
            expect(ten.layout.name).to.equal("4x3")
            expectBounded(12, 1320, 830)
        end)

        it("fits egg frames and result labels on a landscape phone", function()
            local grid = expectBounded(12, 844, 390)
            expect(grid.eggSize < 100).to.equal(true)
        end)

        it("fits the full 99-hatch grid on a compact landscape viewport", function()
            local grid = expectBounded(99, 1024, 576)
            expect(grid.layout.name).to.equal("10x10")
            expect(grid.compactMode).to.equal(true)
        end)

        it("centers a partial final row without escaping horizontally", function()
            local _, positions = expectBounded(10, 844, 390)
            expect(positions[9].isPartialRow).to.equal(true)
            expect(positions[10].isPartialRow).to.equal(true)
            expect(positions[9].x < positions[10].x).to.equal(true)
        end)

        it("reserves proportional footer space for large single reveals", function()
            local grid = expectBounded(1, 1280, 720)
            expect(grid.eggSize).to.equal(300)
            expect(grid.resultFooter).to.equal(124)
        end)
    end)
end
