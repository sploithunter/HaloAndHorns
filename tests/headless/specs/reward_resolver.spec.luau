--[[
    Feature 4: Themed Currency System — reward resolution scenarios.
    Run: mise run test-headless
]]

local RingTopology = loadModule("src/Shared/Game/RingTopology.lua")
local RewardResolver = loadModule("src/Shared/Game/RewardResolver.lua")
local biomeConfig = loadModule("configs/biomes.lua")
local layersConfig = loadModule("configs/layers.lua")

return function()
    describe("RewardResolver", function()
        local resolver
        beforeEach(function()
            resolver = RewardResolver.new(RingTopology.new(biomeConfig), layersConfig)
        end)

        it("earth breakable in base drops 10 grass_coins", function()
            local r = resolver:resolveReward(10, "earth", "base")
            expect(r.currency).to.equal("grass_coins")
            expect(r.amount).to.equal(10)
        end)

        it("earth breakable in Heaven 1 drops 50 of the SAME currency (5x test boost)", function()
            local r = resolver:resolveReward(10, "earth", "heaven_1")
            expect(r.currency).to.equal("grass_coins")
            expect(r.amount).to.equal(50) -- heaven_1 bumped 1.5x -> 5.0x for egg-testing income
        end)

        it("earth breakable in Hell 1 drops 50 grass_coins (not a separate currency)", function()
            local r = resolver:resolveReward(10, "earth", "hell_1")
            expect(r.currency).to.equal("grass_coins")
            expect(r.amount).to.equal(50) -- hell_1 bumped 1.5x -> 5.0x for egg-testing income
        end)

        it(
            "heaven_2 / hell_2 scale at 8.0x (monotonic deeper=richer; absorbs old value_mult)",
            function()
                expect(resolver:resolveReward(10, "earth", "heaven_2").amount).to.equal(80)
                expect(resolver:resolveReward(10, "ice", "hell_2").amount).to.equal(80)
            end
        )

        it("currency drops vary by biome", function()
            expect(resolver:resolveReward(10, "earth", "base").currency).to.equal("grass_coins")
            expect(resolver:resolveReward(10, "ice", "base").currency).to.equal("ice_coins")
            -- ice breakable never yields grass_coins
            expect(resolver:resolveReward(10, "ice", "base").currency).never.to.equal("grass_coins")
        end)

        it("unknown layer falls back to 1.0x", function()
            expect(resolver:layerMultiplier("nowhere")).to.equal(1.0)
            expect(resolver:resolveReward(10, "earth", "nowhere").amount).to.equal(10)
        end)

        it("Light tokens only in Heaven layers", function()
            expect(resolver:layerTokenCurrency("heaven_1")).to.equal("light_tokens")
            expect(resolver:layerTokenCurrency("heaven_2")).to.equal("light_tokens")
            expect(resolver:layerTokenCurrency("base")).to.equal(nil)
            expect(resolver:layerTokenCurrency("hell_1")).never.to.equal("light_tokens")
        end)

        it("Shadow tokens only in Hell layers", function()
            expect(resolver:layerTokenCurrency("hell_1")).to.equal("shadow_tokens")
            expect(resolver:layerTokenCurrency("hell_2")).to.equal("shadow_tokens")
            expect(resolver:layerTokenCurrency("base")).to.equal(nil)
            expect(resolver:layerTokenCurrency("heaven_1")).never.to.equal("shadow_tokens")
        end)
    end)
end
