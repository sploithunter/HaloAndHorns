--[[
    BrewJuice — how hard a brew charge should read on the HUD and body.

    First sip is a glow (the Drink Berserk Brew lesson). Second sip starts
    the badge shake. Near-full is the "barely contained" leak. Pure math so
    HotbarBar and BuffAuraController share one ramp.
]]

local BrewJuice = {}

function BrewJuice.clamp01(x)
    x = tonumber(x) or 0
    if x < 0 then
        return 0
    end
    if x > 1 then
        return 1
    end
    return x
end

function BrewJuice.ramp(charge, startAt, fullAt)
    charge = BrewJuice.clamp01(charge)
    startAt = BrewJuice.clamp01(startAt)
    fullAt = math.max(startAt + 1e-6, BrewJuice.clamp01(fullAt))
    if charge <= startAt then
        return 0
    end
    if charge >= fullAt then
        return 1
    end
    return (charge - startAt) / (fullAt - startAt)
end

function BrewJuice.sample(charge, knobs)
    knobs = knobs or {}
    charge = BrewJuice.clamp01(charge)
    return {
        charge = charge,
        glow = BrewJuice.ramp(charge, knobs.glow_at or 0.05, knobs.glow_full or 0.55),
        shake = BrewJuice.ramp(charge, knobs.shake_at or 0.62, knobs.shake_full or 0.92),
        leak = BrewJuice.ramp(charge, knobs.leak_at or 0.74, knobs.leak_full or 0.98),
    }
end

return BrewJuice
