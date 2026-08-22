--[[
    AwardDelivery — pure durable-award message and claim-ledger rules.

    Producers queue a stable award id through ProfileStore:MessageAsync. The live
    server grants the bundle, records that id in the SAME profile, and acknowledges
    the message. ProfileStore then saves the grant + id + acknowledgement atomically.
    Timestamped messages that remain unclaimed through their deadline are acknowledged
    without a grant so offline award queues cannot remain collectible forever.
]]

local AwardDelivery = {}

AwardDelivery.MESSAGE_KIND = "award_delivery"
AwardDelivery.MESSAGE_VERSION = 1
AwardDelivery.DEFAULT_UNCLAIMED_EXPIRY_SECONDS = 30 * 24 * 60 * 60

local function nonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function timestamp(value)
    local number = tonumber(value)
    if not number or number < 0 or number ~= number or number == math.huge then
        return nil
    end
    return math.floor(number)
end

local function copyMap(value)
    local out = {}
    for key, child in pairs(type(value) == "table" and value or {}) do
        out[key] = child
    end
    return out
end

function AwardDelivery.message(award, options)
    assert(type(award) == "table", "award must be a table")
    assert(nonEmptyString(award.id), "award.id must be a non-empty string")
    assert(#award.id <= 160, "award.id must be at most 160 characters")
    assert(type(award.bundle) == "table", "award.bundle must be a table")

    local stamped = award
    if type(options) == "table" then
        local queuedAt = timestamp(options.now)
        assert(queuedAt ~= nil, "options.now must be a non-negative timestamp")
        local expirySeconds = math.max(
            1,
            math.floor(
                tonumber(options.expiry_seconds) or AwardDelivery.DEFAULT_UNCLAIMED_EXPIRY_SECONDS
            )
        )
        local createdAt = award.created_at == nil and queuedAt or timestamp(award.created_at)
        local expiresAt = award.expires_at == nil and (createdAt + expirySeconds)
            or timestamp(award.expires_at)
        assert(createdAt ~= nil, "award.created_at must be a non-negative timestamp")
        assert(expiresAt ~= nil, "award.expires_at must be a non-negative timestamp")
        assert(expiresAt >= createdAt, "award.expires_at must not precede award.created_at")

        stamped = copyMap(award)
        stamped.created_at = createdAt
        stamped.queued_at = queuedAt
        stamped.expires_at = expiresAt
    end

    return {
        kind = AwardDelivery.MESSAGE_KIND,
        version = AwardDelivery.MESSAGE_VERSION,
        award = stamped,
    }
end

function AwardDelivery.isMessage(message)
    return type(message) == "table" and message.kind == AwardDelivery.MESSAGE_KIND
end

function AwardDelivery.validateMessage(message)
    if not AwardDelivery.isMessage(message) then
        return false, "not_award_delivery"
    end
    if message.version ~= AwardDelivery.MESSAGE_VERSION then
        return false, "unsupported_version"
    end
    local award = message.award
    if type(award) ~= "table" then
        return false, "missing_award"
    end
    if not nonEmptyString(award.id) or #award.id > 160 then
        return false, "invalid_award_id"
    end
    if type(award.bundle) ~= "table" then
        return false, "invalid_bundle"
    end
    if award.source ~= nil and not nonEmptyString(award.source) then
        return false, "invalid_source"
    end
    if award.notification ~= nil and type(award.notification) ~= "table" then
        return false, "invalid_notification"
    end
    for _, field in ipairs({ "created_at", "queued_at", "expires_at" }) do
        if award[field] ~= nil and timestamp(award[field]) == nil then
            return false, "invalid_" .. field
        end
    end
    if
        award.created_at ~= nil
        and award.expires_at ~= nil
        and timestamp(award.expires_at) < timestamp(award.created_at)
    then
        return false, "invalid_expiry_order"
    end
    return true
end

function AwardDelivery.isExpired(award, now)
    if type(award) ~= "table" then
        return false
    end
    local expiresAt = timestamp(award.expires_at)
    local current = timestamp(now)
    return expiresAt ~= nil and current ~= nil and current >= expiresAt
end

function AwardDelivery.root(data)
    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    data.GameData.AwardDelivery = type(data.GameData.AwardDelivery) == "table"
            and data.GameData.AwardDelivery
        or {}

    local root = data.GameData.AwardDelivery
    root.claimed = type(root.claimed) == "table" and root.claimed or {}
    root.order = type(root.order) == "table" and root.order or {}
    return root
end

function AwardDelivery.isClaimed(data, awardId)
    local root = AwardDelivery.root(data)
    return root.claimed[awardId] ~= nil
end

function AwardDelivery.markClaimed(data, awardId, claimedAt, limit)
    local root = AwardDelivery.root(data)
    if root.claimed[awardId] ~= nil then
        return false
    end

    root.claimed[awardId] = math.max(0, math.floor(tonumber(claimedAt) or 0))
    table.insert(root.order, awardId)

    local cap = math.max(1, math.floor(tonumber(limit) or 500))
    while #root.order > cap do
        local oldest = table.remove(root.order, 1)
        if oldest ~= awardId then
            root.claimed[oldest] = nil
        end
    end
    return true
end

return AwardDelivery
