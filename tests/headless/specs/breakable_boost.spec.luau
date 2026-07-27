local BreakableBoost = loadModule("src/Shared/Game/BreakableBoost.lua")
local breakables = loadModule("configs/breakables.lua")

return function()
    describe("BreakableBoost", function()
        it("is neutral for an unboosted crystal", function()
            expect(BreakableBoost.multiplier(0, 100, 1)).to.equal(1)
        end)

        it("scales linearly from half Resonance to full Boost", function()
            expect(BreakableBoost.multiplier(50, 100, 1)).to.equal(1.5)
            expect(BreakableBoost.multiplier(100, 100, 1)).to.equal(2)
        end)

        it("clamps overfill and invalid meters safely", function()
            expect(BreakableBoost.multiplier(150, 100, 1)).to.equal(2)
            expect(BreakableBoost.multiplier(50, 0, 1)).to.equal(1)
            expect(BreakableBoost.multiplier(-20, 100, 1)).to.equal(1)
        end)

        it("configures full Boost to double damage, currency, and eligible mining XP", function()
            expect(breakables.boost.max_damage_bonus).to.equal(1)
            expect(breakables.boost.max_reward_bonus).to.equal(1)
        end)

        it("preserves Level 1-4 XP pacing and starts the XP bonus at Level 5", function()
            local minimum = breakables.boost.reward_xp_min_level
            expect(BreakableBoost.levelGatedMultiplier(100, 100, 1, 4, minimum)).to.equal(1)
            expect(BreakableBoost.levelGatedMultiplier(50, 100, 1, 5, minimum)).to.equal(1.5)
            expect(BreakableBoost.levelGatedMultiplier(100, 100, 1, 5, minimum)).to.equal(2)
        end)

        it("wires the shared multiplier into damage and both reward paths", function()
            local petFollow = readFile("src/Server/Services/PetFollowService.lua")
            local spawner = readFile("src/Server/Services/BreakableSpawner.lua")
            expect(petFollow:find("BreakableBoost.multiplier", 1, true)).to.be.ok()
            expect(spawner:find("BoostRewardBonus", 1, true)).to.be.ok()
            expect(spawner:find("resolvePlayerAward(plr, boostedShare)", 1, true)).to.be.ok()
            expect(spawner:find("BreakableBoost.levelGatedMultiplier", 1, true)).to.be.ok()
            expect(spawner:find("XpReward.fromValue(xpShare", 1, true)).to.be.ok()
        end)
    end)
end
