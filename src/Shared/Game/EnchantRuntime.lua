--[[
    EnchantRuntime

    Pure interpretation helpers for pet enchant behavior. Configs may use the
    family currency `"coins"` to cover every live biome coin wallet
    (`grass_coins`, `desert_coins`, and so on), while `"crystals"` remains the
    distinct legacy/generic crystal wallet.
]]

local EnchantRuntime = {}

local function currencyMatches(expected, actual)
    if expected == nil then
        return true
    end
    if expected == "coins" then
        if actual == nil or actual == "coins" then
            return true
        end
        return type(actual) == "string" and string.match(actual, "_coins$") ~= nil
    end
    return expected == actual
end

function EnchantRuntime.matchesModifierContext(modifier, context)
    if type(modifier) ~= "table" or type(context) ~= "table" then
        return false
    end
    if modifier.kind ~= nil and modifier.kind ~= context.kind then
        return false
    end
    return currencyMatches(modifier.currency, context.currency)
end

-- A pet's enchant TYPE tier is separate from its rolled metal/strength tier. Huge-class traits
-- take precedence; otherwise the authored rarity scales the effect. Kept shared so gameplay and
-- every description display the same effective magnitude.
function EnchantRuntime.petTierId(petData)
    if type(petData) ~= "table" then
        return nil
    end
    if petData.huge == true then
        return "huge"
    end
    return petData.rarity_id or petData.rarityId or petData.rarity_override
end

function EnchantRuntime.typeMultiplier(tier, enchantsConfig)
    local multipliers = type(enchantsConfig) == "table" and enchantsConfig.type_multipliers
    if type(multipliers) ~= "table" or type(tier) ~= "string" then
        return 1
    end
    return tonumber(multipliers[string.lower(tier)]) or 1
end

function EnchantRuntime.magnitude(enchant, petData, enchantsConfig)
    if type(enchant) ~= "table" or type(enchantsConfig) ~= "table" then
        return 0
    end
    local effect = enchantsConfig.effects and enchant.id and enchantsConfig.effects[enchant.id]
    local modifier = effect and effect.modifier
    local strength = tonumber(enchant.strength or enchant.value) or 0
    local per = modifier and tonumber(modifier.amount_per_strength) or 0
    local tier = EnchantRuntime.petTierId(petData)
    return strength * per * EnchantRuntime.typeMultiplier(tier, enchantsConfig)
end

-- Stable replicated attribute for one configured enchant identity. Effect ids are authored
-- snake_case; sanitize anyway so future content cannot create an invalid attribute name.
function EnchantRuntime.effectAttribute(effectId)
    local safe = tostring(effectId or "unknown"):gsub("[^%w_]", "_")
    return "EnchantEffect_" .. safe
end

return EnchantRuntime
