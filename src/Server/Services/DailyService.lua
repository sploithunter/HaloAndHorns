--[[
    DailyService — Phase 7 (the cadence-gated reward gate).

    Daily login streak: a Claim whose gate is the calendar day rather than a
    Condition. The pure DailyStreak resolver does the streak math over integer day
    indices (this service supplies floor(os.time()/86400) as "today"). State lives
    in profile.Daily { lastDay, streak }. Grants flow through RewardService. The
    "Daily ❗" badge = 1 when a claim is available today.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyStreak = require(ReplicatedStorage.Shared.Game.DailyStreak)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local DailyService = {}
DailyService.__index = DailyService

local SECONDS_PER_DAY = 86400

function DailyService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._config = self._configLoader:LoadConfig("daily")
end

function DailyService:_service(name)
    local locator = _G.RBXTemplateServices
    if not locator then
        return nil
    end
    local ok, service = pcall(function()
        return locator:Get(name)
    end)
    return ok and service or nil
end

function DailyService:_today()
    return math.floor(os.time() / SECONDS_PER_DAY)
end

local function state(data)
    if type(data) ~= "table" then
        -- Fresh-join race: a GameAPI daily.status/claim can land before the profile loads. Return a
        -- transient day-0 state rather than nil-indexing (don't mutate; the real profile loads next).
        return { lastDay = nil, streak = 0 }
    end
    if type(data.Daily) ~= "table" then
        data.Daily = { lastDay = nil, streak = 0 }
    end
    return data.Daily
end

-- `today` override is honored only for tests (the bus gates it on context.isTest).
function DailyService:Status(player, today)
    today = today or self:_today()
    local data = self._dataService:GetData(player)
    local s = state(data)
    local r = DailyStreak.resolve(s.lastDay, today, s.streak, self._config)
    -- Surface the calendar (day -> reward bundle) + cycle length so the UI can render
    -- the full week config-free.
    local calendar = {}
    for day, bundle in pairs(self._config.calendar or {}) do
        calendar[tostring(day)] = bundle
    end
    return {
        ok = true,
        claimable = r.claimable,
        reason = r.reason,
        streak = s.streak,
        nextStreak = r.newStreak,
        claimDay = r.claimDay,
        today = today,
        calendar = calendar,
        cycleLength = self._config.cycle_length or 7,
    }
end

function DailyService:Claim(player, today)
    today = today or self:_today()
    local data = self._dataService:GetData(player)
    local s = state(data)
    local r = DailyStreak.resolve(s.lastDay, today, s.streak, self._config)
    if not r.claimable then
        return { ok = false, reason = r.reason or "not_claimable" }
    end

    local bundle = (self._config.calendar or {})[r.claimDay]
    local rewards = self:_service("RewardService")
    local granted
    if rewards and bundle then
        granted = rewards:Grant(player, bundle, "daily:" .. r.claimDay)
    end

    s.lastDay = today
    s.streak = r.newStreak
    self._dataService:RequestSave(player, "daily_claim", { critical = true })
    fireGameEvent(player, "daily_claim", { day = r.claimDay, streak = r.newStreak }) -- fanfare
    return {
        ok = true,
        day = r.claimDay,
        streak = r.newStreak,
        reset = r.reset,
        reward = granted and granted.granted,
    }
end

return DailyService
