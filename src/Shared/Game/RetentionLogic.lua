--[[
    RetentionLogic — pure milestone/funnel rules.

    The persisted record is deliberately compact:
      Milestones[id] = { at, session, seconds, category, detail? }
      AnalyticsFunnelStep = highest contiguous step submitted to Roblox Analytics
]]

local RetentionLogic = {}

local function finiteNumber(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end

local function arrayLength(value)
    local count = 0
    local maxIndex = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
            return nil
        end
        count += 1
        maxIndex = math.max(maxIndex, key)
    end
    return count == maxIndex and count or nil
end

local function sanitized(value, limits, depth, seen)
    local valueType = type(value)
    if valueType == "nil" or valueType == "boolean" then
        return value
    elseif valueType == "number" then
        return finiteNumber(value) and value or nil
    elseif valueType == "string" then
        local maxLength = math.max(1, math.floor(tonumber(limits.max_string_length) or 256))
        return #value <= maxLength and value or string.sub(value, 1, maxLength)
    elseif valueType ~= "table" then
        return tostring(value)
    end

    local maxDepth = math.max(1, math.floor(tonumber(limits.max_context_depth) or 4))
    if depth >= maxDepth or seen[value] then
        return nil
    end
    seen[value] = true

    local maxItems = math.max(1, math.floor(tonumber(limits.max_table_items) or 50))
    local out = {}
    local length = arrayLength(value)
    if length then
        for index = 1, math.min(length, maxItems) do
            local clean = sanitized(value[index], limits, depth + 1, seen)
            if clean ~= nil then
                table.insert(out, clean)
            end
        end
    else
        local count = 0
        for key, child in pairs(value) do
            if count >= maxItems then
                break
            end
            local keyType = type(key)
            if keyType == "string" or keyType == "number" then
                local clean = sanitized(child, limits, depth + 1, seen)
                if clean ~= nil then
                    out[tostring(key)] = clean
                    count += 1
                end
            end
        end
    end
    seen[value] = nil
    return out
end

function RetentionLogic.sanitize(value, limits)
    return sanitized(value, type(limits) == "table" and limits or {}, 0, {})
end

function RetentionLogic.eventKeyPrefix(cohortDate, userId, session)
    local date = tostring(cohortDate or ""):gsub("[^%d]", "")
    if #date ~= 8 then
        date = "00000000"
    end
    return string.format(
        "d%s/u%d/s%d",
        date,
        math.max(0, math.floor(tonumber(userId) or 0)),
        math.max(1, math.floor(tonumber(session) or 1))
    )
end

function RetentionLogic.eventChunkKey(prefix, chunk)
    return string.format("%s/c%05d", prefix, math.max(1, math.floor(tonumber(chunk) or 1)))
end

function RetentionLogic.rawEvent(sequence, name, at, seconds, context, limits)
    return {
        sequence = math.max(1, math.floor(tonumber(sequence) or 1)),
        name = tostring(name or "unknown"),
        at = math.floor(tonumber(at) or 0),
        seconds = math.max(0, tonumber(seconds) or 0),
        context = RetentionLogic.sanitize(context, limits),
    }
end

local function increment(map, key, amount)
    key = tostring(key or "unknown")
    map[key] = (tonumber(map[key]) or 0) + (tonumber(amount) or 1)
end

function RetentionLogic.newAggregate()
    return {
        sessionsStarted = 0,
        sessionsEnded = 0,
        totalSessionSeconds = 0,
        newPlayers = 0,
        newPlayerSessionsEnded = 0,
        newPlayerTotalSessionSeconds = 0,
        tutorialCompleted = 0,
        newPlayerTutorialCompleted = 0,
        exitedBeforeEarnedLevel2 = 0,
        exitedBeforeClaimedLevel2 = 0,
        events = {},
        tutorialSteps = {},
        tutorialExitBefore = {},
        questsCompleted = {},
        areasUnlocked = {},
        earnedLevels = {},
        claimedLevels = {},
        promoCodes = {
            attributed = 0,
            redeemed = 0,
            byCode = {},
            byCampaign = {},
            attributedByCampaign = {},
        },
        exitEarnedLevels = {},
        exitClaimedLevels = {},
        newPlayerExitEarnedLevels = {},
        newPlayerExitClaimedLevels = {},
        starterChoice = {
            shown = 0,
            selected = 0,
            totalSecondsToSelect = 0,
            byPet = {},
        },
        -- All-session committed power picks (PowerService:Select → power_selected).
        -- Share = count / total; not first-session-only because picks continue after L2.
        powerPicks = {
            total = 0,
            byPower = {},
            byLevel = {},
        },
        distinctReturners = {
            d1 = 0,
            d2_7 = 0,
            d8_30 = 0,
        },
    }
end

local RETURN_WINDOWS = {
    { id = "d1", firstDay = 1, lastDay = 1 },
    { id = "d2_7", firstDay = 2, lastDay = 7 },
    { id = "d8_30", firstDay = 8, lastDay = 30 },
}

local function utcDay(timestamp)
    return math.floor(math.max(0, tonumber(timestamp) or 0) / 86400)
end

function RetentionLogic.returnWindow(joinedAt, returnedAt)
    local dayOffset = utcDay(returnedAt) - utcDay(joinedAt)
    for _, window in ipairs(RETURN_WINDOWS) do
        if dayOffset >= window.firstDay and dayOffset <= window.lastDay then
            return window.id, dayOffset
        end
    end
    return nil, dayOffset
end

-- Claims one cohort-relative return window on the player profile. The caller projects the claim
-- into the fixed-key dashboard under cohortDate. Persisting the claim keeps later sessions from
-- inflating a distinct-player counter; using UTC calendar days matches Roblox retention semantics.
function RetentionLogic.claimReturnWindow(state, joinedAt, returnedAt, minimumCohortDate)
    if type(state) ~= "table" or state.Eligible ~= true then
        return nil
    end
    joinedAt = tonumber(joinedAt) or 0
    returnedAt = tonumber(returnedAt) or 0
    if joinedAt <= 0 or returnedAt <= 0 then
        return nil
    end
    local cohortDate = os.date("!%Y%m%d", joinedAt)
    local minimum = tostring(minimumCohortDate or ""):gsub("[^%d]", "")
    if #minimum == 8 and cohortDate < minimum then
        return nil
    end

    state.ReturnTracking = type(state.ReturnTracking) == "table" and state.ReturnTracking or {}
    local tracking = state.ReturnTracking
    local storedCohortDate = tostring(tracking.CohortDate or ""):gsub("[^%d]", "")
    tracking.CohortDate = #storedCohortDate == 8 and storedCohortDate or cohortDate
    local storedCohortDay = tonumber(tracking.CohortDay)
    tracking.CohortDay = storedCohortDay and storedCohortDay >= 0 and math.floor(storedCohortDay)
        or utcDay(joinedAt)
    tracking.Counted = type(tracking.Counted) == "table" and tracking.Counted or {}

    -- Once established, the cohort anchor is immutable even if unrelated legacy profile fields
    -- are later repaired.
    cohortDate = tracking.CohortDate
    local dayOffset = utcDay(returnedAt) - tracking.CohortDay
    local windowId
    for _, window in ipairs(RETURN_WINDOWS) do
        if dayOffset >= window.firstDay and dayOffset <= window.lastDay then
            windowId = window.id
            break
        end
    end
    if not windowId or tracking.Counted[windowId] ~= nil then
        return nil, cohortDate, dayOffset
    end
    tracking.Counted[windowId] = math.floor(returnedAt)
    return windowId, cohortDate, dayOffset
end

function RetentionLogic.aggregateDistinctReturner(counters, windowId)
    counters.distinctReturners = type(counters.distinctReturners) == "table"
            and counters.distinctReturners
        or {}
    if windowId ~= "d1" and windowId ~= "d2_7" and windowId ~= "d8_30" then
        return false
    end
    counters.distinctReturners[windowId] = (tonumber(counters.distinctReturners[windowId]) or 0) + 1
    return true
end

function RetentionLogic.aggregateSessionStarted(counters, firstSession)
    counters.sessionsStarted = (tonumber(counters.sessionsStarted) or 0) + 1
    if firstSession then
        counters.newPlayers = (tonumber(counters.newPlayers) or 0) + 1
    end
end

function RetentionLogic.aggregateEvent(counters, seen, name, ctx, seconds, firstSession)
    seen = type(seen) == "table" and seen or {}
    ctx = type(ctx) == "table" and ctx or {}
    increment(counters.events, name)

    if name == "quest_complete" and type(ctx.quest) == "string" then
        increment(counters.questsCompleted, ctx.quest)
    elseif name == "area_unlocked" and type(ctx.areaId) == "string" then
        increment(counters.areasUnlocked, ctx.areaId)
    elseif name == "level_earned" and tonumber(ctx.level) then
        increment(counters.earnedLevels, math.floor(ctx.level))
    elseif name == "level_claimed" and tonumber(ctx.level) then
        increment(counters.claimedLevels, math.floor(ctx.level))
    elseif name == "promo_link_attributed" then
        counters.promoCodes = type(counters.promoCodes) == "table" and counters.promoCodes
            or { attributed = 0, redeemed = 0, byCode = {}, byCampaign = {} }
        counters.promoCodes.attributed = (tonumber(counters.promoCodes.attributed) or 0) + 1
        counters.promoCodes.attributedByCampaign = type(counters.promoCodes.attributedByCampaign)
                    == "table"
                and counters.promoCodes.attributedByCampaign
            or {}
        increment(counters.promoCodes.attributedByCampaign, ctx.campaign)
    elseif name == "promo_code_redeemed" then
        counters.promoCodes = type(counters.promoCodes) == "table" and counters.promoCodes
            or { redeemed = 0, byCode = {}, byCampaign = {} }
        counters.promoCodes.redeemed = (tonumber(counters.promoCodes.redeemed) or 0) + 1
        counters.promoCodes.byCode = type(counters.promoCodes.byCode) == "table"
                and counters.promoCodes.byCode
            or {}
        counters.promoCodes.byCampaign = type(counters.promoCodes.byCampaign) == "table"
                and counters.promoCodes.byCampaign
            or {}
        increment(counters.promoCodes.byCode, ctx.codeId)
        increment(counters.promoCodes.byCampaign, ctx.campaign)
    elseif name == "power_selected" and type(ctx.power) == "string" and ctx.power ~= "" then
        counters.powerPicks = type(counters.powerPicks) == "table" and counters.powerPicks
            or { total = 0, byPower = {}, byLevel = {} }
        counters.powerPicks.total = (tonumber(counters.powerPicks.total) or 0) + 1
        counters.powerPicks.byPower = type(counters.powerPicks.byPower) == "table"
                and counters.powerPicks.byPower
            or {}
        increment(counters.powerPicks.byPower, ctx.power)
        if tonumber(ctx.level) then
            counters.powerPicks.byLevel = type(counters.powerPicks.byLevel) == "table"
                    and counters.powerPicks.byLevel
                or {}
            increment(counters.powerPicks.byLevel, math.floor(ctx.level))
        end
    end

    if name == "tutorial_complete" and not seen.tutorialComplete then
        seen.tutorialComplete = true
        counters.tutorialCompleted = (tonumber(counters.tutorialCompleted) or 0) + 1
        if firstSession then
            counters.newPlayerTutorialCompleted = (
                tonumber(counters.newPlayerTutorialCompleted) or 0
            ) + 1
        end
    end

    if not firstSession then
        return
    end
    if name == "starter_pet_choice_shown" and not seen.starterChoiceShown then
        seen.starterChoiceShown = true
        counters.starterChoice.shown = (tonumber(counters.starterChoice.shown) or 0) + 1
    elseif name == "starter_pet_selected" and not seen.starterPetSelected then
        seen.starterPetSelected = true
        counters.starterChoice.selected = (tonumber(counters.starterChoice.selected) or 0) + 1
        counters.starterChoice.totalSecondsToSelect = (
            tonumber(counters.starterChoice.totalSecondsToSelect) or 0
        ) + math.max(0, tonumber(seconds) or 0)
        increment(counters.starterChoice.byPet, ctx.petType)
    end
    if name == "tutorial_step_completed" and type(ctx.stepId) == "string" then
        local seenKey = "tutorial:" .. ctx.stepId
        if not seen[seenKey] then
            seen[seenKey] = true
            local step = counters.tutorialSteps[ctx.stepId]
            if type(step) ~= "table" then
                step = { reached = 0, totalSecondsToReach = 0 }
                counters.tutorialSteps[ctx.stepId] = step
            end
            step.reached = (tonumber(step.reached) or 0) + 1
            step.totalSecondsToReach = (tonumber(step.totalSecondsToReach) or 0)
                + math.max(0, tonumber(seconds) or 0)
        end
    end
end

function RetentionLogic.aggregateSessionEnded(counters, summary)
    summary = type(summary) == "table" and summary or {}
    local duration = math.max(0, tonumber(summary.durationSeconds) or 0)
    local earnedLevel = math.max(1, math.floor(tonumber(summary.earnedLevel) or 1))
    local claimedLevel = math.max(1, math.floor(tonumber(summary.claimedLevel) or 1))

    counters.sessionsEnded = (tonumber(counters.sessionsEnded) or 0) + 1
    counters.totalSessionSeconds = (tonumber(counters.totalSessionSeconds) or 0) + duration
    increment(counters.exitEarnedLevels, earnedLevel)
    increment(counters.exitClaimedLevels, claimedLevel)

    if not summary.firstSession then
        return
    end
    counters.newPlayerSessionsEnded = (tonumber(counters.newPlayerSessionsEnded) or 0) + 1
    counters.newPlayerTotalSessionSeconds = (tonumber(counters.newPlayerTotalSessionSeconds) or 0)
        + duration
    increment(counters.newPlayerExitEarnedLevels, earnedLevel)
    increment(counters.newPlayerExitClaimedLevels, claimedLevel)
    if earnedLevel < 2 then
        counters.exitedBeforeEarnedLevel2 = (tonumber(counters.exitedBeforeEarnedLevel2) or 0) + 1
    end
    if claimedLevel < 2 then
        counters.exitedBeforeClaimedLevel2 = (tonumber(counters.exitedBeforeClaimedLevel2) or 0) + 1
    end
    if summary.tutorialDone ~= true then
        increment(counters.tutorialExitBefore, summary.currentTutorialStep or "unknown")
    end
end

function RetentionLogic.aggregateKey(cohortDate, jobId)
    local date = tostring(cohortDate or ""):gsub("[^%d]", "")
    if #date ~= 8 then
        date = "00000000"
    end
    local shard = tostring(jobId or ""):gsub("[^%w]", "")
    if shard == "" then
        shard = "unknown"
    end
    shard = string.sub(shard, 1, 32)
    return string.format("a%s/j%s", date, shard)
end

local function normalizedDate(value)
    local date = tostring(value or ""):gsub("[^%d]", "")
    if #date ~= 8 then
        return "00000000"
    end
    return date
end

function RetentionLogic.isExcludedPlayerName(playerName, prefixes)
    local name = string.lower(tostring(playerName or ""))
    for _, prefix in ipairs(type(prefixes) == "table" and prefixes or {}) do
        local normalized = string.lower(tostring(prefix or ""))
        if normalized ~= "" and string.sub(name, 1, #normalized) == normalized then
            return true
        end
    end
    return false
end

function RetentionLogic.isExcludedUserId(userId, userIds)
    local id = tonumber(userId)
    if not id then
        return false
    end
    for _, configured in ipairs(type(userIds) == "table" and userIds or {}) do
        if tonumber(configured) == id then
            return true
        end
    end
    return false
end

function RetentionLogic.isInternalPlayer(userId, playerName, userIds, prefixes)
    return RetentionLogic.isExcludedUserId(userId, userIds)
        or RetentionLogic.isExcludedPlayerName(playerName, prefixes)
end

function RetentionLogic.dashboardBucketIndex(jobId, bucketCount)
    bucketCount = math.max(1, math.floor(tonumber(bucketCount) or 1))
    local hash = 0
    local value = tostring(jobId or "")
    for index = 1, #value do
        hash = (hash * 31 + string.byte(value, index)) % 2147483647
    end
    return hash % bucketCount
end

function RetentionLogic.dashboardBucketKey(dateUtc, bucketIndex)
    return string.format(
        "d%s/b%02d",
        normalizedDate(dateUtc),
        math.max(0, math.floor(tonumber(bucketIndex) or 0))
    )
end

function RetentionLogic.dashboardContributionId(jobId)
    local id = tostring(jobId or ""):gsub("[^%w]", "")
    if id == "" then
        id = "unknown"
    end
    return string.sub(id, 1, 32)
end

function RetentionLogic.dashboardBuildKey(server)
    server = type(server) == "table" and server or {}
    local placeVersion = math.floor(tonumber(server.placeVersion) or 0)
    if placeVersion > 0 then
        return "place:" .. tostring(placeVersion)
    end
    local commit = tostring(server.buildCommit or ""):gsub("[^%w]", "")
    if commit ~= "" then
        return "commit:" .. string.sub(commit, 1, 40)
    end
    return "unknown"
end

function RetentionLogic.mergeNumeric(target, source)
    target = type(target) == "table" and target or {}
    for key, value in pairs(type(source) == "table" and source or {}) do
        if type(value) == "number" then
            target[key] = (tonumber(target[key]) or 0) + value
        elseif type(value) == "table" then
            target[key] = RetentionLogic.mergeNumeric(target[key], value)
        end
    end
    return target
end

function RetentionLogic.replaceDashboardContribution(current, contribution)
    contribution = type(contribution) == "table" and contribution or {}
    local payload = type(current) == "table" and current or {}
    local contributions = type(payload.contributions) == "table" and payload.contributions or {}
    local contributionId = RetentionLogic.dashboardContributionId(contribution.jobId)
    contributions[contributionId] = {
        updatedAt = math.max(0, math.floor(tonumber(contribution.updatedAt) or 0)),
        server = contribution.server,
        counters = type(contribution.counters) == "table" and contribution.counters or {},
    }

    local counters = {}
    local updatedAt = 0
    for _, serverContribution in pairs(contributions) do
        RetentionLogic.mergeNumeric(counters, serverContribution.counters)
        updatedAt = math.max(updatedAt, tonumber(serverContribution.updatedAt) or 0)
    end

    return {
        kind = "dashboard",
        schemaVersion = math.max(1, math.floor(tonumber(contribution.schemaVersion) or 1)),
        dateUtc = normalizedDate(contribution.dateUtc),
        bucket = math.max(0, math.floor(tonumber(contribution.bucket) or 0)),
        bucketCount = math.max(1, math.floor(tonumber(contribution.bucketCount) or 1)),
        updatedAt = updatedAt,
        definitions = contribution.definitions,
        exclusions = contribution.exclusions,
        contributions = contributions,
        counters = counters,
    }
end

local function ratio(numerator, denominator)
    denominator = tonumber(denominator) or 0
    if denominator <= 0 then
        return nil
    end
    return (tonumber(numerator) or 0) / denominator
end

function RetentionLogic.dashboardSummary(counters)
    counters = type(counters) == "table" and counters or {}
    local ended = tonumber(counters.sessionsEnded) or 0
    local newPlayers = tonumber(counters.newPlayers) or 0
    local newEnded = tonumber(counters.newPlayerSessionsEnded) or 0
    local starterChoice = type(counters.starterChoice) == "table" and counters.starterChoice or {}
    local choices = tonumber(starterChoice.selected) or 0
    local powerPicks = type(counters.powerPicks) == "table" and counters.powerPicks or {}
    local promoCodes = type(counters.promoCodes) == "table" and counters.promoCodes or {}
    local returners = type(counters.distinctReturners) == "table" and counters.distinctReturners
        or {}
    return {
        sessionsStarted = tonumber(counters.sessionsStarted) or 0,
        sessionsEnded = ended,
        averageCompletedSessionSeconds = ratio(counters.totalSessionSeconds, ended),
        newPlayers = newPlayers,
        newPlayerSessionsEnded = newEnded,
        averageCompletedNewPlayerSessionSeconds = ratio(
            counters.newPlayerTotalSessionSeconds,
            newEnded
        ),
        tutorialCompleted = tonumber(counters.tutorialCompleted) or 0,
        newPlayerTutorialCompleted = tonumber(counters.newPlayerTutorialCompleted) or 0,
        newPlayerTutorialCompletionRate = ratio(counters.newPlayerTutorialCompleted, newPlayers),
        exitedBeforeEarnedLevel2 = tonumber(counters.exitedBeforeEarnedLevel2) or 0,
        exitedBeforeEarnedLevel2Rate = ratio(counters.exitedBeforeEarnedLevel2, newEnded),
        exitedBeforeClaimedLevel2 = tonumber(counters.exitedBeforeClaimedLevel2) or 0,
        exitedBeforeClaimedLevel2Rate = ratio(counters.exitedBeforeClaimedLevel2, newEnded),
        starterChoiceShown = tonumber(starterChoice.shown) or 0,
        starterChoiceSelected = choices,
        starterChoiceConversionRate = ratio(choices, starterChoice.shown),
        averageStarterChoiceSeconds = ratio(starterChoice.totalSecondsToSelect, choices),
        powerPickTotal = tonumber(powerPicks.total) or 0,
        promoCodeAttributed = tonumber(promoCodes.attributed) or 0,
        promoCodesRedeemed = tonumber(promoCodes.redeemed) or 0,
        distinctD1Returners = tonumber(returners.d1) or 0,
        distinctD1RetentionRate = ratio(returners.d1, newPlayers),
        distinctD2To7Returners = tonumber(returners.d2_7) or 0,
        distinctD2To7RetentionRate = ratio(returners.d2_7, newPlayers),
        distinctD8To30Returners = tonumber(returners.d8_30) or 0,
        distinctD8To30RetentionRate = ratio(returners.d8_30, newPlayers),
    }
end

function RetentionLogic.powerPickShares(counters)
    local picks = type(counters) == "table" and counters.powerPicks or nil
    picks = type(picks) == "table" and picks or {}
    local byPower = type(picks.byPower) == "table" and picks.byPower or {}
    local total = tonumber(picks.total)
    if not total or total <= 0 then
        total = 0
        for _, count in pairs(byPower) do
            total += tonumber(count) or 0
        end
    end
    local rows = {}
    for power, count in pairs(byPower) do
        count = tonumber(count) or 0
        table.insert(rows, {
            power = tostring(power),
            count = count,
            share = ratio(count, total),
        })
    end
    table.sort(rows, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.power < b.power
    end)
    return {
        total = total,
        rows = rows,
    }
end

local function matches(step, eventName, ctx)
    if type(step) ~= "table" or step.event ~= eventName then
        return false
    end
    for key, expected in pairs(step.match or {}) do
        if type(ctx) ~= "table" or ctx[key] ~= expected then
            return false
        end
    end
    return true
end

function RetentionLogic.ensure(state, eligible, now)
    state = type(state) == "table" and state or {}
    state.Version = tonumber(state.Version) or 1
    if state.EligibilityDecided ~= true then
        state.Eligible = eligible == true
        state.EligibilityDecided = true
    else
        state.Eligible = state.Eligible == true
    end
    local instrumentedAt = tonumber(state.InstrumentedAt) or 0
    state.InstrumentedAt = instrumentedAt > 0 and instrumentedAt or now
    state.Milestones = type(state.Milestones) == "table" and state.Milestones or {}
    state.ReturnTracking = type(state.ReturnTracking) == "table" and state.ReturnTracking or {}
    state.AnalyticsFunnelStep = math.max(0, math.floor(tonumber(state.AnalyticsFunnelStep) or 0))
    state.ActivationFunnelStep = math.max(0, math.floor(tonumber(state.ActivationFunnelStep) or 0))
    state.CombatFunnelStep = math.max(0, math.floor(tonumber(state.CombatFunnelStep) or 0))
    return state
end

function RetentionLogic.record(state, id, category, meta)
    if type(state) ~= "table" or type(id) ~= "string" or id == "" then
        return false
    end
    state.Milestones = type(state.Milestones) == "table" and state.Milestones or {}
    if state.Milestones[id] ~= nil then
        return false
    end
    meta = type(meta) == "table" and meta or {}
    state.Milestones[id] = {
        at = math.floor(tonumber(meta.at) or 0),
        session = math.max(1, math.floor(tonumber(meta.session) or 1)),
        seconds = math.max(0, math.floor(tonumber(meta.seconds) or 0)),
        category = category or "progression",
        detail = meta.detail,
    }
    return true
end

function RetentionLogic.funnelLists(config)
    return {
        { key = "onboarding", steps = ((config or {}).onboarding or {}).steps },
        { key = "combat_training", steps = ((config or {}).combat_training or {}).steps },
        { key = "activation", steps = ((config or {}).activation or {}).steps },
    }
end

function RetentionLogic.matchingSteps(config, eventName, ctx)
    local seen = {}
    local out = {}
    for _, funnel in ipairs(RetentionLogic.funnelLists(config)) do
        for index, step in ipairs(funnel.steps or {}) do
            if not seen[step.id] and matches(step, eventName, ctx) then
                seen[step.id] = true
                out[#out + 1] = {
                    index = index,
                    id = step.id,
                    name = step.name,
                    funnel = funnel.key,
                }
            end
        end
    end
    return out
end

-- Returns the achieved steps immediately after AnalyticsFunnelStep. The caller submits these
-- in order and advances AnalyticsFunnelStep only after each successful AnalyticsService call.
local function pendingSteps(steps, state, cursor)
    local out = {}
    local index = math.max(0, math.floor(tonumber(cursor) or 0)) + 1
    while steps[index] and state.Milestones and state.Milestones[steps[index].id] do
        out[#out + 1] = {
            index = index,
            id = steps[index].id,
            name = steps[index].name,
        }
        index += 1
    end
    return out
end

-- Returns the achieved steps immediately after AnalyticsFunnelStep. The caller submits these
-- in order and advances AnalyticsFunnelStep only after each successful AnalyticsService call.
function RetentionLogic.pendingFunnelSteps(config, state)
    if not (state and state.Eligible) then
        return {}
    end
    return pendingSteps(
        ((config or {}).onboarding or {}).steps or {},
        state,
        state.AnalyticsFunnelStep
    )
end

-- Lifetime activation funnel. Not first-session-only: first quest is optional and
-- often happens after session 1. Still submits only the contiguous prefix.
function RetentionLogic.pendingActivationSteps(config, state)
    if not state then
        return {}
    end
    return pendingSteps(
        ((config or {}).activation or {}).steps or {},
        state,
        state.ActivationFunnelStep
    )
end

-- Cave room-by-room funnel. Lifetime, not first-session-only — same
-- contiguous-prefix rule as Activation.
function RetentionLogic.pendingCombatTrainingSteps(config, state)
    if not state then
        return {}
    end
    return pendingSteps(
        ((config or {}).combat_training or {}).steps or {},
        state,
        state.CombatFunnelStep
    )
end

function RetentionLogic.snapshot(config, state)
    state = type(state) == "table" and state or {}
    local milestones = type(state.Milestones) == "table" and state.Milestones or {}
    local funnel = {}
    for index, step in ipairs(((config or {}).onboarding or {}).steps or {}) do
        local record = milestones[step.id]
        funnel[#funnel + 1] = {
            step = index,
            id = step.id,
            name = step.name,
            reached = record ~= nil,
            at = record and record.at or nil,
            session = record and record.session or nil,
            seconds = record and record.seconds or nil,
        }
    end
    local all = {}
    for id, record in pairs(milestones) do
        all[#all + 1] = {
            id = id,
            category = record.category,
            detail = record.detail,
            at = record.at,
            session = record.session,
            seconds = record.seconds,
        }
    end
    table.sort(all, function(a, b)
        if (a.at or 0) ~= (b.at or 0) then
            return (a.at or 0) < (b.at or 0)
        end
        return a.id < b.id
    end)
    local activation = {}
    for index, step in ipairs(((config or {}).activation or {}).steps or {}) do
        local record = milestones[step.id]
        activation[#activation + 1] = {
            step = index,
            id = step.id,
            name = step.name,
            reached = record ~= nil,
            at = record and record.at or nil,
            session = record and record.session or nil,
            seconds = record and record.seconds or nil,
        }
    end
    local combatTraining = {}
    for index, step in ipairs(((config or {}).combat_training or {}).steps or {}) do
        local record = milestones[step.id]
        combatTraining[#combatTraining + 1] = {
            step = index,
            id = step.id,
            name = step.name,
            reached = record ~= nil,
            at = record and record.at or nil,
            session = record and record.session or nil,
            seconds = record and record.seconds or nil,
        }
    end
    return {
        eligible = state.Eligible == true,
        instrumentedAt = state.InstrumentedAt,
        analyticsFunnelStep = state.AnalyticsFunnelStep or 0,
        activationFunnelStep = state.ActivationFunnelStep or 0,
        combatFunnelStep = state.CombatFunnelStep or 0,
        funnel = funnel,
        activation = activation,
        combatTraining = combatTraining,
        milestones = all,
    }
end

return RetentionLogic
