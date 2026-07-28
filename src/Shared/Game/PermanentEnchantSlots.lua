--[[
    PermanentEnchantSlots

    Pure slot-reconciliation rules for fated pet enchants. Existing valid
    enchants are immutable; only unlocked slots with no valid enchant are
    returned for repair.
]]

local PermanentEnchantSlots = {}

local function isValidEnchant(enchant)
    return type(enchant) == "table" and type(enchant.id) == "string" and enchant.id ~= ""
end

function PermanentEnchantSlots.missing(enchantments, unlockedSlots)
    enchantments = type(enchantments) == "table" and enchantments or {}
    unlockedSlots = math.max(0, math.floor(tonumber(unlockedSlots) or 0))

    local missing = {}
    for slot = 1, unlockedSlots do
        if not isValidEnchant(enchantments[slot]) then
            table.insert(missing, slot)
        end
    end
    return missing
end

return PermanentEnchantSlots
