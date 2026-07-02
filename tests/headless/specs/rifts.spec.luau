--[[
    Feature 21: Chaos Rifts — [unit] [deferred] multiplier scenarios.
    The live event scheduler/spawn/Aether drops are deferred; the power math
    (element multipliers reverse inside a rift) is verified here.
    Run: mise run test-headless
]]

local RiftMultiplier = loadModule("src/Shared/Game/RiftMultiplier.lua")
local config = loadModule("configs/rifts.lua")

return function()
    describe("RiftMultiplier.multiplierFor", function()
        it("Chaotic dominates at 2.0x", function()
            expect(RiftMultiplier.multiplierFor("chaotic", config)).to.equal(2.0)
        end)
        it("Light is penalized at 0.5x", function()
            expect(RiftMultiplier.multiplierFor("light", config)).to.equal(0.5)
        end)
        it("Shadow is penalized at 0.5x", function()
            expect(RiftMultiplier.multiplierFor("shadow", config)).to.equal(0.5)
        end)
        it("Neutral is penalized at 0.5x", function()
            expect(RiftMultiplier.multiplierFor("neutral", config)).to.equal(0.5)
        end)
        it("falls back to the default for unknown elements", function()
            expect(RiftMultiplier.multiplierFor("mystery", config)).to.equal(1.0)
        end)
    end)

    describe("RiftMultiplier.applyToPower", function()
        it("Chaotic pet base 100 -> 200 inside a rift", function()
            expect(RiftMultiplier.applyToPower(100, "chaotic", config)).to.equal(200)
        end)
        it("Light pet base 100 -> 50 inside a rift", function()
            expect(RiftMultiplier.applyToPower(100, "light", config)).to.equal(50)
        end)
    end)
end
