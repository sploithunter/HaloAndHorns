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

        it("builds a shuffled no-repeat deck", function()
            local lowOrder = GameplayTipRotation.shuffledIndices(5, function(minimum, _maximum)
                return minimum
            end)
            local highOrder = GameplayTipRotation.shuffledIndices(5, function(_minimum, maximum)
                return maximum
            end)
            expect(table.concat(lowOrder, ",")).to.equal("2,3,4,5,1")
            expect(table.concat(highOrder, ",")).to.equal("1,2,3,4,5")

            local seen = {}
            for _, index in ipairs(lowOrder) do
                expect(seen[index]).to.equal(nil)
                seen[index] = true
            end
            expect(#lowOrder).to.equal(5)
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
            expect(string.find(all, "grass pets are stronger in desert", 1, true) ~= nil).to.equal(
                true
            )
            expect(string.find(all, "hell guards will fight any pet", 1, true) ~= nil).to.equal(
                true
            )
            expect(string.find(all, "hasten cuts the recharge time", 1, true) ~= nil).to.equal(true)
            expect(string.find(all, "levels 8, 15, 22, 29, 36, 43", 1, true) ~= nil).to.equal(true)
            expect(string.find(all, "heaven trial gate", 1, true) ~= nil).to.equal(true)
            expect(string.find(all, "hell trial gate", 1, true) ~= nil).to.equal(true)
            expect(string.find(all, "combat earns xp faster than mining", 1, true) ~= nil).to.equal(
                true
            )
        end)
    end)
end
