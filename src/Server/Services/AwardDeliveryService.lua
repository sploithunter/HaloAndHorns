--[[
    AwardDeliveryService — durable, server-authored gifts for online or offline players.

    QueueForUser writes a versioned message into the player's ProfileStore record. On an
    active session (including the player's next return), the handler grants through the
    RewardService spine, records the stable award id, acknowledges the message, requests
    a critical save, and shows the configured personal celebration.

    This boundary is intentionally producer-agnostic: leaderboard settlement uses it now;
    a future offline exchange can queue its receipt through the same method.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AwardDelivery = require(ReplicatedStorage.Shared.Game.AwardDelivery)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)

local AwardDeliveryService = {}
AwardDeliveryService.__index = AwardDeliveryService

function AwardDeliveryService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._rewardService = self._modules and self._modules.RewardService
    self._config = self._configLoader:LoadConfig("rewards")
    self._attached = setmetatable({}, { __mode = "k" })
    self._inflight = setmetatable({}, { __mode = "k" })
end

function AwardDeliveryService:Start()
    local function attach(player)
        task.spawn(function()
            if Readiness.awaitAttribute(player, "DataLoaded", true, 20) and player.Parent then
                self:_attach(player)
            end
        end)
    end

    for _, player in ipairs(Players:GetPlayers()) do
        attach(player)
    end
    Players.PlayerAdded:Connect(attach)
    Players.PlayerRemoving:Connect(function(player)
        self._attached[player] = nil
        self._inflight[player] = nil
    end)
end

function AwardDeliveryService:_attach(player)
    if self._attached[player] then
        return
    end
    local profile = self._dataService and self._dataService:GetProfile(player)
    if not profile or not profile:IsActive() then
        return
    end

    self._attached[player] = true
    profile:MessageHandler(function(message, processed)
        if AwardDelivery.isMessage(message) then
            self:_deliver(player, profile, message, processed)
        end
    end)
end

function AwardDeliveryService:_deliver(player, profile, message, processed)
    local valid, reason = AwardDelivery.validateMessage(message)
    if not valid then
        self._logger:Error("Discarding invalid durable award message", {
            context = "AwardDeliveryService",
            player = player.Name,
            reason = reason,
        })
        processed()
        self._dataService:RequestSave(player, "award_discard_invalid", { critical = true })
        return
    end

    local award = message.award
    local inflight = self._inflight[player]
    if not inflight then
        inflight = {}
        self._inflight[player] = inflight
    end
    if inflight[award.id] then
        return
    end
    inflight[award.id] = true

    local function finish()
        inflight[award.id] = nil
    end

    if player.Parent == nil or self._dataService:GetProfile(player) ~= profile then
        finish()
        return
    end

    local data = profile.Data
    if AwardDelivery.isClaimed(data, award.id) then
        processed()
        self._dataService:RequestSave(player, "award_ack_duplicate", { critical = true })
        finish()
        return
    end

    local ok, result = pcall(function()
        return self._rewardService:Grant(
            player,
            award.bundle,
            award.source or ("award:" .. award.id)
        )
    end)
    if not ok or type(result) ~= "table" or result.ok ~= true then
        self._logger:Error("Durable award grant failed; message remains queued", {
            context = "AwardDeliveryService",
            player = player.Name,
            awardId = award.id,
            error = ok and "grant_rejected" or tostring(result),
        })
        finish()
        return
    end

    local delivery = self._config.delivery or {}
    AwardDelivery.markClaimed(data, award.id, os.time(), delivery.claimed_id_limit)
    processed()
    self._dataService:RequestSave(player, "award_delivered:" .. award.id, { critical = true })

    local notification = type(award.notification) == "table" and award.notification or {}
    fireGameEvent(player, notification.event or "award_delivered", {
        name = notification.name or "🎁 Your award has arrived!",
        awardId = award.id,
        source = award.source,
        granted = result.granted,
    })

    self._logger:Info("Durable award delivered", {
        context = "AwardDeliveryService",
        player = player.Name,
        userId = player.UserId,
        awardId = award.id,
        source = award.source,
    })
    finish()
end

function AwardDeliveryService:QueueForUser(userId, award)
    local id = math.floor(tonumber(userId) or 0)
    if id <= 0 then
        return { ok = false, reason = "invalid_user_id" }
    end

    local ok, messageOrError = pcall(AwardDelivery.message, award)
    if not ok then
        return { ok = false, reason = "invalid_award", error = tostring(messageOrError) }
    end

    local profileStore = self._dataService and self._dataService.ProfileStore
    if not profileStore then
        return { ok = false, reason = "profile_store_unavailable" }
    end

    local queued, queueResult = pcall(function()
        return profileStore:MessageAsync("Player_" .. tostring(id), messageOrError)
    end)
    if not queued or queueResult ~= true then
        self._logger:Warn("Failed to queue durable award", {
            context = "AwardDeliveryService",
            userId = id,
            awardId = award.id,
            error = queued and "message_rejected" or tostring(queueResult),
        })
        return { ok = false, reason = "queue_failed" }
    end

    self._logger:Info("Durable award queued", {
        context = "AwardDeliveryService",
        userId = id,
        awardId = award.id,
        source = award.source,
    })
    return { ok = true, awardId = award.id }
end

return AwardDeliveryService
