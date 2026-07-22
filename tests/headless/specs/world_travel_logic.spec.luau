local WorldTravelLogic = loadModule("src/Shared/Game/WorldTravelLogic.lua")
local layersConfig = loadModule("configs/layers.lua")
local areasConfig = loadModule("configs/areas.lua")

return function()
    describe("WorldTravelLogic", function()
        it("derives player-facing realm labels and configured zone ids", function()
            local grass = layersConfig.world_travel.origins[1]
            expect(WorldTravelLogic.layerLabel("base")).to.equal("Home")
            expect(WorldTravelLogic.layerLabel("hell_2")).to.equal("Hell 2")
            expect(WorldTravelLogic.mapFolder("heaven_1")).to.equal("Heaven_1")
            expect(WorldTravelLogic.zoneId("base", grass)).to.equal("Spawn")
            expect(WorldTravelLogic.zoneId("hell_2", grass)).to.equal("Hell_2_Grass")
        end)

        it("returns only the intersection of usable, built, configured, and unlocked", function()
            local catalog = WorldTravelLogic.catalog(layersConfig.world_travel, areasConfig, {
                usableLayers = { base = true, hell_1 = true, hell_2 = true, heaven_1 = true },
                builtLayers = { base = true, hell_1 = false, hell_2 = true, heaven_1 = true },
                unlockedZones = { "Spawn", "Ice", "Hell_2_Ice" },
                quotes = {
                    base = { cost = 0 },
                    hell_2 = { cost = 250, currency = "shadow_tokens" },
                    heaven_1 = { cost = 100, currency = "light_tokens" },
                },
                currentLayer = "base",
                currentArea = "Spawn",
            })

            expect(#catalog).to.equal(2)
            expect(catalog[1].id).to.equal("base")
            expect(#catalog[1].origins).to.equal(2)
            expect(catalog[1].origins[1].id).to.equal("grass")
            expect(catalog[1].origins[1].current).to.equal(true)
            expect(catalog[1].origins[2].id).to.equal("ice")

            expect(catalog[2].id).to.equal("hell_2")
            expect(catalog[2].cost).to.equal(250)
            expect(catalog[2].currency).to.equal("shadow_tokens")
            expect(#catalog[2].origins).to.equal(1)
            expect(catalog[2].origins[1].id).to.equal("ice")
        end)

        it("omits accessible layers with no unlocked configured origin", function()
            local catalog = WorldTravelLogic.catalog(layersConfig.world_travel, areasConfig, {
                usableLayers = { base = true, heaven_1 = true },
                builtLayers = { base = true, heaven_1 = true },
                unlockedZones = { "Spawn" },
            })
            expect(#catalog).to.equal(1)
            expect(catalog[1].id).to.equal("base")
        end)

        it("find accepts only an exact catalog destination", function()
            local catalog = {
                { id = "base", origins = { { id = "grass", zoneId = "Spawn" } } },
            }
            local layer, origin = WorldTravelLogic.find(catalog, "base", "grass")
            expect(layer.id).to.equal("base")
            expect(origin.zoneId).to.equal("Spawn")
            expect(WorldTravelLogic.find(catalog, "base", "lava")).to.equal(nil)
            expect(WorldTravelLogic.find(catalog, "hell_5", "grass")).to.equal(nil)
        end)
    end)
end
