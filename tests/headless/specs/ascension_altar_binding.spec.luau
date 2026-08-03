return function()
    describe("authored Home ascension altar binding", function()
        it("moves functionality off the buried altar and onto the replacement host", function()
            local source = readFile("scripts/studio/wire_home_ascension_altar.luau")
            expect(source:find('OLD_NAME = "AscensionAltar_old"', 1, true) ~= nil).to.equal(true)
            expect(source:find("CollectionService:AddTag(targetHost, ALTAR_TAG)", 1, true) ~= nil).to.equal(
                true
            )
            expect(source:find("CollectionService:RemoveTag(oldHost, ALTAR_TAG)", 1, true) ~= nil).to.equal(
                true
            )
        end)

        it("transfers the old NativeFX using the two hosts as the coordinate contract", function()
            local source = readFile("scripts/studio/wire_home_ascension_altar.luau")
            expect(source:find("targetFX = oldFX:Clone()", 1, true) ~= nil).to.equal(true)
            expect(source:find("targetHost.CFrame * oldHost.CFrame:Inverse()", 1, true) ~= nil).to.equal(
                true
            )
            expect(
                source:find("descendant.CFrame = hostTransform * descendant.CFrame", 1, true) ~= nil
            ).to.equal(true)
        end)
    end)
end
