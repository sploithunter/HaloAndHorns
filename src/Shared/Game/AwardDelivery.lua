--[[
    AwardDelivery — pure durable-award message and claim-ledger rules.

    Producers queue a stable award id through ProfileStore:MessageAsync. The live
    server grants the bundle, records that id in the SAME profile, and acknowledges
    the message. ProfileStore then saves the grant + id + acknowledgement atomically.
]]

local AwardDelivery = {}

AwardDelivery.MESSAGE_KIND = "award_delivery"
AwardDelivery.MESSAGE_VERSION = 1

local function nonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

function AwardDelivery.message(award)
    assert(type(award) == "table", "award must be a table")
    assert(nonEmptyString(award.id), "award.id must be a non-empty string")
    assert(#award.id <= 160, "award.id must be at most 160 characters")
    assert(type(award.bundle) == "table", "award.bundle must be a table")

    return {
        kind = AwardDelivery.MESSAGE_KIND,
        version = AwardDelivery.MESSAGE_VERSION,
        award = award,
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
    return true
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
