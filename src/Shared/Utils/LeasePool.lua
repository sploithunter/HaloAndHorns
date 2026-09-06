-- Bounded idle reuse with lease identities. Delayed owners must retain their lease,
-- not just the object: an old callback must never release a newer use of that object.
local LeasePool = {}
LeasePool.__index = LeasePool

function LeasePool.new(capacity, factory)
    return setmetatable({
        _capacity = math.max(0, math.floor(tonumber(capacity) or 0)),
        _factory = factory,
        _idle = {},
        _active = {},
        _nextLease = 0,
        _closed = false,
        _counts = { created = 0, reused = 0, released = 0, destroyed = 0, active = 0 },
    }, LeasePool)
end

function LeasePool:_destroy(value)
    self._factory.destroy(value)
    self._counts.destroyed += 1
end

function LeasePool:acquire()
    assert(not self._closed, "pool is disposed")
    local value = table.remove(self._idle)
    while value and not self._factory.usable(value) do
        self:_destroy(value)
        value = table.remove(self._idle)
    end
    if value then
        self._counts.reused += 1
    else
        value = self._factory.create()
        self._counts.created += 1
    end
    self._factory.reset(value)
    self._nextLease += 1
    local lease = self._nextLease
    self._active[value] = lease
    self._counts.active += 1
    return value, lease
end

function LeasePool:isCurrent(value, lease)
    return lease ~= nil and self._active[value] == lease
end

function LeasePool:release(value, lease)
    if not self:isCurrent(value, lease) then
        return false
    end
    -- Invalidate before cleanup: cancelling a tween may synchronously fire callbacks.
    self._active[value] = nil
    self._counts.active -= 1
    self._counts.released += 1
    self._factory.clean(value)
    if not self._closed and #self._idle < self._capacity and self._factory.usable(value) then
        table.insert(self._idle, value)
    else
        self:_destroy(value)
    end
    return true
end

function LeasePool:stats()
    local result = table.clone(self._counts)
    result.idle = #self._idle
    result.capacity = self._capacity
    result.closed = self._closed
    return result
end

function LeasePool:dispose()
    if self._closed then
        return
    end
    self._closed = true
    for value, lease in pairs(self._active) do
        self:release(value, lease)
    end
    for _, value in ipairs(self._idle) do
        self:_destroy(value)
    end
    table.clear(self._idle)
end

return LeasePool
