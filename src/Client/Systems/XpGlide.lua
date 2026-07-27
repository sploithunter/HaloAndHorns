--[[
    XpGlide — pure presentation timing for the PlayerBar.

    Progress is measured in complete horizontal-bar sweeps ("bars"), not raw XP. At the default
    rate, one full sweep takes one second regardless of the player's level or XP requirement.
]]

local XpGlide = {}

function XpGlide.advance(shown, target, dt, barsPerSecond)
    shown = tonumber(shown) or 0
    target = tonumber(target) or shown
    dt = math.max(0, tonumber(dt) or 0)
    barsPerSecond = math.max(0, tonumber(barsPerSecond) or 0)

    if target <= shown then
        return target
    end
    return math.min(target, shown + barsPerSecond * dt)
end

return XpGlide
