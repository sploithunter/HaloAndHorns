local Budget = {}

function Budget.shouldSend(previous, now, nearby, config)
    if not config or not config.enabled or nearby or previous == nil then
        return true
    end
    return now - previous >= config.distant_interval
end

return Budget
