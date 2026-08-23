-- One-way, one-pet gift flow. The receiver controls a persistent rarity
-- threshold but never receives an interactive approval prompt.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GiftDelivery = require(ReplicatedStorage.Shared.Game.GiftDelivery)
local GiftLogic = require(ReplicatedStorage.Shared.Game.GiftLogic)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)
local TradeLogic = require(ReplicatedStorage.Shared.Game.TradeLogic)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local GiftService = {}
GiftService.__index = GiftService

local PETS_BUCKET = "pets"
local GIFTS_BUCKET = "gifts"

function GiftService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._inventoryService = self._modules.InventoryService
    self._petTransferService = self._modules.PetTransferService
    self._rosterService = self._modules.RosterService
    self._settingsService = self._modules.SettingsService
    self._deliveryService = self._modules.GiftDeliveryService
    self._statsService = self._modules.StatsService
    self._testerRewardService = self._modules.TesterRewardService
    self._config = self._configLoader:LoadConfig("gifts") or {}
    self._petsConfig = self._configLoader:LoadConfig("pets") or {}
    self._tradeConfig = self._configLoader:LoadConfig("trade") or {}
    self._lastSendAt = setmetatable({}, { __mode = "k" })
    self._opening = setmetatable({}, { __mode = "k" })
    self._outboxInflight = setmetatable({}, { __mode = "k" })
end

function GiftService:Start()
    local function recover(player)
        task.spawn(function()
            if Readiness.awaitAttribute(player, "DataLoaded", true, 20) and player.Parent then
                self:_recoverOutbox(player)
            end
        end)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        recover(player)
    end
    Players.PlayerAdded:Connect(recover)
    Players.PlayerRemoving:Connect(function(player)
        self._lastSendAt[player] = nil
        self._opening[player] = nil
        self._outboxInflight[player] = nil
    end)
end

function GiftService:_defaultPreference()
    return GiftLogic.sanitizePreference(self._config.default_acceptance)
end

function GiftService:_preferenceOf(player)
    if self._settingsService and self._settingsService.GetGiftAcceptance then
        return self._settingsService:GetGiftAcceptance(player)
    end
    return GiftLogic.sanitizePreference(
        player and player:GetAttribute("GiftAcceptance"),
        self:_defaultPreference()
    )
end

function GiftService:GetPreference(player)
    local mode = self:_preferenceOf(player)
    return {
        ok = true,
        mode = mode,
        label = GiftLogic.preferenceLabel(mode, self:_defaultPreference()),
    }
end

function GiftService:SetPreference(player, value)
    if not (self._settingsService and self._settingsService.SetGiftAcceptance) then
        return { ok = false, reason = "settings_service_unavailable" }
    end
    local mode = self._settingsService:SetGiftAcceptance(player, value)
    if not mode then
        return { ok = false, reason = "data_unavailable" }
    end
    return {
        ok = true,
        mode = mode,
        label = GiftLogic.preferenceLabel(mode, self:_defaultPreference()),
    }
end

function GiftService:ListPlayers(player)
    local out = {}
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and other:GetAttribute("DataLoaded") == true then
            local mode = self:_preferenceOf(other)
            table.insert(out, {
                userId = other.UserId,
                name = other.DisplayName or other.Name,
                username = other.Name,
                giftPreference = mode,
                giftPreferenceLabel = GiftLogic.preferenceLabel(mode, self:_defaultPreference()),
                giftsEnabled = mode ~= "off",
            })
        end
    end
    table.sort(out, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)
    return { ok = true, players = out }
end

function GiftService:_petRecord(player, selector)
    local inventory = self._inventoryService
    local target = inventory:ResolvePetTarget(player, selector)
    local bucket = inventory:GetInventory(player, PETS_BUCKET)
    local items = bucket and bucket.items
    if not target or type(items) ~= "table" then
        return nil, "pet_not_found"
    end

    local recordKey = target.kind == "special" and target.uid or target.stackKey
    local record = items[recordKey]
    if
        type(record) ~= "table"
        or (target.kind == "stack" and (tonumber(record.quantity) or 0) <= 0)
    then
        return nil, "pet_not_found"
    end
    if record.locked == true then
        return nil, "item_locked"
    end
    local tradeVerdict =
        TradeLogic.canAddItem("pets", { id = record.id, locked = record.locked }, self._tradeConfig)
    if not tradeVerdict.ok then
        return nil, tradeVerdict.reason
    end
    return {
        target = target,
        recordKey = recordKey,
        record = record,
    }
