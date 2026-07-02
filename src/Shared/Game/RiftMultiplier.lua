--[[
    RiftMultiplier — pure functional core for Chaos Rift power scaling (Feature 21).

    No Roblox APIs. Inside an active Chaos Rift the element power order reverses:
    Chaotic 2.0x, everything else 0.5x (per configs/rifts.lua). The live event
    scheduler/spawn is [deferred]; this is the math PowerFormula will call once rifts
    are active.

      multiplierFor(element, config)            -> number
      applyToPower(basePower, element, config)  -> scaled power (rounded)
]]

local RiftMultiplier = {}

function RiftMultiplier.multiplierFor(element, config)
    local mults = (config and config.multipliers) or {}
    local m = mults[element]
    if m == nil then
        return (config and config.default_multiplier) or 1.0
    end
    return m
end

function RiftMultiplier.applyToPower(basePower, element, config)
    local m = RiftMultiplier.multiplierFor(element, config)
    return math.floor((basePower or 0) * m + 0.5)
end

return RiftMultiplier
