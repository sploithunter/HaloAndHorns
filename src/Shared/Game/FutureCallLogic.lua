--[[
    FutureCallLogic — Roblox-free entitlement and identity rules.

    Existing profiles receive every configured level grant they qualify for,
    exactly once. Admin grants never write progression markers, so they cannot
    accidentally consume the real progression entitlement.
]]

local FutureCallLogic = {}

local function onboardingConfig(config)
    return type(config and config.onboarding) == "table" and config.onboarding or {}
end

function FutureCallLogic.isUnlocked(earnedLevel, config)
    local required = math.max(1, math.floor(tonumber(onboardingConfig(config).unlock_level) or 4))
    return math.max(0, math.floor(tonumber(earnedLevel) or 0)) >= required
end

-- Returns one of three idempotent actions:
--   grant: a profile that has ascended through Level 2 receives the locked token;
--   unlock: that profile has now earned Level 4;
--   migrate: a profile already at Level 4+ is stamped without another token.
function FutureCallLogic.onboardingPlan(gameData, claimedLevel, earnedLevel, config)
    local authored = onboardingConfig(config)
    local grantLevel = math.max(1, math.floor(tonumber(authored.grant_claimed_level) or 2))
    local grantMarker = tostring(authored.grant_marker or "onboarding_token_v1")
    local unlockMarker = tostring(authored.unlock_marker or "onboarding_unlocked_v1")
    local state = type(gameData) == "table" and gameData.FutureCall or nil
    state = type(state) == "table" and state or {}
    local unlocked = FutureCallLogic.isUnlocked(earnedLevel, config)
    local hasGrantMarker = state[grantMarker] == true
    local hasUnlockMarker = state[unlockMarker] == true

    if not hasGrantMarker then
        if unlocked then
            return {
                kind = "migrate",
                grantMarker = grantMarker,
                unlockMarker = unlockMarker,
                previousGrant = state[grantMarker],
                previousUnlock = state[unlockMarker],
            }
        end
        if math.max(0, math.floor(tonumber(claimedLevel) or 0)) < grantLevel then
            return { kind = "none" }
        end
        return {
            kind = "grant",
            amount = math.max(1, math.floor(tonumber(authored.grant_count) or 1)),
            grantMarker = grantMarker,
            previousGrant = state[grantMarker],
        }
    end

    if unlocked and not hasUnlockMarker then
        return {
            kind = "unlock",
            unlockMarker = unlockMarker,
            previousUnlock = state[unlockMarker],
        }
    end
    return { kind = "none" }
end

function FutureCallLogic.markOnboarding(gameData, plan)
    if type(gameData) ~= "table" or type(plan) ~= "table" then
        return false
    end
    gameData.FutureCall = type(gameData.FutureCall) == "table" and gameData.FutureCall or {}
    if plan.grantMarker then
        gameData.FutureCall[plan.grantMarker] = true
    end
    if plan.unlockMarker then
        gameData.FutureCall[plan.unlockMarker] = true
    end
    return true
end

function FutureCallLogic.restoreOnboarding(gameData, plan)
    local state = type(gameData) == "table" and gameData.FutureCall or nil
    if type(state) ~= "table" or type(plan) ~= "table" then
        return
    end
    if plan.grantMarker then
        state[plan.grantMarker] = plan.previousGrant
    end
    if plan.unlockMarker then
        state[plan.unlockMarker] = plan.previousUnlock
    end
end

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
