-- Export only the source-backed slice. Runtime assets and source files stay outside Spawn's tree.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local source = fs.readFile("configs/merge_egg_prototype.lua")
-- This one dependency is presentation-only; the exported subset does not read tier_art.
source = source:gsub("require%(script.Parent.merge_tier_art%)", "{}")
local config = assert(loadstring(source, "merge_egg_prototype"))()
local pricing = require("../../src/Shared/Game/MergeEggPricing")
local combat = require("../../src/Shared/Game/CombatMath")
local waves = require("../../src/Shared/Game/MergeEggWaveGenerator")
local tuning = serde.decode("json", fs.readFile("configs/spawn_merge_bay.json"))
local data = {
    source = { config = "configs/merge_egg_prototype.lua", version = config.version },
    tuning = tuning,
    economy = {
        basePrice = config.team.earth_egg_pricing.base_amount,
        firstUpgradedPrice = config.team.base_egg_generator.first_upgraded_egg_cost,
        growth = config.team.base_egg_generator.egg_cost_growth,
        upgradeMultiplier = config.team.base_egg_generator.upgrade_proposed_egg_value_multiplier,
        mergeRatio = config.team.merge_board.merge_ratio,
        openingCoins = config.opening_economy.pickup_amount
            * #config.opening_economy.pickup_offsets,
    },
    objective = config.objective,
    rewards = config.rewards,
    checkpoints = config.checkpoints,
    earlyDifficulty = config.early_wave_difficulty,
    archetypes = config.enemy.archetypes,
    petsPerHatcher = config.team.positions_by_egg_tier,
    waves = {},
}
for i = 1, 10 do
    data.waves[i] = config.waves[i]
end
local fixtures = { prices = {}, mitigation = {}, difficulty = {}, waveCounts = {} }
for tier = 1, 8 do
    table.insert(fixtures.prices, {
        tier = tier,
        amount = tier == 1 and data.economy.basePrice or pricing.doublingTierCost(
            data.economy.firstUpgradedPrice,
            data.economy.growth,
            tier,
            2
        ),
    })
end
for _, damage in ipairs({ 0, 1, 30, 100, 999 }) do
    for _, armor in ipairs({ 0, 30, 80, 160 }) do
        table.insert(
            fixtures.mitigation,
            { damage = damage, armor = armor, k = 100, result = combat.mitigate(damage, armor, 100) }
        )
    end
end
for _, wave in ipairs({ 1, 2, 5, 10, 15, 20, 30, 45, 60, 100 }) do
    local hp, damage = waves.earlyDifficulty(config.early_wave_difficulty, wave)
    table.insert(fixtures.difficulty, { wave = wave, hp = hp, damage = damage })
end
for i, wave in ipairs(data.waves) do
    table.insert(fixtures.waveCounts, { wave = i, count = waves.count(wave) })
end
fs.writeFile("ports/spawn/world/scripts/lib/data/merge.yml", serde.encode("json", data, true))
fs.writeFile("ports/spawn/tests/fixtures.json", serde.encode("json", fixtures, true))
print(
    "Exported canonical opening waves, prices, rewards and "
        .. tostring(#fixtures.mitigation)
        .. " combat cases"
)
