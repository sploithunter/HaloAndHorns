-- Pure receiver-policy and leaderboard classification rules for one-pet gifts.

local GiftLogic = {}

local LEADERBOARD_POINTS = {
    basic = 1,
    golden = 5,
    rainbow = 25,
}

GiftLogic.DEFAULT_PREFERENCE = "any"
GiftLogic.PREFERENCES = {
    any = { label = "Any gift" },
    uncommon_plus = { label = "Uncommon+", minimum = "uncommon" },
    rare_plus = { label = "Rare+", minimum = "rare" },
    mythic_plus = { label = "Mythical+", minimum = "mythic" },
    off = { label = "Gifts off", disabled = true },
}

local function rarityRanks(rarityOrder)
    local ranks = {}
    for rank, rarityId in ipairs(rarityOrder or {}) do
        ranks[rarityId] = rank
    end
    return ranks
end

function GiftLogic.sanitizePreference(value, defaultValue)
    if type(value) == "string" and GiftLogic.PREFERENCES[value] then
        return value
    end
    if type(defaultValue) == "string" and GiftLogic.PREFERENCES[defaultValue] then
        return defaultValue
    end
    return GiftLogic.DEFAULT_PREFERENCE
end

function GiftLogic.preferenceLabel(value, defaultValue)
    local mode = GiftLogic.sanitizePreference(value, defaultValue)
    return GiftLogic.PREFERENCES[mode].label
end

function GiftLogic.accepts(preference, rarityId, rarityOrder, defaultValue)
    local mode = GiftLogic.sanitizePreference(preference, defaultValue)
    local policy = GiftLogic.PREFERENCES[mode]
    if policy.disabled then
        return false, "gifts_off"
    end
    local ranks = rarityRanks(rarityOrder)
    local rarityRank = ranks[rarityId]
    if not rarityRank then
        return false, "unknown_rarity"
    end
    if mode == "any" then
        return true
    end
    local minimumRank = ranks[policy.minimum]
    if not minimumRank then
        return false, "unknown_rarity"
    end
    if rarityRank < minimumRank then
        return false, "below_preference"
    end
    return true
end

-- The record is authoritative for Huge and persisted rarity overrides. Config is
-- the fallback for compact stack records that intentionally store only identity.
function GiftLogic.resolveRarity(record, petsConfig)
    if type(record) ~= "table" then
        return nil
    end
    if record.huge == true then
        return "huge"
    end

    local rarityId = record.rarity_override or record.rarity_id
    if type(rarityId) == "string" and rarityId ~= "" then
        return rarityId
    end

    if petsConfig and type(petsConfig.getPet) == "function" and type(record.id) == "string" then
        local pet = petsConfig.getPet(record.id, record.variant or "basic")
        if type(pet) == "table" then
            return pet.rarity_id
        end
    end
    return nil
end

-- Three independent giver rankings. Huge is explicitly part of Exclusive,
-- matching the product decision for the three-category board.
function GiftLogic.leaderboardCounter(rarityId)
    if rarityId == "huge" or rarityId == "exclusive" then
        return "exclusive_gift_points"
    elseif rarityId == "secret" then
        return "secret_gift_points"
    elseif rarityId == "mythic" then
        return "mythical_gift_points"
    end
    return nil
end

-- Variant weights mirror the 5% Golden and 1% Rainbow hatch odds. Unknown or
-- legacy variants fail safely to the Basic value instead of inflating a score.
function GiftLogic.leaderboardPoints(recordOrVariant)
    local variant = recordOrVariant
    if type(recordOrVariant) == "table" then
        variant = recordOrVariant.variant
    end
    if type(variant) == "string" then
        variant = string.lower(variant)
    end
    return LEADERBOARD_POINTS[variant] or LEADERBOARD_POINTS.basic
end

-- Old persisted outboxes predate counter_points. Reconstruct their score from
-- the exact pet snapshot, while honoring a valid score already frozen at send.
function GiftLogic.leaderboardScore(gift, storedPoints)
    if type(gift) ~= "table" then
        return nil, 0
    end
    local counterId = GiftLogic.leaderboardCounter(gift.rarity_id)
    if not counterId then
        return nil, 0
    end
    local points = math.floor(tonumber(storedPoints) or 0)
    if points ~= 1 and points ~= 5 and points ~= 25 then
        points = GiftLogic.leaderboardPoints(gift.pet_record)
    end
    return counterId, points
end

return GiftLogic
