--[[
    PowerStatsDiff (pure) — compare two PowerStats.resolveEffective outputs (the SAME power
    resolved against two enhancement sets) and report the axes that CHANGE.

    Drives the ENHANCE-strip result preview: the caller resolves a power twice —
      current   = PowerStats.resolveEffective(record, { ..., enhancements = aggregate(committed) })
      projected = PowerStats.resolveEffective(record, { ..., enhancements = aggregate(committed+staged) })
    — then PowerStatsDiff.diff(current, projected) returns one row per shifted axis, in a
    stable display order, with from/to and the signed fractional change.

    `lowerBetter` axes (recharge, focus cost) IMPROVE when they drop, so `improved` already
    accounts for direction — the UI just colors `improved` green, the rest red.

    Pure: no Roblox APIs, no requires. Inputs/outputs are plain tables of numbers.
]]

local PowerStatsDiff = {}

-- Display order + per-axis metadata. `unit`: "s" seconds, "%" a 0..1 chance, "" a raw number.
-- `lowerBetter` = an enhancement that SHRINKS this axis is the improvement (recharge divides,
-- focus is a cost). Only axes an enhancement can move are listed.
local AXES = {
    { axis = "recharge", label = "Recharge", unit = "s", lowerBetter = true },
    { axis = "cost", label = "Focus", unit = "", lowerBetter = true },
    { axis = "damage", label = "Damage", unit = "" },
    { axis = "magnitude", label = "Potency", unit = "" },
    { axis = "heal", label = "Healing", unit = "" },
    { axis = "shield", label = "Shield", unit = "" },
    { axis = "duration", label = "Duration", unit = "s" },
    { axis = "radius", label = "Range", unit = "" },
    { axis = "accuracy", label = "Accuracy", unit = "%" },
    { axis = "crit", label = "Crit", unit = "%" },
}

-- a sub-0.01 wobble (float noise, or an axis clamped at its cap) isn't a real change
local EPS = 1e-2

-- diff(current, projected) -> { { axis, label, unit, from, to, lowerBetter, improved, deltaPct }, ... }
-- Only axes that moved by more than EPS appear, in AXES order. `deltaPct` is the signed
-- fractional change (to-from)/from, or nil when `from` is 0 (no baseline to ratio against).
function PowerStatsDiff.diff(current, projected)
    current = current or {}
    projected = projected or {}
    local rows = {}
    for _, meta in ipairs(AXES) do
        local from = tonumber(current[meta.axis]) or 0
        local to = tonumber(projected[meta.axis]) or 0
        if math.abs(to - from) > EPS then
            rows[#rows + 1] = {
                axis = meta.axis,
                label = meta.label,
                unit = meta.unit,
                from = from,
                to = to,
                lowerBetter = meta.lowerBetter == true,
                improved = if meta.lowerBetter then to < from else to > from,
                deltaPct = (from ~= 0) and (to - from) / from or nil,
            }
        end
    end
    return rows
end

return PowerStatsDiff
