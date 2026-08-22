local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ChallengeRun = require(ReplicatedStorage.Shared.Game.ChallengeRun)
local InternalAccounts = require(ReplicatedStorage.Shared.Game.InternalAccounts)
local LeaderboardScoring = require(ReplicatedStorage.Shared.Game.LeaderboardScoring)
local LeaderboardStatus = require(ReplicatedStorage.Shared.Game.LeaderboardStatus)
local PetPower = require(ReplicatedStorage.Shared.Game.PetPower)
local Signal = require(ReplicatedStorage.Shared.Libraries.Signal)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)

local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

local function positiveInteger(value, fallback)
    local number = tonumber(value)
    if not number or number <= 0 then
        return fallback
    end
    return math.floor(number)
end

local function isChallengeScore(score)
    return type(score) == "table" and score.kind == "challenge_window"
end

function LeaderboardService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._statsService = self._modules.StatsService
    self._inventoryService = self._modules.InventoryService

    self._config = self._configLoader:LoadConfig("leaderboards")
    self._petsConfig = self._configLoader:LoadConfig("pets")
    self._petProgressionConfig = self._configLoader:LoadConfig("pet_progression")
    self._petPowerConfig = self._configLoader:LoadConfig("pet_power")
    self._boardsById = {}
    self._counterBoards = {}
    self._derivedBoards = {}
    self._challengeBoards = {}
    self._challengeConfig = nil
    pcall(function()
        self._challengeConfig = self._configLoader:LoadConfig("challenge_runs")
    end)
    self._excluded = {}
    self._liveValues = {}
    self._cachedGlobal = {}
    self._cachedGlobalTop100 = {}
    self._globalStores = {}
    self._nameCache = {}
    self._publishGeneration = {}
    self._pendingPublish = {}
    self._pendingRefresh = {}
    self._lastPublished = {}
    self._pendingWrites = 0
    self._challengeRoundStarts = {}
    self.SnapshotChanged = Signal.new()

    self._internalAccounts = self._configLoader:LoadConfig("internal_accounts")
    for userId in pairs(InternalAccounts.userIdSet(self._internalAccounts)) do
        self._excluded[userId] = true
    end
    for _, userId in ipairs(self._config.excluded_user_ids or {}) do
        self._excluded[tonumber(userId)] = true
    end
    -- Hidden from the public page only. Every account still publishes.

    for _, board in ipairs(self._config.boards or {}) do
        self._boardsById[board.id] = board
        self._liveValues[board.id] = {}
        local score = self:_scoreDefinition(board)
        if score.kind == "counter" then
            self._counterBoards[score.counter] = self._counterBoards[score.counter] or {}
            table.insert(self._counterBoards[score.counter], board)
        elseif isChallengeScore(score) then
            table.insert(self._challengeBoards, board)
        else
            table.insert(self._derivedBoards, board)
        end
    end

    if self._statsService and self._statsService.CounterChanged then
        self._statsService.CounterChanged:Connect(function(player, counterId)
            for _, board in ipairs(self._counterBoards[counterId] or {}) do
                self:_refreshBoardForPlayer(board, player, false)
            end
        end)
    end
    if self._inventoryService and self._inventoryService.PetsChanged then
        self._inventoryService.PetsChanged:Connect(function(player)
            for _, board in ipairs(self._derivedBoards) do
                self:_scheduleBoardRefresh(board, player)
            end
        end)
    end

    self._logger:Info("LeaderboardService initialized", {
        context = "LeaderboardService",
        boardCount = #(self._config.boards or {}),
        publication = "event_driven_top_100",
    })
end

