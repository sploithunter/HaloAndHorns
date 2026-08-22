--[[
    LeaderboardAwardService — fixed-round placement awards for configured global boards.

    A per-board DataStore record tracks each entrant's best (lowest numeric) public rank
    for the same clock-aligned round shown on the physical board.
    Expired records become an immutable pending award, then queue through the generic
    AwardDeliveryService. If a player is offline, settlement runs when they return; a
    stable award id and an outbox-style pending record make every retry safe.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ChallengeRun = require(ReplicatedStorage.Shared.Game.ChallengeRun)
local InternalAccounts = require(ReplicatedStorage.Shared.Game.InternalAccounts)
local LeaderboardWindowAward = require(ReplicatedStorage.Shared.Game.LeaderboardWindowAward)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)

local LeaderboardAwardService = {}
LeaderboardAwardService.__index = LeaderboardAwardService

function LeaderboardAwardService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._leaderboards = self._modules and self._modules.LeaderboardService
    self._delivery = self._modules and self._modules.AwardDeliveryService
    self._config = self._configLoader:LoadConfig("leaderboards")
    self._challengeConfig = self._configLoader:LoadConfig("challenge_runs")
    self._boards = {}
    self._stores = {}
    self._updating = {}
    self._lastObservation = {}
    self._due = {}
    self._nextDueSweep = 0
    self._excluded = InternalAccounts.userIdSet(self._configLoader:LoadConfig("internal_accounts"))
    for _, userId in ipairs(self._config.excluded_user_ids or {}) do
        self._excluded[tonumber(userId)] = true
    end

    for _, board in ipairs(self._config.boards or {}) do
        if type(board.awards) == "table" and board.awards.enabled == true then
            self._boards[board.id] = board
        end
    end
end

function LeaderboardAwardService:Start()
    self._leaderboards.SnapshotChanged:Connect(function(boardId, snapshot)
        self:_observeSnapshot(boardId, snapshot)
    end)

    local function settleOnReturn(player)
        task.spawn(function()
            if Readiness.awaitAttribute(player, "DataLoaded", true, 20) and player.Parent then
                for _, board in pairs(self._boards) do
                    self:_scheduleAdvance(board, player.UserId, nil, nil)
                end
            end
        end)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        settleOnReturn(player)
    end
    Players.PlayerAdded:Connect(settleOnReturn)

    RunService.Heartbeat:Connect(function()
        local now = os.time()
        if now < self._nextDueSweep then
            return
        end
        self._nextDueSweep = now + 1
        for key, due in pairs(self._due) do
            if now >= due.at then
                self._due[key] = nil
                self:_scheduleAdvance(due.board, due.userId, nil, nil)
            end
        end
    end)

    -- Subscribe before requesting initial snapshots so the first successful global read is observed.
    task.spawn(function()
        for boardId in pairs(self._boards) do
            local snapshot = self._leaderboards:RequestSnapshot(boardId)
            self:_observeSnapshot(boardId, snapshot)
        end
    end)
end

function LeaderboardAwardService:_windowSeconds()
    return ChallengeRun.leaderboardWindow(self._challengeConfig)
end

function LeaderboardAwardService:_roundEnd(startedAt)
    local seconds, _, _, boundary = ChallengeRun.leaderboardWindow(self._challengeConfig)
    return ChallengeRun.fixedWindowEnd(startedAt, seconds, boundary)
end

function LeaderboardAwardService:_eligible(userId)
    local hide = (self._config.publication or {}).hide_internal_accounts == true
    return not (hide and self._excluded[tonumber(userId)] == true)
end

function LeaderboardAwardService:_storeFor(board)
    if self._stores[board.id] ~= nil then
        return self._stores[board.id] or nil
    end
    local awards = board.awards or {}
    if RunService:IsStudio() and awards.studio_enabled ~= true then
        self._stores[board.id] = false
        return nil
    end
    local storeName = awards.state_store
    if type(storeName) ~= "string" or storeName == "" then
        self._stores[board.id] = false
        return nil
    end
    local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, storeName)
    self._stores[board.id] = ok and store or false
    if not ok then
        self._logger:Warn("Leaderboard award state store unavailable", {
            context = "LeaderboardAwardService",
            board = board.id,
            error = tostring(store),
        })
    end
    return ok and store or nil
end

