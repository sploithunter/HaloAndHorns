-- Pure per-position egg pricing for the Merge an Egg prototype.

local MergeEggPricing = {}

-- Every empty hatcher position starts at tier zero, so its first Earth Egg always uses the base
-- price. Growth applies within one position's later egg/merge tiers, not across other positions.
function MergeEggPricing.eggTierCost(baseAmount, growth, tierIndex)
    local base = math.max(0, math.floor(tonumber(baseAmount) or 0))
    local multiplier = math.max(1, tonumber(growth) or 1)
    local exponent = math.max(0, math.floor(tonumber(tierIndex) or 0))
    return math.max(0, math.floor(base * (multiplier ^ exponent) + 0.5))
end

function MergeEggPricing.totalInitialPositionCost(baseAmount, positionCount)
    local count = math.max(0, math.floor(tonumber(positionCount) or 0))
    return MergeEggPricing.eggTierCost(baseAmount, 1, 0) * count
end

-- Generator and merged-tier prices may grow faster than double, but never slower. `firstTier` is
-- the tier represented by `firstAmount`; this keeps the long ladder from silently flattening.
function MergeEggPricing.doublingTierCost(firstAmount, growth, tierIndex, firstTier)
    local amount = math.max(0, tonumber(firstAmount) or 0)
    local multiplier = math.max(2, tonumber(growth) or 2)
    local first = math.max(1, math.floor(tonumber(firstTier) or 1))
    local tier = math.max(first, math.floor(tonumber(tierIndex) or first))
    local exponent = tier - first
    return math.max(0, math.floor(amount * (multiplier ^ exponent) + 0.5))
end

return MergeEggPricing
