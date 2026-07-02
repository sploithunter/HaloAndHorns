local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Libraries.Signal)

local StatsService = {}
StatsService.__index = StatsService

function StatsService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self.CounterChanged = Signal.new()

    self._config = self._configLoader:LoadConfig("stats")
    self._counters = self._config.counters or {}

    self._logger:Info("StatsService initialized", {
        counterCount = self:_getCounterCount(),
        context = "StatsService",
    })
end

function StatsService:_getCounterCount()
    local count = 0
    for _ in pairs(self._counters) do
        count += 1
    end
    return count
end

function StatsService:_assertCounter(counterId)
    if type(counterId) ~= "string" or not self._counters[counterId] then
        error("Unknown stat counter: " .. tostring(counterId))
    end
end

function StatsService:Get(player, counterId)
    self:_assertCounter(counterId)
    return self._dataService:GetCounter(player, counterId)
end

function StatsService:Set(player, counterId, value)
    self:_assertCounter(counterId)

    if type(value) ~= "number" then
        error("Counter value must be a number for " .. tostring(counterId))
    end

    local oldValue = self._dataService:GetCounter(player, counterId)
    local success = self._dataService:SetCounter(player, counterId, value)

    if success and value ~= oldValue then
        self.CounterChanged:Fire(player, counterId, value, oldValue)
    end

    return success
end

function StatsService:Increment(player, counterId, amount)
    self:_assertCounter(counterId)
    amount = amount or 1

    if type(amount) ~= "number" then
        error("Counter increment amount must be a number for " .. tostring(counterId))
    end

    return self:Set(player, counterId, self._dataService:GetCounter(player, counterId) + amount)
end

function StatsService:GetAll(player)
    local data = self._dataService:GetData(player)
    if not data or not data.Stats then
        return {}
    end

    return data.Stats.Counters or {}
end

return StatsService
