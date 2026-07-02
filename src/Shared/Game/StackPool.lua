--[[
    StackPool (pure) — Feature 8.

    Token-bucket model for stacked common pets. A stack is
    { total_count, ready_count, last_update }. ready_count depletes when a pet is
    downed and refills lazily on read: one instance per `recharge` seconds, capped
    at total. A recharge of 0 refills instantly. Combat contribution scales by the
    ready/total ratio (linear or sqrt-diminishing). Never mutates input stacks.

    Pure: standard Lua only; unit-tested via `mise run test-headless`.
]]

local StackPool = {}

local function clamp(v, lo, hi)
    if v < lo then
        return lo
    elseif v > hi then
        return hi
    end
    return v
end

-- A fresh stack of `total` is fully ready.
function StackPool.newStack(total, now)
    return { total_count = total, ready_count = total, last_update = now }
end

-- Lazily refresh ready_count to account for time elapsed since last_update.
-- Returns a new stack with last_update advanced to `now`.
function StackPool.refresh(stack, now, recharge)
    local total = stack.total_count
    local ready = stack.ready_count
    -- instant-recharge zone -> fully ready
    if recharge == nil or recharge <= 0 then
        return { total_count = total, ready_count = total, last_update = now }
    end
    -- already full (or untracked) -> nothing to refill
    if ready >= total or stack.last_update == nil then
        return { total_count = total, ready_count = math.min(ready, total), last_update = now }
    end
    local elapsed = now - stack.last_update
    local refilled = math.floor(elapsed / recharge)
    return {
        total_count = total,
        ready_count = math.min(total, ready + refilled),
        last_update = now,
    }
end

-- Down one pet from the stack (no-op / no negative when already empty).
function StackPool.down(stack, now)
    if stack.ready_count <= 0 then
        return stack
    end
    return {
        total_count = stack.total_count,
        ready_count = stack.ready_count - 1,
        last_update = now,
    }
end

-- Combat contribution for a stack given its base power and a curve.
function StackPool.contribution(stack, basePower, curve)
    local total = stack.total_count
    if total <= 0 then
        return 0
    end
    local ready = stack.ready_count
    if curve == "sqrt_diminishing" then
        return basePower * (math.sqrt(ready) / math.sqrt(total))
    end
    -- default: linear
    return basePower * (ready / total)
end

-- Add `n` pets: both total and ready rise; refill state (last_update) unchanged.
function StackPool.add(stack, n)
    return {
        total_count = stack.total_count + n,
        ready_count = stack.ready_count + n,
        last_update = stack.last_update,
    }
end

-- Remove `n` pets: pulled from ready first, then non-ready; never negative.
function StackPool.remove(stack, n)
    local newTotal = math.max(0, stack.total_count - n)
    return {
        total_count = newTotal,
        ready_count = clamp(stack.ready_count - n, 0, newTotal),
        last_update = stack.last_update,
    }
end

return StackPool
