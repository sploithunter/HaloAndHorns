-- Pure receiver-policy and leaderboard classification rules for one-pet gifts.

local GiftLogic = {}

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
        return "exclusive_pets_gifted"
    elseif rarityId == "secret" then
        return "secret_pets_gifted"
    elseif rarityId == "mythic" then
        return "mythical_pets_gifted"
    end
    return nil
end

return GiftLogic
