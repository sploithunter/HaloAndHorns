local MonetizationCatalog = loadModule("src/Shared/Game/MonetizationCatalog.lua")

return function()
    describe("MonetizationCatalog", function()
        local config = {
            product_id_mapping = {
                vip = 101,
                speed = 202,
                future_boost = 0,
            },
            passes = {
                { id = "vip", name = "VIP" },
                { id = "speed", name = "Speed" },
            },
            products = {
                { id = "future_boost", name = "Future" },
                { id = "missing", name = "Missing" },
            },
        }

        it("projects configured passes with positive Marketplace IDs in authored order", function()
            local passes = MonetizationCatalog.livePasses(config)
            expect(#passes).to.equal(2)
            expect(passes[1].id).to.equal("vip")
            expect(passes[1].robloxId).to.equal(101)
            expect(passes[1].kind).to.equal("gamepass")
            expect(passes[2].order).to.equal(2)
        end)

        it("hides developer-product placeholders until their IDs are live", function()
            expect(#MonetizationCatalog.liveProducts(config)).to.equal(0)
        end)

        it("normalizes both compact and detailed owned-pass snapshots", function()
            local owned = MonetizationCatalog.ownedSet({
                passes = {
                    "vip",
                    { id = "speed", name = "Speed" },
                    { name = "invalid" },
                },
            })
            expect(owned.vip).to.equal(true)
            expect(owned.speed).to.equal(true)
            expect(owned.invalid).to.equal(nil)
        end)
    end)
end
