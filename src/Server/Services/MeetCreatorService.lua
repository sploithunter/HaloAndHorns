--[[
    MeetCreatorService — the Meet-The-Creator mechanic (configs/creators.lua).

    The first time a player shares a server with a registered creator — and only that
    once, EVER — they receive the creator's egg in their eggs inventory bucket. The
    egg hatches the creator's SPECIES (never the apex creator class — that is granted
    only to the creator themselves) at the configured variant odds.

    Both directions are covered: a player joining a server where a creator is
    present, and a creator joining a server full of players. Met-state persists in
    data.MetCreators[creatorUserId] = os.time().

    HatchEggItem (bus: egg_item.hatch) consumes one egg item and grants the pet.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local ServerLuck = require(ReplicatedStorage.Shared.Game.ServerLuck)

local MeetCreatorService = {}
MeetCreatorService.__index = MeetCreatorService

function MeetCreatorService.new()
    return setmetatable({}, MeetCreatorService)
end

function MeetCreatorService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._inventoryService = self._modules.InventoryService
    self._petGrantService = self._modules.PetGrantService
    self._testerRewardService = self._modules.TesterRewardService
    self._trialEggRewardService = self._modules.TrialEggRewardService
    self._statsService = self._modules.StatsService
    self._chatAnnouncementService = self._modules.ChatAnnouncementService
    self._eggHatchLocks = setmetatable({}, { __mode = "k" })
    self._serverLuckState = { creator = false, founder = false }
    self._serverLuckConnections = setmetatable({}, { __mode = "k" })
    local ok, cfg = pcall(function()
        return self._configLoader:LoadConfig("creators")
    end)
    self._config = (ok and cfg) or { creators = {}, meet = { enabled = false } }
    local monetizationOk, monetization = pcall(function()
        return self._configLoader:LoadConfig("monetization")
    end)
    self._founderLegacyConfig = monetizationOk
            and monetization
            and monetization.founders_choice
            and monetization.founders_choice.legacy
        or {}
end

function MeetCreatorService:_reconcileCreatorCounter(player, data)
    local stats = self._statsService
    if not (stats and type(data) == "table") then
        return
    end
    local count = 0
    for _, metAt in pairs(data.MetCreators or {}) do
        if metAt then
            count += 1
        end
    end
    if count > stats:Get(player, "creators_met") then
        stats:Set(player, "creators_met", count)
    end
end

function MeetCreatorService:_creatorFor(userId)
    return (self._config.creators or {})[tostring(userId)]
end

-- Award `player` the meet-egg for `creatorUserId` if this is their first meeting.
function MeetCreatorService:_tryMeet(player, creatorUserId, creatorDef)
    -- creators DO meet themselves (being in a server with the creator includes
    -- being the creator) — Jason's call, and it makes the mechanic solo-testable
    local dataService = self._dataService
    if not (dataService and dataService:IsDataLoaded(player)) then
        return
    end
    local data = dataService:GetData(player)
    data.MetCreators = data.MetCreators or {}
    self:_reconcileCreatorCounter(player, data)
    if data.MetCreators[tostring(creatorUserId)] then
        return -- once, ever
    end
    data.MetCreators[tostring(creatorUserId)] = os.time()

    local invSvc = self._inventoryService
    local granted = invSvc
        and invSvc:AddItem(player, "eggs", {
            id = creatorDef.egg_id,
            name = creatorDef.egg_name or creatorDef.egg_id,
            source = "met_creator:" .. tostring(creatorUserId),
        })
    dataService:RequestSave(player, "met_creator", { critical = true })
    fireGameEvent(player, "met_creator", {
        creator = creatorDef.name,
        egg = creatorDef.egg_name or creatorDef.egg_id,
        granted = granted ~= nil,
        -- the float reaction renders ctx.name (config styles it)
        name = ("You met %s! %s received!"):format(
            creatorDef.name or "the creator",
            creatorDef.egg_name or "an egg"
        ),
    })
    self._logger:Info("Meet-The-Creator: first meeting", {
        player = player.Name,
        creator = creatorDef.name,
        egg = creatorDef.egg_id,
        granted = granted ~= nil,
    })
end

-- Scan: for `player`, check every registered creator present in this server.
function MeetCreatorService:_scanFor(player)
    local data = self._dataService and self._dataService:GetData(player)
    if data then
        self:_reconcileCreatorCounter(player, data)
    end
    for creatorId, def in pairs(self._config.creators or {}) do
        local creatorPlayer = Players:GetPlayerByUserId(tonumber(creatorId))
        if creatorPlayer then -- including the creator themselves
            self:_tryMeet(player, creatorId, def)
        end
    end
end

function MeetCreatorService:Start()
    local meetEnabled = self._config.meet and self._config.meet.enabled
    local delay = tonumber(self._config.meet and self._config.meet.check_delay) or 8
    local function scanJoin(joiner)
        if meetEnabled then
            task.delay(delay, function()
                if not joiner.Parent then
                    return
                end
                -- the joiner might be meeting creators already here
                self:_scanFor(joiner)
                -- ...or the joiner IS a creator everyone else now meets
                if self:_creatorFor(joiner.UserId) then
                    local def = self:_creatorFor(joiner.UserId)
                    for _, other in ipairs(Players:GetPlayers()) do
                        if other ~= joiner then
                            self:_tryMeet(other, joiner.UserId, def)
                        end
                    end
                end
            end)
        end
    end

    local function watchLuck(joiner)
        local old = self._serverLuckConnections[joiner]
        if old then
            old:Disconnect()
        end
        self._serverLuckConnections[joiner] = joiner
            :GetAttributeChangedSignal("FounderLegacyActive")
            :Connect(function()
                self:_refreshServerLuck(joiner)
            end)
        self:_refreshServerLuck(joiner)
    end

    Players.PlayerAdded:Connect(function(joiner)
        scanJoin(joiner)
        watchLuck(joiner)
    end)
    for _, p in ipairs(Players:GetPlayers()) do
        scanJoin(p)
        watchLuck(p)
    end

    Players.PlayerRemoving:Connect(function(leaving)
        local connection = self._serverLuckConnections[leaving]
        if connection then
            connection:Disconnect()
            self._serverLuckConnections[leaving] = nil
        end
        task.defer(function()
            self:_refreshServerLuck()
            -- defer runs before the player is gone from GetPlayers in some orders;
            -- a second pass next heartbeat keeps the state honest
        end)
        task.delay(0.1, function()
            self:_refreshServerLuck()
        end)
    end)
    self:_refreshServerLuck()
end

-- Hatch one held egg item: consume it, roll the variant, grant the SPECIES pet
-- (plain grant — never huge, never creator class).
-- LUCKY SERVER: registered creators supply 2x to non-creators; Founder’s Legacy supplies 1.5x
-- to everyone. Presence sources never multiply: each player receives the strongest eligible aura.
function MeetCreatorService:_isCreator(player)
    if (self._config.creators or {})[tostring(player.UserId)] ~= nil then
        return true
    end
    -- Studio multi-client test players have fake negative UserIds — the config can
    -- bless them as stand-in creators so the lucky-server mechanic is testable
    if game:GetService("RunService"):IsStudio() then
        local testIds = self._config.server_luck
            and self._config.server_luck.studio_test_creator_ids
        for _, id in ipairs(testIds or {}) do
            if tostring(player.UserId) == tostring(id) then
                return true
            end
        end
    end
    return false
end

function MeetCreatorService:_isLegacyFounder(player)
    return player and player:GetAttribute("FounderLegacyActive") == true
end

function MeetCreatorService:_refreshServerLuck(triggerPlayer)
    local cfg = self._config.server_luck
    local creatorEnabled = cfg and cfg.enabled == true
    local founderCfg = self._founderLegacyConfig or {}
    local founderLuckCfg = founderCfg.server_luck or {}
    local founderEnabled = founderCfg.enabled == true
    local creatorPresent = false
    local presentCreator = nil
    local founderPresent = false
    local presentFounder = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if creatorEnabled and self:_isCreator(p) then
            if not creatorPresent then
                creatorPresent = true
                presentCreator = p
            end
        end
        if founderEnabled and self:_isLegacyFounder(p) then
            if not founderPresent then
                founderPresent = true
                presentFounder = p
            end
        end
    end

    local creatorMultiplier = tonumber(cfg and cfg.mult) or 1
    local founderMultiplier = tonumber(founderLuckCfg.mult) or 1
    local now = os.time()
    for _, p in ipairs(Players:GetPlayers()) do
        local multiplier, source = ServerLuck.resolveForPlayer({
            creatorPresent = creatorPresent,
            founderPresent = founderPresent,
            playerIsCreator = self:_isCreator(p),
            creatorMultiplier = creatorMultiplier,
            founderMultiplier = founderMultiplier,
        })
        if multiplier > 1 then
            p:SetAttribute("ServerLuckBuff", multiplier)
            -- refreshed on every join/leave; horizon just needs to outlive sessions
            p:SetAttribute("ServerLuckBuffUntil", now + 86400)
            p:SetAttribute("ServerLuckSource", source)
        else
            p:SetAttribute("ServerLuckBuff", nil)
            p:SetAttribute("ServerLuckBuffUntil", nil)
            p:SetAttribute("ServerLuckSource", nil)
        end
        p:SetAttribute("IsCreator", self:_isCreator(p))
        p:SetAttribute("CreatorServerLuckBuff", source == "creator" and multiplier or nil)
        p:SetAttribute("CreatorServerLuckBuffUntil", source == "creator" and (now + 86400) or nil)
        p:SetAttribute("FounderServerLuckBuff", source == "founder" and multiplier or nil)
        p:SetAttribute("FounderServerLuckBuffUntil", source == "founder" and (now + 86400) or nil)
    end

    local previous = self._serverLuckState or { creator = false, founder = false }
    self._serverLuckState = { creator = creatorPresent, founder = founderPresent }

    if creatorPresent and not previous.creator then
        -- Prefer the creator whose join caused this inactive -> active transition.
        -- On a late service start, fall back to the creator already present.
        local activatingCreator = triggerPlayer and self:_isCreator(triggerPlayer) and triggerPlayer
            or presentCreator
        if activatingCreator and self._chatAnnouncementService then
            self._chatAnnouncementService:AnnounceCreatorLuck(activatingCreator, creatorMultiplier)
        end
    end

    if founderPresent and not previous.founder then
        local activatingFounder = triggerPlayer
                and self:_isLegacyFounder(triggerPlayer)
                and triggerPlayer
            or presentFounder
        if activatingFounder and self._chatAnnouncementService then
            self._chatAnnouncementService:AnnounceFounderLegacy(
                activatingFounder,
                founderMultiplier
            )
        end
        if activatingFounder then
            local displayName = activatingFounder.DisplayName or activatingFounder.Name
            for _, recipient in ipairs(Players:GetPlayers()) do
                fireGameEvent(recipient, "founders_legacy_active", {
                    name = ("👑 %s entered with Founder's Legacy — %.1fx hatch luck!"):format(
                        displayName,
                        founderMultiplier
                    ),
                    founderUserId = activatingFounder.UserId,
                    multiplier = founderMultiplier,
                })
            end
        end
    end
end

-- Admin/test: forget every met-creator stamp so the once-ever meet can fire again
-- (the egg is a one-of-one — this is how you re-run the flow after testing spends it).
function MeetCreatorService:ResetMeets(player)
    local dataService = self._dataService
    local data = dataService and dataService:GetData(player)
    if not data then
        return { ok = false, reason = "no_data" }
    end
    local count = 0
    for _ in pairs(data.MetCreators or {}) do
        count += 1
    end
    data.MetCreators = {}
    if self._statsService then
        self._statsService:Set(player, "creators_met", 0)
    end
    dataService:RequestSave(player, "meet_reset", { critical = true })
    self._logger:Warn("MetCreators reset (admin)", { player = player.Name, cleared = count })
    -- re-scan NOW (the join-scan already ran) so the meet re-fires without a rejoin
    task.defer(function()
        self:_scanFor(player)
    end)
    return { ok = true, cleared = count }
end

function MeetCreatorService:_hatchEggItemUnlocked(player, eggItemId, confirmedPermanent)
    local invSvc = self._inventoryService
    local rec = invSvc and invSvc:GetItem(player, "eggs", eggItemId)
    if not rec or (tonumber(rec.quantity) or 0) < 1 then
        return { ok = false, reason = "no_egg" }
    end
    -- The inventory key is an instance selector. Limited tester eggs deliberately use a unique
    -- key so provenance cannot merge; their authored egg id remains on the record.
    local baseEggId = tostring(rec.id or eggItemId)
    -- find which creator this egg belongs to
    local def
    for _, c in pairs(self._config.creators or {}) do
        if c.egg_id == baseEggId then
            def = c
            break
        end
    end
    if not def then
        -- GENERAL inventory eggs (boss exclusive eggs, 2026-07-09): any
        -- fixed-odds, non-purchasable egg_sources entry is hatchable from the
        -- eggs bucket through this same path — the creator lookup above is
        -- just the legacy special case. fixed_odds is the safety gate: only
        -- stated-odds eggs may live in inventory (Roblox paid-egg policy).
        local okCfg, eggDef = pcall(function()
            local petsConfig = require(ReplicatedStorage.Configs:WaitForChild("pets"))
            return petsConfig.egg_sources and petsConfig.egg_sources[baseEggId]
        end)
        if not (okCfg and type(eggDef) == "table" and eggDef.fixed_odds == true) then
            return { ok = false, reason = "unknown_egg" }
        end
    end
    -- NORMAL hatch mechanics (Jason): the creator egg is a REAL egg definition in
    -- configs/pets.lua — simulateHatch runs the standard pipeline (species, the
    -- golden/rainbow channels WITH the player's luck, and the slim huge chance).
    local dataService = self._dataService
    local playerData = dataService and dataService:GetData(player)
    local petsConfig = require(ReplicatedStorage.Configs:WaitForChild("pets"))
    local hatch
    if self._trialEggRewardService then
        hatch = self._trialEggRewardService:ResolveHatch(player, eggItemId, rec, confirmedPermanent)
        if hatch and hatch.ok == false then
            return hatch
        end
    end
    if self._testerRewardService then
        hatch = hatch or self._testerRewardService:ResolveHatch(player, rec)
        if hatch and hatch.ok == false then
            return hatch
        end
    end
    local okSim = true
    if not hatch then
        okSim, hatch = pcall(function()
            return petsConfig.simulateHatch(baseEggId, playerData)
        end)
    end
    if not okSim or type(hatch) ~= "table" or not hatch.pet then
        return { ok = false, reason = "hatch_failed" }
    end
    local grantSvc = self._petGrantService
    if not grantSvc then
        return { ok = false, reason = "service_unavailable" }
    end
    local result = grantSvc:GrantPet(player, {
        petType = hatch.pet,
        variant = hatch.variant,
        huge = hatch.huge == true,
        quantity = 1,
        source = hatch.award_id
                and ((hatch.award_kind or "tester_reward_egg") .. ":" .. hatch.award_id)
            or ("creator_egg:" .. baseEggId),
        unique = hatch.award_id ~= nil,
        award_id = hatch.award_id,
        awarded_to_user_id = hatch.awarded_to_user_id,
        award_tier = hatch.award_tier,
        award_version = hatch.award_version,
        award_kind = hatch.award_kind,
    })
    if not result or result.ok == false then
        return { ok = false, reason = "grant_failed" }
    end
    if self._trialEggRewardService then
        self._trialEggRewardService:MarkHatched(player, eggItemId, rec)
    end
    invSvc:RemoveItem(player, "eggs", eggItemId, 1)
    self._logger:Info("Creator egg hatched", {
        player = player.Name,
        egg = eggItemId,
        pet = hatch.pet,
        variant = hatch.variant,
        huge = hatch.huge == true,
    })
    -- Inventory-held eggs use this service rather than EggService. Send their hatch through the
    -- same announcement rules so Mythical/Secret/Exclusive hatches appear server-wide and Huge
    -- hatches appear both locally and on the cross-server channel.
    if self._chatAnnouncementService then
        local family = petsConfig.pets and petsConfig.pets[hatch.pet]
        self._chatAnnouncementService:AnnounceHatches(player, {
            {
                Pet = hatch.pet,
                Type = hatch.variant,
                RarityId = hatch.huge == true and "huge" or (family and family.rarity),
                huge = hatch.huge == true,
            },
        })
    end
    if hatch.huge == true and self._statsService then
        self._statsService:Increment(player, "huge_pets_hatched", 1)
    end
    return { ok = true, pet = hatch.pet, variant = hatch.variant, huge = hatch.huge == true }
end

-- Held eggs are valuable one-shot records. Serialize each player's hatch requests so two client
-- invokes cannot both observe the same egg before the first call consumes it.
function MeetCreatorService:HatchEggItem(player, eggItemId, confirmedPermanent)
    if self._eggHatchLocks[player] then
        return { ok = false, reason = "hatch_busy" }
    end
    self._eggHatchLocks[player] = true
    local ok, result = pcall(function()
        return self:_hatchEggItemUnlocked(player, eggItemId, confirmedPermanent)
    end)
    self._eggHatchLocks[player] = nil
    if not ok then
        self._logger:Error("Held egg hatch failed", {
            player = player and player.Name,
            egg = eggItemId,
            error = tostring(result),
        })
        return { ok = false, reason = "hatch_failed" }
    end
    return result
end

return MeetCreatorService
