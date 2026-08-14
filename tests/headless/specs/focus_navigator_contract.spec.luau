return function()
    describe("FocusNavigator selection adornment contract", function()
        it("assigns the custom selection image through GuiObject", function()
            local source = readFile("src/Client/UI/FocusNavigator.lua")

            expect(source:find("GuiService.SelectionImageObject", 1, true)).to.equal(nil)
            expect(source:find("item.SelectionImageObject = selectionImage", 1, true)).to.be.ok()
        end)
    end)
end
