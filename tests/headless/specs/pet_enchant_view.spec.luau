local PetEnchantView = loadModule("src/Shared/Game/PetEnchantView.lua")

return function()
    describe("PetEnchantView.records", function()
        local config = {
            stack_enchants = { strength = 3 },
            effects = { luck = { display_name = "Luck" } },
        }

        it("projects a stack enchant into the same record shape used by unique pets", function()
            local records = PetEnchantView.records({ enchant = "luck" }, config)
            expect(#records).to.equal(1)
            expect(records[1].id).to.equal("luck")
            expect(records[1].displayName).to.equal("Luck")
            expect(records[1].strength).to.equal(3)
            expect(records[1].stack).to.equal(true)
        end)

        it("preserves an existing unique-pet enchant list", function()
            local unique = { { id = "tactics", strength = 4 } }
            expect(PetEnchantView.records({ enchantments = unique }, config)).to.equal(unique)
        end)

        it("falls back to the stack enchant when an empty list is present", function()
            local records =
                PetEnchantView.records({ enchant = "efficiency", enchantments = {} }, config)
            expect(#records).to.equal(1)
            expect(records[1].id).to.equal("efficiency")
        end)

        it("returns no display records for an unenchanted pet", function()
            expect(#PetEnchantView.records({}, config)).to.equal(0)
            expect(#PetEnchantView.records(nil, config)).to.equal(0)
        end)
    end)
end
