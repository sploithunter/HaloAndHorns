return function()
    describe("HideTogglesInBattle", function()
        it("persists a default-on client opt-out and exposes it in Settings", function()
            local client = readFile("src/Client/Systems/HideTogglesInBattle.lua")
            local badges = readFile("src/Client/Systems/PlayerPowerBadges.lua")
            local gameApi = readFile("src/Server/Services/GameAPIService.lua")
            local settingsPanel = readFile("src/Client/UI/Menus/SettingsPanel.lua")

            expect(string.find(client, "result.hideTogglesInBattle ~= false", 1, true) ~= nil).to.equal(
                true
            )
            expect(
                string.find(
                    client,
                    'callBus("settings.set", { hideTogglesInBattle = enabled })',
                    1,
                    true
                ) ~= nil
            ).to.equal(true)
            expect(string.find(gameApi, "prefs.hideTogglesInBattle ~= false", 1, true) ~= nil).to.equal(
                true
            )
            expect(
                string.find(gameApi, "data.Settings.ClientPrefs.hideTogglesInBattle", 1, true)
                    ~= nil
            ).to.equal(true)
            expect(string.find(settingsPanel, '"Hide Toggles in Battle"', 1, true) ~= nil).to.equal(
                true
            )
            expect(
                string.find(settingsPanel, "HideTogglesInBattle.setEnabled(value)", 1, true) ~= nil
            ).to.equal(true)
            expect(string.find(badges, "HideTogglesInBattle", 1, true) ~= nil).to.equal(true)
            expect(string.find(badges, "EnemyHudActive", 1, true) ~= nil).to.equal(true)
        end)
    end)
end
