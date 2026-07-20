local PetThumbnailFetchPolicy = loadModule("src/Shared/UI/PetThumbnailFetchPolicy.lua")

return function()
    describe("PetThumbnailFetchPolicy", function()
        it("retires the viewport only after flat-image success", function()
            expect(PetThumbnailFetchPolicy.action("Success", true, true)).to.equal("flat")
        end)

        it("keeps the baked viewport on delivery failure or timeout", function()
            expect(PetThumbnailFetchPolicy.action("Failure", true, true)).to.equal("viewport")
            expect(PetThumbnailFetchPolicy.action("TimedOut", true, true)).to.equal("viewport")
        end)

        it("waits for a deferred bake before using the emergency icon", function()
            expect(PetThumbnailFetchPolicy.action("Failure", false, false)).to.equal(
                "wait_for_bake"
            )
            expect(PetThumbnailFetchPolicy.action("Failure", false, true)).to.equal("emergency")
        end)

        it("leaves nonterminal delivery states pending", function()
            expect(PetThumbnailFetchPolicy.action("None", true, true)).to.equal("pending")
            expect(PetThumbnailFetchPolicy.action("Loading", true, true)).to.equal("pending")
        end)
    end)
end
