--[[
    CombatCadence — opt-in attack-rate scaling for authored encounters.

    Actors without CombatCadenceMultiplier keep the ordinary 1x interval. A prototype can stamp
    the same multiplier on both pets and enemies to accelerate direct combat without changing
    global balance config. This scales attack cadence only, not movement, regeneration, or timers.
]]

local CombatCadence = {}

function CombatCadence.multiplier(value)
    local parsed = tonumber(value)
    if not parsed or parsed <= 0 then
        return 1
    end
    return math.clamp(parsed, 0.25, 8)
end

function CombatCadence.interval(seconds, multiplier)
    local base = math.max(0.05, tonumber(seconds) or 1)
    return math.max(0.05, base / CombatCadence.multiplier(multiplier))
end

return CombatCadence
