--[[
    MagnetRadius

    Pure single source of truth for the player's physical loot collection radius. Flat reach from
    the Magnet power adds first, configured pet abilities establish an absolute minimum, then
    equipped Magnet enchants multiply the complete useful radius. Auto Collector is a separate
    passive actor and intentionally never enters this formula.
]]

local MagnetRadius = {}

local function nonNegative(value)
    return math.max(0, tonumber(value) or 0)
end

function MagnetRadius.resolve(baseRadius, magnetBonus, petAbilityRange, enchantBonus)
    local radius = nonNegative(baseRadius) + nonNegative(magnetBonus)
    radius = math.max(radius, nonNegative(petAbilityRange))
    return radius * (1 + nonNegative(enchantBonus))
end

return MagnetRadius
