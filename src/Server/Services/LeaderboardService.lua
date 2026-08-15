local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
    self.SnapshotChanged = Signal.new()

    for _, userId in ipairs(self._config.excluded_user_ids or {}) do
        self._excluded[tonumber(userId)] = true
    end

    for _, board in ipairs(self._config.boards or {}) do
        self._boardsById[board.id] = board
        self._liveValues[board.id] = {}
        local score = self:_scoreDefinition(board)
        if score.kind == "counter" then
            self._counterBoards[score.counter] = self._counterBoards[score.counter] or {}
            table.insert(self._counterBoards[score.counter], board)
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
    Players.PlayerAdded:Connect(function(player)
        task.spawn(function()
            self:_waitForDataAndRefresh(player)
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        -- PlayerRemoving still has access to the profile in the normal teardown path. A forced
        -- write bypasses debounce; if another service released first, the last cached value wins.
        self:RefreshPlayer(player, true)
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

    self:_cleanExcludedKeys()
    self:_startGlobalReadLoop()
    RunService.Heartbeat:Connect(function(deltaTime)
        self:_heartbeat(deltaTime)
    end)

    game:BindToClose(function()
        -- This is bounded by the current server population; it never enumerates saved profiles.
        for _, player in ipairs(Players:GetPlayers()) do
            self:RefreshPlayer(player, true)
        end
    end)
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
        return LeaderboardScoring.countTaxonomy(data, score.pet_ids)
    elseif score.kind == "strongest_squad" then
        local slots = self._inventoryService:RefreshEquipCapacity(player)
        return LeaderboardScoring.strongestLegalSquad(data, slots, function(record)
            return self:_petPower(record)
        end)
    end
    return 0
end

function LeaderboardService:_setLiveValue(board, player, value)
    if self._excluded[player.UserId] then
        self._liveValues[board.id][player.UserId] = nil
        return
    end
    self._liveValues[board.id][player.UserId] = {
        userId = player.UserId,
        name = player.Name,
        displayName = player.DisplayName,
        value = math.max(0, tonumber(value) or 0),
    }
end

function LeaderboardService:_refreshBoardForPlayer(board, player, force)
    if not player or self._excluded[player.UserId] then
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

function LeaderboardService:RefreshPlayer(player, force)
    for _, board in ipairs(self._config.boards or {}) do
        self:_refreshBoardForPlayer(board, player, force == true)
    end
end

function LeaderboardService:_scheduleBoardRefresh(board, player)
    if not player or self._excluded[player.UserId] then
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
    return self:_trimEntries(entries, limit or board.max_entries or 10)
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
        and (not RunService:IsStudio() or global.studio_enabled == true)
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
        if not self._excluded[player.UserId] then
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

function LeaderboardService:_getGlobalStore(board)
    local global = board.global or {}
    if global.enabled ~= true then
        return nil
    end
    if RunService:IsStudio() and global.studio_enabled ~= true then
        return nil
    end
    if self._globalStores[board.id] ~= nil then
        return self._globalStores[board.id] or nil
    end
    local ok, result = pcall(function()
        return DataStoreService:GetOrderedDataStore(global.ordered_store)
    end)
    self._globalStores[board.id] = ok and result or false
    if not ok then
        self._logger:Warn("Failed to open ordered leaderboard store", {
            context = "LeaderboardService",
            board = board.id,
            error = tostring(result),
        })
    end
    return self._globalStores[board.id] or nil
end

function LeaderboardService:_scheduleGlobalValue(board, userId, value, force)
    local store = self:_getGlobalStore(board)
    if not store then
        self:_broadcast(board.id)
        return
    end

    local key = board.id .. ":" .. tostring(userId)
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
    local ok, errorMessage = pcall(function()
        store:SetAsync(tostring(userId), value)
    end)
    self._pendingWrites -= 1
    if ok then
        self._lastPublished[key] = value
    else
        self._logger:Warn("Failed to publish leaderboard value", {
            context = "LeaderboardService",
            board = board.id,
            userId = userId,
            error = tostring(errorMessage),
        })
    end
end

function LeaderboardService:_cleanExcludedKeys()
    task.spawn(function()
        for _, board in ipairs(self._config.boards or {}) do
            local store = self:_getGlobalStore(board)
            if store then
                for userId in pairs(self._excluded) do
                    local ok, errorMessage = pcall(function()
                        store:RemoveAsync(tostring(userId))
                    end)
                    if not ok then
                        self._logger:Warn("Failed to remove excluded leaderboard key", {
                            context = "LeaderboardService",
                            board = board.id,
                            userId = userId,
                            error = tostring(errorMessage),
                        })
                    end
                end
            end
        end
    end)
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
    local store = self:_getGlobalStore(board)
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

    local entries = {}
    for _, row in ipairs(pageOrError:GetCurrentPage()) do
        local userId = tonumber(row.key)
        if userId and not self._excluded[userId] then
            table.insert(entries, {
                userId = userId,
                value = tonumber(row.value) or 0,
            })
        end
    end
    self._cachedGlobalTop100[board.id] = entries

    -- OrderedDataStore keeps/read-caches 100 scores, but a board only needs names for its ten
    -- visible rows. This keeps refresh cost bounded if the experience grows substantially.
    local visible = self:_trimEntries(
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
