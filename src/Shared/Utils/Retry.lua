--[[
    Retry — bounded retry orchestration with an injected wait function.

    The operation returns (success, value). The caller owns the operation, logging, and wait
    implementation; this module owns only attempt count and configured backoff selection.
]]

local Retry = {}

function Retry.run(operation, options)
    options = options or {}
    local attempts = math.max(1, math.floor(tonumber(options.attempts) or 1))
    local backoff = type(options.backoff_seconds) == "table" and options.backoff_seconds or {}
    local wait = options.wait
    local lastResult

    for attempt = 1, attempts do
        local success, result = operation(attempt)
        if success then
            return true, result, attempt
        end
        lastResult = result
        if attempt < attempts and wait then
            local delay = tonumber(backoff[math.min(attempt, #backoff)]) or 0
            wait(math.max(0, delay))
        end
    end

    return false, lastResult, attempts
end

return Retry
