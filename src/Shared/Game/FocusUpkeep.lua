--[[
    FocusUpkeep — PURE math for the always-on (toggle) Focus economy.

    Always-on powers (Swift, Hasten, XP Surge, Magnet, …) DRAIN Focus per second while active — the
    City of Heroes toggle model. Each tick the server sums the upkeep of a player's active toggles and
    pulls it from the pool; if the pool can't cover the tick, the toggles CRASH (detoggle) and stay off
    until manually re-toggled.

    This module is the arithmetic only (Roblox-free, headless-testable):
      • effectiveRate(base, reduction) — a future "efficiency" enhancement lowers a power's upkeep:
            effective = base * clamp(1 - reduction, 0, 1).
      • total(rates)                   — sum the active toggles' (already-effective) per-second rates.
      • step(focus, totalRate, dt)     — drain one tick; report whether the pool crashed.

    The service owns WHICH toggles are active + applying the crash; this owns the numbers.

    Run: mise run test-headless
]]

local FocusUpkeep = {}

-- A power's effective per-second upkeep after `reduction` (the summed `focus` enhancement fraction).
-- REDUCTIVE axis → DIVISION, the same form recharge uses (cd / (1 + Σr)): it asymptotes toward zero
-- but NEVER reaches it, so a slotted toggle always costs SOMETHING (Jason: never actually zero) and
-- stacking focus has natural diminishing returns (the 3rd slot is worth far less than the 1st — the
-- CoH "diversify after 2" curve). No clamp needed: any reduction >= 0 stays positive. Negative/absent
-- reduction → the base rate unchanged.
function FocusUpkeep.effectiveRate(base, reduction)
    local b = tonumber(base) or 0
    if b <= 0 then
        return 0
    end
    local r = tonumber(reduction) or 0
    if r < 0 then
        r = 0
    end
    return b / (1 + r)
end

-- Sum a list of per-second rates (the active toggles' effective upkeep).
function FocusUpkeep.total(rates)
    local sum = 0
    for _, r in ipairs(rates or {}) do
        sum = sum + (tonumber(r) or 0)
    end
    return sum
end

-- Drain one tick of `dt` seconds at `totalRate` focus/sec from `focus`.
-- Returns { focus = newPool, drained = amountRemoved, crashed = couldNotAffordTheFullTick }.
-- crashed = true means the pool ran dry mid-tick: the caller detoggles everything (CoH crash).
function FocusUpkeep.step(focus, totalRate, dt)
    local pool = tonumber(focus) or 0
    local rate = tonumber(totalRate) or 0
    local elapsed = tonumber(dt) or 0
    local need = rate * elapsed
    if need <= 0 then
        return { focus = pool, drained = 0, crashed = false }
    end
    if pool >= need then
        return { focus = pool - need, drained = need, crashed = false }
    end
    -- Can't cover the full tick → drain what's left to 0 and signal a crash.
    return { focus = 0, drained = pool > 0 and pool or 0, crashed = true }
end

return FocusUpkeep
