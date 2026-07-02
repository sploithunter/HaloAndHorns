--[[
    Phase 0 integration — the data-spine modules working together.

    Threads RingTopology + SoulMath (+ RewardResolver) through multi-step conquest
    sequences, proving they interconnect: directional Soul shifts, non-adjacent
    no-ops, re-conquest no-ops, and biome-themed rewards along the way.

    Run: mise run test-headless
]]

local RingTopology = loadModule("src/Shared/Game/RingTopology.lua")
local SoulMath = loadModule("src/Shared/Game/SoulMath.lua")
local RewardResolver = loadModule("src/Shared/Game/RewardResolver.lua")
local biomeConfig = loadModule("configs/biomes.lua")
local soulConfig = loadModule("configs/soul.lua")
local layersConfig = loadModule("configs/layers.lua")

return function()
    describe("Phase 0 conquest flow", function()
        local ring, resolver
        beforeEach(function()
            ring = RingTopology.new(biomeConfig)
            resolver = RewardResolver.new(ring, layersConfig)
        end)

        local function fresh()
            return { soul = 0, last_conquered_biome = nil, conquered_biomes = {} }
        end

        -- Apply a sequence of conquests, returning the final state.
        local function conquer(state, sequence)
            for _, biome in ipairs(sequence) do
                state = SoulMath.applyConquest(state, biome, ring, soulConfig)
            end
            return state
        end

        it("clockwise tour raises Soul toward the Halo, step by step", function()
            local s = fresh()
            s = SoulMath.applyConquest(s, "earth", ring, soulConfig) -- first: 0
            expect(s.soul).to.equal(0)
            s = SoulMath.applyConquest(s, "ice", ring, soulConfig) -- +5
            expect(s.soul).to.equal(5)
            s = SoulMath.applyConquest(s, "lava", ring, soulConfig) -- +5
            expect(s.soul).to.equal(10)
            s = SoulMath.applyConquest(s, "desert", ring, soulConfig) -- +5
            expect(s.soul).to.equal(15)
            s = SoulMath.applyConquest(s, "beach", ring, soulConfig) -- +5
            expect(s.soul).to.equal(20)
            expect(SoulMath.alignment(s.soul, soulConfig)).to.equal("halo")
        end)

        it("counterclockwise tour pulls Soul toward the Horns", function()
            local s = conquer(fresh(), { "earth", "beach", "desert", "lava", "ice" })
            expect(s.soul).to.equal(-20)
            expect(s.last_conquered_biome).to.equal("ice")
            expect(SoulMath.alignment(s.soul, soulConfig)).to.equal("horns")
        end)

        it("non-adjacent jump and re-conquest leave Soul unchanged", function()
            local s = fresh()
            s = SoulMath.applyConquest(s, "earth", ring, soulConfig) -- first: 0
            s = SoulMath.applyConquest(s, "lava", ring, soulConfig) -- non-adjacent to earth: 0
            expect(s.soul).to.equal(0)
            expect(s.last_conquered_biome).to.equal("lava")
            s = SoulMath.applyConquest(s, "ice", ring, soulConfig) -- ccw of lava: -5
            expect(s.soul).to.equal(-5)
            local before = s.soul
            s = SoulMath.applyConquest(s, "lava", ring, soulConfig) -- already conquered: no-op
            expect(s.soul).to.equal(before)
            expect(s.last_conquered_biome).to.equal("ice")
        end)

        it("rewards are themed by the biome being conquered/farmed", function()
            -- as the player tours, a base-layer breakable in each biome pays that
            -- biome's currency (independent of Soul)
            expect(resolver:resolveReward(10, "earth", "base").currency).to.equal("grass_coins")
            expect(resolver:resolveReward(10, "ice", "base").currency).to.equal("ice_coins")
            expect(resolver:resolveReward(10, "lava", "base").currency).to.equal("lava_coins")
            -- and a Heaven run scales the same currency + grants Light tokens
            -- (heaven_1 bumped 1.5x -> 5.0x for egg-testing income)
            expect(resolver:resolveReward(10, "earth", "heaven_1").amount).to.equal(50)
            expect(resolver:layerTokenCurrency("heaven_1")).to.equal("light_tokens")
        end)
    end)
end
