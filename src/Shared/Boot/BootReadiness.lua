--[[
    BootReadiness (shared) — race-free one-shot latches for event-driven boot.

    See docs/BOOT_ORCHESTRATION.md. Named milestones, each a latch that is signalled
    exactly once. The defining property: `await` on an ALREADY-signalled milestone returns
    immediately — a late subscriber can never miss the event. That kills the entire
    fire-once-event race class (the PetHandler :Wait() hang, etc.).

    API:
      BootReadiness.signal(name)            -> bool   mark done (idempotent; false if already)
      BootReadiness.await(name, timeout?)   -> bool   true when signalled; false on timeout
      BootReadiness.isReady(name)           -> bool
      BootReadiness.observe(callback)       -> ()     callback(name, info) on each signal
      BootReadiness.snapshot()              -> table  { [name] = { ready, at } }
      BootReadiness.reset()                 -> ()     (tests only) clear all state

    Pure Lua (coroutine-based) so it is unit-tested headless. In Studio waiters resume via
    `task.spawn` (scheduler-friendly); under the headless runner (no `task`) via
    `coroutine.resume`. Callers must NOT await in a service Init/Start directly (that blocks
    the loader) — await inside a `task.spawn`.
]]

local BootReadiness = {}

-- Roblox globals; both nil under the headless lune runner, which is the signal to fall back
-- to pure coroutine resumption.
local taskLib = task
local clock = (os and os.clock) or function()
    return 0
end

-- name -> { ready: bool, at: number?, waiters: { { thread, done, timedOut } } }
local milestones = {}
-- list of observer callbacks (the orchestrator's mirror/log hooks)
local observers = {}

local function getMilestone(name)
    local m = milestones[name]
    if not m then
        m = { ready = false, at = nil, waiters = {} }
        milestones[name] = m
    end
    return m
end

local function resumeThread(thread)
    if taskLib then
        taskLib.spawn(thread)
    else
        coroutine.resume(thread)
    end
end

-- Mark a milestone's work as STARTED (optional — enables a start log + a duration on signal).
-- Idempotent; ignored once already started or ready. Notifies observers with phase = "started".
function BootReadiness.begin(name)
    assert(type(name) == "string", "BootReadiness.begin: name must be a string")
    local m = getMilestone(name)
    if m.startedAt ~= nil or m.ready then
        return false
    end
    m.startedAt = clock()
    for _, cb in ipairs(observers) do
        pcall(cb, name, { phase = "started", at = m.startedAt })
    end
    return true
end

-- Mark a milestone done. Idempotent: a second signal is a no-op and returns false.
function BootReadiness.signal(name)
    assert(type(name) == "string", "BootReadiness.signal: name must be a string")
    local m = getMilestone(name)
    if m.ready then
        return false
    end
    m.ready = true
    m.at = clock()
    local duration = m.startedAt and (m.at - m.startedAt) or nil

    -- Notify observers (mirror/log). Observers must not yield; isolate failures.
    for _, cb in ipairs(observers) do
        pcall(
            cb,
            name,
            { phase = "ready", at = m.at, startedAt = m.startedAt, duration = duration }
        )
    end

    -- Release all waiters. Swap the list out first so a waiter that re-awaits doesn't mutate
    -- the list we're iterating.
    local waiters = m.waiters
    m.waiters = {}
    for _, entry in ipairs(waiters) do
        if not entry.done then
            entry.done = true
            resumeThread(entry.thread)
        end
    end
    return true
end

-- Yield the calling thread until `name` is signalled. Returns immediately (true) if already
-- signalled. With `timeout` (seconds, Studio only), returns false if it elapses first.
function BootReadiness.await(name, timeout)
    assert(type(name) == "string", "BootReadiness.await: name must be a string")
    local m = getMilestone(name)
    if m.ready then
        return true
    end

    local entry = { thread = coroutine.running(), done = false, timedOut = false }
    table.insert(m.waiters, entry)

    if timeout and taskLib then
        taskLib.delay(timeout, function()
            if not entry.done then
                entry.done = true
                entry.timedOut = true
                resumeThread(entry.thread)
            end
        end)
    end

    coroutine.yield()
    return not entry.timedOut
end

function BootReadiness.isReady(name)
    local m = milestones[name]
    return m ~= nil and m.ready == true
end

-- Register a callback invoked synchronously on every signal: callback(name, { at }).
function BootReadiness.observe(callback)
    assert(type(callback) == "function", "BootReadiness.observe: callback must be a function")
    table.insert(observers, callback)
end

-- A read-only view of every known milestone's state (for the orchestrator's mirror).
function BootReadiness.snapshot()
    local out = {}
    for name, m in pairs(milestones) do
        out[name] = { ready = m.ready, at = m.at, startedAt = m.startedAt }
    end
    return out
end

-- Test-only: clear all latches and observers so specs start from a clean slate.
function BootReadiness.reset()
    milestones = {}
    observers = {}
end

return BootReadiness
