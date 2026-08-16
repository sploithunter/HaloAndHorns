local BestPetSelector = loadModule("src/Shared/Inventory/BestPetSelector.lua")

local function pet(key, role, damage, health, abilities)
    return {
        key = key,
        role = role,
        damage = damage,
        health = health,
        abilities = abilities,
        available = true,
    }
end

return function()
    describe("BestPetSelector damage and tank roles", function()
        it("uses combat damage for ranged and melee", function()
            local weak = pet("weak", "ranged", 20, 500)
            local strong = pet("strong", "ranged", 40, 100)
            expect(BestPetSelector.best({ weak, strong }, "ranged").key).to.equal("strong")
        end)

        it("uses effective health for tanks", function()
            local damageTank = pet("damage", "tank", 80, 500)
            local durableTank = pet("durable", "tank", 40, 900)
            expect(BestPetSelector.best({ damageTank, durableTank }, "tank").key).to.equal(
                "durable"
            )
        end)
    end)

    describe("BestPetSelector support roles", function()
        it("prioritizes AOE support before targeted support", function()
            local targetedHeal = pet("single-heal", "support", 10, 100, {
                { kind = "heal", scope = "single", fraction = 0.5 },
            })
            local teamDefense = pet("team-defense", "support", 10, 100, {
                { kind = "defense", scope = "aura", amount = 10 },
            })
            expect(BestPetSelector.best({ targetedHeal, teamDefense }, "support").key).to.equal(
                "team-defense"
            )
        end)

        it("puts healing first within the same scope", function()
            local offense = pet("offense", "support", 20, 100, {
                { kind = "offense", scope = "aura", mult = 2 },
            })
            local heal = pet("heal", "support", 10, 100, {
                { kind = "heal", scope = "aura", fraction = 0.05 },
            })
            expect(BestPetSelector.best({ offense, heal }, "support").key).to.equal("heal")
        end)
    end)

    describe("BestPetSelector control roles", function()
        it("prioritizes AOE control before single-target control", function()
            local singleHold = pet("single-hold", "control", 10, 100, {
                { kind = "hold", scope = "single", duration = 10 },
            })
            local areaRoot = pet("area-root", "control", 10, 100, {
                { kind = "root", scope = "targeted_aoe", duration = 2 },
            })
            expect(BestPetSelector.best({ singleHold, areaRoot }, "control").key).to.equal(
                "area-root"
            )
        end)

        it("puts full holds first within the same scope", function()
            local root = pet("root", "control", 20, 100, {
                { kind = "root", scope = "single", duration = 20 },
            })
            local hold = pet("hold", "control", 10, 100, {
                { kind = "hold", scope = "single", duration = 2 },
            })
            expect(BestPetSelector.best({ root, hold }, "control").key).to.equal("hold")
        end)

        it("ignores unavailable and wrong-role candidates", function()
            local unavailable = pet("unavailable", "control", 100, 100, {
                { kind = "hold", scope = "aura" },
            })
            unavailable.available = false
            local wrongRole = pet("wrong", "support", 100, 100, {
                { kind = "hold", scope = "aura" },
            })
            local eligible = pet("eligible", "control", 1, 1, {
                { kind = "slow", scope = "single" },
            })
            expect(BestPetSelector.best({ unavailable, wrongRole, eligible }, "control").key).to.equal(
                "eligible"
            )
        end)
    end)
end
