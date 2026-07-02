--[[
    AggroTable — pure threat-table core (Halo & Horns combat).

    Each enemy keeps an aggro table: a map of attacker -> accumulated aggro value. The
    enemy targets (chases + attacks) whoever is highest. Aggro is built by hurting the
    enemy (pets mining it) and by passive threat (a tank's Threat stat ticks it up), and
    it DECAYS over time — so when nothing keeps attacking, the top entry bleeds to zero
    and the enemy disengages. Powers can `clear` an entry (pacify) or `add` a big chunk
    (taunt / a player drawing aggro).

    Pure + Roblox-free: keys are opaque (pet Models / Players at runtime, strings in
    tests); values are numbers. The caller resolves a key's world position + validity.
]]

local AggroTable = {}

function AggroTable.new()
    return { values = {} }
end

-- Add (or subtract) aggro for an attacker. Entries may go NEGATIVE (Phase 2, Jason: fear = the
-- aggro goes negative and the unit RUNS) — a sub-zero entry marks a feared source the unit flees
-- (see `bottom`). Exactly-zero entries are dropped. No-op for a nil key or zero amount.
function AggroTable.add(state, key, amount)
    if key == nil or not amount or amount == 0 then
        return
    end
    local v = (state.values[key] or 0) + amount
    state.values[key] = (v ~= 0) and v or nil
end

-- Force an attacker's aggro to an exact value (fear writes a deterministic negative regardless of
-- how much threat the source had built). Zero clears the entry.
function AggroTable.set(state, key, value)
    if key == nil then
        return
    end
    local v = tonumber(value) or 0
    state.values[key] = (v ~= 0) and v or nil
end

function AggroTable.get(state, key)
    return state.values[key] or 0
end

-- Pacify: drop an attacker from the table entirely (aggro -> 0).
function AggroTable.clear(state, key)
    if key ~= nil then
        state.values[key] = nil
    end
end

-- Raise an attacker's aggro UP TO a floor (never lowers it). Used for proximity aggro:
-- a target close to the enemy keeps a baseline so decay can't drop it below the
-- disengage threshold while it's near — the enemy won't "forget" something in its face.
-- FEAR EXCEPTION: a NEGATIVE entry is a feared source — the unit is too terrified of it
-- for proximity/taunt to re-anchor threat; reinforce skips it until it recovers past 0.
function AggroTable.reinforce(state, key, floor)
    if key == nil or not floor or floor <= 0 then
        return
    end
    local cur = state.values[key] or 0
    if cur < 0 then
        return -- feared: recovery is decay-driven, never floor-forced
    end
    if cur < floor then
        state.values[key] = floor
    end
end

-- Bleed every entry TOWARD 0 by ratePerSecond * dt — positive threat cools off, and a
-- NEGATIVE (feared) entry recovers UP toward calm the same way. Entries reaching 0 are removed.
function AggroTable.decay(state, dt, ratePerSecond)
    local drop = (ratePerSecond or 0) * (dt or 0)
    if drop <= 0 then
        return
    end
    for key, v in pairs(state.values) do
        local nv
        if v > 0 then
            nv = v - drop
            state.values[key] = (nv > 0) and nv or nil
        else
            nv = v + drop
            state.values[key] = (nv < 0) and nv or nil
        end
    end
end

-- Highest-aggro key with value strictly above `minValue`, optionally filtered by
-- isValid(key) (e.g. skip downed/despawned attackers). Returns key, value — or nil if
-- the table is empty / everything is filtered out / nothing exceeds minValue.
function AggroTable.top(state, minValue, isValid)
    local floor = minValue or 0
    local bestKey, bestVal
    for key, v in pairs(state.values) do
        if v > floor and (not isValid or isValid(key)) then
            if not bestVal or v > bestVal then
                bestKey, bestVal = key, v
            end
        end
    end
    return bestKey, bestVal
end

-- Most-NEGATIVE key (the source the unit fears hardest), optionally filtered by isValid.
-- Returns key, value — or nil when nothing is negative. The focus rule (docs/AGGRO_MODEL.md):
-- attack top-of-table; when nothing positive remains and something is NEGATIVE ⇒ FLEE it.
function AggroTable.bottom(state, isValid)
    local worstKey, worstVal
    for key, v in pairs(state.values) do
        if v < 0 and (not isValid or isValid(key)) then
            if not worstVal or v < worstVal then
                worstKey, worstVal = key, v
            end
        end
    end
    return worstKey, worstVal
end

-- Snap every NEGATIVE entry back to 0 (fear window lapsed: the unit shakes it off and can
-- re-engage fresh — proximity/seed rebuild threat naturally from here).
function AggroTable.clearNegatives(state)
    for key, v in pairs(state.values) do
        if v < 0 then
            state.values[key] = nil
        end
    end
end

-- Total POSITIVE threat in the table — the unit's aggro HEAT (how hard the other side is
-- pressing it right now). The rage tipping point's input (docs/AGGRO_MODEL.md): heat past
-- rage.tip ⇒ berserk. Negative (feared) entries are terror, not pressure — excluded.
function AggroTable.heat(state)
    local sum = 0
    for _, v in pairs(state.values) do
        if v > 0 then
            sum += v
        end
    end
    return sum
end

-- Count of live entries (for tests / debug).
function AggroTable.size(state)
    local n = 0
    for _ in pairs(state.values) do
        n += 1
    end
    return n
end

return AggroTable
