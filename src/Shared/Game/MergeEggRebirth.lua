-- Pure progression policy for Merge Defense rebirths.
--
-- Rebirth ranks are deliberately authored rather than extrapolated. Players begin at Rank 1 for
-- free; the persisted count records paid rebirths, so count 0 is Rank 1, count 1 is Rank 2, and so
-- on. Keeping those concepts separate preserves existing saves without exposing a Rank 0.
--
-- Hard rule: rebirth never wipes a Robux purchase or unlock flag. Only
-- authored developer consumables (potions) are spent. Placements reset;
-- entitlements stay.

local MergeEggRebirth = {}

function MergeEggRebirth.normalizeCount(value)
    return math.max(0, math.floor(tonumber(value) or 0))
end

function MergeEggRebirth.rankForCount(count)
    return MergeEggRebirth.normalizeCount(count) + 1
end

function MergeEggRebirth.nextCost(config, count)
    config = type(config) == "table" and config or {}
    if config.enabled ~= true then
        return nil
    end
    local costsByRank = type(config.costs_by_rank) == "table" and config.costs_by_rank or {}
    local nextRank = MergeEggRebirth.rankForCount(count) + 1
    local amount = tonumber(costsByRank[nextRank])
    if not amount then
        return nil
    end
    return {
        amount = math.max(0, math.floor(amount + 0.5)),
        currency = tostring(config.currency or "hall_coins"),
        rank = nextRank,
    }
end

-- Resolve one authored per-rebirth factor. A factor of 2 means the first paid rebirth is 2x and,
-- under additive stacking, the second is 3x. A factor of 1 is an explicit no-change policy. This
-- lets every Merge subsystem declare its own growth axes without burying magic numbers in runtime
-- services (for example cannon power can grow while cannon radius remains exactly 1x).
function MergeEggRebirth.scalingMultiplier(config, count, system, axis)
    config = type(config) == "table" and config or {}
    local factors = config.per_rebirth_factors
    if type(factors) ~= "table" then
        return 1
    end
    local systemName = tostring(system or "")
    local axisName = tostring(axis or "")
    local systemFactors = factors[systemName]
    assert(type(systemFactors) == "table", "Missing rebirth factors for " .. systemName)
    local perRebirthFactor = tonumber(systemFactors[axisName])
    assert(
        perRebirthFactor ~= nil,
        string.format("Missing rebirth factor for %s.%s", systemName, axisName)
    )
    perRebirthFactor = math.max(0, perRebirthFactor)
    local ranks = MergeEggRebirth.normalizeCount(count)
    local stacking = systemFactors.stacking or factors.stacking
    assert(
        stacking == "additive" or stacking == "multiplicative",
        "Missing or invalid rebirth factor stacking"
    )
    if stacking == "multiplicative" then
        return perRebirthFactor ^ ranks
    end
    return 1 + (perRebirthFactor - 1) * ranks
end

function MergeEggRebirth.damageMultiplier(config, count)
    config = type(config) == "table" and config or {}
    local factors = type(config.per_rebirth_factors) == "table" and config.per_rebirth_factors
        or nil
    if factors and type(factors.pets) == "table" and factors.pets.power ~= nil then
        return MergeEggRebirth.scalingMultiplier(config, count, "pets", "power")
    end
    -- Preserve compatibility with older authored configs while the live config uses the unified
    -- factor map above.
    local bonus = math.max(0, tonumber(config.allied_damage_bonus_per_rebirth) or 0)
    local ranks = MergeEggRebirth.normalizeCount(count)
    if tostring(config.damage_stacking or "additive") == "multiplicative" then
        return (1 + bonus) ^ ranks
    end
    return 1 + bonus * ranks
end

function MergeEggRebirth.minimumDeployedTier(config, count)
    config = type(config) == "table" and config or {}
    local requirements = type(config.requirements) == "table" and config.requirements or {}
    local byRank = type(requirements.minimum_deployed_egg_tier_by_rank) == "table"
            and requirements.minimum_deployed_egg_tier_by_rank
        or {}
    local nextRank = MergeEggRebirth.rankForCount(count) + 1
    local tier = tonumber(byRank[nextRank])
    return tier and math.max(1, math.floor(tier)) or nil
end

function MergeEggRebirth.requirementMet(config, count, lowestDeployedTier)
    local required = MergeEggRebirth.minimumDeployedTier(config, count)
    if not required then
        return true, nil
    end
    return math.max(0, math.floor(tonumber(lowestDeployedTier) or 0)) >= required, required
end

return MergeEggRebirth
