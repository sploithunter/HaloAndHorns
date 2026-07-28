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

return EnchantRuntime
