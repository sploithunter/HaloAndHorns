local PermanentEnchantSlots = loadModule("src/Shared/Game/PermanentEnchantSlots.lua")

return function()
    describe("PermanentEnchantSlots.missing", function()
        it("returns only the newly unlocked empty slot", function()
            local enchants = {
                { id = "luck", strength = 2 },
            }
            local missing = PermanentEnchantSlots.missing(enchants, 2)
            expect(#missing).to.equal(1)
            expect(missing[1]).to.equal(2)
            expect(enchants[1].id).to.equal("luck")
        end)

        it("repairs a hole without replacing later valid enchants", function()
            local enchants = {
                [1] = { id = "luck", strength = 2 },
                [3] = { id = "scholar", strength = 4 },
            }
            local missing = PermanentEnchantSlots.missing(enchants, 3)
            expect(#missing).to.equal(1)
            expect(missing[1]).to.equal(2)
            expect(enchants[1].id).to.equal("luck")
            expect(enchants[3].id).to.equal("scholar")
        end)

        it("does not touch locked future slots", function()
            local enchants = {
                [2] = { id = "luck", strength = 2 },
            }
            local missing = PermanentEnchantSlots.missing(enchants, 1)
            expect(#missing).to.equal(1)
            expect(missing[1]).to.equal(1)
            expect(enchants[2].id).to.equal("luck")
        end)
    end)
end
