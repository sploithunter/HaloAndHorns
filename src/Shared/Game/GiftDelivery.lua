-- Pure, versioned ProfileStore message and idempotency rules for pet gifts.

local GiftDelivery = {}

GiftDelivery.MESSAGE_KIND = "gift_delivery"
GiftDelivery.MESSAGE_VERSION = 1

local VALID_RARITIES = {
    common = true,
    uncommon = true,
    rare = true,
    epic = true,
    legendary = true,
    mythic = true,
    secret = true,
    exclusive = true,
    huge = true,
}

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, child in pairs(value) do
        copy[key] = deepCopy(child)
    end
    return copy
end

local function validUserId(value, options)
    if type(value) ~= "number" or value == 0 or value ~= math.floor(value) then
        return false
    end
    return value > 0 or (value < 0 and options ~= nil and options.allow_studio_user_ids == true)
end

function GiftDelivery.isValidUserId(value, options)
    return validUserId(value, options)
end

function GiftDelivery.message(gift, options)
    local message = {
        kind = GiftDelivery.MESSAGE_KIND,
        version = GiftDelivery.MESSAGE_VERSION,
        gift = deepCopy(gift),
    }
    local ok, reason = GiftDelivery.validateMessage(message, options)
    if not ok then
        error("invalid gift: " .. tostring(reason))
    end
    return message
end

function GiftDelivery.isMessage(message)
    return type(message) == "table" and message.kind == GiftDelivery.MESSAGE_KIND
end

function GiftDelivery.validateMessage(message, options)
    if not GiftDelivery.isMessage(message) then
        return false, "wrong_kind"
    end
    if message.version ~= GiftDelivery.MESSAGE_VERSION then
        return false, "wrong_version"
    end
    local gift = message.gift
    if type(gift) ~= "table" then
        return false, "missing_gift"
    end
    if type(gift.id) ~= "string" or gift.id == "" then
        return false, "invalid_gift_id"
    end
    if not validUserId(gift.sender_user_id, options) then
        return false, "invalid_sender"
    end
    if not validUserId(gift.receiver_user_id, options) then
        return false, "invalid_receiver"
    end
    if type(gift.sender_name) ~= "string" or gift.sender_name == "" then
        return false, "invalid_sender_name"
    end
    if type(gift.sent_at) ~= "number" or gift.sent_at <= 0 then
        return false, "invalid_sent_at"
    end
    if type(gift.rarity_id) ~= "string" or not VALID_RARITIES[gift.rarity_id] then
        return false, "invalid_rarity"
    end
    if type(gift.record_key) ~= "string" or gift.record_key == "" then
        return false, "invalid_record_key"
    end
    if type(gift.pet_record) ~= "table" or type(gift.pet_record.id) ~= "string" then
        return false, "invalid_pet_record"
    end
    return true
end

function GiftDelivery.root(data)
    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    data.GameData.Gifts = type(data.GameData.Gifts) == "table" and data.GameData.Gifts or {}
    local root = data.GameData.Gifts
    root.outbox = type(root.outbox) == "table" and root.outbox or {}
    root.sent = type(root.sent) == "table" and root.sent or {}
    root.received = type(root.received) == "table" and root.received or {}
    return root
end

function GiftDelivery.isReceived(data, giftId)
    return GiftDelivery.root(data).received[giftId] == true
end

function GiftDelivery.markReceived(data, giftId)
    local received = GiftDelivery.root(data).received
    if received[giftId] == true then
        return false
    end
    -- Stable gift ids never expire from this ledger. A producer retry months later
    -- must still be unable to mint a second pet after the present was opened.
    received[giftId] = true
    return true
end

function GiftDelivery.isSent(data, giftId)
    return GiftDelivery.root(data).sent[giftId] == true
end

function GiftDelivery.markSent(data, giftId)
    local sent = GiftDelivery.root(data).sent
    if sent[giftId] == true then
        return false
    end
    sent[giftId] = true
    return true
end

function GiftDelivery.wrappedRecord(gift)
    return {
        id = "wrapped_pet_gift",
        gift_id = gift.id,
        sender_user_id = gift.sender_user_id,
        sender_name = gift.sender_name,
        receiver_user_id = gift.receiver_user_id,
        sent_at = gift.sent_at,
        rarity_id = gift.rarity_id,
        record_key = gift.record_key,
        pet_id = gift.pet_record.id,
        pet_variant = gift.pet_record.variant or "basic",
        pet_huge = gift.pet_record.huge == true,
        pet_record = deepCopy(gift.pet_record),
        obtained_at = gift.sent_at,
    }
end

function GiftDelivery.copy(value)
    return deepCopy(value)
end

return GiftDelivery
