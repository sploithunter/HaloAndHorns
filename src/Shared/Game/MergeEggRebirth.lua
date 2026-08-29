-- Pure progression policy for Merge Defense rebirths.
--
-- Rebirth ranks are deliberately authored rather than extrapolated. Players begin at Rank 1 for
-- free; the persisted count records paid rebirths, so count 0 is Rank 1, count 1 is Rank 2, and so
-- on. Keeping those concepts separate preserves existing saves without exposing a Rank 0.

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

function MergeEggRebirth.damageMultiplier(config, count)
    config = type(config) == "table" and config or {}
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
