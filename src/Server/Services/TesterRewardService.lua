--[[
    TesterRewardService

    Config-driven limited testing campaigns. Joining during an active campaign reserves
    eligibility; reaching the campaign's minimum CLAIMED level grants exactly one held egg.
    The egg or its one resulting pet advances through authored variant thresholds only while
    owned by the original award recipient. Trading freezes progress; returning resumes it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)
local TesterRewardCampaign = require(ReplicatedStorage.Shared.Game.TesterRewardCampaign)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local TesterRewardService = {}
TesterRewardService.__index = TesterRewardService

function TesterRewardService.new()
    return setmetatable({ _connections = setmetatable({}, { __mode = "k" }) }, TesterRewardService)
end

function TesterRewardService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._inventoryService = self._modules.InventoryService
    self._progressionService = self._modules.PlayerProgressionService
    self._petProgressionService = self._modules.PetProgressionService
    self._config = self._configLoader:LoadConfig("tester_rewards")
    self._petsConfig = self._configLoader:LoadConfig("pets")
end

function TesterRewardService:Start()
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

function TesterRewardService:_claimedLevel(player)
    if self._progressionService and self._progressionService.GetClaimedLevel then
        return self._progressionService:GetClaimedLevel(player)
    end
    return math.max(1, math.floor(tonumber(player:GetAttribute("ClaimedLevel")) or 1))
end

function TesterRewardService:_rootState(data)
    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    data.GameData.TesterRewards = type(data.GameData.TesterRewards) == "table"
            and data.GameData.TesterRewards
        or {}
    local root = data.GameData.TesterRewards
    root.campaigns = type(root.campaigns) == "table" and root.campaigns or {}
    return root
end

function TesterRewardService:_campaignState(root, awardId)
    local state = root.campaigns[awardId]
    if type(state) ~= "table" then
        state = {}
        root.campaigns[awardId] = state
    end
    return state
end

function TesterRewardService:_findOwnedAwardRecord(player, awardId, preferredEggKey)
    local data = self._dataService:GetData(player)
    local inventory = data and data.Inventory
    local preferred = self._inventoryService:GetItem(player, "eggs", preferredEggKey)
    if type(preferred) == "table" and preferred.award_id == awardId then
        return preferred, preferredEggKey
    end
    for _, bucketName in ipairs({ "eggs", "pets" }) do
        for recordKey, record in
            pairs((inventory and inventory[bucketName] and inventory[bucketName].items) or {})
        do
            if type(record) == "table" and record.award_id == awardId then
                return record, recordKey
            end
        end
    end
    return nil
end

function TesterRewardService:_grantEgg(
    player,
    awardId,
    campaign,
    campaignState,
    claimedLevel,
    testOptions
)
    local inventory = self._inventoryService
    local recordKey = TesterRewardCampaign.recordKey(awardId, player.UserId)
    local existing, existingKey = self:_findOwnedAwardRecord(player, awardId, recordKey)
    if existing then
        -- Repair a missing ledger without ever minting a second copy.
        campaignState.granted_count = math.max(1, tonumber(campaignState.granted_count) or 0)
        campaignState.granted_at = campaignState.granted_at or existing.obtained_at or os.time()
        campaignState.record_key = existingKey
        return false, true
    end

    local eggDef = self._petsConfig.egg_sources[campaign.egg_id]
    testOptions = type(testOptions) == "table" and testOptions or {}
    local tier = tostring(testOptions.tier or ""):lower()
    if tier ~= "basic" and tier ~= "golden" and tier ~= "rainbow" then
        tier = TesterRewardCampaign.tierForLevel(claimedLevel, campaign)
    end
    local record = {
        id = campaign.egg_id,
        quantity = 1,
        obtained_at = os.time(),
        name = (eggDef and eggDef.name) or campaign.egg_id,
        source = "tester_reward:" .. awardId,
        award_id = awardId,
        awarded_to_user_id = player.UserId,
        award_tier = tier,
        award_version = math.max(1, math.floor(tonumber(campaign.version) or 1)),
        variant = tier,
        -- Admin-only deterministic Huge coverage. The flag lives only on the held test egg and is
        -- consumed with it; public campaign grants never write it.
        tester_force_huge = testOptions.forceHuge == true or nil,
    }
    local receipt, err = inventory:InsertRecordSnapshot(player, "eggs", recordKey, record)
    if not receipt then
        self._logger:Warn("Tester reward egg grant failed", {
            player = player.Name,
            awardId = awardId,
            error = tostring(err),
        })
        return false, false
    end

    campaignState.granted_count = (tonumber(campaignState.granted_count) or 0) + 1
    campaignState.granted_at = os.time()
    campaignState.record_key = recordKey
    fireGameEvent(player, "tester_reward_awarded", {
        name = ("🥚 TESTER EGG EARNED! Reach Level %d for Golden and Level %d for Rainbow."):format(
            campaign.golden_level,
            campaign.rainbow_level
        ),
        award = awardId,
        egg = campaign.egg_id,
    })
    return true, true
end

function TesterRewardService:_reconcileOwnedRecords(player, claimedLevel)
    local data = self._dataService:GetData(player)
    local inventory = data and data.Inventory
    local eggChanged = false
    local petKeys = {}

    for _, record in pairs((inventory and inventory.eggs and inventory.eggs.items) or {}) do
        local awardId = type(record) == "table" and record.award_id
        local campaign = awardId and self._config.campaigns[awardId]
        if campaign then
            local changed, tier =
                TesterRewardCampaign.reconcileTier(record, player.UserId, claimedLevel, campaign)
            if changed then
                eggChanged = true
                fireGameEvent(player, "tester_reward_upgraded", {
                    name = ("Your tester egg is now %s!"):format(tier:upper()),
                    award = awardId,
                    tier = tier,
                })
            end
        end
    end

    for recordKey, record in pairs((inventory and inventory.pets and inventory.pets.items) or {}) do
        local awardId = type(record) == "table" and record.award_id
        local campaign = awardId and self._config.campaigns[awardId]
        if campaign then
            local changed, tier =
                TesterRewardCampaign.reconcileTier(record, player.UserId, claimedLevel, campaign)
            if changed then
                local petConfig = self._petsConfig.getPet
                    and self._petsConfig.getPet(record.id, record.variant)
                if self._petProgressionService and petConfig then
                    self._petProgressionService:ApplyProgression(record, petConfig)
                end
                table.insert(petKeys, recordKey)
                fireGameEvent(player, "tester_reward_upgraded", {
                    name = ("Your tester pet is now %s!"):format(tier:upper()),
                    award = awardId,
                    tier = tier,
                })
            end
        end
    end

    if eggChanged then
        self._inventoryService:FlushBucket(player, "eggs", "tester_reward_tier")
    end
    if #petKeys > 0 then
        -- Variant changes must refresh both the card and a possibly deployed world model.
        self._inventoryService:RebuildPetProjections(player)
        self._dataService:RequestSave(player, "tester_reward_pet_tier", { critical = true })
    end
    return eggChanged or #petKeys > 0
end

function TesterRewardService:Reconcile(player, reason)
    if not player or not player.Parent or not self._dataService:IsDataLoaded(player) then
        return { ok = false, reason = "data_not_loaded" }
    end
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "no_data" }
    end

    local now = os.time()
    local claimedLevel = self:_claimedLevel(player)
    local root = self:_rootState(data)
    local stateChanged = false
    local granted = {}

    for awardId, campaign in pairs(self._config.campaigns or {}) do
        local campaignState = self:_campaignState(root, awardId)
        if
            campaignState.eligible_at == nil
            and TesterRewardCampaign.isClaimWindowOpen(campaign, now, RunService:IsStudio())
        then
            campaignState.eligible_at = now
            stateChanged = true
        end
        if TesterRewardCampaign.canGrant(campaign, campaignState, claimedLevel) then
            local didGrant, ledgerOk =
                self:_grantEgg(player, awardId, campaign, campaignState, claimedLevel)
            stateChanged = stateChanged or ledgerOk
            if didGrant then
                table.insert(granted, awardId)
            end
        end
    end

    stateChanged = self:_reconcileOwnedRecords(player, claimedLevel) or stateChanged
    if stateChanged then
        self._dataService:RequestSave(player, "tester_reward_reconcile", { critical = true })
    end
    self:_publishPeopleListBadge(player, data)
    self._logger:Debug("Tester rewards reconciled", {
        player = player.Name,
        reason = reason,
        claimedLevel = claimedLevel,
        granted = #granted,
    })
    return { ok = true, granted = granted, claimedLevel = claimedLevel }