function LeaderboardService:Start()
    self:_rotateChallengeRounds(os.time(), false)

    Players.PlayerAdded:Connect(function(player)
        task.spawn(function()
            self:_waitForDataAndRefresh(player)
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        -- Origin boards still replace their ordered key on leave. Challenge
        -- scores remain for the full award round, even while the entrant is
        -- offline, and disappear only when the next fixed round begins.
        self:RefreshPlayer(player, true, true)
        for boardId in pairs(self._liveValues) do
            self._liveValues[boardId][player.UserId] = nil
            self._pendingRefresh[boardId .. ":" .. tostring(player.UserId)] = nil
        end
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            self:_waitForDataAndRefresh(player)
        end)
    end

    self:_startGlobalReadLoop()
    self:_startChallengeWindowSweep()
    RunService.Heartbeat:Connect(function(deltaTime)
        self:_heartbeat(deltaTime)
    end)

    game:BindToClose(function()
        -- Window expiry first (may drop a published room), then the other
        -- boards replace their keys. Challenge scores are not rewritten just
        -- because the server is closing unless the sweep changed them.
        self:_sweepChallengeWindows(true)
        for _, player in ipairs(Players:GetPlayers()) do
            self:RefreshPlayer(player, true, true)
        end
    end)
end

function LeaderboardService:_fixedChallengeRounds()
    local leaderboard = self._challengeConfig and self._challengeConfig.leaderboard
    return type(leaderboard) == "table" and leaderboard.fixed_rounds == true
end

function LeaderboardService:_challengeRoundStart(board, now)
    if not isChallengeScore(self:_scoreDefinition(board)) or not self:_fixedChallengeRounds() then
        return nil
    end
    local window = ChallengeRun.leaderboardWindow(self._challengeConfig)
    return ChallengeRun.fixedWindowStart(now or os.time(), window)
end

function LeaderboardService:_publicationKey(board, userId)
    local roundStart = self:_challengeRoundStart(board, os.time())
    if roundStart then
        return string.format("%s:%d:%d", board.id, roundStart, userId)
    end
    return board.id .. ":" .. tostring(userId)
end

function LeaderboardService:_scoreDefinition(board)
    if board.score then
        return board.score
    end
    return { kind = "counter", counter = board.stat }
end

function LeaderboardService:_waitForDataAndRefresh(player)
    if Readiness.awaitAttribute(player, "DataLoaded", true, 15) and player.Parent then
        self:RefreshPlayer(player, true)
    end
end

function LeaderboardService:_petPower(record)
    if record.creator == true then
        return tonumber(self._petPowerConfig.max_pet_power) or 0
    end
    local petData = self._petsConfig.getPet(record.id, record.variant or "basic")
    return PetPower.basePowerForLevel(
        petData,
        record.huge == true,
        record.level or 1,
        self._petProgressionConfig
    )
end

function LeaderboardService:_calculate(board, player)
    local data = self._dataService:GetData(player)
    if not data then
        return nil
    end

    local score = self:_scoreDefinition(board)
    if score.kind == "counter" then
        return LeaderboardScoring.counter(data, score.counter)
    elseif score.kind == "inventory_taxonomy" then
        return LeaderboardScoring.countTaxonomy(
            data,
            LeaderboardScoring.taxonomyIds(score, self._petsConfig.pets)
        )
    elseif score.kind == "strongest_squad" then
        local slots = self._inventoryService:RefreshEquipCapacity(player)
        return LeaderboardScoring.strongestLegalSquad(data, slots, function(record)
            return self:_petPower(record)
        end)
    elseif isChallengeScore(score) then
        local window = ChallengeRun.leaderboardWindow(self._challengeConfig)
        if tonumber(score.window_seconds) then
            window = math.max(1, math.floor(score.window_seconds))
        end
        local runs = data.GameData and data.GameData.ChallengeRuns
        local rec = type(runs) == "table" and runs[score.mode]
        if self:_fixedChallengeRounds() then
            return ChallengeRun.fixedWindowBest(rec and rec.recent, os.time(), window)
        end
        return ChallengeRun.windowBest(rec and rec.recent, os.time(), window)
    end
    return 0
end

function LeaderboardService:_hideInternalAccounts()
    return (self._config.publication or {}).hide_internal_accounts == true
end

function LeaderboardService:_visibleEntries(entries)
    return LeaderboardScoring.visibleEntries(entries, self._excluded, self:_hideInternalAccounts())
end

function LeaderboardService:_publicTop(entries, limit)
    return LeaderboardScoring.publicTop(
        entries,
        self._excluded,
        self:_hideInternalAccounts(),
        limit
    )
end

function LeaderboardService:_setLiveValue(board, player, value)
    self._liveValues[board.id][player.UserId] = {
        userId = player.UserId,
        name = player.Name,
        displayName = player.DisplayName,
        value = math.max(0, tonumber(value) or 0),
    }
end

function LeaderboardService:_refreshBoardForPlayer(board, player, force)
    if not player then
        return
    end
    local value = self:_calculate(board, player)
    if value == nil then
        local cached = self._liveValues[board.id] and self._liveValues[board.id][player.UserId]
        value = cached and cached.value
    end
    if value == nil then
        return
    end
    self:_setLiveValue(board, player, value)
    self:_scheduleGlobalValue(board, player.UserId, value, force)
end

function LeaderboardService:RefreshPlayer(player, force, skipChallenge)
    for _, board in ipairs(self._config.boards or {}) do
        if skipChallenge and isChallengeScore(self:_scoreDefinition(board)) then
            -- run persist already published this score
        else
            self:_refreshBoardForPlayer(board, player, force == true)
        end
    end
end

function LeaderboardService:RefreshChallengeBoards(player, force)
    for _, board in ipairs(self._challengeBoards) do
        self:_refreshBoardForPlayer(board, player, force == true)
    end
end

function LeaderboardService:_startChallengeWindowSweep()
    if #self._challengeBoards == 0 then
        return
    end
    self._challengeSweepElapsed = 0
    task.spawn(function()
        self:_sweepChallengeWindows(true)
    end)
end

function LeaderboardService:_rotateChallengeRounds(now, requestReads)
    if not self:_fixedChallengeRounds() then
        return
    end
    for _, board in ipairs(self._challengeBoards) do
        local roundStart = self:_challengeRoundStart(board, now)
        if roundStart and self._challengeRoundStarts[board.id] ~= roundStart then
            self._challengeRoundStarts[board.id] = roundStart
            self._liveValues[board.id] = {}
            self._cachedGlobal[board.id] = nil
            self._cachedGlobalTop100[board.id] = nil
            for key, pending in pairs(self._pendingPublish) do
                if pending.board == board then
                    self._pendingPublish[key] = nil
                end
            end
            self:_broadcast(board.id)
            if requestReads then
                task.spawn(function()
                    self:_readGlobalBoard(board)
                end)
            end
        end
    end
end

function LeaderboardService:_sweepChallengeWindows(force)
    if #self._challengeBoards == 0 then
        return
    end
    local window, cap = ChallengeRun.leaderboardWindow(self._challengeConfig)
    local now = os.time()
    for _, player in ipairs(Players:GetPlayers()) do
        local data = self._dataService and self._dataService:GetData(player)
        local runs = data and data.GameData and data.GameData.ChallengeRuns
        local changed = false
        if type(runs) == "table" then
            for _, rec in pairs(runs) do
                if type(rec) == "table" then
                    local pruned = ChallengeRun.pruneWindow(rec.recent, now, window, cap)
                    if ChallengeRun.recentChanged(rec.recent, pruned) then
                        rec.recent = pruned
                        changed = true
                    end
                end
            end
        end
        if changed and self._dataService and self._dataService.RequestSave then
            self._dataService:RequestSave(player, "challenge_window_sweep")
        end
        self:RefreshChallengeBoards(player, force == true)
    end
end

function LeaderboardService:_scheduleBoardRefresh(board, player)
    if not player then
        return
    end
    local delaySeconds = tonumber((self._config.publication or {}).derive_debounce_seconds) or 1
    local key = board.id .. ":" .. tostring(player.UserId)
    self._pendingRefresh[key] = {
        dueAt = os.clock() + math.max(0, delaySeconds),
        board = board,
        player = player,
    }
end

function LeaderboardService:GetLiveLeaderboard(boardId, limit)
    local board = self._boardsById[boardId]
    if not board then
        return nil, "Unknown leaderboard: " .. tostring(boardId)
    end

    local entries = {}
    for _, entry in pairs(self._liveValues[boardId] or {}) do
        table.insert(entries, table.clone(entry))
    end
    self:_sortEntries(board, entries)
    return self:_publicTop(entries, limit or board.max_entries or 10)
end

function LeaderboardService:_sortEntries(board, entries)
    local descending = board.sort ~= "asc"
    table.sort(entries, function(a, b)
        if a.value == b.value then
            return a.userId < b.userId
        end
        if descending then
            return a.value > b.value
        end
        return a.value < b.value
    end)
end

function LeaderboardService:_trimEntries(entries, limit)
    local trimmed = {}
    for index = 1, math.min(limit, #entries) do
        trimmed[index] = table.clone(entries[index])
        trimmed[index].rank = index
    end
    return trimmed
end

function LeaderboardService:RequestSnapshot(boardId)
    local board = self._boardsById[boardId]
    if not board then
        return { ok = false, reason = "unknown_board" }
    end
    if not self._cachedGlobal[boardId] then
        self:_readGlobalBoard(board)
    end
    return self:GetSnapshot(boardId)
end

function LeaderboardService:GetSnapshot(boardId)
    local board = self._boardsById[boardId]
    if not board then
        return { ok = false, error = "Unknown leaderboard: " .. tostring(boardId) }
    end
    local entries = self._cachedGlobal[boardId]
    local source = "global"
    if not entries then
        entries = self:GetLiveLeaderboard(boardId, board.max_entries)
        source = "server"
    end
    return {
        ok = true,
        boardId = boardId,
        source = source,
        entries = entries,
        updatedAt = os.time(),
        roundStartedAt = self:_challengeRoundStart(board, os.time()),
    }
end

function LeaderboardService:_broadcast(boardId)
    local snapshot = self:GetSnapshot(boardId)
    self:_refreshPlayerStatusTitles()
    Signals.LeaderboardUpdated:FireAllClients(snapshot)
    self.SnapshotChanged:Fire(boardId, snapshot)
end

function LeaderboardService:_statusEntries(board)
    local global = board.global or {}
    local usesGlobal = global.enabled == true
        and (
            not RunService:IsStudio()
            or global.studio_enabled == true
            or self:_studioMayReadGlobal()
        )
    if usesGlobal then
        return self._cachedGlobalTop100[board.id]
    end
    return self:GetLiveLeaderboard(
        board.id,
        positiveInteger((self._config.publication or {}).cache_entries, 100)
    )
end

function LeaderboardService:_refreshPlayerStatusTitles()
    local entriesByBoard = {}
    for _, board in ipairs(self._config.boards or {}) do
        local entries = self:_statusEntries(board)
        if entries then
            entriesByBoard[board.id] = entries
        end
    end

    local rankLimit = positiveInteger((self._config.publication or {}).status_rank_limit, 10)
    for _, player in ipairs(Players:GetPlayers()) do
        local best = nil
        if not (self:_hideInternalAccounts() and self._excluded[player.UserId]) then
            best = LeaderboardStatus.bestForUser(
                player.UserId,
                self._config.boards,
                entriesByBoard,
                rankLimit
            )
        end
        local title = best and best.title or nil
        if player:GetAttribute("LeaderboardStatusTitle") ~= title then
            player:SetAttribute("LeaderboardStatusTitle", title)
        end
    end
end

function LeaderboardService:_studioMayReadGlobal()
    return (self._config.publication or {}).studio_read_global == true
end

function LeaderboardService:_openGlobalStore(board)
    local global = board.global or {}
    local storeName = global.ordered_store
    local roundStart = self:_challengeRoundStart(board, os.time())
    if roundStart then
        -- A new logical OrderedDataStore each round makes the reset atomic and
        -- bounded. Old stores may age out naturally; they are never read again.
        storeName = string.format("%s_r%d", tostring(storeName), roundStart)
    end
    if self._globalStores[storeName] ~= nil then
        return self._globalStores[storeName] or nil
    end
    local ok, result = pcall(function()
        return DataStoreService:GetOrderedDataStore(storeName)
    end)
    self._globalStores[storeName] = ok and result or false
    if not ok then
        self._logger:Warn("Failed to open ordered leaderboard store", {
            context = "LeaderboardService",
            board = board.id,
            store = storeName,
            error = tostring(result),
        })
    end
    return self._globalStores[storeName] or nil
end

function LeaderboardService:_getGlobalReadStore(board)
    local global = board.global or {}
    if global.enabled ~= true then
        return nil
    end
    if
        RunService:IsStudio()
        and global.studio_enabled ~= true
        and not self:_studioMayReadGlobal()
    then
        return nil
    end
    return self:_openGlobalStore(board)
end

function LeaderboardService:_getGlobalStore(board)
    local global = board.global or {}
    if global.enabled ~= true then
        return nil
    end
    if
        RunService:IsStudio()
        and global.studio_enabled ~= true
        and (self._config.publication or {}).studio_write_global ~= true
    then
        return nil
    end
    return self:_openGlobalStore(board)
end

function LeaderboardService:_scheduleGlobalValue(board, userId, value, force)
    local store = self:_getGlobalStore(board)
    if not store then
        self:_broadcast(board.id)
        return
    end

    local key = self:_publicationKey(board, userId)
    local numericValue = math.max(0, math.floor((tonumber(value) or 0) + 0.5))
    self._publishGeneration[key] = (self._publishGeneration[key] or 0) + 1
    local generation = self._publishGeneration[key]

    if force then
        -- A forced join/leave/shutdown snapshot supersedes any older debounced value, even when
        -- the authoritative score has fallen back to the last value we already published.
        self._pendingPublish[key] = nil
        if self._lastPublished[key] == numericValue then
            return
        end
        self:_publishNow(board, store, userId, numericValue, key, generation)
    else
        if self._lastPublished[key] == numericValue and self._pendingPublish[key] == nil then
            return
        end
        local debounce = tonumber((self._config.publication or {}).debounce_seconds) or 20
        self._pendingPublish[key] = {
            dueAt = os.clock() + debounce,
            board = board,
            store = store,
            userId = userId,
            value = numericValue,
            generation = generation,
        }
    end
end

function LeaderboardService:_publishNow(board, store, userId, value, key, generation)
    if self._publishGeneration[key] ~= generation then
        return
    end
    self._pendingWrites += 1
    local score = self:_scoreDefinition(board)
    local ok, errorMessage = pcall(function()
        if value <= 0 and isChallengeScore(score) then
            store:RemoveAsync(tostring(userId))
        else
            store:SetAsync(tostring(userId), value)
        end
    end)
    self._pendingWrites -= 1
    if ok then
        self._lastPublished[key] = value
        if value <= 0 and isChallengeScore(score) then
            self._cachedGlobal[board.id] = nil
            self._cachedGlobalTop100[board.id] = nil
            self:_broadcast(board.id)
            task.spawn(function()
                self:_readGlobalBoard(board)
            end)
        end
    else
        self._logger:Warn("Failed to publish leaderboard value", {
            context = "LeaderboardService",
            board = board.id,
            userId = userId,
            error = tostring(errorMessage),
        })
    end
end

function LeaderboardService:_nameForUserId(userId)
    if self._nameCache[userId] then
        return self._nameCache[userId]
    end
    local online = Players:GetPlayerByUserId(userId)
    if online then
        self._nameCache[userId] = online.DisplayName
        return online.DisplayName
    end
    local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
    name = ok and name or ("Player " .. tostring(userId))
    self._nameCache[userId] = name
    return name
end

function LeaderboardService:_readGlobalBoard(board)
    local requestedRoundStart = self:_challengeRoundStart(board, os.time())
    local store = self:_getGlobalReadStore(board)
    if not store then
        self:_broadcast(board.id)
        return
    end
    local cacheCount = positiveInteger((self._config.publication or {}).cache_entries, 100)
    local ok, pageOrError = pcall(function()
        return store:GetSortedAsync(board.sort == "asc", cacheCount)
    end)
    if not ok then
        self._logger:Warn("Failed to read global leaderboard", {
            context = "LeaderboardService",
            board = board.id,
            error = tostring(pageOrError),
        })
        self:_broadcast(board.id)
        return
    end
    if requestedRoundStart ~= self:_challengeRoundStart(board, os.time()) then
        -- The datastore read crossed a reset boundary. Never let the completed
        -- old-round request repopulate the freshly cleared board.
        task.spawn(function()
            self:_readGlobalBoard(board)
        end)
        return
    end

    local entries = {}
    for _, row in ipairs(pageOrError:GetCurrentPage()) do
        local userId = tonumber(row.key)
        local value = tonumber(row.value) or 0
        if userId and value > 0 then
            table.insert(entries, {
                userId = userId,
                value = value,
            })
        end
    end
    self._cachedGlobalTop100[board.id] = entries

    -- OrderedDataStore keeps/read-caches 100 scores, but a board only needs names for its ten
    -- visible rows. This keeps refresh cost bounded if the experience grows substantially.
    local visible = self:_publicTop(
        entries,
        positiveInteger((self._config.publication or {}).display_entries, 10)
    )
    for _, entry in ipairs(visible) do
        local name = self:_nameForUserId(entry.userId)
        entry.name = name
        entry.displayName = name
    end
    self._cachedGlobal[board.id] = visible
    self:_broadcast(board.id)
end

function LeaderboardService:_startGlobalReadLoop()
    task.spawn(function()
        for _, board in ipairs(self._config.boards or {}) do
            self:_readGlobalBoard(board)
        end
    end)
    self._globalReadElapsed = 0
end

function LeaderboardService:_heartbeat(deltaTime)
    local now = os.clock()
    for key, pending in pairs(self._pendingRefresh) do
        if now >= pending.dueAt then
            self._pendingRefresh[key] = nil
            if pending.player.Parent then
                self:_refreshBoardForPlayer(pending.board, pending.player, false)
            end
        end
    end
    for key, pending in pairs(self._pendingPublish) do
        if now >= pending.dueAt then
            self._pendingPublish[key] = nil
            self:_publishNow(
                pending.board,
                pending.store,
                pending.userId,
                pending.value,
                key,
                pending.generation
            )
        end
    end

    self:_rotateChallengeRounds(os.time(), true)

    local _, _, sweepSeconds = ChallengeRun.leaderboardWindow(self._challengeConfig)
    self._challengeSweepElapsed = (self._challengeSweepElapsed or 0) + deltaTime
    if #self._challengeBoards > 0 and self._challengeSweepElapsed >= sweepSeconds then
        self._challengeSweepElapsed %= sweepSeconds
        task.spawn(function()
            self:_sweepChallengeWindows(false)
        end)
    end

    self._globalReadElapsed = (self._globalReadElapsed or 0) + deltaTime
    local interval = positiveInteger((self._config.publication or {}).refresh_seconds, 90)
    if self._globalReadElapsed >= interval then
        self._globalReadElapsed %= interval
        task.spawn(function()
            for _, board in ipairs(self._config.boards or {}) do
                self:_readGlobalBoard(board)
            end
        end)
    end
end

return LeaderboardService
