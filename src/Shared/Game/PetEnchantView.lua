local PetEnchantView = {}

-- One display projection for both unique-pet enchant lists and Storage-v2 stack enchants.
-- Stack records persist only the effect id; their shared strength remains config-owned.
function PetEnchantView.records(petData, enchantsConfig)
    if type(petData) ~= "table" then
        return {}
    end

    if type(petData.enchantments) == "table" and #petData.enchantments > 0 then
        return petData.enchantments
    end

    if type(petData.enchant) == "string" and petData.enchant ~= "" then
        local stackStrength = type(enchantsConfig) == "table"
                and type(enchantsConfig.stack_enchants) == "table"
                and tonumber(enchantsConfig.stack_enchants.strength)
            or 1
        local effect = type(enchantsConfig) == "table"
                and type(enchantsConfig.effects) == "table"
                and enchantsConfig.effects[petData.enchant]
            or nil
        return {
            {
                id = petData.enchant,
                displayName = type(effect) == "table" and effect.display_name or petData.enchant,
                strength = stackStrength,
                stack = true,
            },
        }
    end

    return {}
end

return PetEnchantView
