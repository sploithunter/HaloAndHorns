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

return MergeEggPricing
