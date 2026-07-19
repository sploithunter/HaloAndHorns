--[[
    RetentionService — persistent activation milestones + Roblox Analytics funnel.

    It observes the existing server GameEvents bus, so quest/zone/tutorial owners stay unaware of
    analytics. New-player onboarding steps go to LogOnboardingFunnelStepEvent; all first-time
    milestones go to one low-cardinality custom event with category/id breakdown fields.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)
local RetentionLogic = require(ReplicatedStorage.Shared.Game.RetentionLogic)

local RetentionService = {}
RetentionService.__index = RetentionService

local function customFields(category, id)
    return {
        [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = category,
        [Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = id,
    }
end

function RetentionService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._config = self._configLoader:LoadConfig("retention")
    self._sessionStarted = {}

    fireGameEvent.tap(function(player, name, ctx)
        self:_onGameEvent(player, name, ctx)
    end)
end

function RetentionService:Start()
    local function begin(player)
        self._sessionStarted[player] = os.clock()
        task.spawn(function()
            if Readiness.awaitAttribute(player, "DataLoaded", true, 20) and player.Parent then
                self:_recordEvent(player, "retention_joined", {})
            end
        end)
    end
    Players.PlayerAdded:Connect(begin)
    Players.PlayerRemoving:Connect(function(player)
        self._sessionStarted[player] = nil
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        begin(player)
    end
end

function RetentionService:_state(player)
    local data = self._dataService:GetData(player)
    if type(data) ~= "table" then
        return nil, nil
    end
    data.Analytics = type(data.Analytics) == "table" and data.Analytics or {}
    local firstSession = tonumber(data.Analytics.SessionCount) == 1
    data.Analytics.Retention =
        RetentionLogic.ensure(data.Analytics.Retention, firstSession, os.time())
    return data.Analytics.Retention, data
end

function RetentionService:_meta(player, detail)
    local data = self._dataService:GetData(player)
    local started = self._sessionStarted[player] or os.clock()
    return {
        at = os.time(),
        session = data and data.Analytics and data.Analytics.SessionCount or 1,
        seconds = os.clock() - started,
        detail = detail,
    }
end

function RetentionService:_logCustom(player, category, id)
    local cfg = self._config.custom_event or {}
    if RunService:IsStudio() or cfg.enabled == false then
        return
    end
    pcall(function()
        AnalyticsService:LogCustomEvent(
            player,
            cfg.name or "RetentionMilestone",
            1,
            customFields(category, id)
        )
    end)
end

function RetentionService:_flushFunnel(player, state)
    local cfg = self._config.onboarding or {}
    if RunService:IsStudio() or cfg.enabled == false then
        return false
    end
    local changed = false
    for _, step in ipairs(RetentionLogic.pendingFunnelSteps(self._config, state)) do
        local ok = pcall(function()
            AnalyticsService:LogOnboardingFunnelStepEvent(
                player,
                step.index,
                step.name,
                customFields("onboarding", step.id)
            )
        end)
        if not ok then
            break
        end
        state.AnalyticsFunnelStep = step.index
        changed = true
    end
    return changed
end

function RetentionService:_recordMilestone(player, id, category, detail)
    local state = self:_state(player)
    if not state then
        return false
    end
    if not RetentionLogic.record(state, id, category, self:_meta(player, detail)) then
        if self:_flushFunnel(player, state) then
            self._dataService:RequestSave(player, "retention_funnel")
        end
        return false
    end
    self:_logCustom(player, category, id)
    self:_flushFunnel(player, state)
    self._dataService:RequestSave(player, "retention_milestone")
    return true
end

function RetentionService:_recordEvent(player, name, ctx)
    if not (player and player.Parent) or not self._dataService:IsDataLoaded(player) then
        return
    end
    for _, step in ipairs(RetentionLogic.matchingSteps(self._config, name, ctx)) do
        self:_recordMilestone(player, step.id, "onboarding")
    end

    if name == "quest_complete" and type(ctx) == "table" and type(ctx.quest) == "string" then
        self:_recordMilestone(player, "quest:" .. ctx.quest, "quest", ctx.quest)
    elseif name == "area_unlocked" and type(ctx) == "table" and type(ctx.areaId) == "string" then
        self:_recordMilestone(player, "area:" .. ctx.areaId, "area", ctx.areaId)
    end
end

function RetentionService:_onGameEvent(player, name, ctx)
    self:_recordEvent(player, name, ctx)
end

function RetentionService:GetSnapshot(player)
    local state, data = self:_state(player)
    if not state then
        return { ok = false, reason = "data_not_loaded" }
    end
    local snapshot = RetentionLogic.snapshot(self._config, state)
    snapshot.ok = true
    snapshot.sessionCount = data.Analytics.SessionCount
    snapshot.totalPlayTime = data.Analytics.TotalPlayTime
    snapshot.lastSessionDuration = data.Analytics.LastSessionDuration
    snapshot.joinDate = data.JoinDate
    snapshot.lastLogin = data.LastLogin
    return snapshot
end

return RetentionService
