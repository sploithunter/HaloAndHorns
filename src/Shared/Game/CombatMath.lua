--[[
    CombatMath — pure functional core for combat resolution (Feature 10).

    No Roblox APIs, no module requires (self-contained for headless runs). Pet
    power is computed elsewhere (PowerFormula) and passed in as a number; this
    module handles the combat arithmetic on top of it.

      attackDamage(petPower, buffMult?)        -> integer damage per hit
      applyDamage(enemyHp, dmg)                -> remaining hp (>= 0)
      isDefeated(enemyHp)                      -> boolean
      encounterEnded(enemies)                  -> boolean (no enemy with hp > 0)
      isPetDowned(damageTaken, petPower, cfg)  -> boolean
      groupScaledHp(baseHp, partySize, cfg)    -> integer
      sunderAmount(enemyAttack)                -> number (Focus drained per hit)
      resolveLoot(dropTable)                   -> { [currency] = amount } (deterministic)
]]

local CombatMath = {}

local function round(n)
    return math.floor(n + 0.5)
end

-- Damage a pet deals per hit. Pet power is the base; an optional buff multiplier
-- (e.g. a player support power) scales it. Mirrors PowerFormula's rounding.
function CombatMath.attackDamage(petPower, buffMult)
    return round(petPower * (buffMult or 1))
end

function CombatMath.applyDamage(enemyHp, dmg)
    local remaining = enemyHp - dmg
    if remaining < 0 then
        return 0
    end
    return remaining
end

function CombatMath.isDefeated(enemyHp)
    return enemyHp <= 0
end

-- Damage after armor mitigation (the defensive stat). Armor curve with diminishing
-- returns and no hard cap: mitigation = armor / (armor + k), so taken = dmg*(1 - that).
-- armor 0 -> full damage; armor == k -> half; armor 3k -> quarter. k is the tuning
-- constant (configs/combat.lua armor_curve_k). Never negative.
function CombatMath.mitigate(dmg, armor, k)
    armor = math.max(0, armor or 0)
    k = k or 100
    if armor <= 0 or k <= 0 then
        return math.max(0, dmg or 0)
    end
    local taken = (dmg or 0) * (1 - armor / (armor + k))
    return taken > 0 and taken or 0
end

-- The encounter ends when no enemy is still alive.
function CombatMath.encounterEnded(enemies)
    for _, e in ipairs(enemies) do
        if (e.hp or 0) > 0 then
            return false
        end
    end
    return true
end

-- A pet (no HP stat) is downed once accumulated enemy damage reaches its
-- power * pet_down_threshold_factor. Downing routes to Spirit Form (Feature 7).
function CombatMath.isPetDowned(damageTaken, petPower, config)
    return damageTaken >= petPower * config.pet_down_threshold_factor
end

-- Multiplayer enemy HP scaling (Feature 18): solo party (size 1) is unscaled.
function CombatMath.groupScaledHp(baseHp, partySize, config)
    local size = partySize or 1
    if size < 1 then
        size = 1
    end
    return round(baseHp * (1 + config.group_scaling.per_extra_player * (size - 1)))
end

-- Focus drained from the player when this enemy attack lands (Feature 12).
function CombatMath.sunderAmount(enemyAttack)
    return (enemyAttack and enemyAttack.sundering) or 0
end

-- Deterministic loot from a drop table: numeric currency/token amounts only.
-- Keys ending in "_chance" are random rolls handled live ([studio]) and skipped.
function CombatMath.resolveLoot(dropTable)
    local out = {}
    for currency, amount in pairs(dropTable or {}) do
        if type(amount) == "number" and not string.match(currency, "_chance$") then
            out[currency] = amount
        end
    end
    return out
end

return CombatMath
