--[[
    CombatDeath — pick + sample enemy death poses.
]]

local CombatDeath = loadModule("src/Shared/Game/CombatDeath.lua")
local cfg = loadModule("configs/combat_deaths.lua")

local function near(a, b)
    return math.abs(a - b) <= 1e-4
end

return function()
    describe("combat_deaths config", function()
        it("authors seven named styles with sounds and prompts", function()
            expect(#cfg.styles).to.equal(7)
            local seen = {}
            for _, style in ipairs(cfg.styles) do
                expect(type(style.id)).to.equal("string")
                expect(type(style.sound)).to.equal("string")
                expect(type(style.prompt)).to.equal("string")
                expect(#style.prompt > 20).to.equal(true)
                expect(seen[style.id]).to.equal(nil)
                seen[style.id] = true
            end
            expect(seen.flop).to.equal(true)
            expect(seen.launch).to.equal(true)
            expect(seen.robux).to.equal(true)
            local sounds = loadModule("configs/sounds.lua")
            expect(sounds.death_flop.bus).to.equal("effects")
            expect(sounds.death_pop.bus).to.equal("effects")
            local enemy = readFile("src/Server/Services/EnemyService.lua")
            expect(enemy:find("SoundGroups.assign", 1, true)).to.be.ok()
            expect(enemy:find('sound.Name = "DeathSound"', 1, true)).to.be.ok()
        end)

        it("plans a staggered Robux cube scatter", function()
            local style = CombatDeath.styleById(cfg, "robux")
            local seq = { 0.1, 0.8, 0.3, 0.6, 0.2, 0.9, 0.4, 0.7 }
            local i = 0
            local plan = CombatDeath.cubePlan(style, function()
                i += 1
                return seq[((i - 1) % #seq) + 1]
            end)
            expect(#plan).to.equal(style.cubes.count)
            expect(plan[1].delay).to.equal(0)
            expect(plan[2].delay > plan[1].delay).to.equal(true)
            expect(plan[#plan].delay > plan[1].delay).to.equal(true)
            expect(plan[1].lifetime).to.equal(style.cubes.lifetime)
            local moved = false
            for _, step in ipairs(plan) do
                if step.x ~= 0 or step.z ~= 0 then
                    moved = true
                end
            end
            expect(moved).to.equal(true)
        end)
    end)

    describe("CombatDeath", function()
        it("picks by weight and prefers launch/shatter for bosses", function()
            local flop = CombatDeath.pick(cfg, function()
                return 0
            end, {})
            expect(flop.id).to.equal("flop")
            -- launch sits in the high boss-weight band (after sink, before robux).
            local last = CombatDeath.pick(cfg, function()
                return 0.75
            end, { rank = "boss" })
            expect(last.id).to.equal("launch")
        end)

        it("samples every style in 0..1 without NaNs", function()
            for _, style in ipairs(cfg.styles) do
                local pose = CombatDeath.sample(style.id, 0.5)
                expect(pose.scale == pose.scale).to.equal(true)
                expect(pose.fade >= 0).to.equal(true)
                local start = CombatDeath.sample(style.id, 0)
                expect(near(start.y, 0) or start.y >= 0 or start.y <= 0).to.equal(true)
            end
        end)
    end)
end
