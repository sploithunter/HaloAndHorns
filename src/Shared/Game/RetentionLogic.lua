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
        exitEarnedLevels = {},
        exitClaimedLevels = {},
        newPlayerExitEarnedLevels = {},
        newPlayerExitClaimedLevels = {},
    }
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
    state.AnalyticsFunnelStep = math.max(0, math.floor(tonumber(state.AnalyticsFunnelStep) or 0))
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

function RetentionLogic.matchingSteps(config, eventName, ctx)
    local out = {}
    for index, step in ipairs(((config or {}).onboarding or {}).steps or {}) do
        if matches(step, eventName, ctx) then
            out[#out + 1] = { index = index, id = step.id, name = step.name }
        end
    end
    return out
end

-- Returns the achieved steps immediately after AnalyticsFunnelStep. The caller submits these
-- in order and advances AnalyticsFunnelStep only after each successful AnalyticsService call.
function RetentionLogic.pendingFunnelSteps(config, state)
    if not (state and state.Eligible) then
        return {}
    end
    local steps = ((config or {}).onboarding or {}).steps or {}
    local out = {}
    local index = math.max(0, math.floor(tonumber(state.AnalyticsFunnelStep) or 0)) + 1
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
    return {
        eligible = state.Eligible == true,
        instrumentedAt = state.InstrumentedAt,
        analyticsFunnelStep = state.AnalyticsFunnelStep or 0,
        funnel = funnel,
        milestones = all,
    }
end

return RetentionLogic
