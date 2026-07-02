--[[
    BuffStack (pure) — additive-on-base buff stacking.

    Implements docs/PET_REALM_ICONS_AND_POWERS.md Part E: every % buff is an ADDITIVE fraction on a
    base of 1.0; all live sources in the same axis SUM; the sum is clamped to the axis cap; a small
    set of GLOBAL multipliers (gamepass/event/rebirth) multiply the result. No multiplicative
    compounding between same-axis sources (ten +25% = +250% = ×3.5, never ×9.3).

    Pure: no Roblox APIs, no os.time — the caller passes `now` (an absolute timestamp). A source is
      { fraction = 0.25, expiry = <absTime> }  -- temporary: live while expiry > now
      { fraction = 0.10 }                       -- permanent: no `expiry` key (always live)
    `fraction` is the BONUS (+0.25 = +25%), NOT a multiplier (×1.25). For a flat-additive axis like
    defense, `fraction` is just the flat amount and you read `sum()` directly (skip `multiplier`).

    API:
      sum(sources, now)                 -> Σ live fractions (no clamp, no +1)
      multiplier(sources, now, axisCfg) -> clamp(1 + Σ, 1, 1 + cap)   [the per-axis multiplier]
      withGlobals(mult, globals)        -> mult × Π(globals)
      resolve(sources, now, axisCfg, globals) -> multiplier × globals  [the whole pipeline]
      isActive(sources, now)            -> boolean (any source live?)
      prune(sources, now)               -> sources with expired ones removed
]]

local BuffStack = {}

-- Is a single source live at `now`? No `expiry` = permanent.
local function live(src, now)
    return src.expiry == nil or src.expiry > now
end

-- Σ of live source fractions (works for fraction axes AND flat-additive axes like defense).
function BuffStack.sum(sources, now)
    local total = 0
    for _, src in ipairs(sources or {}) do
        if live(src, now) then
            total += (src.fraction or 0)
        end
    end
    return total
end

-- Per-axis multiplier: 1 + Σ fractions, clamped to [1, 1 + cap]. axisCfg = { cap?, floor? }
-- (cap/floor are FRACTION bounds; cap 3.0 => ×4.0 max). Missing cap => no upper clamp.
function BuffStack.multiplier(sources, now, axisCfg)
    local s = BuffStack.sum(sources, now)
    local floor = (axisCfg and axisCfg.floor) or 0
    if s < floor then
        s = floor
    end
    local cap = axisCfg and axisCfg.cap
    if cap and s > cap then
        s = cap
    end
    return 1 + s
end

-- Apply the (few) whole-account global multipliers to an axis multiplier.
function BuffStack.withGlobals(mult, globals)
    local m = mult
    for _, g in ipairs(globals or {}) do
        m *= g
    end
    return m
end

-- The full pipeline: base × (1 + Σ axis) × Π(globals) — returns the final multiplier (base = 1).
function BuffStack.resolve(sources, now, axisCfg, globals)
    return BuffStack.withGlobals(BuffStack.multiplier(sources, now, axisCfg), globals)
end

function BuffStack.isActive(sources, now)
    for _, src in ipairs(sources or {}) do
        if live(src, now) then
            return true
        end
    end
    return false
end

-- Return a new list with expired sources removed (permanent ones kept).
function BuffStack.prune(sources, now)
    local kept = {}
    for _, src in ipairs(sources or {}) do
        if live(src, now) then
            kept[#kept + 1] = src
        end
    end
    return kept
end

return BuffStack
