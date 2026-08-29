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

-- A long progression can retain familiar early doubling without allowing exponentiation to
-- dominate every later design decision. `firstTier` is the tier represented by `firstAmount`;
-- growth changes only after `slowAfterTier`, with no discontinuity at the boundary.
function MergeEggPricing.bandedTierCost(
    firstAmount,
    earlyGrowth,
    lateGrowth,
    slowAfterTier,
    tierIndex,
    firstTier
)
    local amount = math.max(0, tonumber(firstAmount) or 0)
    local early = math.max(1, tonumber(earlyGrowth) or 1)
    local late = math.max(1, tonumber(lateGrowth) or early)
    local first = math.max(1, math.floor(tonumber(firstTier) or 1))
    local tier = math.max(first, math.floor(tonumber(tierIndex) or first))
    local boundary = math.max(first, math.floor(tonumber(slowAfterTier) or first))
    local exponent = tier - first
    local earlyExponent = math.min(exponent, boundary - first)
    local lateExponent = math.max(0, exponent - earlyExponent)
    return math.max(0, math.floor(amount * (early ^ earlyExponent) * (late ^ lateExponent) + 0.5))
end

return MergeEggPricing
