local Rules = loadModule("src/Shared/Game/CrossroadsArenaRules.lua")
local Population = loadModule("src/Shared/Worldgen/MissionPopulation.lua")
local cfg = loadModule("configs/crossroads_arena.lua")
local missions = loadModule("configs/missions.lua")
local pets = loadModule("configs/pets.lua")
local roles = loadModule("configs/pet_roles.lua")
local Leash = loadModule("src/Shared/Game/EnemyLeash.lua")
return function()
    describe("Crossroads arena", function()
        it("fields only configured species at the player's content level", function()
            for _, level in ipairs({ 1, 4, 5, 14, 32, 50 }) do
                for seed = 1, 20 do
                    local plan = Rules.plan(cfg, missions, level, 1, 1, seed, Population)
                    expect(plan.team.min_level <= level and plan.team.max_level >= level).to.equal(
                        true
                    )
                    for _, unit in ipairs(plan.units) do
                        expect(pets.pets[unit.pet] ~= nil).to.equal(true)
                        expect(missions.pet_ranks[unit.rank] ~= nil).to.equal(true)
                    end
                end
            end
        end)
        it("keeps every arena team combat-capable with a frontline boss", function()
            for _, team in ipairs(cfg.teams) do
                local hitters = 0
                for _, unit in ipairs(team.packs[1].units) do
                    if roles.by_type[unit.pet] ~= "support" then
                        hitters += 1
                    end
                    if unit.rank == "boss" then
                        expect(roles.by_type[unit.pet]).to.equal("tank")
                    end
                end
                expect(hitters >= 2).to.equal(true)
            end
        end)
        it("honors group settings and team scaling without overrunning the arena", function()
            for seed = 1, 100 do
                local low = Rules.plan(cfg, missions, 14, 0.25, 1, seed, Population)
                local high = Rules.plan(cfg, missions, 14, 2, 8, seed, Population)
                expect(low.groupScale).to.equal(0.25)
                expect(high.groupScale).to.equal(2)
                expect(#high.units >= #low.units).to.equal(true)
                expect(#high.units <= cfg.max_enemies).to.equal(true)
                local bosses = 0
                for _, unit in ipairs(low.units) do
                    if unit.rank == "boss" or unit.rank == "titan" then
                        bosses += 1
                    end
                end
                expect(bosses).to.equal(1)
            end
        end)
        it(
            "uses the Trials boss and villain egg chances without modifying mission config",
            function()
                for _, team in ipairs(cfg.teams) do
                    local source = missions.missions[team.egg_mission].boss_egg
                    expect(Rules.egg(missions, team, "trash_mob")).to.equal(nil)
                    expect(Rules.egg(missions, team, "boss").chance).to.equal(source.chance)
                    local premium = Rules.egg(missions, team, "archvillain")
                    expect(premium.chance).to.equal(
                        missions.player_tuning.boss_budget.villain.egg_chance
                    )
                    expect(source.chance < premium.chance).to.equal(true)
                end
            end
        )
        it(
            "keeps low-level rank stats gentle and uses full tuning from Trials level onward",
            function()
                local lowHp, lowDmg = Rules.onramp(cfg, 1)
                local fullHp, fullDmg = Rules.onramp(cfg, 14)
                expect(lowHp < fullHp and lowDmg < fullDmg).to.equal(true)
                expect(fullHp).to.equal(1)
                expect(fullDmg).to.equal(1)
            end
        )
        it(
            "contains every sampled displacement inside the outer edge with body clearance",
            function()
                local shapes = { { kind = "box", cx = -8072, cz = 8, halfX = 32, halfZ = 51 } }
                for radius = 1, 12 do
                    for angle = 0, 359, 5 do
                        local theta = math.rad(angle)
                        local x, z = Leash.clamp(
                            -8072 + math.cos(theta) * 1000,
                            8 + math.sin(theta) * 1000,
                            shapes,
                            cfg.enemy_inset + radius
                        )
                        expect(Leash.inside(x, z, shapes, radius)).to.equal(true)
                    end
                end
            end
        )
    end)
end
