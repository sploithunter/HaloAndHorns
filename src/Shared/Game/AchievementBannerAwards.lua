-- Pure permanent-award ledger and automatic display policy for player-bay banners.

local AchievementBannerAwards = {}

local function positiveWhole(value, fallback)
    local number = tonumber(value)
    if number == nil then
        number = fallback or 0
    end
    return math.max(0, math.floor(number))
end

local function validId(value)
    return type(value) == "string" and value ~= ""
end

function AchievementBannerAwards.normalize(raw)
    raw = type(raw) == "table" and raw or {}
    raw.version = positiveWhole(raw.version, 1)
    raw.owned = type(raw.owned) == "table" and raw.owned or {}
    raw.pending = type(raw.pending) == "table" and raw.pending or {}
    raw.displayed = type(raw.displayed) == "table" and raw.displayed or {}

    local displayed = {}
    local seen = {}
    for _, awardId in ipairs(raw.displayed) do
        if validId(awardId) and raw.owned[awardId] ~= nil and not seen[awardId] then
            seen[awardId] = true
            displayed[#displayed + 1] = awardId
        end
    end
    raw.displayed = displayed
    return raw
end

function AchievementBannerAwards.eligible(catalog, facts)
    local eligible = {}
    for awardId, award in pairs(type(catalog) == "table" and catalog or {}) do
        local trigger = type(award) == "table" and award.trigger or nil
        local fact = type(trigger) == "table" and trigger.fact or nil
        local goal = type(trigger) == "table" and tonumber(trigger.at_least) or nil
        local value = fact and tonumber(type(facts) == "table" and facts[fact] or nil) or nil
        if validId(awardId) and validId(fact) and goal and value and value >= goal then
            eligible[#eligible + 1] = awardId
        end
    end
    table.sort(eligible)
    return eligible
end

function AchievementBannerAwards.grant(state, awardId, metadata, earnedAt)
    state = AchievementBannerAwards.normalize(state)
    if not validId(awardId) or state.owned[awardId] ~= nil then
        return false, state.owned[awardId]
    end
    metadata = type(metadata) == "table" and metadata or {}
    local record = {
        earned_at = positiveWhole(earnedAt, os.time()),
        source = validId(metadata.source) and metadata.source or "progression",
        value = tonumber(metadata.value),
    }
    state.owned[awardId] = record
    state.pending[awardId] = true
    return true, record
end

function AchievementBannerAwards.pendingIds(state, catalog)
    state = AchievementBannerAwards.normalize(state)
    catalog = type(catalog) == "table" and catalog or {}
    local ids = {}
    for awardId, pending in pairs(state.pending) do
        if pending == true and state.owned[awardId] ~= nil and catalog[awardId] ~= nil then
            ids[#ids + 1] = awardId
        end
    end
    table.sort(ids, function(a, b)
        local left = state.owned[a] or {}
        local right = state.owned[b] or {}
        local leftAt = positiveWhole(left.earned_at)
        local rightAt = positiveWhole(right.earned_at)
        if leftAt ~= rightAt then
            return leftAt < rightAt
        end
        local leftPriority = tonumber(catalog[a] and catalog[a].priority) or 0
        local rightPriority = tonumber(catalog[b] and catalog[b].priority) or 0
        if leftPriority ~= rightPriority then
            return leftPriority < rightPriority
        end
        return a < b
    end)
    return ids
end

function AchievementBannerAwards.present(state, awardIds, maximum, presentedAt)
    state = AchievementBannerAwards.normalize(state)
    maximum = math.max(1, positiveWhole(maximum, 4))
    local displayed = state.displayed
    local presented = {}

    for _, awardId in ipairs(type(awardIds) == "table" and awardIds or {}) do
        if state.owned[awardId] ~= nil and state.pending[awardId] == true then
            for index = #displayed, 1, -1 do
                if displayed[index] == awardId then
                    table.remove(displayed, index)
                end
            end
            displayed[#displayed + 1] = awardId
            state.pending[awardId] = nil
            state.owned[awardId].presented_at = positiveWhole(presentedAt, os.time())
            presented[#presented + 1] = awardId
        end
    end
    while #displayed > maximum do
        table.remove(displayed, 1)
    end
    return presented
end

function AchievementBannerAwards.reconcileDisplayed(state, catalog, maximum)
    state = AchievementBannerAwards.normalize(state)
    catalog = type(catalog) == "table" and catalog or {}
    maximum = math.max(1, positiveWhole(maximum, 4))

    local prior = state.displayed
    local displayed = {}
    local seen = {}
    for _, awardId in ipairs(prior) do
        if catalog[awardId] ~= nil and not seen[awardId] then
            seen[awardId] = true
            displayed[#displayed + 1] = awardId
        end
    end
    for awardId, record in pairs(state.owned) do
        if
            catalog[awardId] ~= nil
            and type(record) == "table"
            and positiveWhole(record.presented_at) > 0
            and not seen[awardId]
        then
            seen[awardId] = true
            displayed[#displayed + 1] = awardId
        end
    end
    table.sort(displayed, function(a, b)
        local left = state.owned[a] or {}
        local right = state.owned[b] or {}
        local leftPresented = positiveWhole(left.presented_at)
        local rightPresented = positiveWhole(right.presented_at)
        if leftPresented ~= rightPresented then
            return leftPresented < rightPresented
        end
        local leftEarned = positiveWhole(left.earned_at)
        local rightEarned = positiveWhole(right.earned_at)
        if leftEarned ~= rightEarned then
            return leftEarned < rightEarned
        end
        local leftPriority = tonumber(catalog[a] and catalog[a].priority) or 0
        local rightPriority = tonumber(catalog[b] and catalog[b].priority) or 0
        if leftPriority ~= rightPriority then
            return leftPriority < rightPriority
        end
        return a < b
    end)
    while #displayed > maximum do
        table.remove(displayed, 1)
    end

    local changed = #displayed ~= #prior
    if not changed then
        for index, awardId in ipairs(displayed) do
            if prior[index] ~= awardId then
                changed = true
                break
            end
        end
    end
    state.displayed = displayed
    return displayed, changed
end

return AchievementBannerAwards
