--[[
    FutureCallLogic — Roblox-free entitlement and identity rules.

    Existing profiles at or above the configured claimed level receive the
    starter grant once. Admin grants never write this marker, so they cannot
    accidentally consume the real progression entitlement.
]]

local FutureCallLogic = {}

function FutureCallLogic.shouldGrant(gameData, claimedLevel, config)
    local entitlement = config and config.entitlement or {}
    local requiredLevel = math.max(1, math.floor(tonumber(entitlement.claimed_level) or 5))
    if math.floor(tonumber(claimedLevel) or 0) < requiredLevel then
        return false
    end
    local state = type(gameData) == "table" and gameData.FutureCall or nil
    local marker = tostring(entitlement.marker or "level5_v1")
    return not (type(state) == "table" and state[marker] == true)
end

function FutureCallLogic.markGranted(gameData, config, value)
    if type(gameData) ~= "table" then
        return nil
    end
    gameData.FutureCall = type(gameData.FutureCall) == "table" and gameData.FutureCall or {}
    local marker =
        tostring((config and config.entitlement and config.entitlement.marker) or "level5_v1")
    gameData.FutureCall[marker] = value ~= false
    return marker
end

function FutureCallLogic.principalName(playerName, config)
    local formatString = config and config.principal and config.principal.name_format
        or "%s's Future Self"
    return string.format(formatString, tostring(playerName or "Player"))
end

return FutureCallLogic
