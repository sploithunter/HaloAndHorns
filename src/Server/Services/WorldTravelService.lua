--[[
    WorldTravelService — server authority for the World Travel power's realm -> origin menu.

    LayerService owns CurrentLayer and physical realm movement. ZoneService owns persisted origin
    unlocks and spawn placement. A saved origin unlock proves the player has reached that realm;
    World Travel returns there without reapplying first-entry Soul/token gates. The server rebuilds
    the catalog on selection, so a forged client cannot travel to a locked or unbuilt destination.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local WorldTravelLogic = require(ReplicatedStorage.Shared.Game.WorldTravelLogic)

local WorldTravelService = {}
WorldTravelService.__index = WorldTravelService

function WorldTravelService.new()
    return setmetatable({}, WorldTravelService)
end

function WorldTravelService:Init()
    self._logger = self._modules.Logger
    self._layerService = self._modules.LayerService
    self._zoneService = self._modules.ZoneService
    self._worldBindingService = self._modules.WorldBindingService
    self._layersConfig = self._modules.ConfigLoader:LoadConfig("layers")
    self._areasConfig = self._modules.ConfigLoader:LoadConfig("areas")
    self._powerService = nil
end

function WorldTravelService:BindPowerService(powerService)
    self._powerService = powerService
end

function WorldTravelService:_isBuilt(layerId)
    local maps = Workspace:FindFirstChild("Maps")
    if not maps then
        return false
    end
    return maps:FindFirstChild(WorldTravelLogic.mapFolder(layerId)) ~= nil
end

function WorldTravelService:GetCatalog(player)
    local travelConfig = self._layersConfig.world_travel or {}
    local built = {}
    for _, layerId in ipairs(travelConfig.layer_order or {}) do
        if self:_isBuilt(layerId) then
            built[layerId] = true
        end
    end
    return WorldTravelLogic.catalog(travelConfig, self._areasConfig, {
        builtLayers = built,
        unlockedZones = self._zoneService:GetUnlockedZones(player),
        currentLayer = self._layerService:GetCurrentLayer(player),
        currentArea = player:GetAttribute("CurrentArea"),
    })
end

function WorldTravelService:Open(player)
    local catalog = self:GetCatalog(player)
    Signals.WorldTravel_Open:FireClient(player, {
        layers = catalog,
        currentLayer = self._layerService:GetCurrentLayer(player),
    })
    return { ok = true, pending = true, destinations = #catalog }
end

function WorldTravelService:Prepare(player, request)
    if type(request) ~= "table" then
        return { ok = false, reason = "invalid_destination" }
    end
    local layerId = request.layer
    local originId = request.origin
    if type(layerId) ~= "string" or type(originId) ~= "string" then
        return { ok = false, reason = "invalid_destination" }
    end
    local layer, origin = WorldTravelLogic.find(self:GetCatalog(player), layerId, originId)
    if not layer or not origin then
        return { ok = false, reason = "destination_locked" }
    end
    if not self._worldBindingService:GetSpawnCFrameForZone(origin.zoneId) then
        return { ok = false, reason = "missing_spawn" }
    end
    local character = player.Character
    if not (character and character:FindFirstChild("HumanoidRootPart")) then
        return { ok = false, reason = "character_not_ready" }
    end
    return {
        ok = true,
        layer = layer.id,
        origin = origin.id,
        zoneId = origin.zoneId,
        cost = layer.cost,
        currency = layer.currency,
    }
end

function WorldTravelService:Travel(player, prepared)
    local current = self:Prepare(player, prepared)
    if not current.ok then
        return current
    end
    -- This is a return to a persisted unlocked destination, not a first realm entry. The catalog
    -- validation above is the authority; force prevents LayerService from reapplying alignment and
    -- traversal-token gates that would hide already-unlocked opposite-alignment realms.
    local layerResult = self._layerService:UseLayer(player, current.layer, { force = true })
    if not layerResult.ok then
        return layerResult
    end
    local zoneResult = self._zoneService:TravelToZone(player, current.zoneId)
    if not zoneResult.ok then
        return zoneResult
    end
    self._logger:Info("World Travel completed", {
        player = player.Name,
        layer = current.layer,
        origin = current.origin,
        zone = current.zoneId,
    })
    return {
        ok = true,
        layer = current.layer,
        origin = current.origin,
        zoneId = current.zoneId,
        cost = layerResult.cost,
        currency = layerResult.currency,
    }
end

function WorldTravelService:Select(player, request)
    local result
    if self._powerService then
        result = self._powerService:Cast(player, "world_travel", {
            worldTravelDestination = request,
        })
    else
        result = { ok = false, reason = "travel_unavailable" }
    end
    Signals.WorldTravel_Result:FireClient(player, result)
    return result
end

function WorldTravelService:Start()
    Signals.WorldTravel_Select.OnServerEvent:Connect(function(player, request)
        self:Select(player, request)
    end)
end

return WorldTravelService
