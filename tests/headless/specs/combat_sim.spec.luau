--[[
    Feature 10: Combat — deterministic end-to-end fight resolution [integration].
    CombatSim composes Targeting + CombatMath + FocusMath over real configs.
    Run: mise run test-headless
]]

local CombatSim = loadModule("src/Shared/Game/CombatSim.lua")
local Targeting = loadModule("src/Shared/Game/Targeting.lua")
local CombatMath = loadModule("src/Shared/Game/CombatMath.lua")
local FocusMath = loadModule("src/Shared/Game/FocusMath.lua")
local combatConfig = loadModule("configs/combat.lua")
local focusConfig = loadModule("configs/focus.lua")
local enemiesConfig = loadModule("configs/enemies.lua")

local deps = { Targeting = Targeting, CombatMath = CombatMath, FocusMath = FocusMath }
local cfg = { combat = combatConfig, focus = focusConfig }

-- Expand a configured enemy id into a fight-ready record at position x.
local function spawn(id, x)
    local def = enemiesConfig.enemies[id]
    return {
        id = id,
        hp = def.hp,
        position = { x = x, y = 0, z = 0 },
        attack = def.attack,
        drop_table = def.drop_table,
    }
end

return function()
    describe("CombatSim full fight", function()
        it(
            "strong pets clear a Hell encounter and collect biome currency + Shadow Tokens",
            function()
                -- 4 imps (120hp) + 1 brute (400hp). Two 300-power pets clear it fast.
                local scenario = {
                    enemies = {
                        spawn("lava_imp", 20),
                        spawn("lava_imp", 40),
                        spawn("lava_imp", 60),
                        spawn("lava_imp", 80),
                        spawn("ember_brute", 100),
                    },
                    pets = { { power = 300 }, { power = 300 } },
                }
                local r = CombatSim.run(scenario, deps, cfg)
                expect(r.ended).to.equal(true)
                expect(r.enemiesDefeated).to.equal(5)
                -- loot: 4 imps (8 lava + 1 shadow each) + brute (30 lava + 4 shadow)
                expect(r.loot.lava_coins).to.equal(4 * 8 + 30)
                expect(r.loot.shadow_tokens).to.equal(4 * 1 + 4)
            end
        )

        it("the Sundering brute drains player Focus over the fight", function()
            -- 10x world (brute 4000hp): one 1000-power pet clears it in 4 rounds,
            -- taking 3 sundering hits first (100 -> 80 -> 60 -> 40) before the kill
            -- round — the SAME fight shape as pre-10x, which is the whole point.
            local scenario = {
                enemies = { spawn("ember_brute", 30) },
                pets = { { power = 1000 } },
            }
            local r = CombatSim.run(scenario, deps, cfg)
            expect(r.ended).to.equal(true)
            expect(r.petsDowned).to.equal(0)
            expect(r.focusRemaining).to.equal(40)
        end)

        it("a fragile pet is downed when enemy damage exceeds its power", function()
            -- pet power 5, threshold factor 1.0 => downed after 5 accumulated dmg.
            -- A tanky enemy (so the fight runs long enough to down the pet).
            local scenario = {
                enemies = { spawn("infernal_boss", 30) },
                pets = { { power = 5 } },
                maxRounds = 50,
            }
            local r = CombatSim.run(scenario, deps, cfg)
            expect(r.petsDowned).to.equal(1)
        end)

        it("all-pets-downed does not end the encounter (no player defeat)", function()
            -- single fragile pet vs boss: pet downs, boss survives, sim bounded by maxRounds
            local scenario = {
                enemies = { spawn("infernal_boss", 30) },
                pets = { { power = 5 } },
                maxRounds = 30,
            }
            local r = CombatSim.run(scenario, deps, cfg)
            expect(r.petsDowned).to.equal(1)
            expect(r.ended).to.equal(false)
            expect(r.enemiesDefeated).to.equal(0)
        end)

        it("a support buff lets pets clear faster (fewer rounds)", function()
            local base = {
                enemies = { spawn("ember_brute", 30) },
                pets = { { power = 100 } },
            }
            local buffed = {
                enemies = { spawn("ember_brute", 30) },
                pets = { { power = 100 } },
                buff = 2,
            }
            local rBase = CombatSim.run(base, deps, cfg)
            local rBuff = CombatSim.run(buffed, deps, cfg)
            expect(rBuff.rounds < rBase.rounds).to.equal(true)
        end)
    end)
end
