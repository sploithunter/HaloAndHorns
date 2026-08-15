return function()
    describe("menu CoreGui visibility contract", function()
        it("owns PlayerList suppression in MenuManager for every full menu", function()
            local manager = readFile("src/Client/UI/MenuManager.lua")

            expect(manager:find("CoreGuiStateGuard.new(function()", 1, true) ~= nil).to.equal(true)
            expect(manager:find("Enum.CoreGuiType.PlayerList", 1, true) ~= nil).to.equal(true)
            expect(manager:find("if hasPanel then", 1, true) ~= nil).to.equal(true)
            expect(manager:find("self._playerListGuard:Suppress()", 1, true) ~= nil).to.equal(true)
            expect(manager:find("self._playerListGuard:Restore()", 1, true) ~= nil).to.equal(true)
            expect(
                manager:find("overlayGui.ChildAdded:Connect(updateOverlayState)", 1, true) ~= nil
            ).to.equal(true)
            expect(
                manager:find("overlayGui.ChildRemoved:Connect(updateOverlayState)", 1, true) ~= nil
            ).to.equal(true)
        end)

        it("does not let Inventory independently restore over another open menu", function()
            local inventory = readFile("src/Client/UI/Menus/InventoryPanel.lua")

            expect(inventory:find("CoreGuiStateGuard", 1, true)).to.equal(nil)
            expect(inventory:find("CoreGuiType.PlayerList", 1, true)).to.equal(nil)
            expect(inventory:find("_playerListGuard", 1, true)).to.equal(nil)
        end)
    end)
end
