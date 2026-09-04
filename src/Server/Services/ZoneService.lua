--[[
    ZoneService

    Server-authoritative area unlock and travel service. WorldBindingService owns
    the map hooks; ZoneService owns whether a player may use them.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local HallOfWorldsLogic = require(ReplicatedStorage.Shared.Game.HallOfWorldsLogic)
local PlayerSpawnSpread = require(ReplicatedStorage.Shared.Game.PlayerSpawnSpread)
local PrologueSpawnGate = require(ReplicatedStorage.Shared.Game.PrologueSpawnGate)
local WorldContext = require(ReplicatedStorage.Shared.Game.WorldContext)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local placesConfig = require(ReplicatedStorage.Configs:WaitForChild("places"))

local ZoneService = {}
ZoneService.__index = ZoneService

local TOUCH_DEBOUNCE_SECONDS = 1
local DEFAULT_START_AREA = "Spawn"
local HALL_START_AREA = "Hall_1"
local TRAVEL_PROMPT_NAME = "ZoneTravelPrompt"
local TRAVEL_PROMPT_ATTACHMENT_NAME = "ZoneTravelPromptAttachment"
local DEFAULT_HALL_PROMPT_HEIGHT_FROM_BOTTOM = 4.5
local UNLOCKED_AREAS_ATTRIBUTE = "UnlockedAreasJson"
local ENTERED_CRYSTAL_WORLD_ATTRIBUTE = "EnteredCrystalWorld"

local function asSet(values)
    local set = {}
    if type(values) ~= "table" then
        return set
    end

    for key, value in pairs(values) do
        if type(key) == "number" then
            set[tostring(value)] = true
        elseif value == true then
            set[tostring(key)] = true
        elseif type(value) == "string" then
            set[value] = true
        end
    end

    return set
end

local function setToSortedArray(set)
    local values = {}
    for key, enabled in pairs(set) do
        if enabled == true then
            table.insert(values, key)
        end
    end
    table.sort(values)
    return values
end

local function getRootPart(player)
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function waitForRootPart(player, timeoutSeconds)
    local character = player.Character
    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
        or character:WaitForChild("HumanoidRootPart", timeoutSeconds or 5)
end

function ZoneService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._economyService = self._modules.EconomyService
    self._worldBindingService = self._modules.WorldBindingService
    self._statsService = self._modules.StatsService
    self._areasConfig = self._configLoader:LoadConfig("areas")
    self._spawnSpreadConfig = self._areasConfig.player_spawn_spread or {}
    self._hallConfig = self._configLoader:LoadConfig("hall_of_worlds")
    self._mergeGateConfig = (self._configLoader:LoadConfig("merge_egg_prototype") or {}).gate or {}
    self._hallEntryEnabled = not (self._hallConfig and self._hallConfig.entry_enabled == false)
    self._combatTutorialConfig = self._configLoader:LoadConfig("combat_tutorial")
    self._hallRouteAreaSet = {}
    for _, routeArea in ipairs((self._hallConfig and self._hallConfig.route) or {}) do
        if type(routeArea.area_id) == "string" then
            self._hallRouteAreaSet[routeArea.area_id] = true
        end
    end
    self._touchDebounce = {}
end

function ZoneService:IsHallEntryEnabled()
    return self._hallEntryEnabled == true
end

function ZoneService:CanLeaveHall(player, sourceHook, targetAreaId)
    -- With the Hall route retired, World Travel and every normal Crystal World destination are
    -- available under their ordinary unlock rules; there is no first-world exit gate to satisfy.
    if not self:IsHallEntryEnabled() then
        return true
    end
    local data = player and self._dataService:GetData(player) or nil
    local gameData = data and data.GameData or {}
    local hallState = HallOfWorldsLogic.normalizeState(
        gameData,
        self._hallConfig and self._hallConfig.version or 2
    )
    local isHallExit = sourceHook and sourceHook:GetAttribute("HallExitToCrystalWorld") == true
        or false
    return HallOfWorldsLogic.canLeaveHall(
        hallState.entered_crystal_world,
        targetAreaId,
        self._hallRouteAreaSet or {},
        isHallExit
    )
end

function ZoneService:GetInitialArea(player)
    if not self:IsHallEntryEnabled() then
        return self:_crystalSpawnArea()
    end
    local data = player and self._dataService:GetData(player) or nil
    local gameData = data and data.GameData or {}
    local hallState = HallOfWorldsLogic.normalizeState(
        gameData,
        self._hallConfig and self._hallConfig.version or 2
    )
    local routeAreaIds = {}
    for _, routeArea in ipairs((self._hallConfig and self._hallConfig.route) or {}) do
        if type(routeArea.area_id) == "string" then
            table.insert(routeAreaIds, routeArea.area_id)
        end
    end
    return HallOfWorldsLogic.initialArea(
        hallState.entered_crystal_world,
        gameData.UnlockedAreas,
        routeAreaIds,
        self._hallConfig and self._hallConfig.initial_area or HALL_START_AREA,
        self._hallConfig and self._hallConfig.crystal_world_area or DEFAULT_START_AREA,
        gameData.LastArea,
        self._hallRouteAreaSet,
        data and data.Tutorial,
        gameData
    )
end

function ZoneService:HasEnteredCrystalWorld(player)
    local data = player and self._dataService and self._dataService:GetData(player)
    local hallState = HallOfWorldsLogic.normalizeState(
        data and data.GameData,
        self._hallConfig and self._hallConfig.version or 2
    )
    return hallState.entered_crystal_world == true
end

function ZoneService:IsHallArea(areaId)
    return type(areaId) == "string"
        and self._hallRouteAreaSet
        and self._hallRouteAreaSet[areaId] == true
end

function ZoneService:IsInHall(player)
    if not player then
        return false
    end
    local active = self._worldBindingService and self._worldBindingService:GetActiveArea(player)
    if self:IsHallArea(active) then
        return true
    end
    return self:IsHallArea(player:GetAttribute("CurrentArea"))
end

function ZoneService:GetRespawnArea(player)
    if not self:IsHallEntryEnabled() then
        return self:_crystalSpawnArea()
    end
    local data = player and self._dataService:GetData(player) or nil
    local gameData = data and data.GameData or {}
    local hallState = HallOfWorldsLogic.normalizeState(
        gameData,
        self._hallConfig and self._hallConfig.version or 2
    )
    local routeAreaIds = {}
    for _, routeArea in ipairs((self._hallConfig and self._hallConfig.route) or {}) do
        if type(routeArea.area_id) == "string" then
            table.insert(routeAreaIds, routeArea.area_id)
        end
    end
    return HallOfWorldsLogic.sessionRespawnArea(
        hallState.entered_crystal_world,
        gameData.UnlockedAreas,
        routeAreaIds,
        self._hallConfig and self._hallConfig.initial_area or HALL_START_AREA,
        self._hallConfig and self._hallConfig.crystal_world_area or DEFAULT_START_AREA,
        gameData.LastArea,
        self._hallRouteAreaSet,
        player and player:GetAttribute("HallGuestVisit") == true,
        data and data.Tutorial,
        gameData
    )
end

function ZoneService:BeginHallGuestVisit(player)
    if typeof(player) ~= "Instance" or not player:IsA("Player") then
        return { ok = false, reason = "invalid_player" }
    end
    if not self:IsHallEntryEnabled() then
        return { ok = false, reason = "hall_disabled" }
    end
    if self:HasEnteredCrystalWorld(player) then
        return { ok = false, reason = "already_member" }
    end
    player:SetAttribute("HallGuestVisit", true)
    local placed, reason = self:PlacePlayerAtZoneSpawn(player, self:_crystalSpawnArea(), {
        remember = false,
    })
    if not placed then
        player:SetAttribute("HallGuestVisit", nil)
        return { ok = false, reason = reason or "guest_place_failed" }
    end
    return { ok = true, areaId = self:_crystalSpawnArea(), guest = true }
end

function ZoneService:EndHallGuestVisit(player)
    if typeof(player) ~= "Instance" or not player:IsA("Player") then
        return
    end
    if player:GetAttribute("HallGuestVisit") ~= true then
        return
    end
    player:SetAttribute("HallGuestVisit", nil)
    if player:GetAttribute("InMission") ~= nil then
        return
    end
    self:PlacePlayerAtZoneSpawn(player, self:GetInitialArea(player))
end

function ZoneService:_crystalSpawnArea()
    return self._hallConfig and self._hallConfig.crystal_world_area or DEFAULT_START_AREA
end

function ZoneService:_rememberArea(player, areaId)
    if typeof(player) ~= "Instance" or not player:IsA("Player") then
        return
    end
    if player:GetAttribute("InPrologue") == true then
        return
    end
    -- Trials own the live character. Persist Crystal World Spawn so a later join
    -- cannot resume into a mission_* CurrentArea from the player list.
    if player:GetAttribute("InMission") ~= nil then
        areaId = self:_crystalSpawnArea()
    end
    local data = self._dataService and self._dataService:GetData(player)
    if type(data) ~= "table" then
        return
    end
    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    if not self:IsHallEntryEnabled() then
        local _, changed = HallOfWorldsLogic.forceHomeResume(
            data.GameData,
            self._hallRouteAreaSet,
            self:_crystalSpawnArea()
        )
        if changed then
            self._dataService:RequestSave(player, "homeworld_resume", { critical = false })
        end
        return
    end
    local hallState = HallOfWorldsLogic.normalizeState(
        data.GameData,
        self._hallConfig and self._hallConfig.version or 2
    )
    local resume = HallOfWorldsLogic.resolvedResumeArea(
        areaId,
        hallState.entered_crystal_world,
        data.GameData.UnlockedAreas,
        self._hallRouteAreaSet,
        self:_crystalSpawnArea(),
        data.Tutorial,
        data.GameData
    )
    if not resume then
        return
    end
    if data.GameData.LastArea == resume then
        return
    end
    data.GameData.LastArea = resume
    self._dataService:RequestSave(player, "last_area", { critical = false })
end

function ZoneService:_watchLastWorld(player)
    player:GetAttributeChangedSignal("InMission"):Connect(function()
        if player:GetAttribute("InMission") ~= nil then
            self:_rememberArea(player, self:_crystalSpawnArea())
        end
    end)
end

function ZoneService:Start()
    self:_connectTravelHooks()
    if self:IsHallEntryEnabled() then
        self:_seatHallAreaZones()
        self:_seatComingSoonWalls()
    end
    self:_setupNetworkSignals()

    self._worldBindingService.AreaEntered:Connect(function(player, areaId)
        self:_handleAreaEntered(player, areaId)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self._touchDebounce[player] = nil
    end)

    Players.PlayerAdded:Connect(function(player)
        self:_connectCharacterSpawnSafety(player)
        self:_watchLastWorld(player)
        self:_syncUnlocksWhenDataLoads(player)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        self:_connectCharacterSpawnSafety(player)
        self:_watchLastWorld(player)
        self:_syncUnlocksWhenDataLoads(player)
    end
end

-- Areas an admin can cycle through for testing area theming + play feel.
local ADMIN_AREAS = { "Grass", "Desert", "Ice", "Lava", "Spawn" }

function ZoneService:_setupNetworkSignals()
    Signals.UnlockZoneRequest.OnServerEvent:Connect(function(player, payload)
        payload = type(payload) == "table" and payload or {}
        local result = self:UnlockZone(player, payload.zoneId)
        Signals.ZoneUnlockResult:FireClient(player, result)
    end)
    -- Admin testing: set the active area + home area (drives UI theme + spawns). Admin-gated.
    Signals.Admin_SetArea.OnServerEvent:Connect(function(player, payload)
        if player:GetAttribute("IsAdmin") ~= true then
            return
        end
        local area = type(payload) == "table" and payload.area or payload
        if type(area) ~= "string" then
            return
        end
        local valid = false
        for _, a in ipairs(ADMIN_AREAS) do
            if a == area then
                valid = true
                break
            end
        end
        if valid then
            player:SetAttribute("CurrentArea", area)
            player:SetAttribute("HomeArea", area) -- the chosen home area drives the UI theme
        end
    end)
end

function ZoneService:_getZone(zoneId)
    return self._areasConfig.zones and self._areasConfig.zones[zoneId]
end

function ZoneService:_resolveAreaId(zoneId)
    return self._worldBindingService:GetPrimaryAreaForZone(zoneId)
end

function ZoneService:_getUnlockSet(player)
    local data = self._dataService:GetData(player)
    if not data then
        return nil
    end

    data.GameData = data.GameData or {}
    local set = asSet(data.GameData.UnlockedAreas)

    for zoneId, zone in pairs(self._areasConfig.zones or {}) do
        if zone.kind == "area" and zone.unlock and zone.unlock.unlocked_by_default == true then
            set[zoneId] = true
        end
    end
    set[DEFAULT_START_AREA] = true
    if self:IsHallEntryEnabled() then
        set[HALL_START_AREA] = true
    else
        for areaId in pairs(self._hallRouteAreaSet or {}) do
            set[areaId] = nil
        end
        HallOfWorldsLogic.forceHomeResume(
            data.GameData,
            self._hallRouteAreaSet,
            self:_crystalSpawnArea()
        )
    end

    data.GameData.UnlockedAreas = setToSortedArray(set)
    self:_publishUnlockedAreas(player, set)
    self:PublishHallMembership(player)
    return set, data
end

function ZoneService:_isParentChainUnlocked(player, zoneId, unlockSet)
    local zone = self:_getZone(zoneId)
    if not zone then
        return false
    end

    local requiredZoneId = zone.unlock and zone.unlock.required_zone
    if requiredZoneId and not self:IsZoneUnlocked(player, requiredZoneId, unlockSet) then
        return false
    end

    if zone.parent then
        return self:_isParentChainUnlocked(player, zone.parent, unlockSet)
    end

    return true
end

function ZoneService:IsZoneUnlocked(player, zoneId, unlockSet)
    local zone = self:_getZone(zoneId)
    if not zone then
        return false
    end

    local areaId = self:_resolveAreaId(zoneId)
    if not self:IsHallEntryEnabled() and self:IsHallArea(areaId or zoneId) then
        return false
    end

    if zone.unlock and zone.unlock.unlocked_by_default == true then
        return true
    end

    unlockSet = unlockSet or self:_getUnlockSet(player)
    if not unlockSet then
        return false
    end

    if zone.kind == "area" and unlockSet[zoneId] ~= true then
        return false
    end
    if zone.kind ~= "area" and areaId and unlockSet[areaId] ~= true then
        return false
    end

    return self:_isParentChainUnlocked(player, zoneId, unlockSet)
end

function ZoneService:GetUnlockedZones(player)
    local unlockSet = self:_getUnlockSet(player)
    if not unlockSet then
        return {}
    end
    return setToSortedArray(unlockSet)
end

-- Reconstruct finite exploration counters from the persisted unlock set. Older profiles could
-- unlock zones before the event-counter bridge existed (or while it was unavailable), which made
-- one-time exploration quests permanently impossible. Reconciliation only moves lifetime totals
-- upward; it never fabricates unlocks or erases historical progress.
function ZoneService:_reconcileUnlockCounters(player, unlockSet)
    local stats = self._statsService
    if not (stats and type(unlockSet) == "table") then
        return
    end

    local areas = 0
    local heaven = 0
    local hell = 0
    for zoneId, unlocked in pairs(unlockSet) do
        local zone = unlocked and self:_getZone(zoneId)
        if
            zone
            and zone.kind == "area"
            and not (zone.unlock and zone.unlock.unlocked_by_default == true)
        then
            areas += 1
            local realm = WorldContext.realmOfZoneId(zoneId)
            if realm == "heaven" then
                heaven += 1
            elseif realm == "hell" then
                hell += 1
            end
        end
    end

    local values = {
        areas_unlocked = areas,
        heaven_areas_unlocked = heaven,
        hell_areas_unlocked = hell,
        realm_areas_unlocked = heaven + hell,
    }
    for counterId, value in pairs(values) do
        if value > stats:Get(player, counterId) then
            stats:Set(player, counterId, value)
        end
    end
end

-- The NEXT gate the player can buy: the lowest-order LOCKED area whose required_zone is already
-- unlocked and that has a coin cost. Returns { zoneId, currency, cost } or nil (nothing to buy).
function ZoneService:GetNextGate(player)
    local unlockSet = self:_getUnlockSet(player)
    if not unlockSet then
        return nil
    end
    local best
    for zoneId, zone in pairs(self._areasConfig.zones or {}) do
        local unlock = zone.kind == "area" and zone.unlock
        local cost = unlock and tonumber(unlock.cost)
        if unlock and cost and unlock.currency and not unlock.unlocked_by_default then
            local locked = not self:IsZoneUnlocked(player, zoneId, unlockSet)
            local req = unlock.required_zone
            local reqOk = (not req) or self:IsZoneUnlocked(player, req, unlockSet)
            if locked and reqOk then
                local order = tonumber(zone.order) or 999
                if not best or order < best.order then
                    best =
                        { zoneId = zoneId, currency = unlock.currency, cost = cost, order = order }
                end
            end
        end
    end
    return best
end

function ZoneService:SetZoneLocked(player, zoneId, locked, options)
    options = options or {}

    local zone = self:_getZone(zoneId)
    if not zone then
        return {
            ok = false,
            reason = "unknown_zone",
            zoneId = zoneId,
        }
    end

    local areaId = self:_resolveAreaId(zoneId)
    if not areaId then
        return {
            ok = false,
            reason = "missing_primary_area",
            zoneId = zoneId,
        }
    end

    local areaZone = self:_getZone(areaId)
    if locked == true and areaZone and areaZone.unlock and areaZone.unlock.unlocked_by_default then
        return {
            ok = false,
            reason = "default_area_cannot_lock",
            zoneId = zoneId,
            areaId = areaId,
        }
    end

    if locked ~= true then
        return self:UnlockZone(player, zoneId, {
            bypassRequirements = options.bypassRequirements == true,
        })
    end

    local unlockSet, data = self:_getUnlockSet(player)
    if not unlockSet or not data then
        return {
            ok = false,
            reason = "data_not_loaded",
            zoneId = zoneId,
            areaId = areaId,
        }
    end

    unlockSet[areaId] = nil
    data.GameData.UnlockedAreas = setToSortedArray(unlockSet)
    if data.GameData.LastArea == areaId then
        data.GameData.LastArea = ""
    end
    self:_publishUnlockedAreas(player, unlockSet)
    self._dataService:RequestSave(player, "zone_lock", { critical = true })

    if self._worldBindingService:GetActiveArea(player) == areaId then
        self:TravelToZone(player, self:GetInitialArea(player))
    end

    self._logger:Info("Zone locked", {
        player = player.Name,
        zoneId = zoneId,
        areaId = areaId,
    })

    return {
        ok = true,
        locked = true,
        zoneId = zoneId,
        areaId = areaId,
    }
end

function ZoneService:_connectCharacterSpawnSafety(player)
    player.CharacterAdded:Connect(function()
        task.defer(function()
            if PlaceRuntime.isMerge(game.PlaceId, placesConfig) then
                return
            end
            task.wait(0.2)
            if player:GetAttribute("InMission") ~= nil then
                return
            end
            if not self:_awaitSpawnSafetyDecision(player) then
                return
            end
            if player:GetAttribute("InMission") ~= nil then
                return
            end
            self:PlacePlayerAtZoneSpawn(player, self:GetRespawnArea(player), {
                remember = player:GetAttribute("HallGuestVisit") ~= true,
            })
        end)
    end)

    if player.Character then
        task.defer(function()
            if PlaceRuntime.isMerge(game.PlaceId, placesConfig) then
                return
            end
            if player:GetAttribute("InMission") ~= nil then
                return
            end
            if not self:_awaitSpawnSafetyDecision(player) then
                return
            end
            if player:GetAttribute("InMission") ~= nil then
                return
            end
            self:PlacePlayerAtZoneSpawn(player, self:GetRespawnArea(player), {
                remember = player:GetAttribute("HallGuestVisit") ~= true,
            })
        end)
    end
end

-- ZoneService and PrologueService both observe CharacterAdded. The prologue decision can yield on
-- profile/model readiness and streaming, so a fixed delay here is not ordering: the normal Home
-- placement can land after the battle-room pivot and win the race. Wait on the replicated gate
-- event instead. An active prologue owns placement; every resolved non-active path falls through
-- to the normal spawn-safety move.
function ZoneService:_awaitSpawnSafetyDecision(player)
    while player.Parent do
        local action = PrologueSpawnGate.action(
            workspace:GetAttribute("PrologueServiceInit") == true,
            player:GetAttribute("InPrologue") == true,
            player:GetAttribute("PrologueGate")
        )
        if action == "place" then
            return true
        elseif action == "skip" then
            return false
        end

        local changed = Instance.new("BindableEvent")
        local connections = {
            player:GetAttributeChangedSignal("InPrologue"):Connect(function()
                changed:Fire()
            end),
            player:GetAttributeChangedSignal("PrologueGate"):Connect(function()
                changed:Fire()
            end),
            player.AncestryChanged:Connect(function()
                changed:Fire()
            end),
        }

        -- Re-check after connecting so a decision that resolved between the first read and the
        -- subscriptions cannot leave this task waiting for an event that already happened.
        action = PrologueSpawnGate.action(
            workspace:GetAttribute("PrologueServiceInit") == true,
            player:GetAttribute("InPrologue") == true,
            player:GetAttribute("PrologueGate")
        )
        if action == "wait" and player.Parent then
            changed.Event:Wait()
        end
        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
        changed:Destroy()
    end
    return false
end

function ZoneService:_spreadSpawnCFrame(player, areaId, spawnCFrame)
    local config = self._spawnSpreadConfig or {}
    if config.enabled == false then
        return spawnCFrame
    end

    local occupied = {}
    local verticalTolerance = math.max(0, tonumber(config.vertical_tolerance) or 12)
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            local otherRoot = getRootPart(otherPlayer)
            local otherArea = self._worldBindingService:GetActiveArea(otherPlayer)
            if otherRoot and (otherArea == nil or otherArea == areaId) then
                local localPosition = spawnCFrame:PointToObjectSpace(otherRoot.Position)
                if math.abs(localPosition.Y) <= verticalTolerance then
                    table.insert(occupied, {
                        x = localPosition.X,
                        z = localPosition.Z,
                    })
                end
            end
        end
    end

    local offset = PlayerSpawnSpread.choose(player.UserId, occupied, config)
    return spawnCFrame * CFrame.new(offset.x, 0, offset.z)
end

function ZoneService:PlacePlayerAtZoneSpawn(player, zoneId, options)
    local spawnCFrame, areaId =
        self._worldBindingService:GetSpawnCFrameForZone(zoneId or DEFAULT_START_AREA)
    if not spawnCFrame then
        return false, "missing_spawn"
    end

    local rootPart = waitForRootPart(player, 5)
    if not rootPart then
        return false, "character_not_ready"
    end

    local destinationCFrame = spawnCFrame
    if not (options and options.spread == false) then
        destinationCFrame = self:_spreadSpawnCFrame(player, areaId, spawnCFrame)
    end

    rootPart.CFrame = destinationCFrame
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero
    self._worldBindingService:SetActiveArea(player, areaId)

    local currentWorld = player:FindFirstChild("CurrentWorld")
    if currentWorld and currentWorld:IsA("StringValue") then
        currentWorld.Value = areaId
    end

    if not (options and options.remember == false) then
        self:_rememberArea(player, areaId)
    end
    return true, nil, areaId
end

function ZoneService:UnlockZone(player, zoneId, options)
    options = options or {}

    local zone = self:_getZone(zoneId)
    if not zone then
        return {
            ok = false,
            reason = "unknown_zone",
            zoneId = zoneId,
        }
    end

    local areaId = self:_resolveAreaId(zoneId)
    if not areaId then
        return {
            ok = false,
            reason = "missing_primary_area",
            zoneId = zoneId,
        }
    end

    local unlockSet, data = self:_getUnlockSet(player)
    if not unlockSet or not data then
        return {
            ok = false,
            reason = "data_not_loaded",
            zoneId = zoneId,
        }
    end

    if unlockSet[areaId] == true then
        return {
            ok = true,
            alreadyUnlocked = true,
            zoneId = zoneId,
            areaId = areaId,
        }
    end

    local unlock = self:_getUnlockConfig(zoneId) or {}
    if options.bypassRequirements ~= true then
        local requiredZoneId = unlock.required_zone
        if requiredZoneId and not self:IsZoneUnlocked(player, requiredZoneId, unlockSet) then
            return {
                ok = false,
                reason = "required_zone_locked",
                zoneId = zoneId,
                areaId = areaId,
                requiredZoneId = requiredZoneId,
                unlock = self:GetUnlockRequirement(player, zoneId),
            }
        end

        local progressionOk, progressionReason = HallOfWorldsLogic.meetsUnlock(
            data.Stats and data.Stats.ClaimedLevel,
            HallOfWorldsLogic.isTutorialCompleted(data.GameData, data.Tutorial),
            unlock,
            data.Tutorial
        )
        if not progressionOk then
            return {
                ok = false,
                reason = progressionReason,
                zoneId = zoneId,
                areaId = areaId,
                unlock = self:GetUnlockRequirement(player, zoneId),
            }
        end

        local currency = unlock.currency
        local cost = tonumber(unlock.cost) or 0
        if currency and cost > 0 then
            if not self._economyService:CanAfford(player, currency, cost) then
                return {
                    ok = false,
                    reason = "insufficient_currency",
                    zoneId = zoneId,
                    areaId = areaId,
                    currency = currency,
                    cost = cost,
                    unlock = self:GetUnlockRequirement(player, zoneId),
                }
            end
            if not self._economyService:RemoveCurrency(player, currency, cost, "zone_unlock") then
                return {
                    ok = false,
                    reason = "currency_debit_failed",
                    zoneId = zoneId,
                    areaId = areaId,
                    currency = currency,
                    cost = cost,
                }
            end
        end
    end

    unlockSet[areaId] = true
    data.GameData.UnlockedAreas = setToSortedArray(unlockSet)
    self:_publishUnlockedAreas(player, unlockSet)
    self._dataService:RequestSave(player, "zone_unlock", { critical = true })

    self._logger:Info("Zone unlocked", {
        player = player.Name,
        zoneId = zoneId,
        areaId = areaId,
    })

    -- Feed the event-counter bridge (StatEventCounters): "area_unlocked" -> areas_unlocked, and the
    -- per-realm variants -> heaven/hell_areas_unlocked. These back the exploration/realm quests
    -- (configs/stats.lua event_counters). Fire AFTER the unlock is committed; purely observational.
    local realm = WorldContext.realmOfZoneId(areaId)
    fireGameEvent(player, "area_unlocked", { zoneId = zoneId, areaId = areaId, realm = realm })
    if realm == "heaven" then
        fireGameEvent(player, "heaven_area_unlocked", { zoneId = zoneId, areaId = areaId })
        fireGameEvent(player, "realm_area_unlocked", { zoneId = zoneId, areaId = areaId })
    elseif realm == "hell" then
        fireGameEvent(player, "hell_area_unlocked", { zoneId = zoneId, areaId = areaId })
        fireGameEvent(player, "realm_area_unlocked", { zoneId = zoneId, areaId = areaId })
    end

    return {
        ok = true,
        alreadyUnlocked = false,
        zoneId = zoneId,
        areaId = areaId,
    }
end

function ZoneService:GetUnlockRequirement(player, zoneId)
    local zone = self:_getZone(zoneId)
    if not zone then
        return nil
    end

    local areaId = self:_resolveAreaId(zoneId)
    local areaZone = areaId and self:_getZone(areaId) or nil
    local unlock = self:_getUnlockConfig(zoneId) or {}
    local currency = unlock.currency
    local cost = tonumber(unlock.cost) or 0
    local requiredZoneId = unlock.required_zone
    local requiredLevel = math.max(0, math.floor(tonumber(unlock.required_level) or 0))
    local data = player and self._dataService:GetData(player) or nil
    local claimedLevel = data and data.Stats and tonumber(data.Stats.ClaimedLevel) or 1
    local tutorialCompleted = data
        and HallOfWorldsLogic.isTutorialCompleted(data.GameData, data.Tutorial)
    local canAfford = currency == nil
        or cost <= 0
        or (player and self._dataService:CanAfford(player, currency, cost))
        or false

    return {
        zoneId = zoneId,
        areaId = areaId,
        displayName = zone.display_name or (areaZone and areaZone.display_name) or zoneId,
        currency = currency,
        cost = cost,
        requiredZoneId = requiredZoneId,
        requiredLevel = requiredLevel,
        meetsLevel = claimedLevel >= requiredLevel,
        tutorialRequired = unlock.tutorial_required == true,
        tutorialCompleted = tutorialCompleted,
        canAfford = canAfford,
    }
end

function ZoneService:_publishUnlockedAreas(player, unlockSet)
    if not player or type(unlockSet) ~= "table" then
        return
    end

    player:SetAttribute(
        UNLOCKED_AREAS_ATTRIBUTE,
        HttpService:JSONEncode(setToSortedArray(unlockSet))
    )
end

function ZoneService:PublishHallMembership(player)
    if not player then
        return
    end
    local data = self._dataService and self._dataService:GetData(player)
    local hallState = HallOfWorldsLogic.normalizeState(
        data and data.GameData,
        self._hallConfig and self._hallConfig.version or 2
    )
    player:SetAttribute(ENTERED_CRYSTAL_WORLD_ATTRIBUTE, hallState.entered_crystal_world == true)
end

function ZoneService:_syncUnlocksWhenDataLoads(player)
    task.spawn(function()
        if Readiness.awaitAttribute(player, "DataLoaded", true, 30) and player.Parent then
            if not self:IsHallEntryEnabled() then
                local data = self._dataService:GetData(player)
                local changed = false
                if data then
                    data.GameData, changed = HallOfWorldsLogic.forceHomeResume(
                        data.GameData,
                        self._hallRouteAreaSet,
                        self:_crystalSpawnArea()
                    )
                end
                if data and changed then
                    self._dataService:RequestSave(player, "homeworld_resume_reconcile", {
                        critical = true,
                    })
                end
            end
            local unlockSet = self:_getUnlockSet(player)
            if unlockSet then
                self:_reconcileUnlockCounters(player, unlockSet)
            end
        end
    end)
end

function ZoneService:_getUnlockConfig(zoneId)
    local zone = self:_getZone(zoneId)
    if not zone then
        return nil
    end

    local areaId = self:_resolveAreaId(zoneId)
    local areaZone = areaId and self:_getZone(areaId) or nil
    return zone.unlock or (areaZone and areaZone.unlock) or {}
end

function ZoneService:_getZoneDisplayName(zoneId)
    local zone = self:_getZone(zoneId)
    local areaId = self:_resolveAreaId(zoneId)
    local areaZone = areaId and self:_getZone(areaId) or nil

    return (areaZone and areaZone.display_name)
        or (zone and zone.display_name)
        or tostring(zoneId or "Area")
end

function ZoneService:TravelToZone(player, targetZoneId, sourceHook)
    local targetAreaId = self:_resolveAreaId(targetZoneId)
    if not targetAreaId then
        return {
            ok = false,
            reason = "missing_primary_area",
            targetZoneId = targetZoneId,
        }
    end

    if not self:IsHallEntryEnabled() and self:IsHallArea(targetAreaId) then
        return {
            ok = false,
            reason = "hall_disabled",
            targetZoneId = targetZoneId,
            targetAreaId = targetAreaId,
        }
    end

    if not self:CanLeaveHall(player, sourceHook, targetAreaId) then
        return {
            ok = false,
            reason = "hall_route_required",
            targetZoneId = targetZoneId,
            targetAreaId = targetAreaId,
        }
    end

    if not self:IsZoneUnlocked(player, targetZoneId) then
        return {
            ok = false,
            reason = "locked",
            targetZoneId = targetZoneId,
            targetAreaId = targetAreaId,
            unlock = self:GetUnlockRequirement(player, targetZoneId),
        }
    end

    local destinationCFrame = self._worldBindingService:GetSpawnCFrameForZone(targetZoneId)
    if not destinationCFrame then
        return {
            ok = false,
            reason = "missing_spawn",
            targetZoneId = targetZoneId,
            targetAreaId = targetAreaId,
        }
    end

    local rootPart = getRootPart(player)
    if not rootPart then
        return {
            ok = false,
            reason = "character_not_ready",
            targetZoneId = targetZoneId,
            targetAreaId = targetAreaId,
        }
    end

    rootPart.CFrame = destinationCFrame
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero
    self._worldBindingService:SetActiveArea(player, targetAreaId)

    local currentWorld = player:FindFirstChild("CurrentWorld")
    if currentWorld and currentWorld:IsA("StringValue") then
        currentWorld.Value = targetAreaId
    end

    self:_rememberArea(player, targetAreaId)

    self._logger:Info("Player traveled to zone", {
        player = player.Name,
        targetZoneId = targetZoneId,
        targetAreaId = targetAreaId,
        sourceHook = sourceHook and sourceHook:GetFullName() or nil,
    })

    return {
        ok = true,
        targetZoneId = targetZoneId,
        targetAreaId = targetAreaId,
        position = rootPart.Position,
    }
end

function ZoneService:TravelViaHook(player, hook)
    local targetZoneId = hook and hook:GetAttribute("TargetZoneId")
    if type(targetZoneId) ~= "string" or targetZoneId == "" then
        return {
            ok = false,
            reason = "missing_target",
        }
    end

    if hook:GetAttribute("RequiresTutorialComplete") == true then
        local data = self._dataService:GetData(player)
        if not (data and HallOfWorldsLogic.isTutorialCompleted(data.GameData, data.Tutorial)) then
            return {
                ok = false,
                reason = "tutorial_required",
                targetZoneId = targetZoneId,
            }
        end
    end

    local result = self:TravelToZone(player, targetZoneId, hook)
    if result.ok == true and hook:GetAttribute("HallExitToCrystalWorld") == true then
        local data = self._dataService:GetData(player)
        if data and data.GameData then
            local hallState = HallOfWorldsLogic.normalizeState(
                data.GameData,
                self._hallConfig and self._hallConfig.version or 2
            )
            if hallState.entered_crystal_world ~= true then
                hallState.entered_crystal_world = true
                hallState.completed = true
                self._dataService:RequestSave(player, "hall_crystal_world_entry", {
                    critical = true,
                })
            end
            self:PublishHallMembership(player)
        end
    end
    return result
end

local COPIED_GATE_VISUAL = {
    CrystalWorldPortal = "CrystalWorldGateVisual",
    CrystalWorldReturnPortal = "CrystalWorldReturnGateVisual",
    HallOfWorldsPortal = "HallOfWorldsGateVisual",
}

-- Copied Home Gate models keep a stale WorldPivot. PivotTo then parks the
-- pivot at the authored point while the arch sits ~70 studs away, so the
-- invisible Portal never overlaps the visible doorway.
function ZoneService:_alignCopiedGatePortal(hook)
    local visualName = COPIED_GATE_VISUAL[hook.Name]
    if not visualName then
        return
    end
    local visual = hook.Parent and hook.Parent:FindFirstChild(visualName)
    if not (visual and visual:IsA("Model")) then
        return
    end
    local boxCf = visual:GetBoundingBox()
    local dest = Vector3.new(boxCf.Position.X, hook.Position.Y, boxCf.Position.Z)
    if (hook.Position - dest).Magnitude <= 4 then
        return
    end
    hook.CFrame = CFrame.new(dest)
    self._logger:Info("Aligned copied world gate portal to its visual", {
        hook = hook:GetFullName(),
        visual = visual:GetFullName(),
    })
end

function ZoneService:_isCombatTutorialEntryHook(hook)
    local entry = self._combatTutorialConfig and self._combatTutorialConfig.entry
    if not (entry and entry.enabled ~= false and hook and hook:IsA("BasePart")) then
        return false
    end
    return hook.Name == tostring(entry.hook_name or "")
end

-- Hall routing stays disabled. The Home Hall arch becomes the combat-tutorial
-- mission door instead of the frosted Coming Soon wall.
function ZoneService:_openCombatTutorialEntry(hook)
    -- The copied Home Hall visual sits ~50 studs from HallOfWorldsPortal (stale
    -- WorldPivot). The Coming Soon seal used to drag the hook into the opening;
    -- skipping that left the MissionDoor prompt on the offset volume.
    self:_alignCopiedGatePortal(hook)

    local entry = self._combatTutorialConfig and self._combatTutorialConfig.entry or {}
    hook:SetAttribute("HallEntryDisabled", nil)
    hook:SetAttribute("MissionId", tostring(entry.mission_id or "combat_tutorial"))
    hook.CanTouch = false
    hook.CanCollide = false
    hook.CanQuery = true

    local travelPrompt = hook:FindFirstChild(TRAVEL_PROMPT_NAME, true)
    if travelPrompt and travelPrompt:IsA("ProximityPrompt") then
        travelPrompt:Destroy()
    end

    if not CollectionService:HasTag(hook, "MissionDoor") then
        CollectionService:AddTag(hook, "MissionDoor")
    end

    local title = hook.Parent and hook.Parent:FindFirstChild("HallOfWorldsGateTitle")
    local label = tostring(entry.title or "COMBAT TRAINING")
    if title then
        for _, descendant in ipairs(title:GetDescendants()) do
            if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                descendant.Text = label
            end
        end
    end
end

function ZoneService:_isDisabledHallEntryHook(hook)
    if self:IsHallEntryEnabled() or not (hook and hook:IsA("BasePart")) then
        return false
    end
    local targetAreaId = self:_resolveAreaId(hook:GetAttribute("TargetZoneId"))
    return self:IsHallArea(targetAreaId)
end

-- Keep the Hall arch as authored scenery, but turn its travel volume into an unmistakable frosted
-- repair wall. This is server-owned as a second line of defense behind TravelToZone's rejection;
-- a stale Studio tag or client prompt can never reopen the retired route.
function ZoneService:_sealDisabledHallEntryHook(hook)
    hook:SetAttribute("HallEntryDisabled", true)
    hook.CanTouch = false
    hook.CanCollide = true
    hook.CanQuery = true

    local prompt = hook:FindFirstChild(TRAVEL_PROMPT_NAME, true)
    if prompt and prompt:IsA("ProximityPrompt") then
        prompt:Destroy()
    end

    local visualName = COPIED_GATE_VISUAL[hook.Name]
    local visual = visualName and hook.Parent and hook.Parent:FindFirstChild(visualName)
    if visual and visual:IsA("Model") then
        local boxCf, boxSize = visual:GetBoundingBox()
        local look = self._hallConfig and self._hallConfig.gate_appearance or {}
        local color = look.color or { 226, 236, 242 }
        local barrier = self._hallConfig and self._hallConfig.entry_barrier or {}
        local openingWidth = math.max(10, boxSize.X * (tonumber(barrier.width_fraction) or 0.58))
        local halfWidth = openingWidth / 2
        local bottomY = -boxSize.Y / 2 + (tonumber(barrier.bottom_inset) or 0.8)
        local archTopY = boxSize.Y / 2 - (tonumber(barrier.top_inset) or 4)
        local springY = archTopY - halfWidth
        local depth = tonumber(barrier.depth) or 3
        local segmentCount = math.max(7, math.floor(tonumber(barrier.curve_segments) or 13))
        if segmentCount % 2 == 0 then
            segmentCount += 1
        end

        local function applyAppearance(part)
            part.Anchored = true
            part.Material = Enum.Material[look.material or "Ice"] or Enum.Material.Ice
            part.Color = Color3.fromRGB(color[1] or 226, color[2] or 236, color[3] or 242)
            part.Transparency = tonumber(look.transparency) or 0.28
            part.Reflectance = tonumber(look.reflectance) or 0.04
            part.CanCollide = true
            part.CanTouch = false
            part.CanQuery = true
            part.CastShadow = false
        end

        -- The original travel hook becomes the jamb-height lower panel. At over twenty studs it
        -- remains the authoritative collision barrier even if a cap strip is streamed late.
        local lowerHeight = math.max(16, springY - bottomY)
        hook.Size = Vector3.new(openingWidth, lowerHeight, depth)
        hook.CFrame = boxCf * CFrame.new(0, bottomY + lowerHeight / 2, 0)
        applyAppearance(hook)

        -- Approximate the round top with adjacent, non-overlapping strips. Sampling each strip at
        -- its outer edge keeps every visible corner inside the authored arch instead of allowing a
        -- rectangular wall to protrude through the curved shoulders.
        local segmentWidth = openingWidth / segmentCount
        for index = 1, segmentCount do
            local capName = ("HallEntryArchCap%02d"):format(index)
            local cap = hook:FindFirstChild(capName)
            if not (cap and cap:IsA("BasePart")) then
                if cap then
                    cap:Destroy()
                end
                cap = Instance.new("Part")
                cap.Name = capName
                cap.Parent = hook
            end
            local x = -halfWidth + (index - 0.5) * segmentWidth
            local outerX = math.min(halfWidth, math.abs(x) + segmentWidth / 2)
            local rise = math.sqrt(math.max(0, halfWidth * halfWidth - outerX * outerX))
            local capHeight = math.max(0.05, rise)
            cap.Size = Vector3.new(segmentWidth, capHeight, depth)
            cap.CFrame = boxCf * CFrame.new(x, springY + capHeight / 2, 0)
            applyAppearance(cap)
            cap:SetAttribute("HallEntryArchCap", true)
        end
    end

    local title = hook.Parent and hook.Parent:FindFirstChild("HallOfWorldsGateTitle")
    if title then
        for _, descendant in ipairs(title:GetDescendants()) do
            if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                -- This sealed in-place Hall route also hosts the cross-place Merge doorway.
                -- Do not repaint its public-release title if ZoneService binds after Merge.
                local gate = self._mergeGateConfig or {}
                if hook.Name == gate.hook_name and (gate.access or {}).public == true then
                    descendant.Text = gate.title
                else
                    descendant.Text = "COMING SOON"
                end
            end
        end
    end
end

function ZoneService:_connectTravelHooks()
    local hooks = {}
    for _, hook in ipairs(self._worldBindingService:GetBound("TeleportPad")) do
        table.insert(hooks, hook)
    end
    for _, hook in ipairs(self._worldBindingService:GetBound("Portal")) do
        table.insert(hooks, hook)
    end

    for _, hook in ipairs(hooks) do
        if hook:IsA("BasePart") then
            if self:_isCombatTutorialEntryHook(hook) then
                self:_openCombatTutorialEntry(hook)
                continue
            end
            if self:_isDisabledHallEntryHook(hook) then
                self:_sealDisabledHallEntryHook(hook)
                continue
            end
            self:_alignCopiedGatePortal(hook)
            self:_seatHallGate(hook)
            self:_ensureTravelPrompt(hook)
        end

        if hook:IsA("BasePart") and not hook:GetAttribute("ZoneServiceConnected") then
            hook:SetAttribute("ZoneServiceConnected", true)
            hook.Touched:Connect(function(hit)
                self:_handleHookTouched(hook, hit)
            end)
        end
    end
end

function ZoneService:_seatHallGate(hook)
    if not CollectionService:HasTag(hook, "HallGate") then
        return
    end
    local gates = self._hallConfig and self._hallConfig.progression_gates
    if type(gates) ~= "table" then
        return
    end
    for _, definition in ipairs(gates) do
        if definition.name == hook.Name then
            local pos = definition.position
            local size = definition.size
            if type(pos) == "table" then
                hook.CFrame = CFrame.new(pos[1] or 0, pos[2] or 0, pos[3] or 0)
            end
            if type(size) == "table" then
                hook.Size = Vector3.new(
                    size[1] or hook.Size.X,
                    size[2] or hook.Size.Y,
                    size[3] or hook.Size.Z
                )
            end
            return
        end
    end
end

function ZoneService:_seatHallAreaZones()
    local maps = workspace:FindFirstChild("Maps")
    local hall = maps
        and maps:FindFirstChild(self._hallConfig and self._hallConfig.map_name or "FuturePath")
    local runtime = hall and hall:FindFirstChild("HallRuntimeBindings")
    if not runtime then
        return
    end
    local zones = self._areasConfig and self._areasConfig.zones or {}
    for areaId in pairs(self._hallRouteAreaSet or {}) do
        if areaId == "Hall_1" then
            continue
        end
        local synthetic = zones[areaId] and zones[areaId].synthetic
        local part = runtime:FindFirstChild(areaId .. "_AreaZone")
        local center = synthetic and synthetic.center
        local size = synthetic and synthetic.size
        if part and part:IsA("BasePart") and type(center) == "table" and type(size) == "table" then
            part.Size =
                Vector3.new(size.x or part.Size.X, size.y or part.Size.Y, size.z or part.Size.Z)
            part.CFrame = CFrame.new(center.x or 0, center.y or 0, center.z or 0)
        end
    end
end

function ZoneService:_seatComingSoonWalls()
    local coming = self._hallConfig and self._hallConfig.coming_soon
    local walls = coming and coming.walls
    if type(walls) ~= "table" then
        return
    end
    local maps = workspace:FindFirstChild("Maps")
    local hall = maps
        and maps:FindFirstChild(self._hallConfig and self._hallConfig.map_name or "FuturePath")
    local runtime = hall and hall:FindFirstChild("HallRuntimeBindings")
    if not runtime then
        return
    end
    local look = self._hallConfig.gate_appearance or {}
    local color = look.color or { 226, 236, 242 }
    for _, definition in ipairs(walls) do
        local name = definition.name
        if type(name) == "string" and name ~= "" then
            local wall = runtime:FindFirstChild(name)
            if not (wall and wall:IsA("BasePart")) then
                wall = Instance.new("Part")
                wall.Name = name
                wall.Anchored = true
                wall.Parent = runtime
            end
            local pos = definition.position or {}
            local size = definition.size or { 100, 28, 5 }
            wall.Size = Vector3.new(size[1] or 100, size[2] or 28, size[3] or 5)
            wall.CFrame = CFrame.new(pos[1] or 0, pos[2] or 0, pos[3] or 0)
            wall.Material = Enum.Material[look.material or "Ice"] or Enum.Material.Ice
            wall.Color = Color3.fromRGB(color[1] or 226, color[2] or 236, color[3] or 242)
            wall.Transparency = look.transparency or 0.28
            wall.Reflectance = look.reflectance or 0.04
            wall.CanCollide = true
            wall.CanTouch = false
            wall.CanQuery = true
            wall.CastShadow = false
            CollectionService:AddTag(wall, "HallComingSoon")
        end
    end
end

function ZoneService:_isPressingLockedHallGate(player, areaId)
    local root = getRootPart(player)
    if not root then
        return false
    end
    for _, gate in ipairs(CollectionService:GetTagged("HallGate")) do
        if gate:IsA("BasePart") then
            local target = gate:GetAttribute("TargetAreaId") or gate:GetAttribute("TargetZoneId")
            if tostring(target) == tostring(areaId) then
                local closest = gate.Position
                local ok, point = pcall(function()
                    return gate:GetClosestPointOnSurface(root.Position)
                end)
                if ok and typeof(point) == "Vector3" then
                    closest = point
                end
                if (root.Position - closest).Magnitude <= 10 then
                    return true
                end
            end
        end
    end
    return false
end

function ZoneService:_ensureTravelPrompt(hook)
    local prompt = hook:FindFirstChild(TRAVEL_PROMPT_NAME, true)
    if prompt and not prompt:IsA("ProximityPrompt") then
        self._logger:Warn("Travel hook has non-prompt child using reserved prompt name", {
            hook = hook:GetFullName(),
            childClass = prompt.ClassName,
        })
        return
    end

    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.Name = TRAVEL_PROMPT_NAME
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
        prompt.RequiresLineOfSight = false
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 14
        prompt.Parent = hook
    end
    if CollectionService:HasTag(hook, "HallGate") then
        prompt.Style = Enum.ProximityPromptStyle.Custom
    end

    local promptHeightFromBottom = tonumber(hook:GetAttribute("PromptHeightFromBottom"))
    if promptHeightFromBottom == nil and CollectionService:HasTag(hook, "HallGate") then
        promptHeightFromBottom = DEFAULT_HALL_PROMPT_HEIGHT_FROM_BOTTOM
    end
    if promptHeightFromBottom ~= nil then
        local attachment = hook:FindFirstChild(TRAVEL_PROMPT_ATTACHMENT_NAME)
        if attachment and not attachment:IsA("Attachment") then
            attachment:Destroy()
            attachment = nil
        end
        if not attachment then
            attachment = Instance.new("Attachment")
            attachment.Name = TRAVEL_PROMPT_ATTACHMENT_NAME
            attachment.Parent = hook
        end
        attachment.Position = Vector3.new(
            0,
            -hook.Size.Y * 0.5 + math.clamp(promptHeightFromBottom, 0, hook.Size.Y),
            0
        )
        prompt.Parent = attachment
    end

    local targetZoneId = hook:GetAttribute("TargetZoneId")
    local targetAreaId = self:_resolveAreaId(targetZoneId)
    local unlock = self:_getUnlockConfig(targetZoneId)
    local unlockCost = unlock and tonumber(unlock.cost) or 0
    local unlockCurrency = unlock and unlock.currency or nil
    local hasProgressionRequirement = unlock
        and (unlock.tutorial_required == true or (tonumber(unlock.required_level) or 0) > 0)
    local forcePrompt = hook:GetAttribute("ForcePrompt") == true
        or hook:GetAttribute("RequiresTutorialComplete") == true

    prompt.ObjectText = self:_getZoneDisplayName(targetZoneId)
    prompt.ActionText = self:_getTravelPromptActionText(targetZoneId, hook)
    prompt.Enabled = type(targetZoneId) == "string"
        and targetZoneId ~= ""
        and (forcePrompt or hasProgressionRequirement or (unlockCurrency ~= nil and unlockCost > 0))
    prompt:SetAttribute("TargetZoneId", targetZoneId)
    prompt:SetAttribute("TargetAreaId", targetAreaId)
    prompt:SetAttribute("UnlockCurrency", unlockCurrency)
    prompt:SetAttribute("UnlockCost", unlockCost)
    prompt:SetAttribute("RequiresUnlockPrompt", prompt.Enabled)
    prompt:SetAttribute("AlwaysPrompt", forcePrompt)

    if not hook:GetAttribute("ZoneServicePromptConnected") then
        hook:SetAttribute("ZoneServicePromptConnected", true)
        prompt.Triggered:Connect(function(player)
            self:_handleHookPromptTriggered(hook, player)
        end)
    end
end

function ZoneService:_getTravelPromptActionText(targetZoneId, hook)
    if hook and hook:GetAttribute("CrystalWorldReturn") == true then
        local lockAction = self._hallConfig
            and self._hallConfig.crystal_world_return
            and self._hallConfig.crystal_world_return.lock_action
        return tostring(lockAction or "Finish the Hall")
    end

    local unlock = self:_getUnlockConfig(targetZoneId)
    local currency = unlock and unlock.currency
    local cost = unlock and tonumber(unlock.cost) or 0

    if currency and cost > 0 then
        return HallOfWorldsLogic.gateButtonText(unlock)
    end

    if unlock and unlock.tutorial_required == true then
        return string.format("Reach Level %d", tonumber(unlock.required_level) or 2)
    end

    return "Travel"
end

function ZoneService:_handleHookPromptTriggered(hook, player)
    if not player then
        return
    end

    local targetZoneId = hook and hook:GetAttribute("TargetZoneId")
    if type(targetZoneId) ~= "string" or targetZoneId == "" then
        Signals.ZoneTravelResult:FireClient(player, {
            ok = false,
            reason = "missing_target",
        })
        return
    end

    if not self:IsZoneUnlocked(player, targetZoneId) then
        local unlockResult = self:UnlockZone(player, targetZoneId)
        unlockResult.unlock = unlockResult.unlock or self:GetUnlockRequirement(player, targetZoneId)
        Signals.ZoneUnlockResult:FireClient(player, unlockResult)

        if unlockResult.ok ~= true then
            return
        end
    end

    -- Hall walls drop in place. Walking through is the travel; do not snap
    -- the player to the next pad.
    if CollectionService:HasTag(hook, "HallGate") then
        return
    end

    local travelResult = self:TravelViaHook(player, hook)
    Signals.ZoneTravelResult:FireClient(player, travelResult)
end

function ZoneService:_handleHookTouched(hook, hit)
    local character = hit and hit.Parent
    local player = character and Players:GetPlayerFromCharacter(character)
    if not player then
        return
    end

    local prompt = hook:FindFirstChild(TRAVEL_PROMPT_NAME, true)
    if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
        return
    end

    local now = os.clock()
    local playerDebounce = self._touchDebounce[player] or {}
    self._touchDebounce[player] = playerDebounce
    if playerDebounce[hook] and now - playerDebounce[hook] < TOUCH_DEBOUNCE_SECONDS then
        return
    end
    playerDebounce[hook] = now

    if CollectionService:HasTag(hook, "HallGate") then
        return
    end

    local result = self:TravelViaHook(player, hook)
    Signals.ZoneTravelResult:FireClient(player, result)
end

function ZoneService:_handleAreaEntered(player, areaId)
    if not self:IsHallEntryEnabled() and self:IsHallArea(areaId) then
        self._logger:Warn("Player entered disabled Hall bounds; returning to Home Spawn", {
            player = player.Name,
            areaId = areaId,
        })
        self:TravelToZone(player, self:_crystalSpawnArea())
        return
    end

    if self:IsZoneUnlocked(player, areaId) then
        return
    end

    if self:IsHallArea(areaId) then
        if self:_isPressingLockedHallGate(player, areaId) then
            return
        end
        local unlockSet = self:_getUnlockSet(player)
        local routeAreaIds = {}
        for _, routeArea in ipairs((self._hallConfig and self._hallConfig.route) or {}) do
            if type(routeArea.area_id) == "string" then
                table.insert(routeAreaIds, routeArea.area_id)
            end
        end
        local dest = HallOfWorldsLogic.lockedEntryReturn(
            unlockSet,
            routeAreaIds,
            areaId,
            self._hallConfig and self._hallConfig.initial_area or HALL_START_AREA
        )
        self._logger:Warn("Player entered locked Hall tile; returning to last unlocked tile", {
            player = player.Name,
            areaId = areaId,
            dest = dest,
        })
        self:TravelToZone(player, dest)
        return
    end

    self._logger:Warn("Player entered locked area; returning to start area", {
        player = player.Name,
        areaId = areaId,
    })

    self:TravelToZone(player, self:GetInitialArea(player))
end

return ZoneService
