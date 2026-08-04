return function()
    describe("manual hatch cooldown education", function()
        it("pairs only the hatch re-entry error with the Auto Hatch Pets-menu tip", function()
            local source = readFile("src/Shared/Services/EggInteractionService.lua")
            expect(
                source:find(
                    'showAutoHatchTip = errorMessage == "Please wait before hatching again"',
                    1,
                    true
                )
            ).to.be.ok()
            expect(source:find("Hatch Fast with Auto Hatch in the Pets Menu", 1, true)).to.be.ok()
            expect(source:find('tip.Name = "AutoHatchTip"', 1, true)).to.be.ok()
            expect(source:find('root.Name = "Cards"', 1, true)).to.be.ok()
        end)
    end)
end
