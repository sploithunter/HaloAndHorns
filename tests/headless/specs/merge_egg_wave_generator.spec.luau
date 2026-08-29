local WaveGenerator = loadModule("src/Shared/Game/MergeEggWaveGenerator.lua")
local prototype = loadModule("configs/merge_egg_prototype.lua")

local function archetypeCount(wave, archetype)
    local total = 0
    for _, group in ipairs(wave.groups or {}) do
        for _, unit in ipairs(group.units or {}) do
            if unit.archetype == archetype then
                total += unit.count
            end
        end
    end
    return total
end

return function()
    describe("Merge Egg endless wave generation", function()
        it("preserves authored waves and exposes a practical endless ceiling", function()
            local authored = { { id = "known" } }
            local config = {
                enabled = true,
                start_wave = 2,
                maximum_wave = 999999,
                cycle = {
                    {
                        groups = {
                            {
                                units = {
                                    { archetype = "brute", count = 1 },
                                    { archetype = "whelp", count = 3 },
                                },
                            },
                        },
                    },
                },
            }
            expect(WaveGenerator.wave(authored, config, 1)).to.equal(authored[1])
            expect(WaveGenerator.waveCount(authored, config)).to.equal(999999)
            expect(WaveGenerator.wave(authored, config, 1000000)).to.equal(nil)
        end)

        it(
            "promotes existing bodies and scales additively without growing the model count",
            function()
                local authored = { { id = "known" } }
                local config = {
                    enabled = true,
                    start_wave = 2,
                    maximum_wave = 100,
                    scaling = {
                        hp_per_cycle = 0.3,
                        damage_per_cycle = 0.12,
                        reward_per_cycle = 0.4,
                    },
                    promotions = {
                        lieutenants_per_group_per_cycle = 1,
                        maximum_lieutenants_per_group = 4,
                        boss_every_cycles = 2,
                        maximum_bosses_per_wave = 2,
                    },
                    cycle = {
                        {
                            groups = {
                                {
                                    units = {
                                        { archetype = "brute", count = 1 },
                                        { archetype = "whelp", count = 3 },
                                    },
                                },
                            },
                        },
                    },
                }
                local first = WaveGenerator.wave(authored, config, 2)
                local second = WaveGenerator.wave(authored, config, 3)
                local third = WaveGenerator.wave(authored, config, 4)
                expect(WaveGenerator.count(first)).to.equal(4)
                expect(WaveGenerator.count(second)).to.equal(4)
                expect(WaveGenerator.count(third)).to.equal(4)
                expect(archetypeCount(first, "whelp")).to.equal(3)
                expect(archetypeCount(second, "whelp")).to.equal(2)
                expect(archetypeCount(second, "lieutenant")).to.equal(1)
                expect(archetypeCount(third, "boss")).to.equal(1)
                expect(second.enemy.hp_multiplier).to.equal(1.3)
                expect(second.enemy.damage_multiplier).to.equal(1.12)
                expect(second.enemy.reward_multiplier).to.equal(1.4)
            end
        )

        it("keeps every configured generated wave under the Studio body cap", function()
            local authored = prototype.waves
            local endless = prototype.endless_waves
            expect(#authored).to.equal(20)
            expect(#endless.cycle).to.equal(10)
            for waveIndex = 21, 80 do
                local wave = WaveGenerator.wave(authored, endless, waveIndex)
                expect(wave.generated).to.equal(true)
                expect(WaveGenerator.count(wave) <= prototype.enemy.maximum_wave_enemies).to.equal(
                    true
                )
            end
        end)
    end)
end
