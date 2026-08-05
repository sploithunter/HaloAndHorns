--[[
    FoundersChoiceService — exact, durable reservation for the launch-10k reward.

    The cohort DataStore keeps one atomic roster value: { count, claims[userId] = ordinal }. A
    retry, rejoin, or admin profile reset therefore returns the same ordinal instead of consuming
    another place. The selected benefit itself lives in the player's profile and is intentionally
    separate from Marketplace ownership; MonetizationService owns the effective union.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signal = require(ReplicatedStorage.Shared.Libraries.Signal)
local FoundersChoice = require(ReplicatedStorage.Shared.Game.FoundersChoice)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)

local FoundersChoiceService = {}
FoundersChoiceService.__index = FoundersChoiceService

function FoundersChoiceService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._monetization = self._configLoader:LoadConfig("monetization")
    self._config = self._monetization.founders_choice or {}
    self._pending = {}
    self.StateChanged = Signal.new()

    if
        self._config.enabled ~= false
        and not (RunService:IsStudio() and self._config.studio_unlimited)
    then
        local ok, store = pcall(function()
            return DataStoreService:GetDataStore(self._config.data_store_name)
        end)
        if ok then
            self._cohortStore = store
        else
            self._logger:Error("Founder's Choice cohort store unavailable", {
                error = tostring(store),
            })
        end
    end

    fireGameEvent.tap(function(player, eventName)
        if eventName == "tutorial_complete" then
            self:QueueEligibility(player, true)
        end
    end)
end

function FoundersChoiceService:Start()
    Players.PlayerAdded:Connect(function(player)
        self:_queueWhenReady(player)
    end)
    Players.PlayerRemoving:Connect(function(player)
        self._pending[player] = nil
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        self:_queueWhenReady(player)
    end
end

function FoundersChoiceService:_queueWhenReady(player)
    task.spawn(function()
        if Readiness.awaitAttribute(player, "DataLoaded", true, 30) and player.Parent then
            self:QueueEligibility(player, false)
        end
    end)
end

function FoundersChoiceService:_profileState(player)
    local data = self._dataService:GetData(player)
    if not data then
        return nil, nil
    end
    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    local state =
        FoundersChoice.normalizeState(data.GameData.FoundersChoice, self._config.cohort_id)
    data.GameData.FoundersChoice = state
    return data, state
end

function FoundersChoiceService:GetState(player)
    local _, state = self:_profileState(player)
    return state
end

function FoundersChoiceService:IsEligiblePass(passId)
    return FoundersChoice.isEligiblePass(self._monetization, passId)
end

function FoundersChoiceService:GetEligiblePassIds()
    local result = {}
    for _, passId in ipairs(self._config.eligible_passes or {}) do
        result[#result + 1] = passId
    end
    return result
end

function FoundersChoiceService:_hasQualified(data, genuineCompletion)
    if self._config.require_tutorial ~= true then
        return true
    end
    if genuineCompletion then
        return true
    end
    if type(data.Tutorial) == "table" and data.Tutorial.done == true then
        return true
    end

    -- Profiles that predate the current tutorial are silently veteran-skipped by TutorialService.
    -- Honor the same claimed-level threshold so launch-era existing players are not excluded merely
    -- because their one-time completion event happened before Founder's Choice shipped.
    local tutorialConfig = self._configLoader:LoadConfig("tutorial")
    local veteranLevel = math.floor(
        tonumber(tutorialConfig.veteran_skip and tutorialConfig.veteran_skip.min_claimed_level) or 3
    )
    local claimed = math.floor(tonumber(data.Stats and data.Stats.ClaimedLevel) or 1)
    return claimed >= veteranLevel
end

function FoundersChoiceService:_reserve(userId)
    local limit = math.max(1, math.floor(tonumber(self._config.player_limit) or 10000))
    if RunService:IsStudio() and self._config.studio_unlimited == true then
        return true, 0, "studio"
    end
    if not self._cohortStore then
        return false, 0, "store_unavailable"
    end

    local userKey = tostring(userId)
    local ok, updated = pcall(function()
        return self._cohortStore:UpdateAsync(self._config.data_store_key, function(current)
            current = type(current) == "table" and current or {}
            current.version = 1
            current.count = math.max(0, math.floor(tonumber(current.count) or 0))
            current.claims = type(current.claims) == "table" and current.claims or {}
            local existing = math.floor(tonumber(current.claims[userKey]) or 0)
            if existing > 0 or current.count >= limit then
                return current
            end
            current.count += 1
            current.claims[userKey] = current.count
            current.updatedAt = os.time()
            return current
        end)
    end)
    if not ok or type(updated) ~= "table" then
        return false, 0, tostring(updated)
    end
    local ordinal = math.floor(tonumber(updated.claims and updated.claims[userKey]) or 0)
    if ordinal <= 0 then
        return false, 0, "cohort_full"
    end
    return true, ordinal, nil
end

function FoundersChoiceService:QueueEligibility(player, genuineCompletion)
    if
        self._config.enabled == false
        or not player
        or not player.Parent
        or self._pending[player]
    then
        return
    end
    local data, state = self:_profileState(player)
    if
        not data
        or state.eligibilityDecided
        or not self:_hasQualified(data, genuineCompletion)
    then
        return
    end

    self._pending[player] = true
    task.spawn(function()
        local eligible, ordinal, reason = self:_reserve(player.UserId)
        self._pending[player] = nil
        if not player.Parent then
            return
        end
        local liveData, liveState = self:_profileState(player)
        if not liveData or liveState.eligibilityDecided then
            return
        end
        if not eligible and reason ~= "cohort_full" then
            self._logger:Warn("Founder's Choice reservation deferred", {
                player = player.Name,
                userId = player.UserId,
                reason = reason,
            })
            return
        end

        liveState.eligibilityDecided = true
        liveState.eligible = eligible
        liveState.claimNumber = ordinal
        liveState.cohortId = self._config.cohort_id
        liveData.GameData.FoundersChoice = liveState
        self._dataService:RequestSave(player, "founders_choice_eligibility", {
            critical = true,
            debounceSeconds = 0,
        })
        if eligible then
            fireGameEvent(player, "founders_choice_available", {
                name = "🎁 FOUNDER'S CHOICE UNLOCKED — pick one permanent benefit!",
                cohortId = liveState.cohortId,
                claimNumber = ordinal,
            })
        end
        self.StateChanged:Fire(player, "eligibility")
        self._logger:Info("Founder's Choice eligibility decided", {
            player = player.Name,
            eligible = eligible,
            claimNumber = ordinal,
            reason = reason,
        })
    end)
end

function FoundersChoiceService:Select(player, passId, unavailablePasses)
    local data, state = self:_profileState(player)
    if not data then
        return false, "Your profile is still loading."
    end
    if not FoundersChoice.canChoose(state) then
        return false,
            state.selectedPassId ~= "" and "Your Founder's Choice is already active."
                or "This profile is not eligible for Founder's Choice."
    end
    if not FoundersChoice.isEligiblePass(self._monetization, passId) then
        return false, "Choose one of the available Founder's benefits."
    end
    if type(unavailablePasses) == "table" and unavailablePasses[passId] == true then
        return false, "You already have that benefit. Choose a different one."
    end

    state.selectedPassId = passId
    state.selectedAt = os.time()
    data.GameData.FoundersChoice = state
    self._dataService:RequestSave(player, "founders_choice_selected", {
        critical = true,
        debounceSeconds = 0,
    })
    fireGameEvent(player, "founders_choice_selected", {
        name = "🎁 Founder's benefit activated!",
        cohortId = state.cohortId,
        claimNumber = state.claimNumber,
        passId = passId,
    })
    self.StateChanged:Fire(player, "selected")
    return true, nil
end

function FoundersChoiceService:ReleaseForMarketplaceOwnership(player, passId)
    local data, state = self:_profileState(player)
    if not data or state.selectedPassId ~= passId then
        return false
    end
    state.selectedPassId = ""
    state.selectedAt = 0
    state.reselections += 1
    data.GameData.FoundersChoice = state
    self._dataService:RequestSave(player, "founders_choice_reselection", {
        critical = true,
        debounceSeconds = 0,
    })
    fireGameEvent(player, "founders_choice_reselection", {
        name = "🎁 Your Founder's Choice is ready to use again!",
        purchasedPassId = passId,
    })
    self.StateChanged:Fire(player, "reselection")
    return true
end

return FoundersChoiceService
