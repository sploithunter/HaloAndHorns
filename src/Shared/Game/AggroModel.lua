--[[
    AggroModel — pure threat MAGNITUDE math for the unified aggro game (configs/aggro.lua).

    Symmetric by construction: every function takes the side ("pet" | "enemy") so the effective value
    is always base[x] * side.<x>_mult — identical machinery on both sides, with the per-side mult as the
    only artificial dial. No Roblox API, no table storage, no positions: this module answers "HOW MUCH
    threat" and "engaged or not"; the caller owns the threat tables (AggroTable), the radius queries,
    and the distance decay multiplier (AggroLeash). Pure + dependency-free so it unit-tests headless.

    Run: mise run test-headless
]]

local AggroModel = {}

-- Mirrors configs/aggro.lua `base` so the module is safe with a missing/partial cfg (tests, early boot).
local BASE_DEFAULTS = {
    threat_per_damage = 1.0,
    splash_frac = 0.25,
    seed_rate = 2,
    engage_floor = 5,
    exit_floor = 1,
    decay_per_second = 4,
}

local function baseNum(cfg, key, default)
    local b = cfg and cfg.base
    local v = b and b[key]
    if type(v) == "number" then
        return v
    end
    return default
end

-- Per-side multiplier over base. Defaults to 1 (symmetric) for a missing side/key.
local function sideMult(cfg, side, key)
    local s = cfg and side and cfg[side]
    local v = s and s[key]
    return (type(v) == "number") and v or 1
end

-- Direct threat a hit puts on the STRUCK unit's table toward the attacker. `side` = the struck
-- unit's side (so the attacker's threat is scaled by how much that side "cares").
function AggroModel.threatFromDamage(cfg, side, damage)
    local d = tonumber(damage) or 0
    if d <= 0 then
        return 0
    end
    return d
        * baseNum(cfg, "threat_per_damage", BASE_DEFAULTS.threat_per_damage)
        * sideMult(cfg, side, "threat_mult")
end

-- The per-side threat multiplier alone — for callers that already hold an aggro amount (e.g. the
-- enemy's existing damage→aggro credit in AddAggro) and just need the artificial difficulty dial.
function AggroModel.threatMult(cfg, side)
    return sideMult(cfg, side, "threat_mult")
end

-- Splash threat each of the struck unit's TEAMMATES gains toward the attacker — a fraction of the
-- direct credit (hit one, the team notices). `side` = the teammate's side (same team as struck).
function AggroModel.splashThreat(cfg, side, directThreat)
    local t = tonumber(directThreat) or 0
    if t <= 0 then
        return 0
    end
    return t
        * baseNum(cfg, "splash_frac", BASE_DEFAULTS.splash_frac)
        * sideMult(cfg, side, "splash_mult")
end

-- Per-tick proximity seed: a small trickle an APPROACHING hostile generates so a fight starts before
-- first contact. A parked/unreachable foe that only ever earns the seed decays back off — the farm-lock fix.
function AggroModel.seedThreat(cfg, side, dt)
    return baseNum(cfg, "seed_rate", BASE_DEFAULTS.seed_rate)
        * sideMult(cfg, side, "seed_mult")
        * (tonumber(dt) or 0)
end

-- Effective per-second decay rate for a side, given the distance multiplier from AggroLeash (1 / chase /
-- leave-area). Caller multiplies by dt and bleeds the table.
function AggroModel.decayRate(cfg, side, distMult)
    local per = baseNum(cfg, "decay_per_second", BASE_DEFAULTS.decay_per_second)
    local b = cfg and cfg.base and cfg.base.decay
    if b and type(b.per_second) == "number" then
        per = b.per_second
    end
    return per * sideMult(cfg, side, "decay_mult") * (tonumber(distMult) or 1)
end

-- Hysteresis gate: ENTER combat when top threat reaches engage_floor; once engaged, STAY until it
-- drops below exit_floor (engage_floor > exit_floor so a unit doesn't flap in and out of the fight).
function AggroModel.engaged(topThreat, wasEngaged, cfg)
    local t = tonumber(topThreat) or 0
    if wasEngaged then
        return t > baseNum(cfg, "exit_floor", BASE_DEFAULTS.exit_floor)
    end
    return t >= baseNum(cfg, "engage_floor", BASE_DEFAULTS.engage_floor)
end

-- RAGE TIPPING POINT (Phase 2, Jason): a unit whose HEAT (total positive threat directed AT it —
-- AggroTable.heat of its own table) crosses its side's rage tip snaps BERSERK, and stays berserk
-- until the heat cools below calm (hysteresis like `engaged`, so it never flaps at the boundary).
-- Knobs are PER-SIDE (cfg.rage.pet / cfg.rage.enemy) because the two sides' tables live on very
-- different scales (pet heat = enemy hits taken; enemy heat = the squad's DPS credited). Missing
-- knobs ⇒ tip = infinity ⇒ that side simply never rages (safe default).
function AggroModel.rageLatch(cfg, side, wasRaged, heat)
    local rage = (cfg and cfg.rage) or {}
    local knobs = rage[side] or rage
    local tip = tonumber(knobs.tip) or math.huge
    local calm = tonumber(knobs.calm) or 0
    local h = tonumber(heat) or 0
    if wasRaged then
        return h > calm
    end
    return h > tip
end

return AggroModel
