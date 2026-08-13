local HudLayout = loadModule("src/Shared/Game/HudLayout.lua")

return function()
    describe("HudLayout", function()
        it("defaults unknown preferences to auto", function()
            expect(HudLayout.normalize(nil)).to.equal("auto")
            expect(HudLayout.normalize("wide")).to.equal("auto")
        end)

        it("uses compact automatically on touch phones and tablets", function()
            expect(HudLayout.resolve("auto", 844, 390, true, false)).to.equal("compact")
            expect(HudLayout.resolve("auto", 2048, 946, true, true)).to.equal("compact")
        end)

        it("keeps desktop classic in auto", function()
            expect(HudLayout.resolve("auto", 1920, 1080, false, true)).to.equal("classic")
            expect(HudLayout.resolve("auto", 1920, 1080, true, true)).to.equal("classic")
        end)

        it("honors explicit overrides", function()
            expect(HudLayout.resolve("classic", 844, 390, true, false)).to.equal("classic")
            expect(HudLayout.resolve("compact", 1920, 1080, false, true)).to.equal("compact")
        end)
    end)
end
