--[[
    ThemeUtility (pure) — Feature 6.

    A pet of theme T gains its utility passive only while the player is in T's
    dichotomy biome (from RingTopology). Returns the passive table (from
    configs/theme_utility.lua) or nil. Biome ids equal their theme in the
    prototype, so the pet theme is used directly as the dichotomy lookup key.
]]

local ThemeUtility = {}

function ThemeUtility.activePassive(petTheme, currentBiome, topology, config)
    if not petTheme or not currentBiome then
        return nil
    end
    local partner = topology:dichotomyPartner(petTheme)
    if partner == nil or partner ~= currentBiome then
        return nil
    end
    local passives = config and config.passives
    return passives and passives[petTheme] or nil
end

return ThemeUtility
