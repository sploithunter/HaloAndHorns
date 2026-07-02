--[[
    PartyMath — pure functional core for group play (Feature 18).

    No Roblox APIs. Difficulty scaling reuses the combat group-scaling curve
    (CombatMath.groupScaledHp) — exposed here too for convenience.

      canJoin(currentSize, maxSize)        -> boolean
      scaledHp(baseHp, partySize, perExtra)-> integer
      splitLoot(loot, partySize)           -> { [currency] = perPlayerAmount }
      attribution(contributions)           -> { fractions = {id=frac}, mvp, total }
]]

local PartyMath = {}

function PartyMath.canJoin(currentSize, maxSize)
    return (tonumber(currentSize) or 0) < (tonumber(maxSize) or 0)
end

-- Enemy HP scaling with party size (solo = unscaled). Mirrors CombatMath.
function PartyMath.scaledHp(baseHp, partySize, perExtra)
    local size = math.max(1, tonumber(partySize) or 1)
    return math.floor((tonumber(baseHp) or 0) * (1 + (tonumber(perExtra) or 0) * (size - 1)) + 0.5)
end

-- Split a loot table equally among the party (floor per player).
function PartyMath.splitLoot(loot, partySize)
    local n = math.max(1, tonumber(partySize) or 1)
    local out = {}
    for currency, amount in pairs(loot or {}) do
        out[currency] = math.floor((tonumber(amount) or 0) / n)
    end
    return out
end

-- Damage attribution: proportional fractions per player + the MVP (top contributor).
function PartyMath.attribution(contributions)
    local total = 0
    for _, dmg in pairs(contributions or {}) do
        total += math.max(0, tonumber(dmg) or 0)
    end
    local fractions = {}
    local mvp, mvpDmg = nil, -1
    for id, dmg in pairs(contributions or {}) do
        local d = math.max(0, tonumber(dmg) or 0)
        fractions[id] = total > 0 and (d / total) or 0
        if d > mvpDmg then
            mvp, mvpDmg = id, d
        end
    end
    return { fractions = fractions, mvp = mvp, total = total }
end

return PartyMath
