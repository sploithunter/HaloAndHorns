--[[
    BrewMeter — pure math for the potion "brew charge" system (one meter per buff axis).

    Each meter holds a normalized CHARGE in [0,1], shown to the player as a draining pie-icon
    (Jason: "an icon with a pie chart… the icon just goes away"). The charge does double duty,
    which is what kills BOTH runaway vectors at once:

      • MAGNITUDE tapers with the charge:  magnitude = charge × cap.  As the pie drains the buff
        fades to nothing — so you literally watch the cap, never hit a hidden wall (anti-cap rule).
      • A SIP closes a FRACTION of the gap to full:  charge += (1 − charge) × sipFraction.  This
        is diminishing returns — it ASYMPTOTES to full, so 1000 sips can never exceed the cap and
        front-loading a stockpile is wasted (a sip at/near full is a no-op → don't consume it).
      • DURATION is just the drain: a meter empties from full in `drainSeconds`, so 1000 potions
        can't bank 1000× duration — you can only ever hold one pie's worth and it's always bleeding.

    Pure + deterministic (no Roblox APIs, no os.time). The service owns the per-player charge
    table, ticks `drain` on a heartbeat, and maps `magnitude` onto the BuffStack axis attribute.
]]

local BrewMeter = {}

function BrewMeter.clamp01(x)
    x = tonumber(x) or 0
    if x < 0 then
        return 0
    elseif x > 1 then
        return 1
    end
    return x
end

-- One drink: close `sipFraction` (0..1) of the remaining gap to full. Diminishing — asymptotes
-- to 1, never exceeds it. Returns the new charge in [0,1].
function BrewMeter.sip(charge, sipFraction)
    charge = BrewMeter.clamp01(charge)
    sipFraction = BrewMeter.clamp01(sipFraction)
    return BrewMeter.clamp01(charge + (1 - charge) * sipFraction)
end

-- A sip would be wasted (meter effectively full) — caller should NOT consume the potion.
function BrewMeter.isFull(charge, fullThreshold)
    fullThreshold = tonumber(fullThreshold) or 0.98
    return BrewMeter.clamp01(charge) >= fullThreshold
end

-- The buff magnitude (a BuffStack fraction) at this charge — TAPER: linear in charge, capped.
function BrewMeter.magnitude(charge, cap)
    return BrewMeter.clamp01(charge) * (tonumber(cap) or 0)
end

-- Drain the meter over `dt` seconds; `drainSeconds` = full→empty time. Returns the new charge.
function BrewMeter.drain(charge, dt, drainSeconds)
    charge = BrewMeter.clamp01(charge)
    drainSeconds = tonumber(drainSeconds) or 0
    if drainSeconds <= 0 then
        return charge
    end
    return BrewMeter.clamp01(charge - (tonumber(dt) or 0) / drainSeconds)
end

-- Seconds of buff left at the current charge (for the pie sweep + when the icon vanishes).
function BrewMeter.remainingSeconds(charge, drainSeconds)
    return BrewMeter.clamp01(charge) * (tonumber(drainSeconds) or 0)
end

-- Empty meter = the buff has ended and the icon goes away.
function BrewMeter.isEmpty(charge)
    return BrewMeter.clamp01(charge) <= 0
end

return BrewMeter
