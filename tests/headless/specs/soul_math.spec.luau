--[[
    Feature 2: Soul Stat — [unit] scenarios from GWT_ACCEPTANCE_SPEC.
    Run: mise run test-headless
]]

local RingTopology = loadModule("src/Shared/Game/RingTopology.lua")
local SoulMath = loadModule("src/Shared/Game/SoulMath.lua")
local biomeConfig = loadModule("configs/biomes.lua")
local soulConfig = loadModule("configs/soul.lua")

return function()
    describe("SoulMath.applyConquest", function()
        local ring
        beforeEach(function()
            ring = RingTopology.new(biomeConfig)
        end)

        local function state(soul, last, conquered)
            return {
                soul = soul,
                last_conquered_biome = last,
                conquered_biomes = conquered or {},
            }
        end

        it("initial soul is zero (new profile default)", function()
            -- the data spine seeds soul = 0; verify the math leaves a fresh
            -- first conquest at 0
            local s = state(0, nil)
            local newState = SoulMath.applyConquest(s, "earth", ring, soulConfig)
            expect(newState.soul).to.equal(0)
        end)

        it("conquering clockwise neighbor increases soul by delta", function()
            local newState, result =
                SoulMath.applyConquest(state(0, "earth"), "ice", ring, soulConfig)
            expect(newState.soul).to.equal(5)
            expect(newState.last_conquered_biome).to.equal("ice")
            expect(result.delta).to.equal(5)
            expect(result.fired).to.equal(true)
        end)

        it("conquering counterclockwise neighbor decreases soul by delta", function()
            local newState = SoulMath.applyConquest(state(0, "earth"), "beach", ring, soulConfig)
            expect(newState.soul).to.equal(-5)
            expect(newState.last_conquered_biome).to.equal("beach")
        end)

        it("conquering a non-adjacent biome does not change soul but updates last", function()
            local newState = SoulMath.applyConquest(state(10, "earth"), "lava", ring, soulConfig)
            expect(newState.soul).to.equal(10)
            expect(newState.last_conquered_biome).to.equal("lava")
        end)

        it("first conquest (no last_conquered) does not change soul", function()
            local newState = SoulMath.applyConquest(state(0, nil), "earth", ring, soulConfig)
            expect(newState.soul).to.equal(0)
            expect(newState.last_conquered_biome).to.equal("earth")
        end)

        it("re-conquering an already-conquered biome is a no-op, no event", function()
            local s = state(15, "ice", { earth = true })
            local newState, result = SoulMath.applyConquest(s, "earth", ring, soulConfig)
            expect(newState.soul).to.equal(15)
            expect(newState.last_conquered_biome).to.equal("ice")
            expect(result.fired).to.equal(false)
        end)

        it("soul is capped at the upper bound", function()
            local newState = SoulMath.applyConquest(state(98, "earth"), "ice", ring, soulConfig)
            expect(newState.soul).to.equal(100)
        end)

        it("soul is capped at the lower bound", function()
            local newState = SoulMath.applyConquest(state(-98, "earth"), "beach", ring, soulConfig)
            expect(newState.soul).to.equal(-100)
        end)

        it("delta is config-driven", function()
            local tenConfig = { delta_per_conquest = 10, range = { min = -100, max = 100 } }
            local newState = SoulMath.applyConquest(state(0, "earth"), "ice", ring, tenConfig)
            expect(newState.soul).to.equal(10)
        end)

        it("does not mutate the input state (immutability)", function()
            local s = state(0, "earth", { earth = true })
            SoulMath.applyConquest(s, "ice", ring, soulConfig)
            expect(s.soul).to.equal(0)
            expect(s.last_conquered_biome).to.equal("earth")
            expect(s.conquered_biomes.ice).to.equal(nil)
        end)
    end)

    describe("SoulMath.alignment", function()
        it("labels halo / horns / neutral from config bands", function()
            expect(SoulMath.alignment(42, soulConfig)).to.equal("halo")
            expect(SoulMath.alignment(-42, soulConfig)).to.equal("horns")
            expect(SoulMath.alignment(0, soulConfig)).to.equal("neutral")
        end)
    end)
end
