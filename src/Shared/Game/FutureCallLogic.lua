--[[
    FutureCallLogic — Roblox-free entitlement and identity rules.

    Existing profiles receive every configured level grant they qualify for,
    exactly once. Admin grants never write progression markers, so they cannot
    accidentally consume the real progression entitlement.
]]

local FutureCallLogic = {}

local function configuredGrants(config)
    local entitlement = config and config.entitlement or {}
    if type(entitlement.grants) == "table" then
        return entitlement.grants
    end
    -- Backward-compatible shape for an older config or a partially synced Studio.
    return { entitlement }
end

function FutureCallLogic.pendingGrants(gameData, claimedLevel, config)
    local level = math.max(0, math.floor(tonumber(claimedLevel) or 0))
    local state = type(gameData) == "table" and gameData.FutureCall or nil
    state = type(state) == "table" and state or {}
    local pending = {
        total = 0,
        grants = {},
    }

    for index, grant in ipairs(configuredGrants(config)) do
        if type(grant) == "table" then
            local requiredLevel = math.max(1, math.floor(tonumber(grant.claimed_level) or 5))
            local marker = tostring(grant.marker or ("level" .. requiredLevel .. "_v1"))
            if level >= requiredLevel and state[marker] ~= true then
                local amount = math.max(0, math.floor(tonumber(grant.grant_count) or 0))
                local legacy = grant.legacy
                if type(legacy) == "table" and state[tostring(legacy.marker or "")] == true then
                    amount = math.max(
                        0,
                        amount - math.max(0, math.floor(tonumber(legacy.granted_count) or 0))
                    )
                end
                pending.total += amount
                pending.grants[#pending.grants + 1] = {
                    index = index,
                    level = requiredLevel,
                    marker = marker,
                    amount = amount,
                    previous = state[marker],
                }
            end
        end
    end

    return pending
end

function FutureCallLogic.markPending(gameData, pending)
    if type(gameData) ~= "table" then
        return false
    end
    gameData.FutureCall = type(gameData.FutureCall) == "table" and gameData.FutureCall or {}
    for _, grant in ipairs(type(pending) == "table" and pending.grants or {}) do
        gameData.FutureCall[grant.marker] = true
    end
    return true
end

function FutureCallLogic.restorePending(gameData, pending)
    local state = type(gameData) == "table" and gameData.FutureCall or nil
    if type(state) ~= "table" then
        return
    end
    for _, grant in ipairs(type(pending) == "table" and pending.grants or {}) do
        state[grant.marker] = grant.previous
    end
end

function FutureCallLogic.principalName(playerName, config)
    local formatString = config and config.principal and config.principal.name_format
        or "%s's Future Self"
    return string.format(formatString, tostring(playerName or "Player"))
end

-- The future self follows the caller's real earned level, not a temporary team/alliance
-- EffectiveLevel. The cap comes from player_progression so Future Call cannot drift from
-- the game's authoritative level ceiling.
function FutureCallLogic.summonLevel(currentLevel, config, progressionConfig)
    local principal = config and config.principal or {}
    local xp = progressionConfig and progressionConfig.xp or {}
    local level = math.max(1, math.floor(tonumber(currentLevel) or 1))
    local offset = math.max(0, math.floor(tonumber(principal.level_offset) or 5))
    local cap = math.max(1, math.floor(tonumber(xp.max_level) or 50))
    return math.min(level + offset, cap)
end

return FutureCallLogic
