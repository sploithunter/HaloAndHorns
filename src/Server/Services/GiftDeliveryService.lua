-- Durable ProfileStore message consumer/producer for unopened pet presents.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AssetFetch = require(ReplicatedStorage.Shared.Utils.AssetFetch)
local GiftDelivery = require(ReplicatedStorage.Shared.Game.GiftDelivery)
local GiftLogic = require(ReplicatedStorage.Shared.Game.GiftLogic)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local GiftDeliveryService = {}
GiftDeliveryService.__index = GiftDeliveryService

local MESSAGE_VALIDATION_OPTIONS = {
    -- Studio multiplayer clients use negative integer UserIds. They are valid
    -- ProfileStore keys for local testing, but must never be accepted live.
    allow_studio_user_ids = RunService:IsStudio(),
}

function GiftDeliveryService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._inventoryService = self._modules.InventoryService
    self._config = self._configLoader:LoadConfig("gifts") or {}
    self._attached = setmetatable({}, { __mode = "k" })
    self._inflight = setmetatable({}, { __mode = "k" })
end

function GiftDeliveryService:Start()
    task.spawn(function()
        self:_preloadPresentModel()
    end)

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

function GiftDeliveryService:_preloadPresentModel()
    local assetsRoot = ReplicatedStorage:FindFirstChild("Assets")
    local modelsRoot = assetsRoot and assetsRoot:FindFirstChild("Models")
    if not modelsRoot then
        return
    end

    local giftsFolder = modelsRoot:FindFirstChild("Gifts") or Instance.new("Folder")
    giftsFolder.Name = "Gifts"
    giftsFolder.Parent = modelsRoot

    local assets = self._config.assets or {}
    local presentations = assets.presentations
    if type(presentations) ~= "table" then
        presentations = { standard = assets }
    end
    local tierIds = {}
    for tierId in pairs(presentations) do
        table.insert(tierIds, tierId)
    end
    table.sort(tierIds)

    for _, tierId in ipairs(tierIds) do
        local presentation = presentations[tierId]
        local assetId = tonumber(tostring(presentation.present_model_asset or ""):match("%d+"))
        local modelName = presentation.replicated_model_name
            or (tierId == "standard" and "StarlightGift" or "StarlightGift_" .. tierId)
        if assetId and not giftsFolder:FindFirstChild(modelName) then
            local ok, loadedOrError = pcall(function()
                return AssetFetch.load(assetId)
            end)
            if not ok or not loadedOrError then
                self._logger:Warn(
                    "Gift present model preload failed; icon fallback remains available",
                    {
                        context = "GiftDeliveryService",
                        tier = tierId,
                        assetId = assetId,
                        error = tostring(loadedOrError),
                    }
                )
                continue
            end

            local loaded = loadedOrError
            local sourceModel = loaded:IsA("Model") and loaded
                or loaded:FindFirstChildOfClass("Model")
            local model
            if sourceModel then
                model = sourceModel:Clone()
            else
                local part = loaded:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    model = Instance.new("Model")
                    local clone = part:Clone()
                    clone.Parent = model
                    model.PrimaryPart = clone
                end
            end
            loaded:Destroy()
            if model then
                model.Name = modelName
                for _, descendant in ipairs(model:GetDescendants()) do
                    if descendant:IsA("BasePart") then
                        descendant.Anchored = true
                        descendant.CanCollide = false
                        descendant.CanTouch = false
                        descendant.CanQuery = false
                    end
                end
                model.Parent = giftsFolder
            end
        end
    end
end

function GiftDeliveryService:_attach(player)
    if self._attached[player] then
        return
    end
    local profile = self._dataService:GetProfile(player)
    if not profile or not profile:IsActive() then
        return
    end
    self._attached[player] = true
    profile:MessageHandler(function(message, processed)
        if GiftDelivery.isMessage(message) then
            self:_deliver(player, profile, message, processed)
        end
    end)
end

