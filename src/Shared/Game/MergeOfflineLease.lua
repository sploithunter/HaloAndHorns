-- Pure fencing decisions. Transform functions are repeatable and never yield or mutate input.
local Lease = {}

function Lease.live(value, now)
    return type(value) == "table" and type(value.expires) == "number" and value.expires > now
end

function Lease.acquire(value, token, now, duration)
    if Lease.live(value, now) then
        return nil
    end
    return { mode = "offline", token = token, expires = now + duration }
end

function Lease.renew(value, token, now, duration)
    if not Lease.live(value, now) or value.mode ~= "offline" or value.token ~= token then
        return nil
    end
    return { mode = "offline", token = token, expires = now + duration }
end

function Lease.online(_value, token, now, duration)
    return { mode = "online", token = token, expires = now + duration }
end

function Lease.release(value, token, now, grace)
    if type(value) ~= "table" or value.token ~= token then
        return nil
    end
    return { mode = "cooldown", token = token, expires = now + grace }
end

function Lease.seeds(internal, config)
    local blocked, seen, result = {}, {}, {}
    for _, id in ipairs(config.excluded_user_ids) do
        blocked[id] = true
    end
    for _, account in ipairs(internal.accounts) do
        local id = account.id
        if type(id) == "number" and id > 0 and not blocked[id] and not seen[id] then
            seen[id] = true
            result[#result + 1] = id
        end
    end
    return result
end

function Lease.validate(config)
    if type(config) ~= "table" or type(config.enabled) ~= "boolean" then
        return false, "offline config missing"
    end
    for _, key in ipairs({
        "maximum_bays",
        "heartbeat_seconds",
        "lease_seconds",
        "fill_seconds",
        "selection_count",
        "acquisition_attempts",
        "pool_sort_range",
        "rotation_seconds",
        "load_timeout_seconds",
        "logout_grace_seconds",
        "walk_speed",
        "navigation_seconds",
        "max_navigation_waypoints",
    }) do
        local n = config[key]
        if type(n) ~= "number" or n ~= n or n <= 0 or n == math.huge then
            return false, "invalid offline " .. key
        end
    end
    if config.maximum_bays > 5 or config.heartbeat_seconds * 2 >= config.lease_seconds then
        return false, "unsafe offline capacity or lease"
    end
    for _, key in ipairs({
        "presence_map",
        "pool_store",
        "login_topic",
        "namespace",
        "pass",
        "name_prefix",
        "display_suffix",
        "claim_action_text",
        "profile_summary_key",
        "summary_title",
        "summary_body",
        "summary_details",
    }) do
        if type(config[key]) ~= "string" or config[key] == "" then
            return false, "invalid offline " .. key
        end
    end
    if type(config.excluded_user_ids) ~= "table" or type(config.studio_enabled) ~= "boolean" then
        return false, "invalid offline eligibility"
    end
    if type(config.studio_fixture_user_id) ~= "number" or config.studio_fixture_user_id >= 0 then
        return false, "fixture must never identify a real account"
    end
    if
        config.selection_count > 100
        or config.selection_count % 1 ~= 0
        or config.maximum_bays % 1 ~= 0
        or config.acquisition_attempts % 1 ~= 0
        or config.pool_sort_range > 2 ^ 31 - 1 -- math.random's signed integer limit, not tuning.
        or config.pool_sort_range % 1 ~= 0
    then
        return false, "offline bounds must fit platform limits"
    end
    return true
end

return Lease
