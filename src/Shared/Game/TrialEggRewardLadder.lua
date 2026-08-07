-- Pure policy for provenance-bound named-trial milestone eggs.

local TrialEggRewardLadder = {}

local function positiveInt(value)
    value = tonumber(value)
    return value and value >= 1 and value % 1 == 0
end

local function ownerMatches(record, userId)
    return type(record) == "table"
        and positiveInt(record.awarded_to_user_id) == true
        and tonumber(record.awarded_to_user_id) == tonumber(userId)
end

function TrialEggRewardLadder.recordKey(awardId, userId)
    return ("trial_reward|%s|%d"):format(tostring(awardId), tonumber(userId) or 0)
end

function TrialEggRewardLadder.isAwardOwner(record, userId)
    return ownerMatches(record, userId)
end

function TrialEggRewardLadder.isCanonicalRecordKey(recordKey, record, track)
    return type(recordKey) == "string"
        and type(record) == "table"
        and type(track) == "table"
        and positiveInt(record.awarded_to_user_id) == true
        and record.award_id == track.award_id
        and recordKey
            == TrialEggRewardLadder.recordKey(track.award_id, record.awarded_to_user_id)
end

function TrialEggRewardLadder.stageRank(track, stageId)
    for rank, milestone in ipairs((track and track.milestones) or {}) do
        if milestone.stage == stageId then
            return rank
        end
    end
    return 0
end

function TrialEggRewardLadder.earnedStage(track, claims, claimedLevel)
    claims = type(claims) == "table" and claims or {}
    claimedLevel = math.max(1, math.floor(tonumber(claimedLevel) or 1))
    local earned
    for _, milestone in ipairs((track and track.milestones) or {}) do
        local claimed = (tonumber(claims[milestone.quest_id]) or 0) > 0
        local levelOk = claimedLevel >= (tonumber(milestone.minimum_level) or 1)
        if claimed and levelOk then
            earned = milestone
        end
    end
    return earned
end

function TrialEggRewardLadder.nextMilestone(track, stageId)
    local current = TrialEggRewardLadder.stageRank(track, stageId)
    return (track and track.milestones and track.milestones[current + 1]) or nil
end

function TrialEggRewardLadder.applyStage(record, userId, track, milestone)
    if not ownerMatches(record, userId) or type(milestone) ~= "table" then
        return false, record and record.trial_reward_stage
    end
    local current = tostring(record.trial_reward_stage or "")
    if
        TrialEggRewardLadder.stageRank(track, milestone.stage)
        <= TrialEggRewardLadder.stageRank(track, current)
    then
        return false, current
    end

    record.trial_reward_stage = milestone.stage
    record.trial_reward_huge_chance = tonumber(milestone.huge_chance) or 0
    record.id = milestone.stage == "huge" and track.huge_egg_id or track.egg_id
    record.variant = milestone.forced_variant or "basic"
    -- Keep the shared award field meaningful to generic trade/card code. The trial-specific stage
    -- is separate because `charged` and `huge` are egg states, not pet variants.
    record.award_tier = record.variant
    return true, milestone.stage
end

function TrialEggRewardLadder.newRecord(track, milestone, userId, now, version)
    local record = {
        id = track.egg_id,
        quantity = 1,
        obtained_at = now,
        source = "trial_reward:" .. track.award_id,
        award_kind = "trial_egg",
        award_id = track.award_id,
        awarded_to_user_id = userId,
        award_version = math.max(1, math.floor(tonumber(version) or 1)),
        trial_reward_track = track.award_id,
    }
    TrialEggRewardLadder.applyStage(record, userId, track, milestone)
    return record
end

function TrialEggRewardLadder.validate(config, petsConfig, questsConfig)
    if type(config) ~= "table" or type(config.tracks) ~= "table" then
        return false, "tracks expected table"
    end
    local eggs = (petsConfig and petsConfig.egg_sources) or {}
    local quests = (questsConfig and questsConfig.defs) or {}
    local seenAwards = {}
    for trackId, definition in pairs(config.tracks) do
        local path = "tracks." .. tostring(trackId)
        if type(definition) ~= "table" then
            return false, path .. " expected table"
        end
        if type(definition.award_id) ~= "string" or definition.award_id == "" then
            return false, path .. ".award_id expected non-empty string"
        end
        if seenAwards[definition.award_id] then
            return false, path .. ".award_id must be unique"
        end
        seenAwards[definition.award_id] = true
        for _, key in ipairs({ "egg_id", "huge_egg_id" }) do
            if type(definition[key]) ~= "string" or not eggs[definition[key]] then
                return false, path .. "." .. key .. " must reference pets.egg_sources"
            end
            if eggs[definition[key]].fixed_odds ~= true then
                return false, path .. "." .. key .. " must be fixed_odds"
            end
        end
        if type(definition.milestones) ~= "table" or #definition.milestones == 0 then
            return false, path .. ".milestones expected non-empty array"
        end
        local priorClears = 0
        local stages = {}
        for index, milestone in ipairs(definition.milestones) do
            local mpath = path .. ".milestones[" .. index .. "]"
            if not positiveInt(milestone.clears) or milestone.clears <= priorClears then
                return false, mpath .. ".clears must increase"
            end
            priorClears = milestone.clears
            if type(milestone.stage) ~= "string" or stages[milestone.stage] then
                return false, mpath .. ".stage must be a unique string"
            end
            stages[milestone.stage] = true
            if type(milestone.quest_id) ~= "string" or not quests[milestone.quest_id] then
                return false, mpath .. ".quest_id must reference quests.defs"
            end
            local chance = tonumber(milestone.huge_chance)
            if not chance or chance < 0 or chance > 1 then
                return false, mpath .. ".huge_chance must be between 0 and 1"
            end
            if
                milestone.forced_variant ~= nil
                and milestone.forced_variant ~= "basic"
                and milestone.forced_variant ~= "golden"
                and milestone.forced_variant ~= "rainbow"
            then
                return false, mpath .. ".forced_variant invalid"
            end
        end
    end
    return true
end

return TrialEggRewardLadder
