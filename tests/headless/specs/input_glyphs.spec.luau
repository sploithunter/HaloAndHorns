local InputGlyphs = loadModule("src/Shared/Game/InputGlyphs.lua")

return function()
    describe("InputGlyphs", function()
        it("uses semantic controller labels", function()
            expect(InputGlyphs.get("gamepad", "interact")).to.equal("X")
            expect(InputGlyphs.get("gamepad", "cast")).to.equal("RT")
            expect(InputGlyphs.get("gamepad", "pets")).to.equal("D-pad Left")
        end)

        it("keeps keyboard copy available", function()
            expect(InputGlyphs.get("mouse_keyboard", "interact")).to.equal("E")
        end)
    end)
end
