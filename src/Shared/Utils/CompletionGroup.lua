local CompletionGroup = {}
CompletionGroup.__index = CompletionGroup

local taskLib = task

local function resume(thread)
    if taskLib then
        taskLib.spawn(thread)
    else
        coroutine.resume(thread)
    end
end

function CompletionGroup.new(expected)
    expected = math.max(0, math.floor(tonumber(expected) or 0))
    return setmetatable({
        _expected = expected,
        _completed = 0,
        _keys = {},
        _waiters = {},
        _cancelReason = nil,
    }, CompletionGroup)
end

function CompletionGroup:IsComplete()
    return self._cancelReason ~= nil or self._completed >= self._expected
end

function CompletionGroup:Resolve(key)
    if self:IsComplete() then
        return false
    end
    key = key or self._completed + 1
    if self._keys[key] then
        return false
    end
    self._keys[key] = true
    self._completed += 1
    if self._completed >= self._expected then
        self:_release()
    end
    return true
end

function CompletionGroup:Cancel(reason)
    if self:IsComplete() then
        return false
    end
    self._cancelReason = reason or "cancelled"
    self:_release()
    return true
end

function CompletionGroup:_release()
    local waiters = self._waiters
    self._waiters = {}
    for _, thread in ipairs(waiters) do
        resume(thread)
    end
end

function CompletionGroup:Await()
    if not self:IsComplete() then
        table.insert(self._waiters, coroutine.running())
        coroutine.yield()
    end
    return self._cancelReason == nil, self._cancelReason
end

return CompletionGroup
