--[[
    PowerFormula (pure) — Feature 6.

    Pet power is ALWAYS computed at runtime, never persisted. It is the base power
    times every contextual multiplier, composed multiplicatively (design §10):

        base × variant × level × enchant × element × theme_utility × stack × buff

    Any missing multiplier defaults to 1 (no effect). The result is rounded to the
    nearest integer. Element/theme_utility multipliers come from ElementResonance
    / ThemeUtility; the rest come from existing pet config + per-pet state.
]]

local PowerFormula = {}

local function mult(value)
    return (type(value) == "number") and value or 1
end

-- factors: { base (number, required), variant?, level?, enchant?, element?,
--            theme_utility?, stack?, buff? }
function PowerFormula.compute(factors)
    assert(
        type(factors) == "table" and type(factors.base) == "number",
        "PowerFormula.compute requires factors.base (number)"
    )
    local product = factors.base
        * mult(factors.variant)
        * mult(factors.level)
        * mult(factors.enchant)
        * mult(factors.element)
        * mult(factors.theme_utility)
        * mult(factors.stack)
        * mult(factors.buff)
    return math.floor(product + 0.5)
end

return PowerFormula
