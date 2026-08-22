--[[
    LeaderboardWindowAward — pure fixed-round placement award state.

    Each player's state is stamped with the public board's authoritative round
    start. During that round we retain the LOWEST NUMERIC rank (their best
    placement). When the round expires, that placement becomes one durable pending
    award. A new round may begin while the old award waits for queue acknowledgement.
]]

local LeaderboardWindowAward = {}

local function copyMap(value)
    local out = {}
    for key, child in pairs(type(value) == "table" and value or {}) do
        if type(child) == "table" then
            out[key] = copyMap(child)
        else
            out[key] = child
        end
    end
    return out
end

local function positiveInteger(value)
    local number = tonumber(value)
    if not number or number <= 0 then
        return nil
    end
    return math.floor(number)
end

function LeaderboardWindowAward.tierForRank(tiers, rank)
    local placement = positiveInteger(rank)
    if not placement then
        return nil
    end
    for _, tier in ipairs(type(tiers) == "table" and tiers or {}) do
        local maxRank = positiveInteger(tier.max_rank)
        if maxRank and placement <= maxRank and type(tier.reward) == "table" then
            return tier
        end
    end
    return nil
end

function LeaderboardWindowAward.awardId(boardId, startedAt)
    return string.format(
        "leaderboard:%s:%d",
        tostring(boardId),
        math.max(0, math.floor(tonumber(startedAt) or 0))
    )
end

function LeaderboardWindowAward.advance(state, observation, options)
    options = options or {}
    local now = math.max(0, math.floor(tonumber(options.now) or 0))
    local windowSeconds = math.max(1, math.floor(tonumber(options.window_seconds) or 1))
    local nextState = copyMap(type(state) == "table" and state or {})
    nextState.version = 1

    local active = type(nextState.active) == "table" and nextState.active or nil
    if active then
        active.started_at = math.max(0, math.floor(tonumber(active.started_at) or now))
        active.best_rank = positiveInteger(active.best_rank)
        if not active.best_rank then
            active = nil
            nextState.active = nil
        end
    end

    local activeExpired = active and now >= active.started_at + windowSeconds
    local blockedByOlderPending = activeExpired and nextState.pending ~= nil
    if activeExpired then
        if nextState.pending == nil then
            local tier = LeaderboardWindowAward.tierForRank(options.tiers, active.best_rank)
            if tier then
                nextState.pending = {
                    id = LeaderboardWindowAward.awardId(options.board_id, active.started_at),
                    board_id = options.board_id,
                    board_name = options.board_name,
                    rank = active.best_rank,
                    window_started_at = active.started_at,
                    window_ended_at = active.started_at + windowSeconds,
                    bundle = copyMap(tier.reward),
                    reward_label = tier.label,
                }
            end
            nextState.active = nil
            active = nil
        end
    end

    local rank = positiveInteger(observation and observation.rank)
    local observedWindowStart = observation
            and math.max(0, math.floor(tonumber(observation.window_started_at) or now))
        or now
    -- One outbox slot is deliberate. If a prior award cannot queue for longer than a full
    -- window, freeze the expired placement rather than letting later ranks leak into it.
    if rank and not blockedByOlderPending then
        if not active then
            active = {
                started_at = observedWindowStart,
                best_rank = rank,
            }
            nextState.active = active
        else
            active.best_rank = math.min(active.best_rank, rank)
        end
    end

    return nextState
end

function LeaderboardWindowAward.acknowledge(state, awardId, queuedAt)
    local nextState = copyMap(type(state) == "table" and state or {})
    if type(nextState.pending) == "table" and nextState.pending.id == awardId then
        nextState.last_queued_id = awardId
        nextState.last_queued_at = math.max(0, math.floor(tonumber(queuedAt) or 0))
        nextState.pending = nil
        return nextState, true
    end
    return nextState, false
end

return LeaderboardWindowAward
