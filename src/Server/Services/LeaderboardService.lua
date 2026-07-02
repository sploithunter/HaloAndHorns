local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

function LeaderboardService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._statsService = self._modules.StatsService

    self._config = self._configLoader:LoadConfig("leaderboards")
    self._boardsById = {}
    self._liveValues = {}
    self._globalStores = {}

    for _, board in ipairs(self._config.boards or {}) do
        self._boardsById[board.id] = board
        self._liveValues[board.id] = {}
    end

    if self._statsService and self._statsService.CounterChanged then
        self._statsService.CounterChanged:Connect(function(player, counterId, newValue)
            self:_onCounterChanged(player, counterId, newValue)
        end)
    end

    self._logger:Info("LeaderboardService initialized", {
        context = "LeaderboardService",
        boardCount = #(self._config.boards or {}),
    })
end

function LeaderboardService:Start()
    Players.PlayerAdded:Connect(function(player)
        task.spawn(function()
            self:_waitForDataAndRefresh(player)
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        for boardId in pairs(self._liveValues) do
            self._liveValues[boardId][player.UserId] = nil
        end
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            self:_waitForDataAndRefresh(player)
        end)
    end

    self:_startGlobalPublishLoop()
end

function LeaderboardService:_waitForDataAndRefresh(player)
    local deadline = os.clock() + 15
    while player.Parent and not self._dataService:IsDataLoaded(player) and os.clock() < deadline do
        task.wait(0.2)
    end

    if player.Parent and self._dataService:IsDataLoaded(player) then
        self:RefreshPlayer(player)
    end
end

function LeaderboardService:_onCounterChanged(player, counterId, newValue)
    for _, board in ipairs(self._config.boards or {}) do
        if board.stat == counterId then
            self:_setLiveValue(board, player, newValue)
            self:_publishGlobalValue(board, player, newValue)
        end
    end
end

function LeaderboardService:_setLiveValue(board, player, value)
    self._liveValues[board.id] = self._liveValues[board.id] or {}
    self._liveValues[board.id][player.UserId] = {
        userId = player.UserId,
        name = player.Name,
        displayName = player.DisplayName,
        value = tonumber(value) or 0,
    }
end

function LeaderboardService:RefreshPlayer(player)
    for _, board in ipairs(self._config.boards or {}) do
        local value = self._statsService:Get(player, board.stat)
        self:_setLiveValue(board, player, value)
    end
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

    local maxEntries = math.min(limit or board.max_entries or 10, #entries)
    local trimmed = {}
    for index = 1, maxEntries do
        trimmed[index] = entries[index]
        trimmed[index].rank = index
    end

    return trimmed
end

function LeaderboardService:GetSnapshot(boardId)
    local entries, errorMessage = self:GetLiveLeaderboard(boardId)
    if not entries then
        return {
            ok = false,
            error = errorMessage,
        }
    end

    return {
        ok = true,
        boardId = boardId,
        entries = entries,
    }
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
        return self._globalStores[board.id]
    end

    local ok, storeOrError = pcall(function()
        return DataStoreService:GetOrderedDataStore(global.ordered_store)
    end)
    if ok then
        self._globalStores[board.id] = storeOrError
    else
        self._globalStores[board.id] = false
        self._logger:Warn("Failed to open ordered leaderboard store", {
            context = "LeaderboardService",
            board = board.id,
            error = tostring(storeOrError),
        })
    end

    return self._globalStores[board.id] or nil
end

function LeaderboardService:_publishGlobalValue(board, player, value)
    local store = self:_getGlobalStore(board)
    if not store then
        return
    end

    task.spawn(function()
        local ok, errorMessage = pcall(function()
            store:SetAsync(tostring(player.UserId), tonumber(value) or 0)
        end)
        if not ok then
            self._logger:Warn("Failed to publish leaderboard value", {
                context = "LeaderboardService",
                board = board.id,
                player = player.Name,
                error = tostring(errorMessage),
            })
        end
    end)
end

function LeaderboardService:_startGlobalPublishLoop()
    task.spawn(function()
        while true do
            local waitSeconds = 120
            for _, board in ipairs(self._config.boards or {}) do
                local global = board.global or {}
                if global.enabled == true then
                    waitSeconds = math.min(waitSeconds, global.refresh_seconds or waitSeconds)
                    for _, player in ipairs(Players:GetPlayers()) do
                        if self._dataService:IsDataLoaded(player) then
                            self:_publishGlobalValue(
                                board,
                                player,
                                self._statsService:Get(player, board.stat)
                            )
                        end
                    end
                end
            end

            -- Publish each board's snapshot to clients. A connected client consumer
            -- (LeaderboardController) caches these for the leaderboard UI; without a listener
            -- these would queue per-client and drop ("invocation queue exhausted").
            for boardId in pairs(self._boardsById) do
                Signals.LeaderboardUpdated:FireAllClients(self:GetSnapshot(boardId))
            end

            task.wait(waitSeconds)
        end
    end)
end

return LeaderboardService
