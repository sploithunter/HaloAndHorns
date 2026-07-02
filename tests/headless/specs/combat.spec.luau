--[[
    Feature 10: Combat System — [unit] / [integration] arithmetic scenarios.
    Run: mise run test-headless
]]

local Targeting = loadModule("src/Shared/Game/Targeting.lua")
local CombatMath = loadModule("src/Shared/Game/CombatMath.lua")
local combatConfig = loadModule("configs/combat.lua")
local enemiesConfig = loadModule("configs/enemies.lua")

local function enemy(id, x, hp)
    return { id = id, position = { x = x, y = 0, z = 0 }, hp = hp }
end

return function()
    describe("Targeting.nearestEnemy", function()
        it("picks the nearest living enemy (auto-target default)", function()
            local from = { x = 0, y = 0, z = 0 }
            local list = { enemy("far", 100, 50), enemy("near", 10, 50), enemy("mid", 40, 50) }
            expect(Targeting.nearestEnemy(from, list).id).to.equal("near")
        end)

        it("skips defeated enemies", function()
            local from = { x = 0, y = 0, z = 0 }
            -- closest is dead -> target the next living one
            local list = { enemy("dead", 5, 0), enemy("alive", 30, 50) }
            expect(Targeting.nearestEnemy(from, list).id).to.equal("alive")
        end)

        it("returns nil when nothing is alive", function()
            local from = { x = 0, y = 0, z = 0 }
            expect(Targeting.nearestEnemy(from, { enemy("d1", 5, 0), enemy("d2", 9, 0) })).to.equal(
                nil
            )
        end)
    end)

    describe("CombatMath damage", function()
        it("pet attack damage equals its power (no buff)", function()
            expect(CombatMath.attackDamage(120)).to.equal(120)
        end)

        it("a support buff scales attack damage", function()
            -- 120 power, 1.5x buff -> 180
            expect(CombatMath.attackDamage(120, 1.5)).to.equal(180)
        end)

        it("applyDamage floors at zero and detects defeat", function()
            expect(CombatMath.applyDamage(50, 30)).to.equal(20)
            expect(CombatMath.applyDamage(50, 80)).to.equal(0)
            expect(CombatMath.isDefeated(0)).to.equal(true)
            expect(CombatMath.isDefeated(1)).to.equal(false)
        end)
    end)

    describe("CombatMath.encounterEnded", function()
        it("is false while any enemy lives, true when all defeated", function()
            expect(CombatMath.encounterEnded({ enemy("a", 0, 10), enemy("b", 5, 0) })).to.equal(
                false
            )
            expect(CombatMath.encounterEnded({ enemy("a", 0, 0), enemy("b", 5, 0) })).to.equal(true)
        end)
    end)

    describe("CombatMath.isPetDowned", function()
        it("downs a pet once accumulated damage reaches power * factor", function()
            -- 10x world: factor 10.0, power 100 -> downed at 1000 absorbed
            expect(CombatMath.isPetDowned(999, 100, combatConfig)).to.equal(false)
            expect(CombatMath.isPetDowned(1000, 100, combatConfig)).to.equal(true)
        end)
    end)

    describe("CombatMath.groupScaledHp", function()
        it("leaves solo HP unscaled", function()
            expect(CombatMath.groupScaledHp(1000, 1, combatConfig)).to.equal(1000)
        end)

        it("scales for a 4-player party: 1000 * (1 + 0.5*3) = 2500", function()
            expect(CombatMath.groupScaledHp(1000, 4, combatConfig)).to.equal(2500)
        end)
    end)

    describe("CombatMath loot + sundering (Hell)", function()
        it("a lava_imp drops lava_coins + shadow_tokens deterministically", function()
            local loot = CombatMath.resolveLoot(enemiesConfig.enemies.lava_imp.drop_table)
            expect(loot.lava_coins).to.equal(8)
            expect(loot.shadow_tokens).to.equal(1)
        end)

        it("skips *_chance random keys in the deterministic loot", function()
            local loot = CombatMath.resolveLoot(enemiesConfig.enemies.ember_brute.drop_table)
            expect(loot.lava_coins).to.equal(30)
            expect(loot.shadow_tokens).to.equal(4)
            expect(loot.rare_drop_chance).to.equal(nil)
        end)

        it("a Sundering enemy drains Focus per hit; a plain one drains none", function()
            expect(CombatMath.sunderAmount(enemiesConfig.enemies.ember_brute.attack)).to.equal(20)
            expect(CombatMath.sunderAmount(enemiesConfig.enemies.lava_imp.attack)).to.equal(0)
        end)
    end)

    describe("CombatMath.mitigate (armor curve)", function()
        it("no armor takes full damage", function()
            expect(CombatMath.mitigate(100, 0, 100)).to.equal(100)
            expect(CombatMath.mitigate(100, nil, 100)).to.equal(100)
        end)

        it("armor == k halves the damage", function()
            expect(CombatMath.mitigate(100, 100, 100)).to.near(50, 1e-6)
        end)

        it("3k armor leaves a quarter (diminishing returns, no hard cap)", function()
            expect(CombatMath.mitigate(100, 300, 100)).to.near(25, 1e-6)
        end)

        it("more armor always helps but never reaches immunity", function()
            local a = CombatMath.mitigate(100, 100, 100)
            local b = CombatMath.mitigate(100, 1000, 100)
            expect(b < a).to.equal(true)
            expect(b > 0).to.equal(true)
        end)

        it("never returns negative", function()
            expect(CombatMath.mitigate(0, 500, 100)).to.equal(0)
        end)
    end)
end
