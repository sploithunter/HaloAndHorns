--[[
    Hit / crit resolution (pet attacks, enemy attacks, taunts). Run: mise run test-headless
]]

local CombatRoll = loadModule("src/Shared/Game/CombatRoll.lua")

return function()
    describe("CombatRoll.resolve", function()
        it("always hits when hit_chance >= 1", function()
            local r = CombatRoll.resolve({ hit_chance = 1, crit_chance = 0 }, 0.99, 0.99)
            expect(r.hit).to.equal(true)
            expect(r.crit).to.equal(false)
            expect(r.multiplier).to.equal(1)
        end)

        it("misses when the hit roll is at/above hit_chance (multiplier 0)", function()
            local r = CombatRoll.resolve({ hit_chance = 0.8 }, 0.85, 0)
            expect(r.hit).to.equal(false)
            expect(r.multiplier).to.equal(0)
        end)

        it("crits when hit AND the crit roll is below crit_chance", function()
            local r = CombatRoll.resolve(
                { hit_chance = 1, crit_chance = 0.25, crit_mult = 2.5 },
                0.1,
                0.2
            )
            expect(r.hit).to.equal(true)
            expect(r.crit).to.equal(true)
            expect(r.multiplier).to.equal(2.5)
        end)

        it("never crits on a miss", function()
            local r =
                CombatRoll.resolve({ hit_chance = 0.5, crit_chance = 1, crit_mult = 3 }, 0.9, 0.0)
            expect(r.hit).to.equal(false)
            expect(r.crit).to.equal(false)
            expect(r.multiplier).to.equal(0)
        end)

        it("defaults: always hits, never crits when params omitted", function()
            local r = CombatRoll.resolve(nil, 0.999, 0.0)
            expect(r.hit).to.equal(true)
            expect(r.crit).to.equal(false)
            expect(r.multiplier).to.equal(1)
        end)

        it("normal hit (no crit) has multiplier 1", function()
            local r =
                CombatRoll.resolve({ hit_chance = 1, crit_chance = 0.1, crit_mult = 2 }, 0.0, 0.5)
            expect(r.crit).to.equal(false)
            expect(r.multiplier).to.equal(1)
        end)
    end)
end
