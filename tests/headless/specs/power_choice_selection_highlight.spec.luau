return function()
    describe("power choice staged-selection highlight", function()
        it("keeps the committed candidate visibly outlined after mobile scaling", function()
            local source = readFile("src/Client/UI/Menus/PowerChoiceMenu.lua")

            expect(source:find("local STAGED_GLOW_THICKNESS = 6", 1, true)).to.be.ok()
            expect(
                source:find("glow.Thickness = hasStaged and STAGED_GLOW_THICKNESS or 2", 1, true)
            ).to.be.ok()
            expect(source:find("glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border", 1, true)).to.be.ok()
        end)
    end)
end
