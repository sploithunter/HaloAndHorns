--[[
    RewardResolver (pure)

    Feature 4 (Themed Currency System): resolve a breakable/activity reward into
    the right themed currency and scaled amount, given the biome and layer. The
    same biome currency is used on every layer — Heaven/Hell only scale the amount
    (no "blessed"/"cursed" variant). Heaven/Hell layers additionally grant a side
    token currency (Light / Shadow).

    Pure: reads the ring topology (biome -> currency) and the layers config;
    unit-tested via `mise run test-headless`.

    layersConfig : { multipliers = { layer = number }, token_currency = { layer = id } }
]]

local RewardResolver = {}
RewardResolver.__index = RewardResolver

function RewardResolver.new(topology, layersConfig)
    assert(topology ~= nil, "RewardResolver.new requires a topology")
    assert(type(layersConfig) == "table", "RewardResolver.new requires a layers config")
    local self = setmetatable({}, RewardResolver)
    self._topology = topology
    self._multipliers = layersConfig.multipliers or {}
    self._tokenCurrency = layersConfig.token_currency or {}
    return self
end

-- Reward multiplier for a layer (defaults to 1.0 for unknown/base).
function RewardResolver:layerMultiplier(layer)
    return self._multipliers[layer] or 1.0
end

-- Themed currency for a biome (from the ring topology config).
function RewardResolver:currencyForBiome(biome)
    return self._topology:currency(biome)
end

-- The side-reward token currency for a layer ("light_tokens" / "shadow_tokens"),
-- or nil in the base layer.
function RewardResolver:layerTokenCurrency(layer)
    return self._tokenCurrency[layer]
end

-- Resolve a base reward in a biome+layer into { currency, amount } (rounded).
function RewardResolver:resolveReward(baseAmount, biome, layer)
    local currency = self:currencyForBiome(biome)
    local amount = math.floor((baseAmount * self:layerMultiplier(layer)) + 0.5)
    return { currency = currency, amount = amount }
end

return RewardResolver
