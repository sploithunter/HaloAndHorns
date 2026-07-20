local PotionShopLogic = loadModule("src/Shared/Game/PotionShopLogic.lua")
local potions = loadModule("configs/potions.lua")

return function()
    describe("PotionShopLogic", function()
        it("stocks the four current potions at the configured gem prices", function()
            local result = PotionShopLogic.catalog(potions, {
                berserk_brew = 3,
                swift_tonic = 1,
            })

            expect(result.ok).to.equal(true)
            expect(result.currency).to.equal("gems")
            expect(result.buyPrice).to.equal(5)
            expect(result.sellPrice).to.equal(2)
            expect(#result.offers).to.equal(4)
            expect(result.offers[1].id).to.equal("berserk_brew")
            expect(result.offers[1].owned).to.equal(3)
            expect(result.offers[3].id).to.equal("swift_tonic")
            expect(result.offers[3].owned).to.equal(1)
        end)

        it("quotes quantity-safe purchases and refuses insufficient funds", function()
            local quote = PotionShopLogic.buyQuote(potions, "fortune_flask", 50, 10)
            expect(quote.ok).to.equal(true)
            expect(quote.quantity).to.equal(10)
            expect(quote.total).to.equal(50)

            local denied = PotionShopLogic.buyQuote(potions, "fortune_flask", 49, 10)
            expect(denied.ok).to.equal(false)
            expect(denied.reason).to.equal("insufficient_funds")
            expect(denied.needed).to.equal(50)
        end)

        it("quotes exact 1, 10, and 100 unit sales", function()
            local quote = PotionShopLogic.sellQuote(potions, "weakening_vial", 200, 100)
            expect(quote.ok).to.equal(true)
            expect(quote.quantity).to.equal(100)
            expect(quote.total).to.equal(200)

            expect(PotionShopLogic.sellQuote(potions, "weakening_vial", 9, 10).reason).to.equal(
                "insufficient_inventory"
            )
        end)

        it("rejects unknown stock, empty inventory, and unlisted quantities", function()
            expect(PotionShopLogic.buyQuote(potions, "mystery_potion", 999, 1).reason).to.equal(
                "not_sold"
            )
            expect(PotionShopLogic.sellQuote(potions, "swift_tonic", 0, 1).reason).to.equal(
                "none_to_sell"
            )
            expect(PotionShopLogic.buyQuote(potions, "swift_tonic", 999, 50).reason).to.equal(
                "invalid_quantity"
            )
        end)
    end)
end
