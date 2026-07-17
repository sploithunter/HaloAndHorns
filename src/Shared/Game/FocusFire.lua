--[[
    FocusFire — pure rules for the Cryomancer's player-scoped accuracy mark.

    The server stores one channel per caster on the marked enemy so multiplayer casts do not
    overwrite one another. The visible Power_focus_fire_Until badge remains a presentation channel;
    these attributes are the authoritative gameplay channel.
]]

local FocusFire = {}

local function suffix(userId)
    return tostring(math.floor(tonumber(userId) or 0))
end

function FocusFire.keys(userId)
    local id = suffix(userId)
    return {
        untilTime = "FocusFire_" .. id .. "_Until",
        accuracyBonus = "FocusFire_" .. id .. "_AccuracyBonus",
        holdPierce = "FocusFire_" .. id .. "_HoldPierce",
    }
end

function FocusFire.isActive(untilTime, now)
    return (tonumber(untilTime) or 0) > (tonumber(now) or 0)
end

-- Accuracy bonuses are flat percentage points, not multipliers. Respect the ordinary accuracy cap,
-- but never reduce a chance already above that cap (for example, from legacy slotted enhancements).
function FocusFire.applyAccuracy(baseChance, bonus, untilTime, now, cap)
    local base = math.clamp(tonumber(baseChance) or 0, 0, 1)
    if not FocusFire.isActive(untilTime, now) then
        return base, 0
    end
    local added = math.max(0, tonumber(bonus) or 0)
    local capped = math.clamp(tonumber(cap) or 1, 0, 1)
    local resolved = math.max(base, math.min(base + added, capped))
    return resolved, resolved - base
end

-- This gate is ONLY for innate HoldImmune. Temporary boss HoldResistUntil is checked separately
-- and never reaches this function, preserving the boss breakout immunity window.
function FocusFire.piercesInnateHold(untilTime, chance, now, roll)
    if not FocusFire.isActive(untilTime, now) then
        return false
    end
    local pierceChance = math.clamp(tonumber(chance) or 0, 0, 1)
    return (tonumber(roll) or 1) < pierceChance
end

return FocusFire