function LeaderboardAwardService:_observeSnapshot(boardId, snapshot)
    local board = self._boards[boardId]
    if not board or type(snapshot) ~= "table" or snapshot.ok ~= true then
        return
    end
    -- Never settle from a server-local fallback after a global read failure.
    if snapshot.source ~= "global" then
        return
    end

    local now = os.time()
    local roundStartedAt = math.floor(tonumber(snapshot.roundStartedAt) or 0)
    local debounce =
        math.max(30, math.floor(tonumber((board.awards or {}).observation_debounce_seconds) or 300))
    for _, entry in ipairs(snapshot.entries or {}) do
        local userId = math.floor(tonumber(entry.userId) or 0)
        local rank = math.floor(tonumber(entry.rank) or 0)
        if userId > 0 and rank > 0 and self:_eligible(userId) then
            local key = board.id .. ":" .. tostring(userId)
            local last = self._lastObservation[key]
            if not last or last.rank ~= rank or now - last.at >= debounce then
                self._lastObservation[key] = { rank = rank, at = now }
                self:_scheduleAdvance(board, userId, rank, roundStartedAt)
            end
        end
    end
end

function LeaderboardAwardService:_scheduleAdvance(board, userId, rank, roundStartedAt)
    local key = board.id .. ":" .. tostring(userId)
    if self._updating[key] then
        return
    end
    self._updating[key] = true
    task.spawn(function()
        local ok, err = pcall(function()
            self:_advanceUser(board, userId, rank, roundStartedAt)
        end)
        self._updating[key] = nil
        if not ok then
            self._logger:Warn("Leaderboard award state update failed", {
                context = "LeaderboardAwardService",
                board = board.id,
                userId = userId,
                error = tostring(err),
            })
        end
    end)
end

function LeaderboardAwardService:_scheduleDue(board, userId, state)
    local active = type(state) == "table" and state.active
    if type(active) ~= "table" then
        return
    end
    local dueAt = self:_roundEnd(math.floor(tonumber(active.started_at) or 0))
    if dueAt <= 0 then
        return
    end
    local key = board.id .. ":" .. tostring(userId)
    local prior = self._due[key]
    if prior and prior.at == dueAt then
        return
    end
    self._due[key] = {
        at = dueAt,
        board = board,
        userId = userId,
    }
end

function LeaderboardAwardService:_advanceUser(board, userId, rank, roundStartedAt)
    local store = self:_storeFor(board)
    if not store then
        return
    end
    local key = tostring(userId)
    if not self:_eligible(userId) then
        pcall(store.RemoveAsync, store, key)
        return
    end

    local now = os.time()
    local awards = board.awards or {}
    local ok, stateOrError = pcall(function()
        return store:UpdateAsync(key, function(current)
            if current == nil and rank == nil then
                return nil
            end
            local observedStart = math.floor(tonumber(roundStartedAt) or 0)
            if observedStart <= 0 then
                observedStart = now
            end
            local active = type(current) == "table" and current.active or nil
            local activeStart = math.floor(tonumber(active and active.started_at) or observedStart)
            return LeaderboardWindowAward.advance(current, rank and {
                rank = rank,
                window_started_at = observedStart,
            } or nil, {
                now = now,
                window_seconds = self:_windowSeconds(),
                window_ends_at = self:_roundEnd(activeStart),
                board_id = board.id,
                board_name = board.display_name or board.id,
                tiers = awards.tiers,
            })
        end)
    end)
    if not ok then
        error(stateOrError)
    end
    local state = stateOrError
    if type(state) ~= "table" then
        return
    end

    self:_scheduleDue(board, userId, state)
    local pending = state.pending
    if type(pending) ~= "table" or type(pending.id) ~= "string" then
        return
    end

    local label = type(pending.reward_label) == "string" and pending.reward_label
        or "your leaderboard prize"
    local queued = self._delivery:QueueForUser(userId, {
        id = pending.id,
        source = "leaderboard:" .. board.id,
        -- Anchor the generic 30-day claim period to when this award round ended. A retry
        -- must never extend an offline player's deadline.
        created_at = pending.window_ended_at,
        bundle = pending.bundle,
        notification = {
            event = "award_delivered",
            title = "Gauntlet Champion Award",
            name = string.format(
                "🏆 %s award — best rank #%d: %s",
                tostring(pending.board_name or board.display_name or board.id),
                math.max(1, math.floor(tonumber(pending.rank) or 1)),
                label
            ),
        },
    })
    if not queued.ok then
        return
    end

    local ackAt = os.time()
    local ackOk, ackError = pcall(function()
        return store:UpdateAsync(key, function(current)
            -- acknowledge also returns a didAck boolean for ordinary callers. An
            -- UpdateAsync transform interprets its second return as the userIds
            -- metadata array, so returning that boolean makes Roblox reject the
            -- write with AttributeFormatError instead of clearing the outbox.
            local acknowledgedState = LeaderboardWindowAward.acknowledge(current, pending.id, ackAt)
            return acknowledgedState
        end)
    end)
    if not ackOk then
        self._logger:Warn("Leaderboard award queued but outbox acknowledgement failed", {
            context = "LeaderboardAwardService",
            board = board.id,
            userId = userId,
            awardId = pending.id,
            error = tostring(ackError),
        })
    end
end

return LeaderboardAwardService
