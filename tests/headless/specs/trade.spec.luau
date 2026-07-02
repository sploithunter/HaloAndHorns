--[[
    Feature 19: Trading — [unit] / [integration] scenarios.
    Run: mise run test-headless
]]

local TradeLogic = loadModule("src/Shared/Game/TradeLogic.lua")
local config = loadModule("configs/trade.lua")

return function()
    describe("TradeLogic.canAddItem", function()
        it("allows offering an unlocked pet", function()
            local r = TradeLogic.canAddItem("pets", { id = "bear", locked = false }, config)
            expect(r.ok).to.equal(true)
        end)

        it("rejects a locked pet", function()
            local r = TradeLogic.canAddItem("pets", { id = "bear", locked = true }, config)
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("pet_locked")
        end)

        it("rejects soulbound biome coins (e.g. lava_coins)", function()
            local r = TradeLogic.canAddItem("currencies", { id = "lava_coins" }, config)
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("currencies_not_tradeable")
        end)

        it("allows gems (the only tradeable currency)", function()
            local r = TradeLogic.canAddItem("currencies", { id = "gems" }, config)
            expect(r.ok).to.equal(true)
        end)

        it("rejects a biome coin even when gems are allowlisted", function()
            local r = TradeLogic.canAddItem("currencies", { id = "grass_coins" }, config)
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("currencies_not_tradeable")
        end)

        it("allows cosmetics", function()
            local r = TradeLogic.canAddItem("cosmetics", { id = "halo_skin" }, config)
            expect(r.ok).to.equal(true)
        end)

        it("allows enhancements (all are tradeable)", function()
            local r = TradeLogic.canAddItem("enhancements", { id = "enh_anvil_fire_L1" }, config)
            expect(r.ok).to.equal(true)
        end)
    end)

    describe("TradeLogic.canExecute (both-confirm gate)", function()
        it("rejects when only one side confirmed", function()
            local r = TradeLogic.canExecute(
                { items = {}, confirmed = true },
                { items = {}, confirmed = false }
            )
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("not_both_confirmed")
        end)

        it("executes when both sides confirmed", function()
            local r = TradeLogic.canExecute(
                { items = {}, confirmed = true },
                { items = {}, confirmed = true }
            )
            expect(r.ok).to.equal(true)
        end)
    end)

    describe("TradeLogic.auditRecord", function()
        it("captures both players, their items and a timestamp", function()
            local rec = TradeLogic.auditRecord(
                "alice",
                "bob",
                { items = { { id = "bear" } }, confirmed = true },
                { items = { { id = "wolf" } }, confirmed = true },
                12345
            )
            expect(rec.a).to.equal("alice")
            expect(rec.b).to.equal("bob")
            expect(rec.a_items[1].id).to.equal("bear")
            expect(rec.b_items[1].id).to.equal("wolf")
            expect(rec.timestamp).to.equal(12345)
        end)
    end)
end