end

function GiftService:ListMyPets(player, targetUserId)
    local targetPlayer = Players:GetPlayerByUserId(math.floor(tonumber(targetUserId) or 0))
    if
        not targetPlayer
        or targetPlayer == player
        or targetPlayer:GetAttribute("DataLoaded") ~= true
    then
        return { ok = false, reason = "player_not_found" }
    end
    local preference = self:_preferenceOf(targetPlayer)
    local bucket = self._inventoryService:GetInventory(player, PETS_BUCKET)
    local pets = {}
    for recordKey, record in pairs((bucket and bucket.items) or {}) do
        local rarityId = GiftLogic.resolveRarity(record, self._petsConfig)
        local accepted = GiftLogic.accepts(
            preference,
            rarityId,
            self._petsConfig.rarity_order,
            self:_defaultPreference()
        )
        local tradeable = TradeLogic.canAddItem(
            "pets",
            { id = record.id, locked = record.locked },
            self._tradeConfig
        )
        if accepted and tradeable.ok then
            table.insert(pets, {
                uid = recordKey,
                id = record.id,
                variant = record.variant or "basic",
                element = record.element,
                huge = record.huge,
                locked = record.locked,
                quantity = tonumber(record.quantity) or 1,
                serial = record.serial,
                level = record.level,
                rarity_id = rarityId,
                record = GiftDelivery.copy(record),
            })
        end
    end
    return {
        ok = true,
        pets = pets,
        targetUserId = targetPlayer.UserId,
        targetName = targetPlayer.DisplayName or targetPlayer.Name,
        preference = preference,
        preferenceLabel = GiftLogic.preferenceLabel(preference, self:_defaultPreference()),
    }
end

function GiftService:_detachPet(player, recordKey)
    if self._rosterService and self._rosterService.RemovePetReference then
        pcall(function()
            self._rosterService:RemovePetReference(player, recordKey)
        end)
    end
end

function GiftService:_finalizeQueued(player, giftId)
    local data = self._dataService:GetData(player)
    if not data then
        return false, "data_unavailable"
    end
    local root = GiftDelivery.root(data)
    local entry = root.outbox[giftId]
    if not entry then
        return GiftDelivery.isSent(data, giftId), "outbox_missing"
    end

    if not GiftDelivery.isSent(data, giftId) then
        local counterId, counterPoints =
            GiftLogic.leaderboardScore(entry.gift, entry.counter_points)
        if counterId and self._statsService then
            local ok, incremented = pcall(function()
                return self._statsService:Increment(player, counterId, counterPoints)
            end)
            if not ok or not incremented then
                return false, "counter_failed"
            end
        end
        GiftDelivery.markSent(data, giftId)
    end
    root.outbox[giftId] = nil
    return self._dataService:SaveAndConfirm(player, "gift_finalize:" .. giftId, {
        timeoutSeconds = (self._config.limits or {}).save_confirm_timeout_seconds,
    })
end

function GiftService:_queueOutboxEntry(player, giftId)
    local data = self._dataService:GetData(player)
    local root = data and GiftDelivery.root(data)
    local entry = root and root.outbox[giftId]
    if not entry or type(entry.gift) ~= "table" then
        return { ok = false, reason = "outbox_missing" }
    end

    local byPlayer = self._outboxInflight[player] or {}
    self._outboxInflight[player] = byPlayer
    if byPlayer[giftId] then
        return { ok = true, pending = true, giftId = giftId }
    end
    byPlayer[giftId] = true
    local queued = self._deliveryService:QueueForUser(entry.gift.receiver_user_id, entry.gift)
    if not queued.ok then
        byPlayer[giftId] = nil
        return { ok = false, reason = queued.reason or "queue_failed", giftId = giftId }
    end

    local finalized, finalizeReason = self:_finalizeQueued(player, giftId)
    byPlayer[giftId] = nil
    if not finalized then
        self._logger:Warn("Gift message queued; sender finalization will reconcile later", {
            context = "GiftService",
            player = player.Name,
            giftId = giftId,
            reason = finalizeReason,
        })
        task.delay(3, function()
            if player.Parent then
                self:_finalizeQueued(player, giftId)
            end
        end)
    end
    return { ok = true, queued = true, giftId = giftId, finalizationPending = not finalized }
