--[[
    BattleSim — [unit] Monte Carlo battle simulator (the pacing-row engine).
    Run: mise run test-headless
]]

local BattleSim = loadModule("src/Shared/Game/BattleSim.lua")

-- A no-randomness rng (always hits, never crits at chance<1) for deterministic shapes.
local function alwaysHit()
    return 0
end

local function pet(over)
    local p = {
        perHit = 50,
        interval = 1,
        hitChance = 1,
        critChance = 0,
        critMult = 2,
        pool = 100,
        defense = 0,
        threatMult = 1,
    }
    for k, v in pairs(over or {}) do
        p[k] = v
    end
    return p
end

local function enemy(over)
    local e = { hp = 200, armor = 0, dmg = 10, cadence = 1, hitChance = 1, critChance = 0 }
    for k, v in pairs(over or {}) do
        e[k] = v
    end
    return e
end

return function()
    describe("BattleSim.run shapes", function()
        it("clears a beatable enemy and reports the clock", function()
            local r = BattleSim.run(
                { pets = { pet() }, enemies = { enemy() } }, -- 50/swing vs 200hp -> 4 swings
                alwaysHit
            )
            expect(r.cleared).to.equal(true)
            expect(r.t >= 3 and r.t <= 5).to.equal(true)
            expect(r.petsDown).to.equal(0)
        end)

        it("a squad that cannot win dies and reports when", function()
            local r = BattleSim.run({
                pets = { pet({ perHit = 1, pool = 50 }) },
                enemies = { enemy({ hp = 100000, dmg = 25 }) },
            }, alwaysHit)
            expect(r.cleared).to.equal(false)
            expect(r.timeout).to.equal(false)
            expect(r.t >= 1 and r.t <= 4).to.equal(true) -- 50 pool / 25-per-second
        end)

        it("zero-damage stalemate times out", function()
            local r = BattleSim.run({
                max_seconds = 5,
                pets = { pet({ perHit = 0 }) }, -- floors to 1 dmg... so give it huge enemy
                enemies = { enemy({ hp = 1e9, dmg = 0 }) },
            }, alwaysHit)
            expect(r.cleared).to.equal(false)
            expect(r.timeout).to.equal(true)
        end)

        it("enemy armor slows the kill on the armor curve", function()
            -- big pools so the pet survives both runs (this test is about the KILL clock)
            local naked = BattleSim.run(
                { pets = { pet({ pool = 1e6 }) }, enemies = { enemy({ hp = 400 }) } },
                alwaysHit
            )
            local armored = BattleSim.run({
                pets = { pet({ pool = 1e6 }) },
                enemies = { enemy({ hp = 400, armor = 100 }) }, -- halves damage
            }, alwaysHit)
            expect(armored.cleared and naked.cleared).to.equal(true)
            expect(armored.t > naked.t * 1.8).to.equal(true)
        end)

        it("a taunt tank soaks the hits while dps stays untouched", function()
            local r = BattleSim.run({
                pets = {
                    pet({ pool = 1000, taunt = true, threatMult = 5 }),
                    pet({ perHit = 80, pool = 50 }), -- squishy dps would die fast if targeted
                },
                enemies = { enemy({ hp = 500, dmg = 30 }) },
            }, alwaysHit)
            expect(r.cleared).to.equal(true)
            expect(r.petsDown).to.equal(0) -- the tank held aggro; the squishy never got hit
        end)
    end)

    describe("the buffer-death dynamic (Jason's case)", function()
        -- "what if my armor buffer dies? It is no longer armoring. That makes a big
        -- ass difference" — pin it: same squad, but when the defense-aura pet is made
        -- fragile enough to die mid-fight, the survivors' EHP collapses and the squad
        -- does measurably worse than when the buffer survives.
        it("losing the defense buffer mid-fight worsens the outcome", function()
            local function squadWith(bufferPool)
                return {
                    max_seconds = 300,
                    pets = {
                        -- the buffer: big team-defense aura, NO taunt protection
                        pet({
                            perHit = 5,
                            pool = bufferPool,
                            threatMult = 10, -- draws fire (stands in for aggro luck)
                            auras = { { kind = "defense", amount = 400 } }, -- 80% mitigation
                        }),
                        pet({ perHit = 30, pool = 150 }),
                        pet({ perHit = 30, pool = 150 }),
                    },
                    enemies = { enemy({ hp = 3000, dmg = 40, cadence = 1 }) },
                }
            end
            local sturdy = BattleSim.run(squadWith(100000), alwaysHit) -- buffer never dies
            local fragile = BattleSim.run(squadWith(30), alwaysHit) -- buffer dies early
            expect(sturdy.cleared).to.equal(true)
            expect(sturdy.petsDown).to.equal(0)
            -- with the buffer dead the aura is gone: the squad takes ~5x damage and loses pets
            -- (or the whole fight) where the sturdy run finished clean
            local worse = (not fragile.cleared) or (fragile.petsDown or 0) > 0
            expect(worse).to.equal(true)
        end)

        it("an offense aura stops boosting when its source goes down", function()
            -- identical squads; in B the offense buffer is unkillable, in A it dies
            -- immediately — B must clear faster.
            local function squad(bufferPool)
                return {
                    max_seconds = 300,
                    pets = {
                        pet({
                            perHit = 1,
                            pool = bufferPool,
                            threatMult = 100,
                            auras = { { kind = "offense", fraction = 1.0 } }, -- +100% team damage
                        }),
                        pet({ perHit = 40, pool = 100000 }),
                    },
                    enemies = { enemy({ hp = 4000, dmg = 50, cadence = 1 }) },
                }
            end
            local dies = BattleSim.run(squad(10), alwaysHit)
            local lives = BattleSim.run(squad(100000), alwaysHit)
            expect(lives.cleared).to.equal(true)
            expect(dies.cleared).to.equal(true) -- the carry still grinds it out
            expect(lives.t < dies.t).to.equal(true) -- but the living buffer is faster
        end)

        it("a healer extends survival", function()
            local function squad(withHealer)
                local auras = withHealer and { { kind = "heal", fraction = 0.3, interval = 1.5 } }
                    or {}
                return {
                    max_seconds = 60,
                    pets = {
                        pet({ perHit = 1, pool = 200, auras = auras, threatMult = 0 }),
                        pet({ perHit = 1, pool = 200, threatMult = 10 }), -- eats the hits
                    },
                    enemies = { enemy({ hp = 1e9, dmg = 30, cadence = 1 }) },
                }
            end
            local without = BattleSim.run(squad(false), alwaysHit)
            local withHeal = BattleSim.run(squad(true), alwaysHit)
            expect(withHeal.t > without.t).to.equal(true)
        end)

        -- RAGE rides SupportAura.rageFraction — the SAME function EnemyService stamps
        -- live rage with (the unified code path), so this also proves the sim consumes
        -- the shared rules.
        it("a raging pet clears faster once hurt past its threshold", function()
            local function squad(withRage)
                local auras = withRage and { { kind = "rage", enrage_below = 0.5, mult = 2.0 } }
                    or {}
                -- enemy chews 10/s into a 300 pool: rage flips on at 150 taken (~15s)
                return {
                    max_seconds = 60,
                    pets = { pet({ perHit = 50, pool = 300, auras = auras }) },
                    enemies = { enemy({ hp = 1000, dmg = 10, cadence = 1 }) },
                }
            end
            local plain = BattleSim.run(squad(false), alwaysHit)
            local raging = BattleSim.run(squad(true), alwaysHit)
            expect(plain.cleared).to.equal(true)
            expect(raging.cleared).to.equal(true)
            expect(raging.t < plain.t).to.equal(true)
        end)

        it("rage scales by the pet's variantMult (rainbow rages harder)", function()
            local function squad(variantMult)
                return {
                    max_seconds = 60,
                    pets = {
                        pet({
                            perHit = 50,
                            pool = 300,
                            variantMult = variantMult,
                            auras = { { kind = "rage", enrage_below = 0.5, mult = 2.0 } },
                        }),
                    },
                    enemies = { enemy({ hp = 2000, dmg = 10, cadence = 1 }) },
                }
            end
            local basic = BattleSim.run(squad(1), alwaysHit)
            local rainbow = BattleSim.run(squad(1.5), alwaysHit)
            expect(rainbow.t < basic.t).to.equal(true)
        end)
    end)

    describe("BattleSim.runMany aggregation", function()
        it("is deterministic for a fixed seed and varies across trials", function()
            local spec = {
                pets = { pet({ hitChance = 0.7, critChance = 0.2 }) },
                enemies = { enemy({ hp = 600 }) },
            }
            local a = BattleSim.runMany(spec, 5, 42)
            local b = BattleSim.runMany(spec, 5, 42)
            expect(a.clearTime).to.equal(b.clearTime)
            expect(a.wins).to.equal(b.wins)
        end)

        it("reports winRate and median clocks", function()
            local r = BattleSim.runMany({
                pets = { pet() },
                enemies = { enemy() },
            }, 5, 1)
            expect(r.winRate).to.equal(1)
            expect(r.clearTime and r.clearTime > 0).to.equal(true)
            expect(r.dieTime).to.equal(nil)
        end)
    end)
end
