--[[
    EarlyBoostSampler — Roblox-free one-time level entitlement rules.

    Each configured milestone grants one inventory token after the player's claimed
    level reaches the threshold. Named markers make the schedule safe to reconcile
    for existing profiles without replaying the level-up claim.
]]

local EarlyBoostSampler = {}

local function stateFor(gameData)
    local state = type(gameData) == "table" and gameData.EarlyBoostSampler or nil
    return type(state) == "table" and state or {}
end

function EarlyBoostSampler.pendingGrants(gameData, claimedLevel, config)
    local level = math.max(0, math.floor(tonumber(claimedLevel) or 0))
    local state = stateFor(gameData)
    local pending = {}

    for index, grant in ipairs((config and config.grants) or {}) do
        if type(grant) == "table" then
            local requiredLevel = math.max(1, math.floor(tonumber(grant.claimed_level) or 1))
            local itemId = tostring(grant.item_id or "")
            local marker = tostring(grant.marker or ("level" .. requiredLevel .. "_v1"))
            if itemId ~= "" and level >= requiredLevel and state[marker] ~= true then
                pending[#pending + 1] = {
                    index = index,
                    level = requiredLevel,
                    itemId = itemId,
                    marker = marker,
                    quantity = math.max(1, math.floor(tonumber(grant.quantity) or 1)),
                    displayName = tostring(grant.display_name or itemId),
                    previous = state[marker],
                }
            end
        end
    end

    return pending
end

function EarlyBoostSampler.markGrant(gameData, grant)
    if type(gameData) ~= "table" or type(grant) ~= "table" then
        return false
    end
    gameData.EarlyBoostSampler = type(gameData.EarlyBoostSampler) == "table"
            and gameData.EarlyBoostSampler
        or {}
    gameData.EarlyBoostSampler[grant.marker] = true
    return true
end

function EarlyBoostSampler.restoreGrant(gameData, grant)
    local state = type(gameData) == "table" and gameData.EarlyBoostSampler or nil
    if type(state) == "table" and type(grant) == "table" then
        state[grant.marker] = grant.previous
    end
end

return EarlyBoostSampler
