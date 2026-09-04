local DamageScope = loadModule("src/Shared/Game/MergeEggDamageScope.lua")
local Rebirth = loadModule("src/Shared/Game/MergeEggRebirth.lua")
local WaveGenerator = loadModule("src/Shared/Game/MergeEggWaveGenerator.lua")
local XpYield = loadModule("src/Shared/Game/MergeEggXpYield.lua")
local config = loadModule("configs/merge_egg_prototype.lua")

local stage = config.progression_loop.stages.home
local yieldConfig = config.rewards.combat_xp_yield

local function waveAt(waveIndex)
    return WaveGenerator.wave(config.waves, config.endless_waves, waveIndex)
end

local function resolve(rebirthCount, waveIndex, damageLevel, fireRateLevel)
    local damageDefinition = config.management_upgrades.definitions.damage
    local fireRateDefinition = config.management_upgrades.definitions.fire_rate
    local managementDamage = 1 + (damageLevel or 0) * damageDefinition.step
    local managementFireRate = 1 + (fireRateLevel or 0) * fireRateDefinition.step
    local rebirthDamage = Rebirth.damageMultiplier(config.rebirth, rebirthCount)
    local alliedDamage = DamageScope.additiveUpgradeMultiplier(managementDamage, rebirthDamage)
    return XpYield.resolve(yieldConfig, {
        rebirthCount = rebirthCount,
        enemyHpMultiplier = XpYield.enemyHpMultiplier(
            stage.combat_layers,
            waveIndex,
            waveAt(waveIndex)
        ),
        alliedDamageMultiplier = alliedDamage,
        alliedCadenceMultiplier = managementFireRate,
    })
end

local function firstFullYieldWave(rebirthCount, damageLevel, fireRateLevel, maximumWave)
    for waveIndex = 1, maximumWave do
        if resolve(rebirthCount, waveIndex, damageLevel, fireRateLevel).multiplier >= 1 then
            return waveIndex
        end
    end
    return nil
end

return function()
    describe("Merge Egg post-rebirth combat XP yield", function()
        it("leaves the first run unchanged", function()
            expect(yieldConfig.simulation_player_pet_kill_share).to.equal(0.5)
            expect(resolve(0, 1).multiplier).to.equal(1)
            expect(resolve(0, 1000, 20, 20).multiplier).to.equal(1)
        end)

        it("cubes easy post-rebirth fights and restores full XP when HP catches up", function()
            expect(resolve(1, 1).multiplier).to.equal(0.125)
            expect(resolve(1, 10).multiplier).to.equal(0.125)
            expect(resolve(1, 11).multiplier).to.equal(1)
        end)

        it("fits the live Rank 10 Wave 30 checkpoint at one fifth of its former XP", function()
            local result = resolve(9, 30)
            expect(result.relativeDifficulty).to.equal(0.45)
            expect(result.difficultyExponent).to.equal(3)
            expect(result.multiplier).to.be.near(0.091125)
            expect(result.multiplier / result.relativeDifficulty).to.be.near(0.2025)
        end)

        it("includes persistent Damage and Fire Rate in relative time-to-kill", function()
            local result = resolve(1, 1, 9, 9)
            expect(result.enemyDifficultyMultiplier).to.equal(1)
            expect(result.alliedOffenseMultiplier).to.be.near(3.5525)
            expect(result.multiplier).to.equal(yieldConfig.minimum_multiplier)
        end)

        it("keeps extreme-rank opening kills visible without making them full value", function()
            local result = resolve(49, 1, 20, 20)
            expect(result.multiplier).to.equal(yieldConfig.minimum_multiplier)
        end)

        it(
            "guarantees difficulty overtakes every authored rebirth rank within 1000 waves",
            function()
                local damageMax = config.management_upgrades.definitions.damage.max_level
                local fireRateMax = config.management_upgrades.definitions.fire_rate.max_level
                local latest
                for rebirthCount = 1, config.rebirth.max_rank - 1 do
                    local catchUp = firstFullYieldWave(rebirthCount, damageMax, fireRateMax, 1000)
                    expect(catchUp).to.be.ok()
                    latest = math.max(latest or 0, catchUp)
                end
                expect(latest).to.equal(421)
            end
        )

        it("falls back safely for disabled or malformed tuning", function()
            expect(XpYield.multiplier(nil, nil)).to.equal(1)
            expect(XpYield.multiplier({ enabled = false }, {
                rebirthCount = 20,
                enemyHpMultiplier = 0,
                alliedDamageMultiplier = "bad",
            })).to.equal(1)
        end)
    end)
end
