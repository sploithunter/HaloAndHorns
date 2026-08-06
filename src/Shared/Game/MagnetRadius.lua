--[[
    MagnetRadius

    Pure single source of truth for the physical loot collection radius. Flat reach from the
    Magnet power and Auto Collector pass adds first, configured pet abilities establish an
    absolute minimum, then equipped Magnet enchants multiply the complete useful radius.
]]

local MagnetRadius = {}

local function nonNegative(value)
    return math.max(0, tonumber(value) or 0)
end

function MagnetRadius.resolve(
    baseRadius,
    magnetBonus,
    autoCollectBonus,
    petAbilityRange,
    enchantBonus
)
    local radius = nonNegative(baseRadius)
        + nonNegative(magnetBonus)
        + nonNegative(autoCollectBonus)
    radius = math.max(radius, nonNegative(petAbilityRange))
    return radius * (1 + nonNegative(enchantBonus))
end

return MagnetRadius
