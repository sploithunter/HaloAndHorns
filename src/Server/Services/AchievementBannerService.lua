--[[
    AchievementBannerService — permanent player-bay awards and replicated gallery mounting.

    Gameplay services report authoritative facts. This service evaluates the config catalog,
    persists idempotent awards, and presents queued cloth only at an explicit checkpoint call.
    The final models replicate to everyone; the camera packet is sent only to the owning player.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementBannerAwards = require(ReplicatedStorage.Shared.Game.AchievementBannerAwards)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local AssetFetch = require(ReplicatedStorage.Shared.Utils.AssetFetch)

local AchievementBannerService = {}
AchievementBannerService.__index = AchievementBannerService

local function configuredNumber(value, path)
    local parsed = tonumber(value)
    assert(parsed ~= nil, "achievement_banners is missing numeric " .. path)
    return parsed
end

local function configuredString(value, path)
    assert(type(value) == "string" and value ~= "", "achievement_banners is missing " .. path)
    return value
end

local function positiveWhole(value, fallback)
    local number = tonumber(value)
    if number == nil then
        number = fallback or 0
    end
    return math.max(0, math.floor(number))
end

local function countKeys(values)
    local count = 0
    for _ in pairs(type(values) == "table" and values or {}) do
        count += 1
    end
    return count
end

local function sanitizeModel(model)
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            descendant.Massless = true
        elseif
            descendant:IsA("Script")
            or descendant:IsA("LocalScript")
            or descendant:IsA("ModuleScript")
        then
            descendant:Destroy()
        end
    end
end

local function modelWithCloth(root, clothName)
    if root:IsA("Model") and root:FindFirstChild(clothName, true) then
        return root
    end
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("Model") and descendant:FindFirstChild(clothName, true) then
            return descendant
        end
    end
    return nil
end

function AchievementBannerService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._config = (self._configLoader and self._configLoader:LoadConfig("achievement_banners"))
        or require(ReplicatedStorage.Configs:WaitForChild("achievement_banners"))
    self._templates = {}
    self._config = table.clone(self._config)
    self._config.awards = table.clone(self._config.awards)
    self._templateFailures = {}
end

function AchievementBannerService:_log(level, message, data)
    if self._logger and self._logger[level] then
        self._logger[level](self._logger, message, data)
    end
end

function AchievementBannerService:_state(player)
    local data = self._dataService and self._dataService:GetData(player)
    if not data then
        return nil
    end
    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    local state = AchievementBannerAwards.normalize(data.GameData.AchievementBanners)
    data.GameData.AchievementBanners = state
    local progress = data.GameData.MergeDefense or {}
    AchievementBannerAwards.expandWaveCatalog(self._config, progress.highest_wave, state.owned)
    player:SetAttribute("AchievementBannerPendingCount", countKeys(state.pending))
    player:SetAttribute("AchievementBannerOwnedCount", countKeys(state.owned))
    return state
end

function AchievementBannerService:_requestSave(player, reason)
    if self._dataService and self._dataService.RequestSave then
        self._dataService:RequestSave(player, reason, {
            critical = true,
        })
    end
end

function AchievementBannerService:RecordFacts(player, facts, source)
    local state = self:_state(player)
    if not state then
        return {}
    end
    facts = type(facts) == "table" and facts or {}
    if facts.merge_wave ~= nil then
        facts = table.clone(facts)
        facts.merge_wave = math.max(
            tonumber(facts.merge_wave) or 0,
            tonumber(player:GetAttribute("MergeHighestWave")) or 0
        )
        AchievementBannerAwards.expandWaveCatalog(self._config, facts.merge_wave, state.owned)
    end
    local granted = {}
    for _, awardId in ipairs(AchievementBannerAwards.eligible(self._config.awards, facts)) do
        local definition = self._config.awards[awardId]
        local trigger = type(definition) == "table" and definition.trigger or {}
        local didGrant = AchievementBannerAwards.grant(state, awardId, {
            source = tostring(source or "progression"),
            value = facts[trigger.fact],
        })
        if didGrant then
            granted[#granted + 1] = awardId
        end
    end
    player:SetAttribute("AchievementBannerPendingCount", countKeys(state.pending))
    player:SetAttribute("AchievementBannerOwnedCount", countKeys(state.owned))
    if #granted > 0 then
        self:_requestSave(player, "achievement_banner_earned")
        self:_log("Info", "Achievement banners earned and queued", {
            player = player.Name,
            awards = table.concat(granted, ","),
            source = source,
        })
    end
    return granted
end

function AchievementBannerService:_referencePart(bay)
    local display = self._config.display or {}
    local name = configuredString(display.reference_name, "display.reference_name")
    local named = {}
    local claimPads = {}
    for _, descendant in ipairs(bay and bay:GetDescendants() or {}) do
        if descendant:IsA("BasePart") then
            if descendant.Name == name then
                named[#named + 1] = descendant
            elseif descendant:GetAttribute("MergeEggBayClaimPad") == true then
                claimPads[#claimPads + 1] = descendant
            end
        end
    end
    local candidates = #named > 0 and named or claimPads
    table.sort(candidates, function(left, right)
        if left.Position.Y ~= right.Position.Y then
            return left.Position.Y > right.Position.Y
        end
        return left:GetFullName() < right:GetFullName()
    end)
    return candidates[1]
end

function AchievementBannerService:_template(variantId)
    variantId = tostring(variantId or "")
    if self._templates[variantId] then
        return self._templates[variantId]
    end
    if self._templateFailures[variantId] then
        return nil
    end
    local definition = ((self._config.model or {}).variants or {})[variantId]
    local assetId = type(definition) == "table" and tonumber(definition.asset_id) or nil
    if not assetId then
        self._templateFailures[variantId] = true
        self:_log("Warn", "Achievement banner variant has no model asset", {
            variant = variantId,
        })
        return nil
    end
    local loaded, container = pcall(AssetFetch.load, assetId)
    if not loaded or not container then
        self:_log("Warn", "Achievement banner model load failed", {
            variant = variantId,
            assetId = assetId,
            reason = tostring(container),
        })
        return nil
    end
    local clothName = configuredString(self._config.model.cloth_name, "model.cloth_name")
    local model = modelWithCloth(container, clothName)
    if not model then
        container:Destroy()
        self._templateFailures[variantId] = true
        self:_log("Warn", "Achievement banner model has no cloth", {
            variant = variantId,
            assetId = assetId,
        })
        return nil
    end
    if model ~= container then
        model.Parent = nil
        container:Destroy()
    end
    sanitizeModel(model)
    local bounds = model:GetBoundingBox()
    model.WorldPivot = CFrame.new(bounds.Position)
    model.Name = "AchievementBannerTemplate_" .. variantId
    self._templates[variantId] = model
    return model
end

function AchievementBannerService:_mountOne(folder, reference, slot, player, awardId)
    local award = self._config.awards[awardId]
    if type(award) ~= "table" then
        return nil
    end
    local template = self:_template(award.variant)
    if not template then
        return nil
    end
    local model = template:Clone()
    model.Name = "AchievementBanner_" .. awardId
    local scale =
        math.max(0.1, configuredNumber(self._config.display.model_scale, "display.model_scale"))
    pcall(function()
        model:ScaleTo(model:GetScale() * scale)
    end)

    local localPosition = Vector3.new(
        configuredNumber(slot.x, "display.slots[].x"),
        configuredNumber(slot.y, "display.slots[].y"),
        configuredNumber(slot.z, "display.slots[].z")
    )
    local position = reference.CFrame:PointToWorldSpace(localPosition)
    local slotAnchor = tostring(self._config.display.slot_anchor or "center")
    if slotAnchor == "top_center" then
        local _, boundsSize = model:GetBoundingBox()
        position -= reference.CFrame.UpVector * (boundsSize.Y * 0.5)
    else
        assert(slotAnchor == "center", "achievement_banners has invalid display.slot_anchor")
    end
    local camera = self._config.display.camera
    local cameraPosition = position
        - reference.CFrame.LookVector * math.max(
            1,
            configuredNumber(camera.distance, "display.camera.distance")
        )
        + reference.CFrame.UpVector * configuredNumber(camera.height, "display.camera.height")
    local target = position
        + reference.CFrame.UpVector
            * configuredNumber(camera.target_height, "display.camera.target_height")
    local mount = CFrame.lookAt(position, cameraPosition, reference.CFrame.UpVector)
        * CFrame.Angles(
            0,
            math.rad(
                configuredNumber(
                    self._config.display.model_yaw_degrees,
                    "display.model_yaw_degrees"
                )
            ),
            0
        )
    model:PivotTo(mount)
    model:SetAttribute("AchievementAwardId", awardId)
    model:SetAttribute("AchievementOwnerUserId", player.UserId)
    model:SetAttribute(
        "AchievementVariant",
        configuredString(award.variant, "awards." .. awardId .. ".variant")
    )
    model:SetAttribute(
        "AchievementStyle",
        configuredString(award.style, "awards." .. awardId .. ".style")
    )
    model:SetAttribute(
        "AchievementTitle",
        configuredString(award.title, "awards." .. awardId .. ".title")
    )
    model:SetAttribute(
        "AchievementValue",
        configuredString(award.value, "awards." .. awardId .. ".value")
    )
    model:SetAttribute(
        "AchievementFooter",
        configuredString(award.footer, "awards." .. awardId .. ".footer")
    )
    model:SetAttribute("AchievementFlutter", true)

    local cameraValue = Instance.new("CFrameValue")
    cameraValue.Name = configuredString(camera.value_name, "display.camera.value_name")
    cameraValue.Value = CFrame.lookAt(cameraPosition, target, reference.CFrame.UpVector)
    cameraValue.Parent = model
    model.Parent = folder
    CollectionService:AddTag(model, self._config.tag)
    return model
end

function AchievementBannerService:ClearBay(bay)
    local name = configuredString(self._config.display.folder_name, "display.folder_name")
    local existing = bay and bay:FindFirstChild(name)
    if existing then
        existing:Destroy()
    end
end

function AchievementBannerService:MountBay(player, bay)
    local state = self:_state(player)
    local reference = self:_referencePart(bay)
    if not (state and reference) then
        return nil, "achievement_banner_reference_missing"
    end
    local display = self._config.display or {}
    local slots = type(display.slots) == "table" and display.slots or {}
    local displayed, displayChanged = AchievementBannerAwards.reconcileDisplayed(
        state,
        self._config.awards,
        positiveWhole(configuredNumber(display.maximum, "display.maximum"))
    )
    if displayChanged then
        self:_requestSave(player, "achievement_banner_display_reconciled")
    end
    if #displayed == 0 or #slots == 0 then
        self:ClearBay(bay)
        return {}, nil
    end

    local folder = Instance.new("Folder")
    folder.Name = configuredString(display.folder_name, "display.folder_name")
    folder:SetAttribute("AchievementOwnerUserId", player.UserId)
    local mounted = {}
    local mountedCount = 0
    for index, awardId in ipairs(displayed) do
        local slot = slots[index]
        if slot then
            local host = self:_mountOne(folder, reference, slot, player, awardId)
            if host then
                mounted[awardId] = host
                mountedCount += 1
            end
        end
    end
    if mountedCount == 0 then
        folder:Destroy()
        return nil, "achievement_banner_template_missing"
    end
    self:ClearBay(bay)
    folder.Parent = bay
    return mounted, nil
end

function AchievementBannerService:PresentCheckpoint(player, bay, checkpointWave, facts)
    if (self._config.ceremony or {}).enabled == false then
        return { presented = false, minimumCheckpointSeconds = 0 }
    end
    self:RecordFacts(player, facts, "merge_checkpoint")
    local state = self:_state(player)
    if not state then
        return { presented = false, minimumCheckpointSeconds = 0 }
    end
    local pending = AchievementBannerAwards.pendingIds(state, self._config.awards)
    if #pending == 0 then
        return { presented = false, minimumCheckpointSeconds = 0 }
    end
    if not self:_referencePart(bay) then
        return { presented = false, minimumCheckpointSeconds = 0 }
    end

    local primaryId = pending[#pending]
    local primaryAward = self._config.awards[primaryId]
    if not primaryAward or not self:_template(primaryAward.variant) then
        return { presented = false, minimumCheckpointSeconds = 0 }
    end
    local priorDisplayed = table.clone(state.displayed)
    local priorPending = table.clone(state.pending)
    local priorPresentedAt = {}
    for _, awardId in ipairs(pending) do
        local owned = state.owned[awardId]
        priorPresentedAt[awardId] = owned and owned.presented_at or false
    end
    AchievementBannerAwards.present(
        state,
        pending,
        positiveWhole(configuredNumber(self._config.display.maximum, "display.maximum")),
        os.time(),
        self._config.awards
    )
    local mounted = self:MountBay(player, bay)
    local host = mounted and mounted[primaryId]
    if not host then
        state.displayed = priorDisplayed
        state.pending = priorPending
        for _, awardId in ipairs(pending) do
            local owned = state.owned[awardId]
            if owned then
                owned.presented_at = priorPresentedAt[awardId] or nil
            end
        end
        self:MountBay(player, bay)
        return { presented = false, minimumCheckpointSeconds = 0 }
    end
    host:SetAttribute("AchievementCheckpointWave", positiveWhole(checkpointWave))
    player:SetAttribute("AchievementBannerPendingCount", countKeys(state.pending))
    self:_requestSave(player, "achievement_banner_presented")
    Signals.AchievementBannerCeremony:FireClient(player, {
        host = host,
        awardId = primaryId,
        presentedCount = #pending,
        checkpointWave = positiveWhole(checkpointWave),
    })
    self:_log("Info", "Achievement banners mounted at checkpoint", {
        player = player.Name,
        checkpointWave = checkpointWave,
        primary = primaryId,
        count = #pending,
    })
    return {
        presented = true,
        minimumCheckpointSeconds = math.max(
            0,
            configuredNumber(
                self._config.ceremony.checkpoint_minimum_seconds,
                "ceremony.checkpoint_minimum_seconds"
            )
        ),
    }
end

return AchievementBannerService
