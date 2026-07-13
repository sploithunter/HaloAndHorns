--[[
    Allegiance (pure) — the heaven/hell combat-targeting asymmetry.

    The realm farming-vs-combat mechanic (Jason):
      • HELL attackers attack ALL targets (free-for-all → hell is combat).
      • HEAVEN attackers attack ONLY hell targets (→ heaven coexists → farming).
      • NEUTRAL actors have "free will" and take the CURRENT REALM's side, then follow
        the rule above (a neutral pet in heaven acts heaven; in hell acts hell).
      • Off-realm (the neutral homeworld) the mechanic doesn't apply — everyone attacks
        all, exactly as combat worked before realms.

    Mission combat may pass policy="universal" to bypass realm non-aggression without bypassing
    the separate realm resonance calculation. This keeps normal Heaven peaceful while ensuring
    Trials always start with any valid squad.

    NOTE: this pure PROACTIVE gate answers "would X initiate on Y". Neutral home/creator
    pets (Colorado) are additionally REACTIVE — they don't initiate here, but JOIN a fight
    already engaged with the squad; that runtime override lives in EnemyService
    (_petHostileToEnemy), which can see the aggro state this stateless module cannot.

    Pure: no Roblox API. Sides are plain strings; the service resolves a pet's side from
    its species `realm` and the current realm from the player's layer, then calls hostile().
]]

local Allegiance = {}

-- Collapse any raw side/realm string to "heaven" | "hell" | "neutral".
function Allegiance.normalize(raw)
    if type(raw) ~= "string" then
        return "neutral"
    end
    local s = string.lower(raw)
    if s == "heaven" or s == "light" then
        return "heaven"
    elseif s == "hell" or s == "shadow" then
        return "hell"
    end
    return "neutral"
end

-- An actor's EFFECTIVE side: a neutral actor takes the current realm's side ("free will").
function Allegiance.effective(rawSide, currentRealm)
    local side = Allegiance.normalize(rawSide)
    if side == "neutral" then
        return Allegiance.normalize(currentRealm)
    end
    return side
end

-- Does an attacker attack a target, in `currentRealm`, under `aggressionPolicy`?
--   universal                 → true (Trials: everyone may initiate)
--   off-realm (neutral realm) → true (mechanic inactive; attack all, legacy behavior)
--   hell attacker            → true (attacks everything)
--   heaven attacker          → only a hell target
--   neutral resolves to the realm side first, then the above.
function Allegiance.hostile(attackerSide, targetSide, currentRealm, aggressionPolicy)
    if aggressionPolicy == "universal" then
        return true
    end
    local realm = Allegiance.normalize(currentRealm)
    if realm == "neutral" then
        return true -- homeworld / no realm: allegiance gating is off
    end
    local a = Allegiance.effective(attackerSide, realm)
    local t = Allegiance.effective(targetSide, realm)
    if a == "hell" then
        return true
    elseif a == "heaven" then
        return t == "hell"
    end
    return true
end

return Allegiance