end

function GiftService:_recoverOutbox(player)
    local data = self._dataService:GetData(player)
    if not data then
        return
    end
    local root = GiftDelivery.root(data)
    local giftIds = {}
    for giftId in pairs(root.outbox) do
        table.insert(giftIds, giftId)
    end
    table.sort(giftIds)
    for _, giftId in ipairs(giftIds) do
        if player.Parent == nil then
            return
        end
        if GiftDelivery.isSent(data, giftId) then
            root.outbox[giftId] = nil
            self._dataService:RequestSave(player, "gift_clear_recovered:" .. giftId, {
                critical = true,
            })
        else
            local result = self:_queueOutboxEntry(player, giftId)
            if not result.ok then
                self._logger:Warn("Persisted pet gift is waiting for a later queue retry", {
                    context = "GiftService",
                    player = player.Name,
                    giftId = giftId,
                    reason = result.reason,
                })
            end
        end
    end
end

function GiftService:_scheduleOutboxRetry(player, giftId, needsSaveConfirmation)
    task.delay(3, function()
        if player.Parent == nil then
            return
        end
        if needsSaveConfirmation then
            local saved = self._dataService:SaveAndConfirm(
                player,
                "gift_outbox_retry_before_message:" .. giftId,
                { timeoutSeconds = (self._config.limits or {}).save_confirm_timeout_seconds }
            )
            if not saved then
                self:_scheduleOutboxRetry(player, giftId, true)
                return
            end
        end
        local queued = self:_queueOutboxEntry(player, giftId)
        if not queued.ok then
            self:_scheduleOutboxRetry(player, giftId, false)
        end
    end)
end

function GiftService:Send(player, targetUserId, selector)
    local now = os.clock()
    local cooldown = tonumber((self._config.limits or {}).send_cooldown_seconds) or 1
    if now - (self._lastSendAt[player] or -math.huge) < cooldown then
        return { ok = false, reason = "too_fast" }
    end
    self._lastSendAt[player] = now

    local target = Players:GetPlayerByUserId(math.floor(tonumber(targetUserId) or 0))
    if not target then
        return { ok = false, reason = "player_not_found" }
    end
    if target == player then
        return { ok = false, reason = "self_target" }
    end
    if target:GetAttribute("DataLoaded") ~= true then
        return { ok = false, reason = "target_not_ready" }
    end

    -- Final-send revalidation: picker snapshots are display only.
    local pet, petReason = self:_petRecord(player, selector)
    if not pet then
        return { ok = false, reason = petReason }
    end
    if self._testerRewardService and self._testerRewardService.ReconcileRecordBeforeTrade then
        self._testerRewardService:ReconcileRecordBeforeTrade(player, pet.record)
    end
    local rarityId = GiftLogic.resolveRarity(pet.record, self._petsConfig)
    local preference = self:_preferenceOf(target)
    local accepted, acceptanceReason = GiftLogic.accepts(
        preference,
        rarityId,
        self._petsConfig.rarity_order,
        self:_defaultPreference()
    )
    if not accepted then
        return { ok = false, reason = acceptanceReason, preference = preference }
    end

    local record = GiftDelivery.copy(pet.record)
    record.quantity = pet.target.kind == "stack" and 1 or record.quantity
    record.equipped_slot = nil
    record.equipped_slots = nil
    local giftId = HttpService:GenerateGUID(false)
    local gift = {
        id = giftId,
        sender_user_id = player.UserId,
        sender_name = player.DisplayName or player.Name,
        receiver_user_id = target.UserId,
        sent_at = os.time(),
        rarity_id = rarityId,
        record_key = pet.recordKey,
        pet_record = record,
    }

    self:_detachPet(player, pet.recordKey)
    local removed = self._inventoryService:RemoveItem(
        player,
        PETS_BUCKET,
        pet.recordKey,
        1,
        { deferFlush = true }
    )
    if not removed then
        return { ok = false, reason = "pet_not_found" }
    end

    local data = self._dataService:GetData(player)
    local root = GiftDelivery.root(data)
    root.outbox[giftId] = {
        gift = GiftDelivery.copy(gift),
        counter_id = GiftLogic.leaderboardCounter(rarityId),
        counter_points = GiftLogic.leaderboardPoints(record),
        state = "escrowed",
    }
    self._inventoryService:FlushBucket(player, PETS_BUCKET, "gift_escrow:" .. giftId)

    -- This ordering is the ownership boundary: never MessageAsync first.
    local saved, saveReason = self._dataService:SaveAndConfirm(
        player,
        "gift_outbox_before_message:" .. giftId,
        { timeoutSeconds = (self._config.limits or {}).save_confirm_timeout_seconds }
    )
    if not saved then
        self:_scheduleOutboxRetry(player, giftId, true)
        return {
            ok = true,
            pending = true,
            giftId = giftId,
            reason = saveReason,
        }
    end

    local queued = self:_queueOutboxEntry(player, giftId)
    if not queued.ok then
        self:_scheduleOutboxRetry(player, giftId, false)
        return { ok = true, pending = true, giftId = giftId, reason = queued.reason }
    end

    fireGameEvent(player, "gift_sent", {
        name = "🎁 Gift sent to " .. (target.DisplayName or target.Name) .. "!",
        giftId = giftId,
    })
    return {
        ok = true,
        queued = true,
        giftId = giftId,
        targetName = target.DisplayName or target.Name,
    }
