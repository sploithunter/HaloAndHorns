--[[
    WorldTravelService — server authority for the World Travel power's realm -> origin menu.

    LayerService owns realm access, recurring traversal cost, and CurrentLayer. ZoneService owns
    persisted origin unlocks and spawn placement. This service exposes only their intersection and
    rebuilds it on selection, so a forged client cannot travel to a locked or unbuilt destination.
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
    local usable, built, quotes = {}, {}, {}
    for _, layerId in ipairs(travelConfig.layer_order or {}) do
        local quote = self._layerService:CanUseLayer(player, layerId)
        if quote.ok then
            usable[layerId] = true
            quotes[layerId] = quote
        end
        if self:_isBuilt(layerId) then
            built[layerId] = true
        end
    end
    return WorldTravelLogic.catalog(travelConfig, self._areasConfig, {
        usableLayers = usable,
        builtLayers = built,
        unlockedZones = self._zoneService:GetUnlockedZones(player),
        quotes = quotes,
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
    local layerResult = self._layerService:UseLayer(player, current.layer)
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
