--[[
    BreakableBoost — pure math for a crystal's shared Boost meter.

    The same normalized 0..1 meter drives both faster pet damage and richer
    currency/XP rewards. Keeping the interpolation here prevents the two
    consumers from drifting.
]]

local BreakableBoost = {}

function BreakableBoost.fraction(boost, maxBoost)
    local maximum = math.max(0, tonumber(maxBoost) or 0)
    if maximum <= 0 then
        return 0
    end
    return math.clamp((tonumber(boost) or 0) / maximum, 0, 1)
end

function BreakableBoost.multiplier(boost, maxBoost, maxBonus)
    local bonus = math.max(0, tonumber(maxBonus) or 0)
    return 1 + BreakableBoost.fraction(boost, maxBoost) * bonus
end

function BreakableBoost.levelGatedMultiplier(boost, maxBoost, maxBonus, playerLevel, minimumLevel)
    local level = math.max(1, math.floor(tonumber(playerLevel) or 1))
    local minimum = math.max(1, math.floor(tonumber(minimumLevel) or 1))
    if level < minimum then
        return 1
    end
    return BreakableBoost.multiplier(boost, maxBoost, maxBonus)
end

return BreakableBoost
