--[[
    StatEventCounters — the "free data" bridge (Jason): every fire on the GameEvents
    bus can feed a lifetime profile counter, declared in configs/stats.lua
    `event_counters = { <event_name> = "<counter_id>" }`. One tap, config-driven —
    adding an achievement/alignment stat is a config line, never a service edit.

    Consumers: achievements + quests read the counters (QuestBaselines windows them
    for start->stop missions); the future light/dark ALIGNMENT axis rides the same
    pattern (event -> weighted counter) when its scoring lands.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local StatEventCounters = {}
StatEventCounters.__index = StatEventCounters

function StatEventCounters.new()
    return setmetatable({}, StatEventCounters)
end

function StatEventCounters:Init()
    self._logger = self._modules and self._modules.Logger
    self._statsService = self._modules and self._modules.StatsService
    local ok, statsConfig = pcall(function()
        return (self._modules.ConfigLoader):LoadConfig("stats")
    end)
    self._map = (ok and type(statsConfig) == "table" and statsConfig.event_counters) or {}
end

function StatEventCounters:Start()
    if next(self._map) == nil then
        return
    end
    fireGameEvent.tap(function(player, name, _ctx)
        local counterId = self._map[name]
        if counterId and self._statsService then
            -- pcall'd by the tap already; a bad counter id logs loudly in Studio via
            -- StatsService's assert rather than silently eating events
            self._statsService:Increment(player, counterId, 1)
        end
    end)
    if self._logger then
        local n = 0
        for _ in pairs(self._map) do
            n += 1
        end
        self._logger:Info("StatEventCounters tapping the bus", { mappings = n })
    end
end

return StatEventCounters
