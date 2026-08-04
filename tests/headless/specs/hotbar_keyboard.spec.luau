local HotbarKeyboard = loadModule("src/Client/Systems/HotbarKeyboard.lua")

return function()
    describe("HotbarKeyboard.resolve", function()
        it("maps plain digits to the bottom row", function()
            expect(HotbarKeyboard.resolve("One", false, false, false, false)).to.equal(1)
            expect(HotbarKeyboard.resolve("Zero", false, false, false, false)).to.equal(10)
        end)

        it("maps Shift+digits to the top row even when CoreGui handled the chord", function()
            expect(HotbarKeyboard.resolve("One", true, true, false, false)).to.equal(11)
            expect(HotbarKeyboard.resolve("Zero", true, true, false, false)).to.equal(20)
        end)

        it("recognizes shifted punctuation key codes from alternate layouts", function()
            expect(HotbarKeyboard.resolve("Exclamation", false, true, false, false)).to.equal(11)
            expect(HotbarKeyboard.resolve("RightParenthesis", false, true, false, false)).to.equal(
                20
            )
        end)

        it("does not steal ordinary processed digits", function()
            expect(HotbarKeyboard.resolve("One", false, true, false, false)).to.equal(nil)
        end)

        it("does not cast while typing or while the Roblox menu is open", function()
            expect(HotbarKeyboard.resolve("One", true, true, true, false)).to.equal(nil)
            expect(HotbarKeyboard.resolve("One", true, true, false, true)).to.equal(nil)
        end)

        it("ignores unrelated keys", function()
            expect(HotbarKeyboard.resolve("Q", true, false, false, false)).to.equal(nil)
        end)
    end)
end
