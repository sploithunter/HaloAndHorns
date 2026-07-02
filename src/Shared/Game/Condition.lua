--[[
    Condition — pure functional gate for the reward spine (Phase 7).

    The universal predicate reused by quests, daily milestones, and achievements.
    Evaluated against a plain snapshot (no Roblox APIs); the service builds the
    snapshot from StatsService / PlayerProgressionService / DataService.

    Snapshot shape:
      { counters = { breakables_broken = 37, ... }, level = 8, currencies = { coins = 1200 } }

    Condition types:
      { type = "counter_at_least",  counter = "breakables_broken", value = 50 }
      { type = "level_at_least",    value = 10 }
      { type = "currency_at_least", currency = "coins", value = 1000 }
      { type = "all_of", of = { {...}, {...} } }   -- every sub-condition met
      { type = "any_of", of = { {...}, {...} } }   -- at least one met

    progress() returns { current, target, fraction, met } for UI progress bars.
]]

local Condition = {}

-- The (current, target) pair a leaf condition measures. Composites aggregate.
local function leafValues(cond, snapshot)
    snapshot = snapshot or {}
    if cond.type == "counter_at_least" then
        local counters = snapshot.counters or {}
        return counters[cond.counter] or 0, cond.value or 0
    elseif cond.type == "level_at_least" then
        return snapshot.level or 1, cond.value or 0
    elseif cond.type == "currency_at_least" then
        local currencies = snapshot.currencies or {}
        return currencies[cond.currency] or 0, cond.value or 0
    end
    return nil, nil
end

function Condition.isMet(cond, snapshot)
    if not cond then
        return true -- no gate (e.g. shop offers gate on cost, not condition)
    end
    if cond.type == "all_of" then
        for _, sub in ipairs(cond.of or {}) do
            if not Condition.isMet(sub, snapshot) then
                return false
            end
        end
        return true
    elseif cond.type == "any_of" then
        for _, sub in ipairs(cond.of or {}) do
            if Condition.isMet(sub, snapshot) then
                return true
            end
        end
        return false
    end
    local current, target = leafValues(cond, snapshot)
    if current == nil then
        return false -- unknown condition type fails closed
    end
    return current >= target
end

function Condition.progress(cond, snapshot)
    if not cond then
        return { current = 1, target = 1, fraction = 1, met = true }
    end
    if cond.type == "all_of" or cond.type == "any_of" then
        local subs = cond.of or {}
        local metCount = 0
        for _, sub in ipairs(subs) do
            if Condition.isMet(sub, snapshot) then
                metCount += 1
            end
        end
        local target = #subs
        local met = Condition.isMet(cond, snapshot)
        return {
            current = metCount,
            target = target,
            fraction = target > 0 and math.min(1, metCount / target) or 1,
            met = met,
        }
    end
    local current, target = leafValues(cond, snapshot)
    current = current or 0
    target = target or 0
    local fraction = target > 0 and math.min(1, current / target) or 1
    return { current = current, target = target, fraction = fraction, met = current >= target }
end

return Condition