end

function TesterRewardService:_publishPeopleListBadge(player, data)
    local tester = false
    local root = data and data.GameData and data.GameData.TesterRewards
    if type(root) == "table" and type(root.campaigns) == "table" then
        for _, state in pairs(root.campaigns) do
            if type(state) == "table" and (tonumber(state.granted_count) or 0) > 0 then
                tester = true
                break
            end
        end
    end
    if not tester then
        local inventory = data and data.Inventory
        for _, bucketName in ipairs({ "eggs", "pets" }) do
            local items = inventory and inventory[bucketName] and inventory[bucketName].items
            if type(items) == "table" then
                for _, record in pairs(items) do
                    if type(record) == "table" and type(record.award_id) == "string" then
                        tester = true
                        break
                    end
                end
            end
            if tester then
                break
            end
        end
    end
    player:SetAttribute("IsBetaTester", tester)
end

-- Resolve one held award egg immediately before hatching. The record is reconciled first, so an
-- original recipient who reached a threshold while the egg was offline always gets the earned
-- guaranteed variant. A non-recipient hatcher receives the frozen stored tier.
function TesterRewardService:ResolveHatch(player, record)
    if type(record) ~= "table" or type(record.award_id) ~= "string" then
        return nil
    end
    local campaign = self._config.campaigns[record.award_id]
    if not campaign then
        return { ok = false, reason = "award_campaign_missing" }
    end
    TesterRewardCampaign.reconcileTier(record, player.UserId, self:_claimedLevel(player), campaign)
    local huge = record.tester_force_huge == true
        or math.random() < (tonumber(campaign.huge_chance) or 0)
    return {
        ok = true,
        pet = huge and (campaign.huge_pet_id or campaign.pet_id) or campaign.pet_id,
        variant = tostring(record.award_tier or "basic"),
        huge = huge,
        award_id = record.award_id,
        awarded_to_user_id = record.awarded_to_user_id,
        award_tier = record.award_tier,
        award_version = record.award_version,
    }
