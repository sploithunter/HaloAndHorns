local InputPlatform = loadModule("src/Shared/Game/InputPlatform.lua")

return function()
    describe("InputPlatform", function()
        it("keeps input and display classification independent", function()
            expect(InputPlatform.inputMode("Enum.PreferredInput.Gamepad", {})).to.equal("gamepad")
            expect(InputPlatform.displayClass(false, 844, 390, { touch = true })).to.equal(
                "compact"
            )
            expect(InputPlatform.displayClass(true, 1920, 1080, {})).to.equal("ten_foot")
        end)

        it("falls back to device capabilities", function()
            expect(InputPlatform.inputMode(nil, { gamepad = true })).to.equal("gamepad")
            expect(InputPlatform.inputMode(nil, { touch = true, keyboard = false })).to.equal(
                "touch"
            )
            expect(InputPlatform.inputMode(nil, {})).to.equal("mouse_keyboard")
        end)

        it("ships console runtime support behind a disabled feature gate", function()
            local gameConfig = loadModule("configs/game.lua")
            local client = readFile("src/Client/init.client.lua")
            local context = readFile("src/Client/Systems/InputContext.lua")

            expect(gameConfig.features.console_support).to.equal(false)
            expect(client:find('IsFeatureEnabled("console_support", false)', 1, true)).to.be.ok()
            expect(context:find('SetAttribute("ConsoleSupportEnabled"', 1, true)).to.be.ok()
        end)
    end)
end
