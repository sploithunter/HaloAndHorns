--[[
    PowerStats (pure) — resolve a Power record's `*Base` stats into EFFECTIVE values at cast time.
    See docs/PET_REALM_POWER_DATA_MODEL.md.

        effective = base × (caster/target level + kind) calc

    The level/kind calc is config-driven (`ctx.scaling`, one entry per axis) and defaults to
    IDENTITY — with no scaling config, `effective == base`, so introducing this resolver changes no
    behaviour (the balance tuning is a later phase). Accuracy reuses the level-diff to-hit curve via
    an INJECTED `ctx.toHit` function (so this module stays pure + headless-testable; PowerService
    passes `Accuracy.toHit` at runtime). Targets with no level (crystals, self/ally) never roll — the
    caller simply omits `ctx.targetLevel`, mirroring the mining accuracy exemption.

    Pure: no Roblox APIs, no requires. Inputs are plain tables; output is a plain table.
]]

local PowerStats = {}

local function num(v, default)
    local n = tonumber(v)
    if n == nil then
        return default
    end
    return n
end

-- A kind[] tag set targets enemies (and so can MISS) when it carries a hostile targeting tag.
-- self / ally / team / farm are not hostile and auto-land.
function PowerStats.targetsEnemies(kind)
    if type(kind) ~= "table" then
        return false
    end
    for _, k in ipairs(kind) do
        if k == "target" or k == "aoe" then
            return true
        end
    end
    return false
end

-- Per-axis level scaling: 1 + per_level × (level − base_level), clamped to [min, max]. With no cfg
-- (or an empty one) this returns 1 — the identity that keeps base == effective until a phase tunes it.
function PowerStats.levelScale(level, cfg)
    if type(cfg) ~= "table" then
        return 1
    end
    local per = num(cfg.per_level, 0)
    local baseLevel = num(cfg.base_level, 1)
    local scale = 1 + per * ((num(level, 1)) - baseLevel)
    local lo = num(cfg.min, 0)
    local hi = num(cfg.max, math.huge)
    return math.clamp(scale, lo, hi)
end

-- resolveEffective(power, ctx) -> effective stats.
--   power = a Power record (the `*Base` fields + `kind`).
--   ctx   = {
--     casterLevel?  = number (default 1) — player level, or pet EffectiveLevel when a pet casts,
--     targetLevel?  = number — the enemy's published Level (omit for crystals/self/ally → auto-land),
--     toHit?        = function(attackerLevel, defenderLevel, accCfg) -> chance  (inject Accuracy.toHit),
--     accuracy?     = table — combat.accuracy config passed through to toHit,
--     scaling?      = { recharge?, duration?, damage?, radius?, magnitude?, heal?, shield? } per-axis
--                     levelScale cfgs (each {per_level, base_level, min, max}); absent ⇒ identity,
--     critBonus?    = number — additive crit from buffs/auras (CritBuff + CritAura),
--     radiusMagnitude? = boolean — radius-magnitude families (Magnet): the reach IS the magnitude,
--                     so a `range` (radius) enhancement folds into the magnitude boost — both axes
--                     do the same job. Caller sets it from enhancements.radius_families[family].
--   }
function PowerStats.resolveEffective(power, ctx)
    power = power or {}
    ctx = ctx or {}
    local s = ctx.scaling or {}
    local casterLevel = num(ctx.casterLevel, 1)

    -- Slotted ENHANCEMENTS (Enhancements.aggregate over the power's slots): per-axis bonus
    -- fractions, e.g. { damage = 0.33, recharge = 0.20 }. Boost axes MULTIPLY by (1 + v);
    -- recharge DIVIDES by (1 + v) — a recharge enhancement SHORTENS the cooldown.
    local enh = ctx.enhancements or {}
    local function boost(axis)
        return 1 + (num(enh[axis], 0))
    end
    -- radius-magnitude families (Magnet): the reach IS the magnitude, so a `range` (radius)
    -- enhancement folds INTO the magnitude boost — both axes do the same job (Jason). This is
    -- the single home for that fold; the passive cast stamp resolves through here too, so the
    -- ENHANCE preview and the live HUD can never diverge.
    local magBoost = num(enh.magnitude, 0)
    if ctx.radiusMagnitude then
        magBoost += num(enh.radius, 0)
    end
    -- damage-magnitude families (vulnerability debuffs like Sandstorm): the power has no damage of
    -- its own — its `magnitude` IS the bonus-damage it makes enemies take. So a `damage` enhancement
    -- folds INTO the magnitude boost (otherwise it scales a 0 damageBase = no change). Same fold home
    -- as radiusMagnitude, so the ENHANCE preview and the live cast agree.
    if ctx.damageIsMagnitude then
        magBoost += num(enh.damage, 0)
    end
    -- heal-magnitude families: heal powers store the heal amount in magnitude (no healBase), so a
    -- `healing` enhancement folds into magnitude too (same reason as damageIsMagnitude).
    if ctx.healIsMagnitude then
        magBoost += num(enh.heal, 0)
    end

    local eff = {
        cost = num(power.costBase, 0), -- focus cost (unscaled by default)
        recharge = num(power.rechargeBase, 0)
            * PowerStats.levelScale(casterLevel, s.recharge)
            / boost("recharge"),
        duration = num(power.durationBase, 0)
            * PowerStats.levelScale(casterLevel, s.duration)
            * boost("duration"),
        damage = num(power.damageBase, 0) * PowerStats.levelScale(casterLevel, s.damage) * boost(
            "damage"
        ),
        tick = num(power.tickBase, 0), -- cadence is not level-scaled
        radius = num(power.radiusBase, 0) * PowerStats.levelScale(casterLevel, s.radius) * boost(
            "radius"
        ),
        magnitude = num(power.magnitudeBase, 0)
            * PowerStats.levelScale(casterLevel, s.magnitude)
            * (1 + magBoost),
        heal = num(power.healBase, 0) * PowerStats.levelScale(casterLevel, s.heal) * boost("heal"),
        shield = num(power.shieldBase, 0) * PowerStats.levelScale(casterLevel, s.shield) * boost(
            "shield"
        ),
        targets = power.targetsBase, -- nil = all-in-radius / single by kind
    }

    -- Accuracy: accuracyBase × to-hit, but only for hostile-targeting powers WITH a target level.
    -- Anything else (self/ally/team buffs, crystals) auto-lands at accuracyBase.
    local acc = num(power.accuracyBase, 1) * boost("accuracy")
    if ctx.targetLevel and ctx.toHit and PowerStats.targetsEnemies(power.kind) then
        acc = acc * (tonumber(ctx.toHit(casterLevel, ctx.targetLevel, ctx.accuracy)) or 1)
    end
    eff.accuracy = math.clamp(acc, 0, 1)

    -- Crit is FLAT-additive (a chance), not a multiplier: power's own critBase + buff/aura bonus.
    eff.crit = math.max(0, num(power.critBase, 0) + num(ctx.critBonus, 0))

    return eff
end

return PowerStats
