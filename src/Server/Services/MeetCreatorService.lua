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

local MeetCreatorService = {}
MeetCreatorService.__index = MeetCreatorService

function MeetCreatorService.new()
    return setmetatable({}, MeetCreatorService)
end

function MeetCreatorService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    local ok, cfg = pcall(function()
        return self._configLoader:LoadConfig("creators")
    end)
    self._config = (ok and cfg) or { creators = {}, meet = { enabled = false } }
end

function MeetCreatorService:_svc(name)
    local locator = _G.RBXTemplateServices
    local ok, svc = pcall(function()
        return locator and locator:Get(name)
    end)
    return ok and svc or nil
end

function MeetCreatorService:_creatorFor(userId)
    return (self._config.creators or {})[tostring(userId)]
end

-- Award `player` the meet-egg for `creatorUserId` if this is their first meeting.
function MeetCreatorService:_tryMeet(player, creatorUserId, creatorDef)
    -- creators DO meet themselves (being in a server with the creator includes
    -- being the creator) — Jason's call, and it makes the mechanic solo-testable
    local dataService = self:_svc("DataService")
    if not (dataService and dataService:IsDataLoaded(player)) then
        return
    end
    local data = dataService:GetData(player)
    data.MetCreators = data.MetCreators or {}
    if data.MetCreators[tostring(creatorUserId)] then
        return -- once, ever
    end
    data.MetCreators[tostring(creatorUserId)] = os.time()

    local invSvc = self:_svc("InventoryService")
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
    for creatorId, def in pairs(self._config.creators or {}) do
        local creatorPlayer = Players:GetPlayerByUserId(tonumber(creatorId))
        if creatorPlayer then -- including the creator themselves
            self:_tryMeet(player, creatorId, def)
        end
    end
end

function MeetCreatorService:Start()
    if not (self._config.meet and self._config.meet.enabled) then
        return
    end
    local delay = tonumber(self._config.meet.check_delay) or 8
    local function onJoin(joiner)
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
    Players.PlayerAdded:Connect(onJoin)
    for _, p in ipairs(Players:GetPlayers()) do
        onJoin(p)
    end

    -- lucky-server presence tracking (joins stamp immediately — no meet delay needed;
    -- leaves re-evaluate so the buff drops when the last creator goes)
    Players.PlayerAdded:Connect(function()
        self:_refreshServerLuck()
    end)
    Players.PlayerRemoving:Connect(function(leaving)
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
-- LUCKY SERVER: while any registered creator is present, every NON-creator player
-- wears ServerLuckBuff (folded into hatch luck by EggService, same convention as
-- the bunny aura). Creators stay baseline so their playtesting reads true balance.
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

function MeetCreatorService:_refreshServerLuck()
    local cfg = self._config.server_luck
    local enabled = cfg and cfg.enabled == true
    local creatorPresent = false
    if enabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if self:_isCreator(p) then
                creatorPresent = true
                break
            end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if creatorPresent and not self:_isCreator(p) then
            p:SetAttribute("ServerLuckBuff", tonumber(cfg.mult) or 1.25)
            -- refreshed on every join/leave; horizon just needs to outlive sessions
            p:SetAttribute("ServerLuckBuffUntil", os.time() + 86400)
        else
            p:SetAttribute("ServerLuckBuff", nil)
            p:SetAttribute("ServerLuckBuffUntil", nil)
        end
    end
end

-- Admin/test: forget every met-creator stamp so the once-ever meet can fire again
-- (the egg is a one-of-one — this is how you re-run the flow after testing spends it).
function MeetCreatorService:ResetMeets(player)
    local dataService = self:_svc("DataService")
    local data = dataService and dataService:GetData(player)
    if not data then
        return { ok = false, reason = "no_data" }
    end
    local count = 0
    for _ in pairs(data.MetCreators or {}) do
        count += 1
    end
    data.MetCreators = {}
    dataService:RequestSave(player, "meet_reset", { critical = true })
    self._logger:Warn("MetCreators reset (admin)", { player = player.Name, cleared = count })
    -- re-scan NOW (the join-scan already ran) so the meet re-fires without a rejoin
    task.defer(function()
        self:_scanFor(player)
    end)
    return { ok = true, cleared = count }
end

function MeetCreatorService:HatchEggItem(player, eggItemId)
    -- find which creator this egg belongs to
    local def
    for _, c in pairs(self._config.creators or {}) do
        if c.egg_id == eggItemId then
            def = c
            break
        end
    end
    if not def then
        return { ok = false, reason = "unknown_egg" }
    end
    local invSvc = self:_svc("InventoryService")
    local rec = invSvc and invSvc:GetItem(player, "eggs", eggItemId)
    if not rec or (tonumber(rec.quantity) or 0) < 1 then
        return { ok = false, reason = "no_egg" }
    end
    -- NORMAL hatch mechanics (Jason): the creator egg is a REAL egg definition in
    -- configs/pets.lua — simulateHatch runs the standard pipeline (species, the
    -- golden/rainbow channels WITH the player's luck, and the slim huge chance).
    local dataService = self:_svc("DataService")
    local playerData = dataService and dataService:GetData(player)
    local petsConfig = require(ReplicatedStorage.Configs:WaitForChild("pets"))
    local okSim, hatch = pcall(function()
        return petsConfig.simulateHatch(eggItemId, playerData)
    end)
    if not okSim or type(hatch) ~= "table" or not hatch.pet then
        return { ok = false, reason = "hatch_failed" }
    end
    local grantSvc = self:_svc("PetGrantService")
    if not grantSvc then
        return { ok = false, reason = "service_unavailable" }
    end
    local result = grantSvc:GrantPet(player, {
        petType = hatch.pet,
        variant = hatch.variant,
        huge = hatch.huge == true,
        quantity = 1,
        source = "creator_egg:" .. eggItemId,
    })
    if not result or result.ok == false then
        return { ok = false, reason = "grant_failed" }
    end
    invSvc:RemoveItem(player, "eggs", eggItemId, 1)
    self._logger:Info("Creator egg hatched", {
        player = player.Name,
        egg = eggItemId,
        pet = hatch.pet,
        variant = hatch.variant,
        huge = hatch.huge == true,
    })
    return { ok = true, pet = hatch.pet, variant = hatch.variant, huge = hatch.huge == true }
end

return MeetCreatorService
