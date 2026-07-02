--[[
    PetSurvivability — pure functional core for a pet's EFFECTIVE HP (the inventory
    card's ❤ number).

    Pets have no HP stat (configs/combat.lua): a pet is downed once accumulated enemy
    damage reaches its endurance ceiling = power * pet_down_threshold_factor
    (PetEndurance.maxEndurance). Incoming damage is reduced by the armor curve
    (CombatMath.mitigate, defense vs k) and the element durability taken_mult.

    "Effective HP" is therefore the RAW (pre-mitigation) damage a pet can absorb before
    it is downed — defined off the SAME two curves the server downs it with, so the
    displayed ❤ equals real survivability:

        EHP = ceiling / (survivingFraction * takenMult)
            = (power * factor) * (1 + defense/k) / takenMult     (since takenMult=1 today)

    A blaster (defense 0) reads ❤ = power*factor; a tank (defense 100, k 100) reads
    ❤ = 2 * power*factor. Defense is the multiplier that makes ❤ more than just 10x the
    power number — exactly the "power + defense in one figure" the card wants.

    No Roblox APIs; composes the two pure combat cores. Unit-tested headless.
]]

-- Sibling pure cores via script.Parent (resolves both in Roblox runtime and the headless harness,
-- which shims script.Parent:WaitForChild -> a module path). game:GetService is NOT headless-safe.
local PetEndurance = require(script.Parent:WaitForChild("PetEndurance"))
local CombatMath = require(script.Parent:WaitForChild("CombatMath"))

local PetSurvivability = {}

-- power     — the pet's resolved power (the same realized power the endurance ceiling uses)
-- defense   — innate role toughness + (display ignores live buffs; this is the at-rest card stat)
-- factor    — pet_down_threshold_factor (configs/combat.lua)
-- k         — armor_curve_k (configs/combat.lua)
-- takenMult — element durability (combat_fx taken_mult); <1 = tankier, currently 1.0 for all
function PetSurvivability.effectiveHp(power, defense, factor, k, takenMult)
    local ceiling = PetEndurance.maxEndurance(power, factor) -- power * factor (floored at 1)
    -- Surviving fraction: raw 1 damage lands as mitigate(1, defense, k) after the armor curve.
    local survivingFraction = CombatMath.mitigate(1, defense or 0, k or 100)
    if survivingFraction <= 0 then
        return ceiling -- no mitigation possible (k<=0): EHP collapses to the raw ceiling
    end
    local tm = tonumber(takenMult) or 1
    if tm <= 0 then
        tm = 1
    end
    return ceiling / (survivingFraction * tm)
end

return PetSurvivability
