--[[
    RetentionLogic — pure milestone/funnel rules.

    The persisted record is deliberately compact:
      Milestones[id] = { at, session, seconds, category, detail? }
      AnalyticsFunnelStep = highest contiguous step submitted to Roblox Analytics
]]

local RetentionLogic = {}

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
