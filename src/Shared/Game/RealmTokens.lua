--[[
    RealmTokens (pure) — World S3 token-earning loop (design doc §14, fork 1).

    Light/shadow tokens are the realm-traversal currency. They're EARNED from realm
    activity while the player is in a realm layer, from three config-driven channels:
      - income cut  : a fraction of biome-coin income converts to the realm's token
      - conquest    : a flat grant per conquest
      - hatch       : a flat grant per egg hatched in a realm
    The realm a player is in (their CurrentLayer) decides the token: heaven -> light,
    hell -> shadow, base/neutral -> none. This module only computes grants; the service
    (LayerService) reads CurrentLayer and deposits via DataService.

    Pure: standard Lua only; headless-tested. Knobs live in `configs/layers.lua` `earning`.

      currencyForLayer(layerId, config)        -> "light_tokens" | "shadow_tokens" | nil
      fromIncome(amount, layerId, config)      -> { currency, amount } | nil
      flat(kind, layerId, config)              -> { currency, amount } | nil   (kind: "conquest"|"hatch")
]]

local RealmTokens = {}

-- The token a layer pays in (base/neutral pays nothing). Reuses layers.token_currency
-- (heaven_* -> light_tokens, hell_* -> shadow_tokens).
function RealmTokens.currencyForLayer(layerId, config)
    if not layerId or layerId == "base" then
        return nil
    end
    return (config.token_currency and config.token_currency[layerId]) or nil
end

-- Income cut: floor(amount * income_cut), raised to income_min when positive income would
-- otherwise round to 0. Returns nil at base / for non-positive income / when the cut is off.
function RealmTokens.fromIncome(amount, layerId, config)
    local currency = RealmTokens.currencyForLayer(layerId, config)
    amount = tonumber(amount) or 0
    if not currency or amount <= 0 then
        return nil
    end
    local earning = config.earning or {}
    local cut = tonumber(earning.income_cut) or 0
    if cut <= 0 then
        return nil
    end
    local tokens = math.floor(amount * cut)
    local minTokens = math.floor(tonumber(earning.income_min) or 0)
    if tokens < minTokens then
        tokens = minTokens
    end
    if tokens <= 0 then
        return nil
    end
    return { currency = currency, amount = tokens }
end

-- Flat grant for a discrete event (conquest / hatch) keyed to the player's realm.
function RealmTokens.flat(kind, layerId, config)
    local currency = RealmTokens.currencyForLayer(layerId, config)
    if not currency then
        return nil
    end
    local earning = config.earning or {}
    local key = (kind == "conquest" and "conquest_tokens")
        or (kind == "hatch" and "hatch_tokens")
        or nil
    if not key then
        return nil
    end
    local n = math.floor(tonumber(earning[key]) or 0)
    if n <= 0 then
        return nil
    end
    return { currency = currency, amount = n }
end

-- Depth-scaled hatch luck bonus (design doc §15 — deeper = rarer pulls). 0 at base.
-- = layerDepth * depth_rewards.hatch_luck_per_depth.
function RealmTokens.hatchLuck(layerId, config)
    if not layerId or layerId == "base" then
        return 0
    end
    local depth = tonumber(tostring(layerId):match("_(%d+)$")) or 0
    local perDepth = tonumber(config.depth_rewards and config.depth_rewards.hatch_luck_per_depth)
        or 0
    return depth * perDepth
end

return RealmTokens
