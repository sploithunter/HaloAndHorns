-- Positive permission only. Unknown/failed ownership checks never mean "does not own".
local Policy = {}
function Policy.eligible(marketplaceOwns, effectiveCollector, previouslyOwned)
    return marketplaceOwns == false and effectiveCollector ~= true and previouslyOwned ~= true
end
function Policy.pickup(state, now, eligible, manual, currency, config)
    if not config.enabled or eligible ~= true or not manual or not config.currencies[currency] then
        return false
    end
    state.pickups = math.min((state.pickups or 0) + 1, config.manual_pickups)
    if
        state.pickups < config.manual_pickups
        or (state.notifications or 0) >= config.max_notifications
        or now < (state.nextAt or 0)
    then
        return false
    end
    state.pickups = 0
    state.notifications = (state.notifications or 0) + 1
    state.nextAt = now + config.notification_interval_seconds
    return true
end
function Policy.canPlay(snapshot)
    return snapshot.eligible == true and snapshot.collector ~= true and not snapshot.blocked
end
return Policy
