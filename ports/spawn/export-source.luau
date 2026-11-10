-- Export only the source-backed slice. Runtime assets and source files stay outside Spawn's tree.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local source = fs.readFile("configs/merge_egg_prototype.lua")
-- This one dependency is presentation-only; the exported subset does not read tier_art.
source = source:gsub("require%(script.Parent.merge_tier_art%)", "{}")
local config = assert(loadstring(source, "merge_egg_prototype"))()
local pricing = require("../../src/Shared/Game/MergeEggPricing")
local formatSource = fs.readFile("src/Shared/Game/MergeEggCostFormat.lua")
local moneyFormat = assert(
    loadstring(
        formatSource:gsub(
            "return MergeEggCostFormat",
            "return {format=MergeEggCostFormat.format,notations=SUFFIXES}"
        ),
        "cost-format"
    )
)()
local combat = require("../../src/Shared/Game/CombatMath")
local waves = require("../../src/Shared/Game/MergeEggWaveGenerator")
local pets = assert(
    loadstring("local Vector3,Color3=...\n" .. fs.readFile("configs/pets.lua"), "pets")
)(roblox.Vector3, roblox.Color3)
local follow = assert(
    loadstring("local Vector3,Color3=...\n" .. fs.readFile("configs/pet_follow.lua"), "pet_follow")
)(roblox.Vector3, roblox.Color3)
local animations = assert(loadstring(fs.readFile("configs/animations.lua"), "animations"))()
local roles = assert(loadstring(fs.readFile("configs/pet_roles.lua"), "pet_roles"))()
local formation = require("../../src/Shared/Game/PetFormation")
local motion = require("../../src/Shared/Game/PetAttackMotion")
local hitReact = require("../../src/Shared/Game/HitReact")
local strikeDefaults = motion.resolve({}, "", "")
strikeDefaults.fn = nil
local stage = config.progression_loop.stages[config.progression_loop.default_stage]
local tiers = {}
local elements = {}
for _, areas in pairs(pets.realm_area_eggs) do
    for area, eggId in pairs(areas) do
        if follow.ranged_bolt.melee_by_element[area] then
            elements[eggId] = area
        end
    end
end
for tier, eggId in ipairs(stage.egg_progression) do
    local egg = assert(pets.egg_sources[eggId], eggId)
    local huge = tier >= config.team.prototype_huge_progression.start_tier
    table.insert(tiers, {
        tier = tier,
        eggId = eggId,
        name = (huge and "Huge " or "") .. egg.name,
        huge = huge,
        element = assert(elements[eggId], eggId),
        positions = stage.team_positions_by_egg_tier[tier],
        draftRolls = stage.draft_rolls_by_tier[tier],
        color = string.format(
            "#%02x%02x%02x",
            table.unpack(
                config.team.merge_board.slot_colors[(tier - 1) % #config.team.merge_board.slot_colors + 1]
            )
        ),
        mesh = egg.mesh_asset,
        texture = egg.texture_asset,
        model = egg.asset_id,
    })
end
local tuning = serde.decode("json", fs.readFile("configs/spawn_merge_bay.json"))
local data = {
    source = { config = "configs/merge_egg_prototype.lua", version = config.version },
    tuning = tuning,
    tiers = tiers,
    managementBoard = config.world.management_board,
    eggHeight = config.team.merge_board.egg_height * tuning.scene.sourceTransform.metersPerStud,
    progression = {
        stage = config.progression_loop.default_stage,
        normalTiers = config.team.prototype_huge_progression.normal_tier_count,
        hugeStart = config.team.prototype_huge_progression.start_tier,
    },
    presentation = {
        combatText = follow.ranged_bolt.combat_text,
        melee = follow.ranged_bolt.melee_by_element,
        animation = animations.attack,
        costNotations = moneyFormat.notations,
        attack = follow.attack,
        formation = follow.formation,
        roles = roles,
        strikeDefaults = strikeDefaults,
        hitReact = { duration = hitReact.DURATION, recoil = hitReact.RECOIL, yaw = hitReact.YAW },
    },
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
    petsPerHatcher = stage.team_positions_by_egg_tier,
    waves = {},
}
for i = 1, 10 do
    data.waves[i] = config.waves[i]
end
local fixtures = {
    prices = {},
    generatorUpgrades = {},
    costLabels = {},
    tiers = tiers,
    mitigation = {},
    difficulty = {},
    waveCounts = {},
    formations = {},
    strikes = {},
}
for _, style in ipairs({
    "static_ring",
    "orbit",
    "lunge",
    "spiral",
    "pincer",
    "firing_line",
    "swarm",
}) do
    local attack = table.clone(follow.attack)
    attack.style = style
    attack.angle_offset = 0.23
    for _, count in ipairs({ 1, 3, 9 }) do
        for _, phase in ipairs({ 0, 0.37, 2 }) do
            for index = 1, count do
                table.insert(fixtures.formations, {
                    style = style,
                    count = count,
                    phase = phase,
                    index = index,
                    angle = attack.angle_offset,
                    result = formation.attackOffset(index, count, phase, attack),
                })
            end
        end
    end
end
for _, pair in ipairs({
    { "melee", "doggy" },
    { "tank", "bear" },
    { "ranged", "kitty" },
    { "support", "bunny" },
    { "control", "snowfox" },
}) do
    local profile = motion.resolve(follow.attack.strike_motion, pair[1], pair[2])
    for _, fraction in ipairs({ 0, 0.1, 0.25, 0.5, 0.9, 1, 1.5 }) do
        table.insert(fixtures.strikes, {
            role = pair[1],
            petType = pair[2],
            elapsed = fraction * profile.duration,
            result = motion.sample(profile, fraction * profile.duration),
            sidestepOdd = motion.advanceSidestep(0.2, profile, 1),
            sidestepEven = motion.advanceSidestep(0.2, profile, 2),
        })
    end
end
for tier = 1, #tiers do
    local value = tier == 1 and data.economy.basePrice
        or pricing.doublingTierCost(data.economy.firstUpgradedPrice, data.economy.growth, tier, 2)
    table.insert(fixtures.costLabels, { value = value, label = moneyFormat.format(value) })
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
for tier = 1, #tiers - 1 do
    local amount =
        pricing.doublingTierCost(data.economy.firstUpgradedPrice, data.economy.growth, tier + 1, 2)
    table.insert(fixtures.generatorUpgrades, {
        tier = tier,
        amount = pricing.generatorUpgradeCost(
            amount,
            tuning.hatcherCount,
            data.economy.upgradeMultiplier
        ),
    })
end
for _, damage in ipairs({ 0, 1, 30, 100, 999 }) do
    for _, armor in ipairs({ 0, 30, 80, 160 }) do
        table.insert(fixtures.mitigation, {
            damage = damage,
            armor = armor,
            k = 100,
            result = combat.mitigate(damage, armor, 100),
        })
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
