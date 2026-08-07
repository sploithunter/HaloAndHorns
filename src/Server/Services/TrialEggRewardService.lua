--[[
    TrialEggRewardService

    Grants one provenance-bound evolving egg for each named-trial track. Only the exact
    record awarded to the account may evolve. Trading freezes it; returning it to the
    original award recipient catches it up. Hatching is permanent and pets never evolve.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)
local TrialEggRewardLadder = require(ReplicatedStorage.Shared.Game.TrialEggRewardLadder)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local TrialEggRewardService = {}
TrialEggRewardService.__index = TrialEggRewardService

function TrialEggRewardService.new()
    return setmetatable(
        { _connections = setmetatable({}, { __mode = "k" }) },
        TrialEggRewardService
    )
end

function TrialEggRewardService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._inventoryService = self._modules.InventoryService
    self._config = self._configLoader:LoadConfig("trial_rewards")
    self._petsConfig = self._configLoader:LoadConfig("pets")
    self._tracksByAward = {}
    for _, track in pairs(self._config.tracks or {}) do
        self._tracksByAward[track.award_id] = track
    end
end

function TrialEggRewardService:Start()
    local function watch(player)
        if self._connections[player] then
            return
        end
        self._connections[player] = player
            :GetAttributeChangedSignal("ClaimedLevel")
            :Connect(function()
                self:Reconcile(player, "level_changed")
            end)
        task.spawn(function()
            if Readiness.awaitAttribute(player, "DataLoaded", true, 15) then
                self:Reconcile(player, "join")
            end
        end)
    end
    Players.PlayerAdded:Connect(watch)
    Players.PlayerRemoving:Connect(function(player)
        local connection = self._connections[player]
        if connection then
            connection:Disconnect()
        end
        self._connections[player] = nil
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        watch(player)
    end
end

function TrialEggRewardService:_claimedLevel(player)
    return math.max(1, math.floor(tonumber(player:GetAttribute("ClaimedLevel")) or 1))
end

function TrialEggRewardService:_rootState(data)
    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    data.GameData.TrialEggRewards = type(data.GameData.TrialEggRewards) == "table"
            and data.GameData.TrialEggRewards
        or {}
    local root = data.GameData.TrialEggRewards
    root.tracks = type(root.tracks) == "table" and root.tracks or {}
    return root
end

function TrialEggRewardService:_state(root, awardId)
    local state = root.tracks[awardId]
    if type(state) ~= "table" then
        state = {}
        root.tracks[awardId] = state
    end
    return state
end

function TrialEggRewardService:_record(player, track)
    local preferred = TrialEggRewardLadder.recordKey(track.award_id, player.UserId)
    local record = self._inventoryService:GetItem(player, "eggs", preferred)
    if
        type(record) == "table"
        and record.award_id == track.award_id
        and TrialEggRewardLadder.isAwardOwner(record, player.UserId)
    then
        return record, preferred
    end
    return nil, preferred
end

function TrialEggRewardService:_isCanonicalRecord(recordKey, record, track)
    return TrialEggRewardLadder.isCanonicalRecordKey(recordKey, record, track)
end

function TrialEggRewardService:_grant(player, track, milestone, state)
    local recordKey = TrialEggRewardLadder.recordKey(track.award_id, player.UserId)
    local record = TrialEggRewardLadder.newRecord(
        track,
        milestone,
        player.UserId,
        os.time(),
        self._config.version
    )
    local eggDef = self._petsConfig.egg_sources[record.id]
    record.name = (eggDef and eggDef.name) or record.id
    local receipt, err =
        self._inventoryService:InsertRecordSnapshot(player, "eggs", recordKey, record)
    if not receipt then
        self._logger:Warn("Trial egg grant failed", {
            player = player.Name,
            awardId = track.award_id,
            error = tostring(err),
        })
        return false
    end
    state.granted_at = os.time()
    state.record_key = recordKey
    state.stage = milestone.stage
    fireGameEvent(player, "trial_egg_awarded", {
        name = ("🥚 %s earned! Keep it unhatched to evolve it through 100 clears."):format(
            eggDef and eggDef.name or "Trial Egg"
        ),
        award = track.award_id,
        stage = milestone.stage,
    })
    return true
end

function TrialEggRewardService:Reconcile(player, reason)
    if not player or not player.Parent or not self._dataService:IsDataLoaded(player) then
        return { ok = false, reason = "data_not_loaded" }
    end
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "no_data" }
    end
    local root = self:_rootState(data)
    local claims = type(data.QuestClaims) == "table" and data.QuestClaims or {}
    local claimedLevel = self:_claimedLevel(player)
    local changed = false

    for _, track in pairs(self._config.tracks or {}) do
        local milestone = TrialEggRewardLadder.earnedStage(track, claims, claimedLevel)
        if milestone then
            local state = self:_state(root, track.award_id)
            local record, recordKey = self:_record(player, track)
            if not state.granted_at then
                if record then
                    -- Repair old or interrupted grants without minting a second egg.
                    state.granted_at = record.obtained_at or os.time()
                    state.record_key = recordKey
                    changed = true
                else
                    changed = self:_grant(player, track, milestone, state) or changed
                    record, recordKey = self:_record(player, track)
                end
            end
            if record then
                state.record_key = recordKey
                local upgraded, stage =
                    TrialEggRewardLadder.applyStage(record, player.UserId, track, milestone)
                if upgraded then
                    local eggDef = self._petsConfig.egg_sources[record.id]
                    record.name = (eggDef and eggDef.name) or record.id
                    state.stage = stage
                    changed = true
                    fireGameEvent(player, "trial_egg_upgraded", {
                        name = ("Your %s evolved to %s!"):format(
                            track.display_name or "Trial Egg",
                            stage:upper()
                        ),
                        award = track.award_id,
                        stage = stage,
                    })
                end
            end
        end
    end

    if changed then
        self._inventoryService:FlushBucket(player, "eggs", "trial_egg_reconcile")
        self._dataService:RequestSave(player, "trial_egg_reconcile", { critical = true })
    end
    self._logger:Debug("Trial eggs reconciled", {
        player = player.Name,
        reason = reason,
        changed = changed,
    })
    return { ok = true, changed = changed }
end

function TrialEggRewardService:ResolveHatch(player, recordKey, record, confirmedPermanent)
    if type(record) ~= "table" or type(record.award_id) ~= "string" then
        return nil
    end
    local track = self._tracksByAward[record.award_id]
    if not track then
        return nil
    end
    if not self:_isCanonicalRecord(recordKey, record, track) then
        return { ok = false, reason = "invalid_award_record" }
    end

    -- Only the original recipient can catch the egg up. A traded egg keeps its stored stage.
    if TrialEggRewardLadder.isAwardOwner(record, player.UserId) then
        local data = self._dataService:GetData(player)
        local milestone = TrialEggRewardLadder.earnedStage(
            track,
            data and data.QuestClaims,
            self:_claimedLevel(player)
        )
        if milestone then
            TrialEggRewardLadder.applyStage(record, player.UserId, track, milestone)
        end
    end

    if record.trial_reward_stage ~= "huge" and confirmedPermanent ~= true then
        return { ok = false, reason = "progression_confirmation_required" }
    end

    local baseEggId = record.trial_reward_stage == "huge" and track.huge_egg_id or track.egg_id
    local hatch = self._petsConfig.simulateHatch(baseEggId, {})
    if type(hatch) ~= "table" or not hatch.pet then
        return { ok = false, reason = "hatch_failed" }
    end
    local forcedVariant = tostring(record.variant or "basic")
    if record.trial_reward_stage ~= "huge" then
        hatch.variant = forcedVariant
        hatch.huge = math.random() < (tonumber(record.trial_reward_huge_chance) or 0)
    else
        hatch.huge = true
    end
    return {
        ok = true,
        pet = hatch.pet,
        variant = hatch.variant or "basic",
        huge = hatch.huge == true,
        award_kind = "trial_egg_hatch",
        award_id = record.award_id,
        awarded_to_user_id = record.awarded_to_user_id,
        award_tier = hatch.variant or "basic",
        award_version = record.award_version,
    }
end

function TrialEggRewardService:MarkHatched(player, recordKey, record)
    if
        type(record) ~= "table"
        or not self._tracksByAward[record.award_id]
        or not self:_isCanonicalRecord(recordKey, record, self._tracksByAward[record.award_id])
        or not TrialEggRewardLadder.isAwardOwner(record, player.UserId)
    then
        return
    end
    local data = self._dataService:GetData(player)
    if not data then
        return
    end
    local state = self:_state(self:_rootState(data), record.award_id)
    state.hatched_at = state.hatched_at or os.time()
    state.hatched_stage = record.trial_reward_stage
end

function TrialEggRewardService:ReconcileRecordBeforeTrade(player, recordKey, record)
    if type(record) ~= "table" then
        return false
    end
    local track = self._tracksByAward[record.award_id]
    if
        not track
        or not self:_isCanonicalRecord(recordKey, record, track)
        or not TrialEggRewardLadder.isAwardOwner(record, player.UserId)
    then
        return false
    end
    local data = self._dataService:GetData(player)
    local milestone = TrialEggRewardLadder.earnedStage(
        track,
        data and data.QuestClaims,
        self:_claimedLevel(player)
    )
    return milestone and TrialEggRewardLadder.applyStage(record, player.UserId, track, milestone)
        or false
end

return TrialEggRewardService
