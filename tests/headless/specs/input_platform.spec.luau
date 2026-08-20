local InputPlatform = loadModule("src/Shared/Game/InputPlatform.lua")

return function()
    describe("InputPlatform", function()
        it("keeps input and display classification independent", function()
            expect(InputPlatform.inputMode("Enum.PreferredInput.Gamepad", {})).to.equal("gamepad")
            expect(InputPlatform.displayClass(false, 844, 390, { touch = true })).to.equal("phone")
            expect(InputPlatform.displayClass(false, 1080, 810, { touch = true })).to.equal(
                "tablet"
            )
            expect(InputPlatform.displayClass(false, 1920, 1080, { keyboard = true })).to.equal(
                "desktop"
            )
            expect(InputPlatform.displayClass(true, 1920, 1080, {})).to.equal("ten_foot")
            expect(InputPlatform.isCompactDisplay("phone")).to.equal(true)
            expect(InputPlatform.isCompactDisplay("tablet")).to.equal(true)
            expect(InputPlatform.isCompactDisplay("desktop")).to.equal(false)
        end)

        it("classifies Studio device emulators that omit TouchEnabled", function()
            -- iPhone 17 Pro landscape 874×402, iPad 9th gen 1080×810.
            expect(InputPlatform.displayClass(false, 874, 402, { keyboard = true })).to.equal(
                "phone"
            )
            expect(InputPlatform.displayClass(false, 1080, 810, { keyboard = true })).to.equal(
                "tablet"
            )
            expect(InputPlatform.displayClass(false, 1280, 720, { keyboard = true })).to.equal(
                "desktop"
            )
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
