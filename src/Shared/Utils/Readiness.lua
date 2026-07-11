local Readiness = {}

local function awaitPredicate(instance, attributeName, predicate, timeoutSeconds)
    if predicate(instance:GetAttribute(attributeName)) then
        return true
    end

    local waitingThread = coroutine.running()
    local settled = false
    local matched = false
    local connection
    local function finish(value)
        if settled then
            return
        end
        settled = true
        matched = value == true
        if connection then
            connection:Disconnect()
        end
        task.spawn(waitingThread)
    end

    connection = instance:GetAttributeChangedSignal(attributeName):Connect(function()
        if predicate(instance:GetAttribute(attributeName)) then
            finish(true)
        end
    end)
    task.delay(math.max(0, tonumber(timeoutSeconds) or 0), function()
        finish(false)
    end)
    if predicate(instance:GetAttribute(attributeName)) then
        finish(true)
    end
    coroutine.yield()
    return matched
end

function Readiness.awaitAttribute(instance, attributeName, expectedValue, timeoutSeconds)
    expectedValue = expectedValue == nil and true or expectedValue
    return awaitPredicate(instance, attributeName, function(value)
        return value == expectedValue
    end, timeoutSeconds)
end

function Readiness.awaitAttributePresent(instance, attributeName, timeoutSeconds)
    return awaitPredicate(instance, attributeName, function(value)
        return value ~= nil
    end, timeoutSeconds)
end

return Readiness
