-- Merge Defense combat XP follows relative time-to-kill after a paid rebirth.
--
-- The ordinary combat curve already compares enemy level with earned player level. Merge enemies
-- intentionally keep that shared level while their HP grows by combat layer/endless cycle and
-- allied DPS grows through durable Rebirth, Damage, and Fire Rate bonuses. Without this second,
-- Merge-only ratio, a reset to Wave 1 looks like an even-level fight and pays full XP despite being
-- cleared many times faster than the baseline run.

local MergeEggXpYield = {}

local function positive(value, fallback)
    local resolved = tonumber(value)
    if resolved == nil or resolved <= 0 then
        return fallback
    end
    return resolved
end

function MergeEggXpYield.enemyHpMultiplier(combatLayers, waveIndex, wave)
    local resolvedWave = math.max(1, math.floor(tonumber(waveIndex) or 1))
    local layerMultiplier = 1
    for _, layer in ipairs(type(combatLayers) == "table" and combatLayers or {}) do
        local throughWave = math.max(1, math.floor(tonumber(layer.through_wave) or resolvedWave))
        if resolvedWave <= throughWave then
            layerMultiplier = positive((layer.enemy or {}).hp_multiplier, 1)
            break
        end
    end
    local waveMultiplier = positive(
        type(wave) == "table" and type(wave.enemy) == "table" and wave.enemy.hp_multiplier,
        1
    )
    return layerMultiplier * waveMultiplier
end

function MergeEggXpYield.resolve(config, context)
    config = type(config) == "table" and config or {}
    context = type(context) == "table" and context or {}

    local enemyDifficultyMultiplier = positive(context.enemyHpMultiplier, 1)
    local alliedDamageMultiplier = positive(context.alliedDamageMultiplier, 1)
    local alliedCadenceMultiplier = positive(context.alliedCadenceMultiplier, 1)
    local rebirthCount = math.max(0, math.floor(tonumber(context.rebirthCount) or 0))
    local alliedOffenseMultiplier = alliedDamageMultiplier
    if config.include_allied_cadence ~= false then
        alliedOffenseMultiplier *= alliedCadenceMultiplier
    end

    local neutral = {
        multiplier = 1,
        enemyDifficultyMultiplier = enemyDifficultyMultiplier,
        alliedOffenseMultiplier = alliedOffenseMultiplier,
        relativeDifficulty = enemyDifficultyMultiplier / alliedOffenseMultiplier,
    }
    if config.enabled ~= true then
        return neutral
    end
    if config.after_rebirth_only ~= false and rebirthCount <= 0 then
        return neutral
    end

    local minimum = math.clamp(positive(config.minimum_multiplier, 0.05), 0, 1)
    local maximum = math.max(minimum, positive(config.maximum_multiplier, 1))
    local fullYieldDifficulty = positive(config.full_yield_difficulty_ratio, 1)
    local relativeDifficulty = enemyDifficultyMultiplier / alliedOffenseMultiplier
    local multiplier = math.clamp(relativeDifficulty / fullYieldDifficulty, minimum, maximum)
    return {
        multiplier = multiplier,
        enemyDifficultyMultiplier = enemyDifficultyMultiplier,
        alliedOffenseMultiplier = alliedOffenseMultiplier,
        relativeDifficulty = relativeDifficulty,
    }
end

function MergeEggXpYield.multiplier(config, context)
    return MergeEggXpYield.resolve(config, context).multiplier
end

return MergeEggXpYield
