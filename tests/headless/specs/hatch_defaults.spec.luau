local eggSystem = loadModule("configs/egg_system.lua")

return function()
    describe("new-player hatch defaults", function()
        it("uses max hatch without automatically selecting auto hatch", function()
            local panel = eggSystem.ui.hatch_panel

            expect(panel.default_action_mode).to.equal("max")
            expect(panel.default_action_mode == "auto").to.equal(false)
        end)
    end)
end
