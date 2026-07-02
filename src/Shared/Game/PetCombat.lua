--[[
    PetCombat — pure functional core for pet work/damage resolution.

    Extracts the damage + cadence rules that used to live inline in the cloned
    per-pet script (PetScripts/Follow.server.lua, issue #4) into a single
    headless-testable place. No Roblox APIs. The modifier-pipeline RESOLUTION
    (power -> adjusted value) stays in the service (CombatService) where the
    ModifierService is available; this module owns the deterministic arithmetic
    applied on top of it.

      damagePerHit(resolvedDamage)   -> integer (floored, minimum 1)
      applyDamage(hp, dmg)           -> { hp = remaining, contributed = dealt }
      attackInterval(efficiency)     -> seconds between hits (clamped 0.2..2)
]]

local PetCombat = {}

-- A hit always lands at least 1 damage; fractional pipeline output is floored.
function PetCombat.damagePerHit(resolvedDamage)
    return math.max(1, math.floor(resolvedDamage))
end

-- Apply damage to a target's HP. Never below 0; reports the amount actually
-- contributed (for the breakable contribution ledger / loot attribution).
function PetCombat.applyDamage(hp, dmg)
    local newHp = math.max(0, hp - dmg)
    return { hp = newHp, contributed = hp - newHp }
end

-- Seconds between attacks from an efficiency multiplier. Higher efficiency ->
-- faster attacks; clamped to [0.2, 2] (matches the legacy cadence rule).
function PetCombat.attackInterval(efficiency)
    return math.clamp(1 / math.max(0.05, efficiency), 0.2, 2)
end

return PetCombat
