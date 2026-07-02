--[[
    CombatRoll — pure hit / crit resolution (Halo & Horns combat).

    One place to roll whether an action lands and whether it crits — used for pet attacks,
    enemy attacks, and taunts (each with its own chances in configs/combat.lua `rolls`).
    Roblox-free + deterministic: the caller passes the random values (0..1), so tests can
    pin them; at runtime the service passes math.random().

    params = { hit_chance = 0..1, crit_chance = 0..1, crit_mult = number }
    returns { hit = bool, crit = bool, multiplier = number }
      multiplier: 0 on a miss, 1 on a normal hit, crit_mult on a crit — so callers just
      do `amount * result.multiplier`.
]]

local CombatRoll = {}

function CombatRoll.resolve(params, hitRoll, critRoll)
    params = params or {}
    local hitChance = params.hit_chance
    if hitChance == nil then
        hitChance = 1
    end
    local critChance = params.crit_chance or 0
    local critMult = params.crit_mult or 2

    local hit = (hitRoll or 0) < hitChance
    local crit = hit and ((critRoll or 1) < critChance)
    local multiplier = 0
    if hit then
        multiplier = crit and critMult or 1
    end
    return { hit = hit, crit = crit, multiplier = multiplier }
end

return CombatRoll
