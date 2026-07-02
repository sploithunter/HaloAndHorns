--[[
    BattleSim — Monte Carlo squad-vs-pack battle simulator (pure; headless-tested).

    Jason: "the only way to make this real is to simulate it... we know all the exact
    mechanics... run it like 5 times. What [closed-form EV] is not taking into account is
    certain characters dying first — what if my armor buffer dies? It is no longer
    armoring. That makes a big ass difference."

    So this plays the fight FOR REAL on a fixed tick: swing timers, hit/crit rolls,
    armor-curve mitigation, threat/taunt targeting, endurance pools, shields — and the
    part that matters: when a pet goes DOWN its damage stops AND its auras stop
    (defense/offense/heal vanish mid-fight, exactly like EnemyService's live channels).

    Pure: all randomness comes through the injected rng() (math.random live, a seeded
    LCG in specs), so trials are reproducible headlessly. No Roblox APIs.

      BattleSim.run(spec, rng)            -> one trial result
      BattleSim.runMany(spec, trials, rng or seed) -> aggregate over N trials
      BattleSim.lcg(seed)                 -> deterministic rng for specs

    spec = {
      tick = 0.1, max_seconds = 90, armor_k = 100, dmg_axis_cap = 5,
      pets = { {
        perHit,                -- EV-free per-swing damage (profile.combatEffective; rolls happen here)
        interval,              -- seconds between swings
        hitChance, critChance, critMult,
        pool,                  -- endurance (Power x pet_down_threshold_factor)
        shield = 0,            -- flat absorb (CombatShield), depletes first
        defense = 0,           -- innate role + Defense attr + static power buffs
        threatMult = 1, taunt = false,
        dmgBuffFraction = 0,   -- STATIC player-power damage fraction (PetDamageBuff-1)
        variantMult = 1,       -- variant effect multiplier (basic 1 / golden 1.25 / rainbow 1.5)
        auras = { { kind = "offense"|"defense"|"heal", fraction|amount, interval } },
        -- rage auras pass through RAW ({ kind = "rage", enrage_below, mult }): the rules
        -- live in SupportAura.rageFraction — the SAME function EnemyService:_supportPass
        -- stamps live rage with (Jason: "the same unified code path"), scaled by
        -- variantMult here, not pre-scaled by the spec builder.
      } },
      enemies = { { hp, armor, dmg, cadence, hitChance, critChance, critMult } },
    }

    result = { cleared, t, petsDown, poolLeftFrac } | { cleared=false, t (die/timeout), timeout }
]]

-- Sibling pure module (headless loadModule resolves script.Parent to the repo dir).
local SupportAura = require(script.Parent:WaitForChild("SupportAura"))

local BattleSim = {}

-- Deterministic LCG (Numerical Recipes constants) for reproducible spec trials.
function BattleSim.lcg(seed)
    local state = (tonumber(seed) or 1) % 2147483647
    return function()
        state = (state * 1103515245 + 12345) % 2147483648
        return state / 2147483648
    end
end

local function num(v, d)
    return tonumber(v) or d
end

-- One full fight. Fixed-tick (default 0.1s): cheap, and finer than any swing cadence.
function BattleSim.run(spec, rng)
    spec = spec or {}
    rng = rng or BattleSim.lcg(1)
    local tick = num(spec.tick, 0.1)
    local maxT = num(spec.max_seconds, 90)
    local k = num(spec.armor_k, 100)
    local dmgCap = num(spec.dmg_axis_cap, 5)

    -- Working copies (the input spec is never mutated — callers reuse it across trials).
    local pets, enemies = {}, {}
    for i, p in ipairs(spec.pets or {}) do
        pets[i] = {
            perHit = num(p.perHit, 1),
            interval = math.max(num(p.interval, 1), tick),
            hitChance = num(p.hitChance, 1),
            critChance = num(p.critChance, 0),
            critMult = num(p.critMult, 2),
            pool = num(p.pool, 1),
            taken = 0,
            shield = num(p.shield, 0),
            defense = num(p.defense, 0),
            threatMult = num(p.threatMult, 1),
            taunt = p.taunt == true,
            dmgBuffFraction = num(p.dmgBuffFraction, 0),
            variantMult = num(p.variantMult, 1),
            auras = p.auras or {},
            threat = p.taunt and 1 or 0, -- a taunt pet starts on the table (it pulls)
            swingAt = 0,
            auraAt = {},
            down = false,
        }
    end
    for i, e in ipairs(spec.enemies or {}) do
        enemies[i] = {
            hp = num(e.hp, 1),
            armor = num(e.armor, 0),
            dmg = num(e.dmg, 0),
            cadence = math.max(num(e.cadence, 1.5), tick),
            hitChance = num(e.hitChance, 1),
            critChance = num(e.critChance, 0),
            critMult = num(e.critMult, 2),
            swingAt = 0,
        }
    end
    if #pets == 0 or #enemies == 0 then
        return { cleared = #enemies == 0, t = 0, petsDown = 0, poolLeftFrac = 1 }
    end

    -- Squad focus order: most dangerous per HP first (optimal focus fire — drop the
    -- biggest incoming-damage-per-effort targets, i.e. minions melt before the brute).
    local order = {}
    for i in ipairs(enemies) do
        order[#order + 1] = i
    end
    table.sort(order, function(a, b)
        local ea, eb = enemies[a], enemies[b]
        return (ea.dmg / ea.cadence) / math.max(ea.hp, 1)
            > (eb.dmg / eb.cadence) / math.max(eb.hp, 1)
    end)

    local function aliveOffenseFraction()
        local f = 0
        for _, p in ipairs(pets) do
            if not p.down then
                for _, a in ipairs(p.auras) do
                    if a.kind == "offense" then
                        f += num(a.fraction, 0)
                    end
                end
            end
        end
        return f
    end

    local function teamDefenseAmount(excludeDown)
        local d = 0
        for _, p in ipairs(pets) do
            if not (excludeDown and p.down) then
                for _, a in ipairs(p.auras) do
                    if a.kind == "defense" then
                        d += num(a.amount, 0)
                    end
                end
            end
        end
        return d
    end

    local function currentTarget()
        -- Enemy targeting: taunt pets hold the table while alive; otherwise top threat.
        local best, bestThreat
        for _, p in ipairs(pets) do
            if not p.down and p.taunt then
                if not best or p.threat > bestThreat then
                    best, bestThreat = p, p.threat
                end
            end
        end
        if best then
            return best
        end
        for _, p in ipairs(pets) do
            if not p.down and (not best or p.threat > bestThreat) then
                best, bestThreat = p, p.threat
            end
        end
        return best
    end

    local function focusEnemy()
        for _, idx in ipairs(order) do
            if enemies[idx].hp > 0 then
                return enemies[idx]
            end
        end
        return nil
    end

    local t = 0
    while t < maxT do
        t += tick

        -- Pets swing.
        local target = focusEnemy()
        if not target then
            break -- cleared (checked below with exact t)
        end
        local offFraction = aliveOffenseFraction()
        for _, p in ipairs(pets) do
            if not p.down and t >= p.swingAt then
                p.swingAt = t + p.interval
                if rng() < p.hitChance then
                    local dmg = p.perHit
                    -- RAGE: same rules as live (SupportAura.rageFraction — the unified
                    -- path), evaluated against this pet's CURRENT health each swing.
                    -- pool floor of 1 mirrors PetEndurance.maxEndurance.
                    local rageF = SupportAura.rageFraction(
                        p.auras,
                        1 - p.taken / math.max(p.pool, 1),
                        p.variantMult
                    )
                    local mult = math.min(1 + p.dmgBuffFraction + offFraction + rageF, dmgCap)
                    dmg = dmg * mult
                    if rng() < p.critChance then
                        dmg = dmg * p.critMult
                    end
                    dmg = dmg * (k / (target.armor + k))
                    dmg = math.max(1, math.floor(dmg + 0.5))
                    target.hp -= dmg
                    p.threat += dmg * p.threatMult
                    if target.hp <= 0 then
                        target = focusEnemy()
                        if not target then
                            break
                        end
                    end
                end
            end
        end

        -- Cleared?
        local anyEnemy = false
        for _, e in ipairs(enemies) do
            if e.hp > 0 then
                anyEnemy = true
                break
            end
        end
        if not anyEnemy then
            local downs, poolLeft, poolMax = 0, 0, 0
            for _, p in ipairs(pets) do
                poolMax += p.pool
                poolLeft += math.max(0, p.pool - p.taken)
                if p.down then
                    downs += 1
                end
            end
            return {
                cleared = true,
                t = t,
                petsDown = downs,
                poolLeftFrac = poolMax > 0 and poolLeft / poolMax or 1,
            }
        end

        -- Enemies swing (each at the live threat target; defense AURA only counts while
        -- its source pet is ALIVE — the armor buffer dying mid-fight is THE point).
        local auraDefense = teamDefenseAmount(true)
        for _, e in ipairs(enemies) do
            if e.hp > 0 and t >= e.swingAt then
                e.swingAt = t + e.cadence
                local victim = currentTarget()
                if not victim then
                    return { cleared = false, t = t, timeout = false } -- squad wiped
                end
                if rng() < e.hitChance then
                    local dmg = e.dmg
                    if rng() < e.critChance then
                        dmg = dmg * e.critMult
                    end
                    local defense = victim.defense + auraDefense
                    dmg = dmg * (k / (defense + k))
                    if victim.shield > 0 then
                        local absorbed = math.min(victim.shield, dmg)
                        victim.shield -= absorbed
                        dmg -= absorbed
                    end
                    victim.taken += dmg
                    if victim.taken >= victim.pool then
                        victim.down = true
                    end
                end
            end
        end

        -- Squad wiped?
        local anyPet = false
        for _, p in ipairs(pets) do
            if not p.down then
                anyPet = true
                break
            end
        end
        if not anyPet then
            return { cleared = false, t = t, timeout = false }
        end

        -- Heal auras (EnemyService heal channel: mend the most-hurt non-downed ally by
        -- a fraction of its pool, every interval — stops when the healer goes down).
        for _, p in ipairs(pets) do
            if not p.down then
                for ai, a in ipairs(p.auras) do
                    if a.kind == "heal" then
                        local interval = math.max(num(a.interval, 2), tick)
                        p.auraAt[ai] = p.auraAt[ai] or 0
                        if t >= p.auraAt[ai] then
                            p.auraAt[ai] = t + interval
                            local hurt
                            for _, q in ipairs(pets) do
                                if not q.down and q.taken > 0 then
                                    if not hurt or q.taken / q.pool > hurt.taken / hurt.pool then
                                        hurt = q
                                    end
                                end
                            end
                            if hurt then
                                hurt.taken =
                                    math.max(0, hurt.taken - num(a.fraction, 0) * hurt.pool)
                            end
                        end
                    end
                end
            end
        end
    end

    return { cleared = false, t = maxT, timeout = true } -- stalemate
end

local function median(list)
    if #list == 0 then
        return nil
    end
    table.sort(list)
    return list[math.ceil(#list / 2)]
end

-- N trials -> the aggregate the HUD shows. rngOrSeed: a function (live: math.random) or
-- a numeric seed (specs: deterministic; each trial reseeds seed+i so trials differ).
function BattleSim.runMany(spec, trials, rngOrSeed)
    trials = math.max(1, math.floor(tonumber(trials) or 5))
    local wins, clearTimes, dieTimes, downs, poolLefts = 0, {}, {}, {}, {}
    local timeouts = 0
    for i = 1, trials do
        local rng
        if type(rngOrSeed) == "function" then
            rng = rngOrSeed
        else
            rng = BattleSim.lcg((tonumber(rngOrSeed) or 0) + i * 7919)
        end
        local r = BattleSim.run(spec, rng)
        if r.cleared then
            wins += 1
            clearTimes[#clearTimes + 1] = r.t
            downs[#downs + 1] = r.petsDown or 0
            poolLefts[#poolLefts + 1] = r.poolLeftFrac or 0
        else
            dieTimes[#dieTimes + 1] = r.t
            if r.timeout then
                timeouts += 1
            end
        end
    end
    return {
        trials = trials,
        wins = wins,
        winRate = wins / trials,
        timeouts = timeouts,
        clearTime = median(clearTimes),
        dieTime = median(dieTimes),
        petsDown = median(downs),
        poolLeftFrac = median(poolLefts),
    }
end

return BattleSim