end

function GiftService:GetState(player)
    local bucket = self._inventoryService:GetInventory(player, GIFTS_BUCKET)
    local gifts = {}
    for giftId, record in pairs((bucket and bucket.items) or {}) do
        table.insert(gifts, {
            giftId = giftId,
            senderName = record.sender_name,
            senderUserId = record.sender_user_id,
            rarityId = record.rarity_id,
            petId = record.pet_id,
            petVariant = record.pet_variant,
            petHuge = record.pet_huge,
            sentAt = record.sent_at,
        })
    end
    table.sort(gifts, function(a, b)
        return (tonumber(a.sentAt) or 0) > (tonumber(b.sentAt) or 0)
    end)
    return { ok = true, gifts = gifts, count = #gifts }
end

function GiftService:OpenGift(player, giftId)
    local byPlayer = self._opening[player] or {}
    self._opening[player] = byPlayer
    if byPlayer[giftId] then
        return { ok = false, reason = "already_opening" }
    end
    byPlayer[giftId] = true
    local function finish(result)
        byPlayer[giftId] = nil
        return result
    end

    local bucket = self._inventoryService:GetInventory(player, GIFTS_BUCKET)
    local wrapped = bucket and bucket.items and bucket.items[giftId]
    if type(wrapped) ~= "table" or type(wrapped.pet_record) ~= "table" then
        return finish({ ok = false, reason = "gift_not_found" })
    end

    local receipt, grantReason = self._petTransferService:GrantRecord(
        player,
        wrapped.record_key,
        wrapped.pet_record,
        { deferFlush = true }
    )
    if not receipt then
        return finish({ ok = false, reason = "pet_storage_full", detail = grantReason })
    end

    local removed =
        self._inventoryService:RemoveItem(player, GIFTS_BUCKET, giftId, 1, { deferFlush = true })
    if not removed then
        self._petTransferService:RevokeGrant(receipt, { deferFlush = true })
        return finish({ ok = false, reason = "gift_remove_failed" })
    end

    self._inventoryService:FinalizeRecordInsert(receipt)
    self._inventoryService:FlushBucket(player, PETS_BUCKET, "gift_open_pet:" .. giftId)
    self._inventoryService:FlushBucket(player, GIFTS_BUCKET, "gift_open_present:" .. giftId)
    local saved, saveReason = self._dataService:SaveAndConfirm(player, "gift_open:" .. giftId, {
        timeoutSeconds = (self._config.limits or {}).save_confirm_timeout_seconds,
    })
    local record = wrapped.pet_record
    return finish({
        ok = true,
        giftId = giftId,
        senderName = wrapped.sender_name,
        persistencePending = not saved,
        persistenceReason = not saved and saveReason or nil,
        pet = {
            petType = record.id,
            variant = record.variant or "basic",
            rarityId = wrapped.rarity_id,
            huge = record.huge == true,
            record = GiftDelivery.copy(record),
        },
        presentModelAsset = (self._config.assets or {}).present_model_asset,
        presentIcon = (self._config.assets or {}).inventory_icon,
    })
end

return GiftService