function GiftDeliveryService:_deliver(player, profile, message, processed)
    local valid, reason = GiftDelivery.validateMessage(message, MESSAGE_VALIDATION_OPTIONS)
    if not valid or message.gift.receiver_user_id ~= player.UserId then
        self._logger:Error("Discarding invalid durable gift message", {
            context = "GiftDeliveryService",
            player = player.Name,
            reason = valid and "receiver_mismatch" or reason,
        })
        processed()
        self._dataService:RequestSave(player, "gift_discard_invalid", { critical = true })
        return
    end

    local gift = message.gift
    local inflight = self._inflight[player] or {}
    self._inflight[player] = inflight
    if inflight[gift.id] then
        return
    end
    inflight[gift.id] = true
    local function finish()
        inflight[gift.id] = nil
    end

    if player.Parent == nil or self._dataService:GetProfile(player) ~= profile then
        finish()
        return
    end

    local data = profile.Data
    if GiftDelivery.isReceived(data, gift.id) then
        local saved = self._dataService:SaveAndConfirm(player, "gift_ack_duplicate:" .. gift.id, {
            timeoutSeconds = (self._config.limits or {}).save_confirm_timeout_seconds,
        })
        if saved then
            processed()
        end
        finish()
        return
    end

    local wrapped = GiftDelivery.wrappedRecord(gift)
    local receipt, insertError = self._inventoryService:InsertRecordSnapshot(
        player,
        "gifts",
        gift.id,
        wrapped,
        { deferFlush = true }
    )
    if not receipt then
        self._logger:Warn("Durable gift remains queued because the present could not be stored", {
            context = "GiftDeliveryService",
            player = player.Name,
            giftId = gift.id,
            reason = insertError,
        })
        finish()
        return
    end

    GiftDelivery.markReceived(data, gift.id)
    self._inventoryService:FinalizeRecordInsert(receipt)
    self._inventoryService:FlushBucket(player, "gifts", "gift_received:" .. gift.id)
    local saved, saveReason =
        self._dataService:SaveAndConfirm(player, "gift_received:" .. gift.id, {
            timeoutSeconds = (self._config.limits or {}).save_confirm_timeout_seconds,
        })
    if not saved then
        self._logger:Warn("Gift stored in-session but awaiting a confirmed profile save", {
            context = "GiftDeliveryService",
            player = player.Name,
            giftId = gift.id,
            reason = saveReason,
        })
        finish()
        return
    end

    processed()
    local _, presentation = GiftLogic.resolvePresentation(gift.rarity_id, self._config.assets)
    fireGameEvent(player, "gift_received", {
        name = "🎁 A gift from " .. gift.sender_name .. " is waiting in Inventory > Gifts!",
        giftId = gift.id,
        senderName = gift.sender_name,
        icon = presentation.inventory_icon,
    })
    self._logger:Info("Durable pet gift delivered as an unopened present", {
        context = "GiftDeliveryService",
        player = player.Name,
        giftId = gift.id,
        senderUserId = gift.sender_user_id,
    })
    finish()
end

function GiftDeliveryService:QueueForUser(userId, gift)
    local id = tonumber(userId) or 0
    if not GiftDelivery.isValidUserId(id, MESSAGE_VALIDATION_OPTIONS) then
        return { ok = false, reason = "invalid_user_id" }
    end
    local ok, messageOrError = pcall(GiftDelivery.message, gift, MESSAGE_VALIDATION_OPTIONS)
    if not ok then
        return { ok = false, reason = "invalid_gift", error = tostring(messageOrError) }
    end
    local profileStore = self._dataService.ProfileStore
    if not profileStore then
        return { ok = false, reason = "profile_store_unavailable" }
    end
    local queued, queueResult = pcall(function()
        return profileStore:MessageAsync("Player_" .. tostring(id), messageOrError)
    end)
    if not queued or queueResult ~= true then
        self._logger:Warn("Failed to queue durable pet gift", {
            context = "GiftDeliveryService",
            userId = id,
            giftId = gift.id,
            error = queued and "message_rejected" or tostring(queueResult),
        })
        return { ok = false, reason = "queue_failed" }
    end
    return { ok = true, queued = true, giftId = gift.id }
end

return GiftDeliveryService
