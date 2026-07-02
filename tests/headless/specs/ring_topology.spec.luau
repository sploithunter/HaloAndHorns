--[[
    Feature 1: Ring Map Topology — [unit] scenarios from GWT_ACCEPTANCE_SPEC.
    Run: mise run test-headless
]]

local RingTopology = loadModule("src/Shared/Game/RingTopology.lua")
local biomeConfig = loadModule("configs/biomes.lua")

return function()
    describe("RingTopology", function()
        local ring
        beforeEach(function()
            ring = RingTopology.new(biomeConfig)
        end)

        it("clockwise neighbor of earth is ice", function()
            expect(ring:clockwiseNeighbor("earth")).to.equal("ice")
        end)

        it("counterclockwise neighbor of earth is beach", function()
            expect(ring:counterclockwiseNeighbor("earth")).to.equal("beach")
        end)

        it("clockwise adjacency wraps: beach -> earth", function()
            expect(ring:clockwiseNeighbor("beach")).to.equal("earth")
        end)

        it("counterclockwise adjacency wraps: earth -> beach", function()
            expect(ring:counterclockwiseNeighbor("earth")).to.equal("beach")
        end)

        it("walks the full clockwise ring", function()
            expect(ring:clockwiseNeighbor("ice")).to.equal("lava")
            expect(ring:clockwiseNeighbor("lava")).to.equal("desert")
            expect(ring:clockwiseNeighbor("desert")).to.equal("beach")
        end)

        it("theme is config-driven, not inferred", function()
            expect(ring:theme("ice")).to.equal("ice")
            expect(ring:theme("lava")).to.equal("lava")
        end)

        it("dichotomy partners are config-driven (incl. nil)", function()
            expect(ring:dichotomyPartner("earth")).to.equal("desert")
            expect(ring:dichotomyPartner("desert")).to.equal("earth")
            expect(ring:dichotomyPartner("ice")).to.equal("lava")
            expect(ring:dichotomyPartner("lava")).to.equal("ice")
            expect(ring:dichotomyPartner("beach")).to.equal(nil)
        end)

        it("currency is config-driven per biome", function()
            expect(ring:currency("earth")).to.equal("grass_coins")
            expect(ring:currency("ice")).to.equal("ice_coins")
        end)

        it("areAdjacent reflects the ring (both directions, wrap)", function()
            expect(ring:areAdjacent("earth", "ice")).to.equal(true)
            expect(ring:areAdjacent("earth", "beach")).to.equal(true)
            expect(ring:areAdjacent("earth", "lava")).to.equal(false)
            expect(ring:areAdjacent("earth", "desert")).to.equal(false)
        end)

        it("returns nil for unknown biomes", function()
            expect(ring:clockwiseNeighbor("nope")).to.equal(nil)
            expect(ring:theme("nope")).to.equal(nil)
            expect(ring:has("earth")).to.equal(true)
            expect(ring:has("nope")).to.equal(false)
        end)

        -- [integration]: adding a 6th biome to config requires no module change
        it("adding a 6th biome (swamp) works with no module change", function()
            local extended = {
                order = { "earth", "ice", "lava", "desert", "beach", "swamp" },
                biomes = {
                    earth = { theme = "earth", dichotomy = "desert", currency = "earth_coins" },
                    swamp = { theme = "swamp", dichotomy = nil, currency = "swamp_coins" },
                },
            }
            local r = RingTopology.new(extended)
            expect(r:count()).to.equal(6)
            -- adjacency now includes swamp between beach and earth
            expect(r:clockwiseNeighbor("beach")).to.equal("swamp")
            expect(r:clockwiseNeighbor("swamp")).to.equal("earth")
            expect(r:counterclockwiseNeighbor("earth")).to.equal("swamp")
            expect(r:theme("swamp")).to.equal("swamp")
        end)
    end)
end
