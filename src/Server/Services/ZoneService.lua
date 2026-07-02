--[[
    ZoneService

    Server-authoritative area unlock and travel service. WorldBindingService owns
    the map hooks; ZoneService owns whether a player may use them.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local WorldContext = require(ReplicatedStorage.Shared.Game.WorldContext)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local ZoneService = {}
ZoneService.__index = ZoneService

local TOUCH_DEBOUNCE_SECONDS = 1
local DEFAULT_START_AREA = "Spawn"
local TRAVEL_PROMPT_NAME = "ZoneTravelPrompt"
local UNLOCKED_AREAS_ATTRIBUTE = "UnlockedAreasJson"

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
    self._worldBindingService = self._modules.WorldBindingService
    self._areasConfig = self._configLoader:LoadConfig("areas")
    self._touchDebounce = {}
end

function ZoneService:Start()
    self:_connectTravelHooks()
    self:_setupNetworkSignals()

    self._worldBindingService.AreaEntered:Connect(function(player, areaId)
        self:_handleAreaEntered(player, areaId)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self._touchDebounce[player] = nil
    end)

    Players.PlayerAdded:Connect(function(player)
        self:_connectCharacterSpawnSafety(player)
        self:_syncUnlocksWhenDataLoads(player)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        self:_connectCharacterSpawnSafety(player)
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

    data.GameData.UnlockedAreas = setToSortedArray(set)
    self:_publishUnlockedAreas(player, set)
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

    if zone.unlock and zone.unlock.unlocked_by_default == true then
        return true
    end

    unlockSet = unlockSet or self:_getUnlockSet(player)
    if not unlockSet then
        return false
    end

    local areaId = self:_resolveAreaId(zoneId)
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
    self:_publishUnlockedAreas(player, unlockSet)
    self._dataService:RequestSave(player, "zone_lock", { critical = true })

    if self._worldBindingService:GetActiveArea(player) == areaId then
        self:TravelToZone(player, DEFAULT_START_AREA)
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
            task.wait(0.2)
            self:PlacePlayerAtZoneSpawn(
                player,
                self._worldBindingService:GetActiveArea(player) or DEFAULT_START_AREA
            )
        end)
    end)

    if player.Character then
        task.defer(function()
            self:PlacePlayerAtZoneSpawn(
                player,
                self._worldBindingService:GetActiveArea(player) or DEFAULT_START_AREA
            )
        end)
    end
end

function ZoneService:PlacePlayerAtZoneSpawn(player, zoneId)
    local spawnCFrame, areaId =
        self._worldBindingService:GetSpawnCFrameForZone(zoneId or DEFAULT_START_AREA)
    if not spawnCFrame then
        return false, "missing_spawn"
    end

    local rootPart = waitForRootPart(player, 5)
    if not rootPart then
        return false, "character_not_ready"
    end

    rootPart.CFrame = spawnCFrame
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero
    self._worldBindingService:SetActiveArea(player, areaId)

    local currentWorld = player:FindFirstChild("CurrentWorld")
    if currentWorld and currentWorld:IsA("StringValue") then
        currentWorld.Value = areaId
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

        local currency = unlock.currency
        local cost = tonumber(unlock.cost) or 0
        if currency and cost > 0 then
            if not self._dataService:CanAfford(player, currency, cost) then
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
            self._dataService:RemoveCurrency(player, currency, cost, "zone_unlock")
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
    elseif realm == "hell" then
        fireGameEvent(player, "hell_area_unlocked", { zoneId = zoneId, areaId = areaId })
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

function ZoneService:_syncUnlocksWhenDataLoads(player)
    task.spawn(function()
        local startedAt = os.clock()
        while player.Parent and player:GetAttribute("DataLoaded") ~= true do
            if os.clock() - startedAt > 30 then
                return
            end
            task.wait(0.25)
        end

        if player.Parent then
            self:GetUnlockedZones(player)
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

    return self:TravelToZone(player, targetZoneId, hook)
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

function ZoneService:_ensureTravelPrompt(hook)
    local prompt = hook:FindFirstChild(TRAVEL_PROMPT_NAME)
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
        prompt.RequiresLineOfSight = false
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 14
        prompt.Parent = hook
    end

    local targetZoneId = hook:GetAttribute("TargetZoneId")
    local targetAreaId = self:_resolveAreaId(targetZoneId)
    local unlock = self:_getUnlockConfig(targetZoneId)
    local unlockCost = unlock and tonumber(unlock.cost) or 0
    local unlockCurrency = unlock and unlock.currency or nil

    prompt.ObjectText = self:_getZoneDisplayName(targetZoneId)
    prompt.ActionText = self:_getTravelPromptActionText(targetZoneId)
    prompt.Enabled = type(targetZoneId) == "string"
        and targetZoneId ~= ""
        and unlockCurrency ~= nil
        and unlockCost > 0
    prompt:SetAttribute("TargetZoneId", targetZoneId)
    prompt:SetAttribute("TargetAreaId", targetAreaId)
    prompt:SetAttribute("UnlockCurrency", unlockCurrency)
    prompt:SetAttribute("UnlockCost", unlockCost)
    prompt:SetAttribute("RequiresUnlockPrompt", prompt.Enabled)

    if not hook:GetAttribute("ZoneServicePromptConnected") then
        hook:SetAttribute("ZoneServicePromptConnected", true)
        prompt.Triggered:Connect(function(player)
            self:_handleHookPromptTriggered(hook, player)
        end)
    end
end

function ZoneService:_getTravelPromptActionText(targetZoneId)
    local unlock = self:_getUnlockConfig(targetZoneId)
    local currency = unlock and unlock.currency
    local cost = unlock and tonumber(unlock.cost) or 0

    if currency and cost > 0 then
        return string.format("Unlock %d %s", cost, currency)
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

    local travelResult = self:TravelViaHook(player, hook)
    Signals.ZoneTravelResult:FireClient(player, travelResult)
end

function ZoneService:_handleHookTouched(hook, hit)
    local character = hit and hit.Parent
    local player = character and Players:GetPlayerFromCharacter(character)
    if not player then
        return
    end

    local now = os.clock()
    local playerDebounce = self._touchDebounce[player] or {}
    self._touchDebounce[player] = playerDebounce
    if playerDebounce[hook] and now - playerDebounce[hook] < TOUCH_DEBOUNCE_SECONDS then
        return
    end
    playerDebounce[hook] = now

    local result = self:TravelViaHook(player, hook)
    Signals.ZoneTravelResult:FireClient(player, result)
end

function ZoneService:_handleAreaEntered(player, areaId)
    if self:IsZoneUnlocked(player, areaId) then
        return
    end

    self._logger:Warn("Player entered locked area; returning to start area", {
        player = player.Name,
        areaId = areaId,
    })

    self:TravelToZone(player, DEFAULT_START_AREA)
end

return ZoneService
