local HatchRevealPolicy = loadModule("src/Shared/Game/HatchRevealPolicy.lua")

return function()
    describe("HatchRevealPolicy", function()
        it("prefers uploaded flat art even when a legacy viewport exists", function()
            expect(HatchRevealPolicy.source("rbxassetid://123", true)).to.equal("rbxassetid://123")
        end)

        it("uses a generated instance only when flat art is absent", function()
            expect(HatchRevealPolicy.source(nil, true)).to.equal("generated_image")
        end)

        it("uses a visible fallback when neither source exists", function()
            expect(HatchRevealPolicy.source(nil, false)).to.equal(HatchRevealPolicy.FALLBACK_IMAGE)
        end)
    end)
end
