local GameplayTipRotation = loadModule("src/Shared/Game/GameplayTipRotation.lua")
local config = loadModule("configs/gameplay_tips.lua")

return function()
    describe("gameplay tip rotation", function()
        it("wraps through every configured tip", function()
            expect(GameplayTipRotation.nextIndex(0, 3)).to.equal(1)
            expect(GameplayTipRotation.nextIndex(1, 3)).to.equal(2)
            expect(GameplayTipRotation.nextIndex(3, 3)).to.equal(1)
            expect(GameplayTipRotation.nextIndex(9, 0)).to.equal(nil)
        end)

        it("ships a large compact learning library", function()
            local ok, err = GameplayTipRotation.validate(config)
            if not ok then
                error(err)
            end
            expect(#config.tips >= 60).to.equal(true)
            expect(config.interval_seconds).to.equal(60)
            expect(config.display_seconds).to.equal(10)
        end)

        it("covers the requested hidden mechanics", function()
            local all = string.lower(table.concat(config.tips, "\n"))
            expect(string.find(all, "berserk brew", 1, true) ~= nil).to.equal(true)
            expect(string.find(all, "combat and mining", 1, true) ~= nil).to.equal(true)
            expect(string.find(all, "single-origin", 1, true) ~= nil).to.equal(true)
            expect(string.find(all, "dual-origin", 1, true) ~= nil).to.equal(true)
            expect(string.find(all, "lumen dove", 1, true) ~= nil).to.equal(true)
            expect(string.find(all, "focus enhancements", 1, true) ~= nil).to.equal(true)
        end)
    end)
end
