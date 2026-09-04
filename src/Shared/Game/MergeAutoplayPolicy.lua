-- Pure production action whitelist and deterministic strategy scheduling.
local Policy = {}
local ALLOWED = {
    create = true,
    upgrade_base = true,
    place = true,
    merge = true,
    cannon = true,
    bulwark = true,
    collect = true,
}

function Policy.validate(config)
    if
        type(config) ~= "table"
        or type(config.enabled) ~= "boolean"
        or config.currency ~= "hall_coins"
        or type(config.pass_id) ~= "string"
        or type(config.entitlement_feature) ~= "string"
    then
        return false, "Invalid autoplay entitlement/currency"
    end
    for _, key in ipairs({
        "tick_seconds",
        "action_seconds",
        "target_timeout_seconds",
        "blocked_retry_seconds",
        "maximum_failures",
        "report_seconds",
        "history_limit",
        "arrival_distance",
        "collect_distance",
        "maximum_vertical_distance",
        "request_seconds",
    }) do
        local value = config[key]
        if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then
            return false, "Invalid autoplay " .. key
        end
    end
    if type(config.strategies) ~= "table" or not config.strategies[config.default_strategy] then
        return false, "Missing autoplay strategy"
    end
    for _, strategy in pairs(config.strategies) do
        if
            type(strategy) ~= "table"
            or type(strategy.sequence) ~= "table"
            or #strategy.sequence == 0
            or type(strategy.cannons) ~= "table"
            or type(strategy.bulwarks) ~= "table"
        then
            return false, "Invalid autoplay strategy"
        end
        for _, category in ipairs(strategy.sequence) do
            if category ~= "eggs" and category ~= "cannon" and category ~= "bulwark" then
                return false, "Unsafe autoplay category"
            end
        end
    end
    for _, key in ipairs({ "navigation", "ui", "labels", "purchase_menu" }) do
        if type(config[key]) ~= "table" then
            return false, "Missing autoplay " .. key
        end
    end
    return true
end

function Policy.allowed(action, config, testing)
    if type(action) ~= "table" or not ALLOWED[action.kind] then
        return false
    end
    local amount = tonumber(action.amount)
    if not amount or amount ~= amount or amount < 0 or amount == math.huge then
        return false
    end
    if action.currency ~= config.currency then
        return false
    end
    if action.operation == "unlock" then
        return false
    end
    if action.replacing == true and testing ~= true then
        return false
    end
    return true
end

function Policy.choose(candidates, state, config, now)
    local strategy = config.strategies[state.strategy or config.default_strategy]
    if not strategy then
        return nil
    end
    local groups = {}
    for _, action in ipairs(candidates) do
        if
            Policy.allowed(action, config, state.allowReplacement == true)
            and (not state.blocked[action.key] or state.blocked[action.key] <= now)
        then
            local group = action.freePriority and "free" or action.category
            groups[group] = groups[group] or {}
            table.insert(groups[group], action)
        end
    end
    local function best(group)
        local list = groups[group] or {}
        table.sort(list, function(a, b)
            local ap, bp = a.freePriority or a.priority or 0, b.freePriority or b.priority or 0
            if ap ~= bp then
                return ap < bp
            end
            if a.amount ~= b.amount then
                return a.amount < b.amount
            end
            return a.key < b.key
        end)
        return list[1]
    end
    local free = best("free")
    if free then
        return free
    end
    -- Save toward the scheduled purchase instead of starving expensive defenses by continually
    -- spending the wallet on cheap eggs. Skip categories with no legal owned/unlocked action.
    for offset = 0, #strategy.sequence - 1 do
        local index = ((state.cursor or 1) + offset - 1) % #strategy.sequence + 1
        local action = best(strategy.sequence[index])
        if action then
            action.cursor = index
            return action
        end
    end
    return nil
end

return Policy