end

-- Authenticated AdminToolsService entry point for pre-launch coverage while the public claim window
-- remains closed. Replaces the target's copy of this campaign so Basic/Golden/Rainbow/Huge can be
-- replayed repeatedly without consuming a launch entitlement or waiting for real levels.
function TesterRewardService:AdminGrantTestEgg(player, awardId, tier, forceHuge)
    if not player or not player.Parent or not self._dataService:IsDataLoaded(player) then
        return { ok = false, reason = "data_not_loaded" }
    end
    local campaign = self._config.campaigns[tostring(awardId or "")]
    if not campaign then
        return { ok = false, reason = "campaign_missing" }
    end
    tier = tostring(tier or "basic"):lower()
    if tier ~= "basic" and tier ~= "golden" and tier ~= "rainbow" then
        return { ok = false, reason = "invalid_tier" }
    end

    local data = self._dataService:GetData(player)
    local inventory = data and data.Inventory
    if not inventory then
        return { ok = false, reason = "inventory_missing" }
    end

    -- Replace any prior test copy, egg or hatched pet. This is deliberately scoped to one
    -- campaign id and is reachable only through the authenticated admin action.
    for _, bucketName in ipairs({ "eggs", "pets" }) do
        local bucket = inventory[bucketName]
        if type(bucket) == "table" and type(bucket.items) == "table" then
            for recordKey, record in pairs(bucket.items) do
                if type(record) == "table" and record.award_id == awardId then
                    bucket.items[recordKey] = nil
                end
            end
            local used = 0
            for _ in pairs(bucket.items) do
                used += 1
            end
            bucket.used_slots = used
        end
    end
    if type(data.Equipped) == "table" then
        -- Test replacement is a full scenario boundary; do not leave an equipped ref to the
        -- deleted award pet.
        data.Equipped.pets = {}
    end

    local root = self:_rootState(data)
    root.campaigns[awardId] = nil
    local campaignState = self:_campaignState(root, awardId)
    campaignState.eligible_at = os.time()
    local didGrant, ledgerOk = self:_grantEgg(player, awardId, campaign, campaignState, 1, {
        tier = tier,
        forceHuge = forceHuge == true,
    })
    if not ledgerOk then
        return { ok = false, reason = "grant_failed" }
    end

    self._inventoryService:FlushBucket(player, "eggs", "admin_tester_reward")
    self._inventoryService:RebuildPetProjections(player)
    self._dataService:RequestSave(player, "admin_tester_reward", {
        critical = true,
        debounceSeconds = 0,
    })
    return {
        ok = didGrant == true,
        awardId = awardId,
        tier = tier,
        huge = forceHuge == true,
    }
end

-- TradeService calls this before escrow. It captures any level threshold reached by the original
-- owner; after the record moves, the stored tier freezes until it returns.
function TesterRewardService:ReconcileRecordBeforeTrade(player, record)
    if type(record) ~= "table" or type(record.award_id) ~= "string" then
        return false
    end
    local campaign = self._config.campaigns[record.award_id]
    if not campaign then
        return false
    end
    return TesterRewardCampaign.reconcileTier(
        record,
        player.UserId,
        self:_claimedLevel(player),
        campaign
    )
end

return TesterRewardService
