-- Mission tile templates generated from source must win over any runtime cache
-- accidentally captured in Models.rbxm, and stamping must pivot from TileRoot.

return function()
    describe("mission tile runtime contract", function()
        it("rebuilds code-defined kits instead of trusting captured MissionTiles", function()
            local source = readFile("src/Server/Services/MissionInstanceService.lua")

            expect(source:find("local captured = store:FindFirstChild(kitId)", 1, true) ~= nil).to.equal(
                true
            )
            expect(source:find("captured:Destroy()", 1, true) ~= nil).to.equal(true)
            expect(source:find("folder = TileKitBuilder.build(kit, store)", 1, true) ~= nil).to.equal(
                true
            )
            expect(
                source:find(
                    "store:FindFirstChild(kitId) or TileKitBuilder.build(kit, store)",
                    1,
                    true
                ) == nil
            ).to.equal(true)
        end)

        it("reasserts TileRoot as PrimaryPart before PivotTo", function()
            local source = readFile("src/Server/World/MissionStamper.lua")
            local rootLookup =
                source:find('local tileRoot = clone:FindFirstChild("TileRoot")', 1, true)
            local primaryPart = source:find("clone.PrimaryPart = tileRoot", 1, true)
            local pivotTo = source:find("clone:PivotTo(", 1, true)

            expect(rootLookup ~= nil).to.equal(true)
            expect(primaryPart ~= nil).to.equal(true)
            expect(pivotTo ~= nil).to.equal(true)
            expect(rootLookup < primaryPart).to.equal(true)
            expect(primaryPart < pivotTo).to.equal(true)
        end)
    end)
end
