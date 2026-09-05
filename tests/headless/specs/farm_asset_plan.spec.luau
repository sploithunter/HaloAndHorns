local Plan = loadModule("src/Shared/Game/FarmAssetPlan.lua")
local config = loadModule("configs/farm_asset_warmup.lua")
local function catalog()
    local pets = {}
    for _, id in ipairs({ "a", "b", "c", "old", "owned", "dormant" }) do
        pets[id] = { variants = { basic = {}, golden = {}, rainbow = {} } }
    end
    return {
        pets = pets,
        egg_sources = {
            basic_egg = { pet_weights = { a = 10, b = 1 } },
            next = { pet_weights = { c = 1 } },
            distant = { pet_weights = { dormant = 1 } },
        },
    }
end
return function()
    describe("Farm predictive assets", function()
        it(
            "boots the Earth pool including rare pets and all variants without the catalog",
            function()
                local pets, eggs = Plan.build(config, catalog(), { now = 0 })
                expect(eggs.basic_egg).to.equal(true)
                expect(pets.a.basic).to.equal(true)
                expect(pets.b.rainbow).to.equal(true)
                expect(pets.dormant).to.equal(nil)
            end
        )
        it(
            "selects two distinct nearby stands, not duplicate visual markers or distant eggs",
            function()
                local pets, eggs = Plan.build(config, catalog(), {
                    now = 0,
                    eggs = {
                        { id = "basic_egg", distance = 1 },
                        { id = "basic_egg", distance = 2 },
                        { id = "next", distance = 50 },
                        { id = "distant", distance = 500 },
                    },
                })
                expect(eggs.next).to.equal(true)
                expect(eggs.distant).to.equal(nil)
                expect(pets.c.golden).to.equal(true)
            end
        )
        it("pins living and equipped old pets independently of the current egg", function()
            local pets = Plan.build(config, catalog(), {
                now = 0,
                active = { { id = "old", variant = "rainbow" } },
                equipped = { { id = "owned", variant = "golden" } },
            })
            expect(pets.old.rainbow).to.equal(true)
            expect(pets.old.basic).to.equal(true)
            expect(pets.owned.golden).to.equal(true)
        end)
        it(
            "bounds recent owned models by distinct type and variant, not stack quantities",
            function()
                local cfg = table.clone(config)
                cfg.recent_owned_models = 1
                local pets = Plan.build(cfg, catalog(), {
                    now = 0,
                    owned = {
                        {
                            id = "owned",
                            variant = "golden",
                            obtained_at = 50,
                            quantity = 10000,
                        },
                        { id = "old", variant = "basic", obtained_at = 10 },
                    },
                })
                expect(pets.owned.golden).to.equal(true)
                expect(pets.old).to.equal(nil)
            end
        )
        it("expires explicit previews and never considers a zero stack owned", function()
            local pets = Plan.build(config, catalog(), {
                now = 20,
                requested = {
                    { id = "old", variant = "basic", expiresAt = 10 },
                    { id = "owned", variant = "golden", expiresAt = 21 },
                },
            })
            expect(pets.old).to.equal(nil)
            expect(pets.owned.golden).to.equal(true)
            expect(Plan.owns({ { id = "old", quantity = 0 } }, "old", "basic")).to.equal(false)
            expect(Plan.owns({ { id = "owned", variant = "golden" } }, "owned", "basic")).to.equal(
                false
            )
            expect(Plan.owns({ { id = "owned", variant = "golden" } }, "owned", "golden")).to.equal(
                true
            )
        end)
        it("does not let the prediction budget evict active pets", function()
            local cfg = table.clone(config)
            cfg.maximum_predictive_pet_types = 1
            local pets = Plan.build(cfg, catalog(), { now = 0, active = { { id = "old" } } })
            expect(pets.old.basic).to.equal(true)
            expect(pets.a.basic).to.equal(true)
            expect(pets.b).to.equal(nil)
        end)
    end)
end
