-- Pure policy for limited tester-reward campaigns.
--
-- One award is one egg OR its one hatched pet. `awarded_to_user_id` never changes. Progression
-- reconciles only while the current owner matches that id; a trade therefore freezes the earned
-- tier without soul-binding either record. Returning the record to the award recipient resumes
-- reconciliation from their current claimed level.

local TesterRewardCampaign = {}

local TIER_RANK = {
    basic = 1,
    golden = 2,
    rainbow = 3,
}

local function positiveInt(value)
    value = tonumber(value)
    return value and value >= 1 and value % 1 == 0
end

function TesterRewardCampaign.recordKey(awardId, userId)
    return ("tester_reward|%s|%d"):format(tostring(awardId), tonumber(userId) or 0)
end

function TesterRewardCampaign.tierForLevel(level, campaign)
    level = math.max(1, math.floor(tonumber(level) or 1))
    campaign = campaign or {}
    if level >= (tonumber(campaign.rainbow_level) or math.huge) then
        return "rainbow"
    end
    if level >= (tonumber(campaign.golden_level) or math.huge) then
        return "golden"
    end
    return "basic"
end

function TesterRewardCampaign.isAwardOwner(record, ownerUserId)
    return type(record) == "table"
        and positiveInt(record.awarded_to_user_id)
        and tonumber(record.awarded_to_user_id) == tonumber(ownerUserId)
end

function TesterRewardCampaign.reconcileTier(record, ownerUserId, claimedLevel, campaign)
    if not TesterRewardCampaign.isAwardOwner(record, ownerUserId) then
        return false, tostring(record and record.award_tier or "basic")
    end

    local current = tostring(record.award_tier or record.variant or "basic"):lower()
    if not TIER_RANK[current] then
        current = "basic"
    end
    local desired = TesterRewardCampaign.tierForLevel(claimedLevel, campaign)
    if TIER_RANK[desired] <= TIER_RANK[current] then
        return false, current
    end

    record.award_tier = desired
    -- Both held eggs and hatched pets carry variant for projection/UI. The egg's authored model
    -- remains egg_id; variant describes the guaranteed pet result.
    record.variant = desired
    return true, desired
end

function TesterRewardCampaign.isClaimWindowOpen(campaign, now)
    local claim = type(campaign) == "table" and campaign.claim or nil
    if type(claim) ~= "table" or claim.enabled ~= true then
        return false
    end
    now = tonumber(now) or os.time()
    local startsAt = tonumber(claim.starts_at) or 0
    local endsAt = tonumber(claim.ends_at) or math.huge
    return now >= startsAt and now <= endsAt
end

function TesterRewardCampaign.canGrant(campaign, campaignState, claimedLevel)
    campaign = campaign or {}
    campaignState = campaignState or {}
    local limit = math.max(1, math.floor(tonumber(campaign.claim_limit) or 1))
    local granted = math.max(0, math.floor(tonumber(campaignState.granted_count) or 0))
    local minimumLevel = math.max(1, math.floor(tonumber(campaign.minimum_claim_level) or 1))
    return campaignState.eligible_at ~= nil
        and granted < limit
        and math.floor(tonumber(claimedLevel) or 1) >= minimumLevel
end

function TesterRewardCampaign.validate(config, petsConfig)
    if type(config) ~= "table" then
        return false, "expected table"
    end
    if type(config.defaults) ~= "table" then
        return false, "defaults expected table"
    end
    if type(config.campaigns) ~= "table" then
        return false, "campaigns expected table"
    end

    local seen = {}
    for campaignId, campaign in pairs(config.campaigns) do
        local path = "campaigns." .. tostring(campaignId)
        if type(campaignId) ~= "string" or campaignId == "" then
            return false, path .. " id must be a non-empty string"
        end
        if seen[campaignId] then
            return false, path .. " duplicate id"
        end
        seen[campaignId] = true
        if type(campaign) ~= "table" then
            return false, path .. " expected table"
        end
        for _, key in ipairs({ "egg_id", "pet_id" }) do
            if type(campaign[key]) ~= "string" or campaign[key] == "" then
                return false, path .. "." .. key .. " must be a non-empty string"
            end
        end
        if
            campaign.huge_pet_id ~= nil
            and (type(campaign.huge_pet_id) ~= "string" or campaign.huge_pet_id == "")
        then
            return false, path .. ".huge_pet_id must be a non-empty string when provided"
        end
        for _, key in ipairs({
            "claim_limit",
            "minimum_claim_level",
            "golden_level",
            "rainbow_level",
        }) do
            if not positiveInt(campaign[key]) then
                return false, path .. "." .. key .. " must be a positive integer"
            end
        end
        if campaign.golden_level <= campaign.minimum_claim_level then
            return false, path .. ".golden_level must exceed minimum_claim_level"
        end
        if campaign.rainbow_level <= campaign.golden_level then
            return false, path .. ".rainbow_level must exceed golden_level"
        end
        local hugeChance = tonumber(campaign.huge_chance)
        if not hugeChance or hugeChance < 0 or hugeChance > 1 then
            return false, path .. ".huge_chance must be between 0 and 1"
        end
        if type(campaign.claim) ~= "table" or type(campaign.claim.enabled) ~= "boolean" then
            return false, path .. ".claim.enabled must be boolean"
        end
        if campaign.claim.enabled then
            if not tonumber(campaign.claim.starts_at) or not tonumber(campaign.claim.ends_at) then
                return false, path .. ".claim requires numeric starts_at and ends_at"
            end
            if campaign.claim.ends_at <= campaign.claim.starts_at then
                return false, path .. ".claim.ends_at must exceed starts_at"
            end
        end
        if petsConfig then
            local eggs = petsConfig.egg_sources or {}
            local pets = petsConfig.pets or {}
            if not eggs[campaign.egg_id] then
                return false, path .. ".egg_id must reference pets.egg_sources"
            end
            if eggs[campaign.egg_id].fixed_odds ~= true then
                return false, path .. ".egg_id must be a fixed_odds held egg"
            end
            if not pets[campaign.pet_id] then
                return false, path .. ".pet_id must reference pets.pets"
            end
            if campaign.huge_pet_id and not pets[campaign.huge_pet_id] then
                return false, path .. ".huge_pet_id must reference pets.pets"
            end
        end
    end
    return true
end

return TesterRewardCampaign
