--[[
    CurrencyKeys — canonical (lowercase) currency-key normalization, dedup by max.
    Run: mise run test-headless
]]

local CurrencyKeys = loadModule("src/Shared/Game/CurrencyKeys.lua")

return function()
    describe("CurrencyKeys.normalize", function()
        it("merges a case-variant duplicate by max (real balance wins)", function()
            local out = CurrencyKeys.normalize({ Gems = 80, gems = 820, coins = 50 })
            expect(out.gems).to.equal(820)
            expect(out.Gems).to.equal(nil)
            expect(out.coins).to.equal(50)
        end)

        it("keeps the larger when the legacy key is bigger", function()
            local out = CurrencyKeys.normalize({ Gems = 5000, gems = 0 })
            expect(out.gems).to.equal(5000)
        end)

        it("passes an already-canonical map through unchanged", function()
            local out = CurrencyKeys.normalize({ gems = 10, grass_coins = 99 })
            expect(out.gems).to.equal(10)
            expect(out.grass_coins).to.equal(99)
        end)

        it("returns an empty table for nil / non-table input", function()
            expect(next(CurrencyKeys.normalize(nil))).to.equal(nil)
            expect(next(CurrencyKeys.normalize(42))).to.equal(nil)
        end)

        it("coerces a non-number value to 0", function()
            local out = CurrencyKeys.normalize({ gems = "nope" })
            expect(out.gems).to.equal(0)
        end)
    end)
end
