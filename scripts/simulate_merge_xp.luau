--!nocheck
--[[
    Offline Merge Defense XP / rebirth safety simulator (Lune; no Studio).

    It loads the shipping Lua configs and pure gameplay modules, then advances the real authored
    opening and endless wave generator. The report answers three separate questions:

      * How much XP is expected when durable player pets secure the configured share of final hits?
      * At what wave does enemy HP catch the current rank's persistent Merge DPS advantage?
      * What is the earliest theoretical wave that could fund the next rebirth if the player spent
        no Waycoins and collected every defeated-enemy drop? (A deliberately optimistic bound.)

    Examples:
      mise exec -- lune run scripts/simulate_merge_xp.luau
      mise exec -- lune run scripts/simulate_merge_xp.luau --rank 10 --level 28 --waves 1000
      mise exec -- lune run scripts/simulate_merge_xp.luau --rank 10 --level 40 --checkpoint-wave 30
      mise exec -- lune run scripts/simulate_merge_xp.luau --all-ranks --damage-level 20 --fire-rate-level 20
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local moduleCache = {}
local loadModule

local function makeEnv(extra)
    local env = {
        assert = assert,
        error = error,
        ipairs = ipairs,
        next = next,
        pairs = pairs,
        pcall = pcall,
        print = print,
        warn = warn,
        select = select,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        typeof = typeof,
        table = table,
        string = string,
        math = math,
        os = os,
        setmetatable = setmetatable,
        getmetatable = getmetatable,
        Color3 = {
            new = function()
                return {}
            end,
            fromRGB = function()
                return {}
            end,
            fromHSV = function()
                return {}
            end,
        },
        Vector2 = {
            new = function(x, y)
                return { x = x, y = y }
            end,
        },
        Vector3 = {
            new = function(x, y, z)
                return { x = x, y = y, z = z }
            end,
        },
        UDim = {
            new = function()
                return {}
            end,
        },
        UDim2 = {
            new = function()
                return {}
            end,
            fromScale = function()
                return {}
            end,
            fromOffset = function()
                return {}
            end,
        },
        NumberRange = {
            new = function(minimum, maximum)
                return { Min = minimum, Max = maximum or minimum }
            end,
        },
        Enum = setmetatable({}, {
            __index = function()
                return setmetatable({}, {
                    __index = function()
                        return {}
                    end,
                })
            end,
        }),
    }
    for key, value in extra or {} do
        env[key] = value
    end
    return env
end

function loadModule(path)
    if moduleCache[path] ~= nil then
        return moduleCache[path]
    end
    local source = fs.readFile(path)
    local directory = path:match("^(.*)/[^/]+$") or "."
    local env = makeEnv({
        require = function(target)
            if type(target) == "string" then
                return loadModule(target)
            end
            error("non-pure require in " .. path)
        end,
        script = {
            Parent = setmetatable({}, {
                __index = function(_, name)
                    return `{directory}/{name}.lua`
                end,
            }),
        },
    })
    local export = luau.load(source, { debugName = path, environment = env })()
    moduleCache[path] = export
    return export
end

local config = loadModule("configs/merge_egg_prototype.lua")
local leveling = loadModule("configs/leveling.lua")
local DamageScope = loadModule("src/Shared/Game/MergeEggDamageScope.lua")
local Pricing = loadModule("src/Shared/Game/MergeEggPricing.lua")
local Rebirth = loadModule("src/Shared/Game/MergeEggRebirth.lua")
local WaveGenerator = loadModule("src/Shared/Game/MergeEggWaveGenerator.lua")
local XpReward = loadModule("src/Shared/Game/XpReward.lua")
local XpYield = loadModule("src/Shared/Game/MergeEggXpYield.lua")

local options = {
    waves = 1000,
    level = 28,
    rank = nil,
    allRanks = false,
    damageLevel = 0,
    fireRateLevel = 0,
    coinLevel = 0,
    checkpointWave = nil,
    killShare = tonumber(config.rewards.combat_xp_yield.simulation_player_pet_kill_share) or 0.5,
}

local function numericOption(index, name)
    local value = tonumber(process.args[index + 1])
    assert(value ~= nil, name .. " expects a number")
    return value
end

do
    local index = 1
    while index <= #process.args do
        local arg = process.args[index]
        if arg == "--waves" then
            options.waves = math.max(1, math.floor(numericOption(index, arg)))
            index += 2
        elseif arg == "--level" then
            options.level = math.max(1, math.floor(numericOption(index, arg)))
            index += 2
        elseif arg == "--rank" then
            options.rank = math.max(1, math.floor(numericOption(index, arg)))
            index += 2
        elseif arg == "--all-ranks" then
            options.allRanks = true
            index += 1
        elseif arg == "--damage-level" then
            options.damageLevel = math.max(0, math.floor(numericOption(index, arg)))
            index += 2
        elseif arg == "--fire-rate-level" then
            options.fireRateLevel = math.max(0, math.floor(numericOption(index, arg)))
            index += 2
        elseif arg == "--coin-level" then
            options.coinLevel = math.max(0, math.floor(numericOption(index, arg)))
            index += 2
        elseif arg == "--checkpoint-wave" then
            options.checkpointWave = math.max(1, math.floor(numericOption(index, arg)))
            index += 2
        elseif arg == "--kill-share" then
            options.killShare = math.clamp(numericOption(index, arg), 0, 1)
            index += 2
        elseif arg == "--help" or arg == "-h" then
            print("See the examples at the top of scripts/simulate_merge_xp.luau")
            return
        else
            error("unknown argument: " .. tostring(arg))
        end
    end
end

local stage = config.progression_loop.stages.home
local rewardConfig = config.rewards
local yieldConfig = rewardConfig.combat_xp_yield
local archetypes = config.enemy.archetypes
local rankTiers = config.combat_level.rank_tiers

local function upgradeMultiplier(id, level)
    local definition = config.management_upgrades.definitions[id]
    local capped = math.min(math.max(0, level), math.max(0, definition.max_level or level))
    return 1 + capped * math.max(0, tonumber(definition.step) or 0)
end

local function waveAt(waveIndex)
    return WaveGenerator.wave(config.waves, config.endless_waves, waveIndex)
end

local function layerAt(waveIndex)
    for _, layer in stage.combat_layers or {} do
        if waveIndex <= math.max(1, math.floor(tonumber(layer.through_wave) or options.waves)) then
            return layer
        end
    end
    return stage
end

local function rewardMultiplier(waveIndex, wave)
    local layer = layerAt(waveIndex)
    return math.max(0, tonumber((layer.enemy or {}).reward_multiplier) or 1)
        * math.max(0, tonumber(((wave or {}).enemy or {}).reward_multiplier) or 1)
end

local function contextFor(rank, waveIndex, damageLevel, fireRateLevel)
    local rebirthCount = rank - 1
    local rebirthDamage = Rebirth.damageMultiplier(config.rebirth, rebirthCount)
    local managementDamage = upgradeMultiplier("damage", damageLevel)
    local openingHp = WaveGenerator.earlyDifficulty(config.early_wave_difficulty, waveIndex)
    return XpYield.resolve(yieldConfig, {
        rebirthCount = rebirthCount,
        enemyHpMultiplier = XpYield.enemyHpMultiplier(
            stage.combat_layers,
            waveIndex,
            waveAt(waveIndex)
        ) * openingHp,
        alliedDamageMultiplier = DamageScope.additiveUpgradeMultiplier(
            managementDamage,
            rebirthDamage
        ),
        alliedCadenceMultiplier = upgradeMultiplier("fire_rate", fireRateLevel),
    })
end

local function forEachUnit(wave, callback)
    for _, group in wave.groups or {} do
        for _, unit in group.units or {} do
            local count = math.max(1, math.floor(tonumber(unit.count) or 1))
            callback(tostring(unit.archetype), count)
        end
    end
end

local function combatXp(archetypeId, xpMultiplier)
    local archetype = assert(archetypes[archetypeId], "unknown archetype " .. archetypeId)
    local tier = tostring(rankTiers[tostring(archetype.rank or "trash")] or "trash_mob")
    local enemyLevel = options.level + math.max(0, tonumber(leveling.rank_offset[tier]) or 0)
    local rankMultiplier = tonumber(leveling.combat_xp.rank_xp_mult[tier]) or 1
    local xp = XpReward.fromEnemyLevel(enemyLevel, leveling.combat_xp.xp_per_level, rankMultiplier)
    xp = if xp > 0 and xpMultiplier > 0 then math.max(1, math.floor(xp * xpMultiplier)) else 0
    return XpReward.applyOnramp(xp, options.level, leveling.onramp, "combat")
end

local function rewardAmount(archetypeId)
    local archetype = assert(archetypes[archetypeId], "unknown archetype " .. archetypeId)
    local kind = tostring(archetype.reward_kind or "trash")
    return math.max(0, tonumber(rewardConfig[kind .. "_amount"]) or 0)
end

local function tierEggValue(tier)
    local pricing = stage.egg_pricing or config.team.earth_egg_pricing
    if tier <= 1 then
        return math.max(0, math.floor(tonumber(pricing.base_amount) or 100))
    end
    local generator = config.team.base_egg_generator
    return Pricing.doublingTierCost(
        generator.first_upgraded_egg_cost,
        generator.egg_cost_growth,
        tier,
        2
    )
end

local function nextRebirthCost(rank)
    local count = rank - 1
    local nextTier = Rebirth.rankForCount(count) + 1
    return Rebirth.nextCost(config.rebirth, count, tierEggValue(nextTier))
end

local function simulateRank(rank, damageLevel, fireRateLevel, coinLevel)
    local result = {
        rank = rank,
        expectedXp = 0,
        maximumXp = 0,
        grossCoins = config.rebirth.starting_wallet_amount or 0,
        fullYieldWave = nil,
        nextAffordableWave = nil,
    }
    local price = nextRebirthCost(rank)
    result.nextCost = price and price.amount or nil
    local coinMultiplier = Rebirth.scalingMultiplier(config.rebirth, rank - 1, "coins", "amount")
        * upgradeMultiplier("coin_value", coinLevel)

    for waveIndex = 1, options.waves do
        local wave = assert(waveAt(waveIndex), "missing wave " .. waveIndex)
        local xpContext = contextFor(rank, waveIndex, damageLevel, fireRateLevel)
        if not result.fullYieldWave and xpContext.multiplier >= 1 then
            result.fullYieldWave = waveIndex
        end
        if waveIndex == 1 then
            result.openingMultiplier = xpContext.multiplier
            result.openingOffense = xpContext.alliedOffenseMultiplier
        end
        if waveIndex == options.checkpointWave then
            result.checkpointMultiplier = xpContext.multiplier
            result.checkpointRelativeDifficulty = xpContext.relativeDifficulty
        end
        local waveRewardMultiplier = rewardMultiplier(waveIndex, wave)
        forEachUnit(wave, function(archetypeId, count)
            local xp = combatXp(archetypeId, xpContext.multiplier) * count
            result.maximumXp += xp
            result.expectedXp += xp * options.killShare
            local rawCoins = math.floor(rewardAmount(archetypeId) * waveRewardMultiplier)
            result.grossCoins += math.floor(rawCoins * coinMultiplier + 0.5) * count
        end)
        if
            not result.nextAffordableWave
            and result.nextCost
            and result.grossCoins >= result.nextCost
        then
            result.nextAffordableWave = waveIndex
        end
    end
    return result
end

local function commas(value)
    local text = tostring(math.floor((tonumber(value) or 0) + 0.5))
    while true do
        local changed, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        text = changed
        if count == 0 then
            return text
        end
    end
end

local ranks = {}
if options.rank then
    ranks = { math.clamp(options.rank, 1, config.rebirth.max_rank) }
elseif options.allRanks then
    for rank = 1, config.rebirth.max_rank do
        ranks[#ranks + 1] = rank
    end
else
    for _, rank in { 1, 2, 3, 5, 10, 20, 30, 40, 50 } do
        if rank <= config.rebirth.max_rank then
            ranks[#ranks + 1] = rank
        end
    end
end

print(
    string.format(
        "Merge Defense XP simulation | waves 1-%d | player L%d | player-pet kill share %.0f%%",
        options.waves,
        options.level,
        options.killShare * 100
    )
)
print(
    string.format(
        "management: Damage L%d, Fire Rate L%d, Coin Value L%d | rebirth price factor %s",
        options.damageLevel,
        options.fireRateLevel,
        options.coinLevel,
        commas(config.rebirth.indexed_egg_value_multiplier)
    )
)
print(
    "Next-affordable is an optimistic no-spend/all-drops-collected bound, not a predicted play wave.\n"
)
print(
    "Rank | Allied DPS | Wave-1 XP | Full XP at | Expected XP | Max XP | Next cost | Earliest afford"
)
print(
    "-----|------------|-----------|------------|-------------|--------|-----------|----------------"
)
for _, rank in ranks do
    local row = simulateRank(rank, options.damageLevel, options.fireRateLevel, options.coinLevel)
    print(
        string.format(
            "%4d | %10.2fx | %8.1f%% | %10s | %11s | %6s | %9s | %s",
            rank,
            row.openingOffense,
            row.openingMultiplier * 100,
            row.fullYieldWave and ("Wave " .. row.fullYieldWave) or "> horizon",
            commas(row.expectedXp),
            commas(row.maximumXp),
            row.nextCost and commas(row.nextCost) or "MAX",
            row.nextAffordableWave and ("Wave " .. row.nextAffordableWave) or "> horizon"
        )
    )
    if options.checkpointWave then
        print(
            string.format(
                "     checkpoint Wave %d: %.1f%% XP at %.3f relative difficulty",
                options.checkpointWave,
                (row.checkpointMultiplier or 0) * 100,
                row.checkpointRelativeDifficulty or 0
            )
        )
    end
end

local damageMax = config.management_upgrades.definitions.damage.max_level
local fireRateMax = config.management_upgrades.definitions.fire_rate.max_level
local latestWave = 0
local latestRank = 1
local missing = {}
for rank = 2, config.rebirth.max_rank do
    local row = simulateRank(rank, damageMax, fireRateMax, options.coinLevel)
    if not row.fullYieldWave then
        missing[#missing + 1] = rank
    elseif row.fullYieldWave > latestWave then
        latestWave = row.fullYieldWave
        latestRank = rank
    end
end
print("")
if #missing > 0 then
    print(
        string.format(
            "SAFETY FAIL: max persistent DPS did not reach full-XP difficulty by Wave %d at ranks %s",
            options.waves,
            table.concat(missing, ",")
        )
    )
    process.exit(1)
else
    print(
        string.format(
            "SAFETY PASS: every rank is overtaken within the horizon; latest is Rank %d at Wave %d (max Damage/Fire Rate).",
            latestRank,
            latestWave
        )
    )
end
