--[[
    PetEndurance — pure functional core for the DEFENSIVE half of inverse mining
    (Feature 10, slice 1b).

    Pets have no HP stat. Instead they accumulate enemy damage ("damage taken")
    and are DOWNED once it reaches their endurance ceiling (petPower *
    pet_down_threshold_factor — same ceiling CombatMath.isPetDowned uses). The
    inverse-mining feel the design calls for:
      - a pet taken ALL the way down is out for a long heal (the consequence);
      - a pet only PARTIALLY damaged regenerates that damage back over time
        (faster than a full-defeat heal) once it has been out of combat briefly.

    This module is the arithmetic only (no Roblox APIs, no requires): EnemyService
    owns the live state (per-pet attributes + timers) and calls these. Unit-tested
    headless via `mise run test-headless`.
]]

local PetEndurance = {}

-- The damage a pet can absorb before it is downed. Floored at 1 so a 0-power pet
-- still takes a hit to down (never an instant/divide-by-zero down).
function PetEndurance.maxEndurance(petPower, factor)
    local ceiling = (petPower or 0) * (factor or 1)
    if ceiling < 1 then
        return 1
    end
    return ceiling
end

-- Accumulate one enemy hit. Never negative.
function PetEndurance.applyHit(damageTaken, hitDamage)
    local d = (damageTaken or 0) + (hitDamage or 0)
    if d < 0 then
        return 0
    end
    return d
end

-- Downed once accumulated damage reaches the endurance ceiling.
function PetEndurance.isDowned(damageTaken, petPower, factor)
    return (damageTaken or 0) >= PetEndurance.maxEndurance(petPower, factor)
end

-- Partial-damage regen: bleed accumulated damage back toward 0 at perSecond.
-- Clamped at 0 (fully healed). Caller gates this on the out-of-combat delay.
function PetEndurance.regen(damageTaken, dt, perSecond)
    local d = (damageTaken or 0) - (perSecond or 0) * (dt or 0)
    if d < 0 then
        return 0
    end
    return d
end

-- Whether enough time has passed since the last hit to start regenerating.
function PetEndurance.canRegen(now, lastHitAt, delaySeconds)
    return (now - (lastHitAt or 0)) >= (delaySeconds or 0)
end

-- Staged degradation state (§11.3) for HUD + recall agency. The pet weakens through
-- Strained -> Critical before it is Downed, so the player can recall it in time.
-- thresholds: { strained_at, critical_at } health fractions (defaults 0.6 / 0.3).
function PetEndurance.state(damageTaken, petPower, factor, thresholds)
    if PetEndurance.isDowned(damageTaken, petPower, factor) then
        return "Downed"
    end
    local hf = PetEndurance.healthFraction(damageTaken, petPower, factor)
    local strainedAt = (thresholds and thresholds.strained_at) or 0.6
    local criticalAt = (thresholds and thresholds.critical_at) or 0.3
    if hf <= criticalAt then
        return "Critical"
    elseif hf <= strainedAt then
        return "Strained"
    end
    return "Healthy"
end

-- Health fraction in [0,1] (1 = full, 0 = downed) for an endurance bar.
function PetEndurance.healthFraction(damageTaken, petPower, factor)
    local max = PetEndurance.maxEndurance(petPower, factor)
    local f = 1 - (damageTaken or 0) / max
    if f < 0 then
        return 0
    end
    if f > 1 then
        return 1
    end
    return f
end

return PetEndurance
