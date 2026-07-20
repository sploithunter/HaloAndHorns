local PetThumbnailFetchPolicy = loadModule("src/Shared/UI/PetThumbnailFetchPolicy.lua")

return function()
    describe("PetThumbnailFetchPolicy", function()
        it("uses only the flat image after delivery succeeds", function()
            expect(PetThumbnailFetchPolicy.action("Success")).to.equal("flat")
        end)

        it("constructs 3D only after delivery failure or timeout", function()
            expect(PetThumbnailFetchPolicy.action("Failure")).to.equal("lazy_3d")
            expect(PetThumbnailFetchPolicy.action("TimedOut")).to.equal("lazy_3d")
        end)

        it("keeps nonterminal delivery states viewport-free", function()
            expect(PetThumbnailFetchPolicy.action("None")).to.equal("pending")
            expect(PetThumbnailFetchPolicy.action("Loading")).to.equal("pending")
        end)

        it("bakes cached viewports only for variants missing flat art", function()
            expect(PetThumbnailFetchPolicy.needsCachedBake(true)).to.equal(false)
            expect(PetThumbnailFetchPolicy.needsCachedBake(false)).to.equal(true)
        end)
    end)
end
