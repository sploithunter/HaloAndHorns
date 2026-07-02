--[[
    DamageOverTime — pure functional core for DoT (burn / poison / bleed) on the pet-attack axis.

    DoT is ORTHOGONAL to targeting (Jason): targeting decides WHERE a hit lands (single /
    targeted_aoe / aura / contagion); DoT decides WHEN the damage resolves — instant vs ticking over
    time. So it composes with any targeting: a single-target burn, a targeted_aoe burn, etc. A pet
    declares it as a sibling field `attack_dot = { fraction, tick, duration }` in configs/pets.lua.

    On a hit, the attack stamps a DoT on the target: it deals `fraction * hitDamage` per tick, every
    `tick` seconds, for `duration` seconds. EnemyService stores the live state as plain attributes
    (DotPerTick / DotInterval / DotNextTick / DotExpireAt / DotSourceUserId) and calls these for the
    arithmetic — no Roblox APIs here, unit-tested headless.

      DamageOverTime.perTick(hitDamage, fraction)               -> integer per-tick damage (>=0)
      DamageOverTime.ticksDue(nextTickAt, interval, expireAt, now) -> count, newNextTickAt
      DamageOverTime.isExpired(expireAt, now)                   -> boolean
]]

local DamageOverTime = {}

-- Per-tick damage a hit's DoT deals: a fraction of the triggering hit, floored to a whole number.
function DamageOverTime.perTick(hitDamage, fraction)
    local d = (tonumber(hitDamage) or 0) * (tonumber(fraction) or 0)
    if d <= 0 then
        return 0
    end
    return math.floor(d + 0.5)
end

-- How many whole ticks are DUE at `now` (a slow combat loop may cover several intervals in one
-- step), and the advanced next-tick time. A tick only counts if it falls on/before the DoT's expiry
-- (+ epsilon) so a burn deals exactly duration/interval ticks, no more. Returns (count, newNextAt).
function DamageOverTime.ticksDue(nextTickAt, interval, expireAt, now)
    interval = tonumber(interval) or 0
    nextTickAt = tonumber(nextTickAt) or 0
    expireAt = tonumber(expireAt) or 0
    now = tonumber(now) or 0
    if interval <= 0 then
        return 0, nextTickAt
    end
    local count = 0
    local nextAt = nextTickAt
    while now >= nextAt and nextAt <= expireAt + 1e-6 do
        count += 1
        nextAt += interval
    end
    return count, nextAt
end

-- The DoT is finished once we're past its expiry time.
function DamageOverTime.isExpired(expireAt, now)
    return (tonumber(now) or 0) > (tonumber(expireAt) or 0)
end

return DamageOverTime
