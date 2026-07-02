--[[
    WorldBindingService

    Binds Studio-authored map hooks to config-defined gameplay areas.
    In auto/synthetic map modes it also creates valid baseplate hooks so the
    same services can run without a hand-built world.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local WorldBindingService = {}
WorldBindingService.__index = WorldBindingService

local VALID_ZONE_KINDS = {
    world = true,
    island = true,
    area = true,
}

local function toVector3(value, fallback)
    fallback = fallback or Vector3.zero
    if typeof(value) == "Vector3" then
        return value
    end
    if type(value) ~= "table" then
        return fallback
    end

    return Vector3.new(
        tonumber(value.x or value.X or value[1]) or fallback.X,
        tonumber(value.y or value.Y or value[2]) or fallback.Y,
        tonumber(value.z or value.Z or value[3]) or fallback.Z
    )
end

local function ensureFolder(parent, name)
    local folder = parent:FindFirstChild(name)
    if not folder or not folder:IsA("Folder") then
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = parent
    end
    return folder
end

local function ensureNumberValue(parent, name, value)
    local numberValue = parent:FindFirstChild(name)
    if not numberValue or not numberValue:IsA("NumberValue") then
        numberValue = Instance.new("NumberValue")
        numberValue.Name = name
        numberValue.Parent = parent
    end
    numberValue.Value = tonumber(value) or 0
    return numberValue
end

local function ensurePart(parent, name, className)
    local part = parent:FindFirstChild(name)
    if not part or not part:IsA("BasePart") then
        if part then
            part:Destroy()
        end
        part = Instance.new(className or "Part")
        part.Name = name
        part.Parent = parent
    end
    return part
end

local function addTag(instance, tag)
    if not CollectionService:HasTag(instance, tag) then
        CollectionService:AddTag(instance, tag)
    end
end

local function getPrimaryPartOrSelf(instance)
    if not instance then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance
    end
    if instance:IsA("Model") then
        return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function getInstanceCenter(instance)
    local part = getPrimaryPartOrSelf(instance)
    if part then
        return part.Position
    end
    return nil
end

local function sortZoneIds(zones, predicate)
    local ids = {}
    for zoneId, zone in pairs(zones or {}) do
        if not predicate or predicate(zoneId, zone) then
            table.insert(ids, zoneId)
        end
    end

    table.sort(ids, function(a, b)
        local left = zones[a].order or 9999
        local right = zones[b].order or 9999
        if left == right then
            return a < b
        end
        return left < right
    end)

    return ids
end

function WorldBindingService:_markerRaycastExclusions()
    local exclusions = {}
    for tagName in pairs(self._markersConfig.tags or {}) do
        for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
            if instance:IsDescendantOf(workspace) then
                table.insert(exclusions, instance)
            end
        end
    end
    return exclusions
end

function WorldBindingService:_findGroundSpawnPosition(areaId)
    local playerSpawn = self._playerSpawnsByArea[areaId]
    local playerSpawnPart = getPrimaryPartOrSelf(playerSpawn)
    if playerSpawnPart then
        return playerSpawnPart.Position + Vector3.new(0, 5, 0)
    end

    local areaZone = self._areaZoneById[areaId]
    local center = getInstanceCenter(areaZone) or self:_areaCenter(areaId)
    local rayHeight = 500
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = self:_markerRaycastExclusions()
    params.IgnoreWater = true

    local result = workspace:Raycast(
        center + Vector3.new(0, rayHeight, 0),
        Vector3.new(0, -rayHeight * 2, 0),
        params
    )

    if result then
        return result.Position + Vector3.new(0, 5, 0)
    end

    for _, spawnZone in ipairs(self._spawnZonesByArea[areaId] or {}) do
        local part = getPrimaryPartOrSelf(spawnZone)
        if part then
            return part.Position + Vector3.new(0, (part.Size.Y * 0.5) + 5, 0)
        end
    end

    return nil
end

function WorldBindingService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._areaEntered = Instance.new("BindableEvent")
    self._areaExited = Instance.new("BindableEvent")
    self.AreaEntered = self._areaEntered.Event
    self.AreaExited = self._areaExited.Event
    self._boundByTag = {}
    self._zoneById = {}
    self._areaZoneById = {}
    self._playerSpawnsByArea = {}
    self._spawnZonesByArea = {}
    self._teleportPadsByArea = {}
    self._portalsByZone = {}
    self._activeAreaByPlayer = {}

    self._gameConfig = self._configLoader:LoadConfig("game")
    self._areasConfig = self._configLoader:LoadConfig("areas")
    self._markersConfig = self._configLoader:LoadConfig("markers")
    self._breakablesConfig = self._configLoader:LoadConfig("breakables")
    self._petsConfig = self._configLoader:LoadConfig("pets")
    self._enchantsConfig = self._configLoader:LoadConfig("enchants")
    self._mapMode = (self._gameConfig.map and self._gameConfig.map.mode) or "auto"

    self:_validateZoneTree()
end

function WorldBindingService:Start()
    self:RebuildBindings()
    Players.PlayerRemoving:Connect(function(player)
        self._activeAreaByPlayer[player] = nil
    end)
end

function WorldBindingService:_validateZoneTree()
    local zones = self._areasConfig.zones or {}

    for zoneId, zone in pairs(zones) do
        if zone.id ~= zoneId then
            error("areas.zones." .. tostring(zoneId) .. ".id must match table key")
        end
        if not VALID_ZONE_KINDS[zone.kind] then
            error("areas.zones." .. tostring(zoneId) .. ".kind is invalid")
        end
        if zone.parent and not zones[zone.parent] then
            error("areas.zones." .. tostring(zoneId) .. ".parent references missing zone")
        end
    end

    local visiting = {}
    local visited = {}
    local function visit(zoneId)
        if visiting[zoneId] then
            error("areas zone cycle detected at " .. tostring(zoneId))
        end
        if visited[zoneId] then
            return
        end
        visiting[zoneId] = true
        local zone = zones[zoneId]
        if zone and zone.parent then
            visit(zone.parent)
        end
        visiting[zoneId] = nil
        visited[zoneId] = true
    end

    for zoneId in pairs(zones) do
        visit(zoneId)
    end
end

function WorldBindingService:_hasAuthoredHooks()
    for tagName in pairs(self._markersConfig.tags or {}) do
        for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
            if instance:IsDescendantOf(workspace) and not instance:GetAttribute("Synthetic") then
                return true
            end
        end
    end

    return false
end

function WorldBindingService:_getSyntheticRoot()
    local rootName = (self._markersConfig.synthetic and self._markersConfig.synthetic.root_name)
        or "SyntheticMap"
    local root = workspace:FindFirstChild(rootName)
    if not root or not root:IsA("Folder") then
        if root then
            root:Destroy()
        end
        root = Instance.new("Folder")
        root.Name = rootName
        root.Parent = workspace
    end
    root:SetAttribute("GeneratedByWorldBindingService", true)
    return root
end

function WorldBindingService:_getAreaIndex(areaId)
    local zones = self._areasConfig.zones or {}
    local ids = sortZoneIds(zones, function(_, zone)
        return zone.kind == "area"
    end)

    for index, id in ipairs(ids) do
        if id == areaId then
            return index
        end
    end
    return 1
end

function WorldBindingService:_spawnPosition(areaId)
    local zone = self._areasConfig.zones and self._areasConfig.zones[areaId]
    local synthetic = zone and zone.synthetic
    if synthetic and synthetic.spawn_position then
        return toVector3(synthetic.spawn_position, self:_areaCenter(areaId) + Vector3.new(0, 4, 0))
    end

    return self:_areaCenter(areaId) + Vector3.new(0, 4, 0)
end

function WorldBindingService:_areaFloorY(areaId)
    local zone = self._areasConfig.zones and self._areasConfig.zones[areaId]
    local synthetic = zone and zone.synthetic
    return tonumber(synthetic and synthetic.floor_y) or 0
end

function WorldBindingService:_areaCenter(areaId)
    local zone = self._areasConfig.zones and self._areasConfig.zones[areaId]
    local synthetic = zone and zone.synthetic
    if synthetic and synthetic.center then
        return toVector3(synthetic.center, Vector3.zero)
    end

    local spacing = (self._markersConfig.synthetic and self._markersConfig.synthetic.area_spacing)
        or 220
    return Vector3.new((self:_getAreaIndex(areaId) - 1) * spacing, 0, 0)
end

function WorldBindingService:_createAreaFloor(root, areaId)
    local floorsFolder = ensureFolder(root, "Floors")
    local floor = ensurePart(floorsFolder, "Floor_" .. areaId)
    local center = self:_areaCenter(areaId)
    local size = self:_areaSize(areaId)
    floor.Anchored = true
    floor.CanCollide = true
    floor.CanTouch = true
    floor.CanQuery = true
    floor.Transparency = 0
    floor.Color = Color3.fromRGB(46, 158, 74)
    floor.Material = Enum.Material.Grass
    floor.Size = Vector3.new(size.X, size.Y, size.Z)
    floor.Position = Vector3.new(center.X, self:_areaFloorY(areaId) - (size.Y / 2), center.Z)
    floor:SetAttribute("AreaId", areaId)
    floor:SetAttribute("Synthetic", true)
    return floor
end

function WorldBindingService:_areaSize(areaId)
    local zone = self._areasConfig.zones and self._areasConfig.zones[areaId]
    local synthetic = zone and zone.synthetic
    if synthetic and synthetic.size then
        return toVector3(synthetic.size, Vector3.new(160, 4, 160))
    end
    return toVector3(
        self._markersConfig.synthetic and self._markersConfig.synthetic.default_area_size,
        Vector3.new(160, 4, 160)
    )
end

function WorldBindingService:_createZoneHook(root, zoneId, zone)
    local zonesFolder = ensureFolder(root, "Zones")
    local part = ensurePart(zonesFolder, "Zone_" .. zoneId)
    local center =
        self:_areaCenter(zone.kind == "area" and zoneId or (zone.primary_area or "Spawn"))
    local size = self:_areaSize(zone.kind == "area" and zoneId or (zone.primary_area or "Spawn"))
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = true
    part.CanQuery = true
    part.Transparency = 1
    part.Size = size
    part.Position = Vector3.new(center.X, center.Y, center.Z)
    part:SetAttribute("ZoneId", zoneId)
    part:SetAttribute("Kind", zone.kind)
    part:SetAttribute("ParentZoneId", zone.parent)
    part:SetAttribute("Synthetic", true)
    addTag(part, "Zone")

    if zone.kind == "area" then
        part:SetAttribute("AreaId", zoneId)
        addTag(part, "AreaZone")
    end

    return part
end

function WorldBindingService:_ensureLegacyAreaFolders(areaId)
    local gameFolder = ensureFolder(workspace, "Game")
    gameFolder:SetAttribute("GeneratedFromConfig", true)

    local breakablesFolder = ensureFolder(gameFolder, "Breakables")
    local crystalsFolder = ensureFolder(breakablesFolder, "Crystals")
    local worldFolder = ensureFolder(crystalsFolder, areaId)
    ensureFolder(worldFolder, "Items")

    local worldConfig = self._breakablesConfig.worlds and self._breakablesConfig.worlds[areaId]
    local defaultMax = self._breakablesConfig.defaults
            and self._breakablesConfig.defaults.max_per_world
        or 0
    ensureNumberValue(worldFolder, "CurrentItems", 0)
    ensureNumberValue(worldFolder, "Max", (worldConfig and worldConfig.max) or defaultMax)

    return gameFolder, worldFolder
end

function WorldBindingService:_createSpawnZone(areaId)
    local _, worldFolder = self:_ensureLegacyAreaFolders(areaId)
    local worldConfig = self._breakablesConfig.worlds and self._breakablesConfig.worlds[areaId]
    local spawnAreaConfig = worldConfig and worldConfig.spawn_area or {}
    local syntheticConfig = self._markersConfig.synthetic
            and self._markersConfig.synthetic.spawn_zone
        or {}
    local center = self:_areaCenter(areaId)

    local spawnZone =
        ensurePart(worldFolder, spawnAreaConfig.name or syntheticConfig.name or "SpawnArea")
    spawnZone.Anchored = true
    spawnZone.CanCollide = false
    spawnZone.CanTouch = true
    spawnZone.CanQuery = true
    spawnZone.Transparency = tonumber(spawnAreaConfig.transparency or syntheticConfig.transparency)
        or 1
    spawnZone.Size =
        toVector3(spawnAreaConfig.size or syntheticConfig.size, Vector3.new(140, 1, 140))
    local configuredPosition = spawnAreaConfig.position
            and toVector3(spawnAreaConfig.position, center)
        or Vector3.new(center.X, tonumber(syntheticConfig.y) or center.Y, center.Z)
    spawnZone.Position = configuredPosition
    spawnZone:SetAttribute("AreaId", areaId)
    spawnZone:SetAttribute("SpawnerId", "spawn_crystals")
    spawnZone:SetAttribute("Synthetic", true)
    spawnZone:SetAttribute("DepthOffset", 0)
    if worldConfig and worldConfig.max then
        spawnZone:SetAttribute("MaxCountOverride", worldConfig.max)
    end
    addTag(spawnZone, "SpawnZone")

    return spawnZone
end

function WorldBindingService:_createEggHooks(areaId)
    local zone = self._areasConfig.zones and self._areasConfig.zones[areaId]
    local synthetic = zone and zone.synthetic
    local eggStands = synthetic and synthetic.egg_stands
    if type(eggStands) ~= "table" then
        return
    end

    local gameFolder = ensureFolder(workspace, "Game")
    local eggsFolder = ensureFolder(gameFolder, "Eggs")
    local spawnPointsFolder = ensureFolder(eggsFolder, "SpawnPoints")

    for _, standConfig in ipairs(eggStands) do
        local eggId = tostring(standConfig.egg_id or "")
        if eggId ~= "" then
            local spawnId = tostring(standConfig.spawn_id or eggId)
            local spawnPoint = nil
            for _, child in ipairs(spawnPointsFolder:GetChildren()) do
                if child:IsA("BasePart") and child:GetAttribute("SpawnId") == spawnId then
                    spawnPoint = child
                    break
                end
            end
            if not spawnPoint then
                spawnPoint = Instance.new("Part")
                spawnPoint.Name = "EggSpawnPoint"
                spawnPoint.Parent = spawnPointsFolder
            end

            spawnPoint.Anchored = true
            spawnPoint.CanCollide = false
            spawnPoint.CanTouch = false
            spawnPoint.CanQuery = false
            spawnPoint.Transparency = 1
            spawnPoint.Size = Vector3.new(3, 1, 3)
            spawnPoint.Position = toVector3(standConfig.position, self:_areaCenter(areaId))
            spawnPoint:SetAttribute("AreaId", areaId)
            spawnPoint:SetAttribute("EggId", eggId)
            spawnPoint:SetAttribute("EggType", eggId)
            spawnPoint:SetAttribute("SpawnId", spawnId)
            spawnPoint:SetAttribute("Synthetic", true)
            spawnPoint:SetAttribute("SpawnMode", "spawn_model")
            addTag(spawnPoint, "EggStand")
        end
    end
end

function WorldBindingService:_createPodiumHook(areaId)
    local root = self:_getSyntheticRoot()
    local anchorsFolder = ensureFolder(root, "Anchors")
    local podiumName = areaId == "Spawn" and "PetDisplay_Podium" or ("PetDisplay_Podium_" .. areaId)
    local podium = ensurePart(anchorsFolder, podiumName)
    local center = self:_areaCenter(areaId)
    podium.Anchored = true
    podium.CanCollide = false
    podium.CanTouch = false
    podium.CanQuery = true
    podium.Transparency = 1
    podium.Size = Vector3.new(6, 1, 6)
    podium.Position = center + Vector3.new(0, 0.5, 34)
    podium:SetAttribute("AreaId", areaId)
    podium:SetAttribute("Slot", 1)
    podium:SetAttribute("Synthetic", true)
    addTag(podium, "PODPodium")
end

function WorldBindingService:_createTravelPad(sourceAreaId, targetZoneId, offset, namePrefix)
    if self:_hasTeleportPad(sourceAreaId, targetZoneId) then
        return nil
    end

    local root = self:_getSyntheticRoot()
    local travelFolder = ensureFolder(root, "Travel")
    local padName =
        string.format("%s_%s_to_%s", namePrefix or "TeleportPad", sourceAreaId, targetZoneId)
    local pad = ensurePart(travelFolder, padName)
    local center = self:_areaCenter(sourceAreaId)

    pad.Anchored = true
    pad.CanCollide = false
    pad.CanTouch = true
    pad.CanQuery = true
    pad.Transparency = 0.35
    pad.Color = Color3.fromRGB(80, 220, 255)
    pad.Material = Enum.Material.Neon
    pad.Size = Vector3.new(12, 1, 12)
    pad.Position = center + (offset or Vector3.new(0, 0.5, 52))
    pad:SetAttribute("AreaId", sourceAreaId)
    pad:SetAttribute("TargetZoneId", targetZoneId)
    pad:SetAttribute("Synthetic", true)
    addTag(pad, "TeleportPad")
    return pad
end

function WorldBindingService:_createPortal(sourceZoneId, targetZoneId, sourceAreaId, offset)
    if self:_hasPortal(sourceZoneId, targetZoneId) then
        return nil
    end

    local root = self:_getSyntheticRoot()
    local travelFolder = ensureFolder(root, "Travel")
    local portalName = string.format("Portal_%s_to_%s", sourceZoneId, targetZoneId)
    local portal = ensurePart(travelFolder, portalName)
    local center = self:_areaCenter(sourceAreaId)

    portal.Anchored = true
    portal.CanCollide = false
    portal.CanTouch = true
    portal.CanQuery = true
    portal.Transparency = 0.25
    portal.Color = Color3.fromRGB(180, 90, 255)
    portal.Material = Enum.Material.Neon
    portal.Size = Vector3.new(10, 16, 2)
    portal.Position = center + (offset or Vector3.new(52, 8, 0))
    portal:SetAttribute("ZoneId", sourceZoneId)
    portal:SetAttribute("TargetZoneId", targetZoneId)
    portal:SetAttribute("Synthetic", true)
    addTag(portal, "Portal")
    return portal
end

function WorldBindingService:_hasTeleportPad(sourceAreaId, targetZoneId)
    for _, instance in ipairs(CollectionService:GetTagged("TeleportPad")) do
        if
            instance:IsDescendantOf(workspace)
            and instance:GetAttribute("AreaId") == sourceAreaId
            and instance:GetAttribute("TargetZoneId") == targetZoneId
        then
            return true
        end
    end
    return false
end

function WorldBindingService:_hasPortal(sourceZoneId, targetZoneId)
    for _, instance in ipairs(CollectionService:GetTagged("Portal")) do
        if
            instance:IsDescendantOf(workspace)
            and instance:GetAttribute("ZoneId") == sourceZoneId
            and instance:GetAttribute("TargetZoneId") == targetZoneId
        then
            return true
        end
    end
    return false
end

function WorldBindingService:_childrenOf(parentZoneId, kind)
    return sortZoneIds(self._areasConfig.zones or {}, function(_, zone)
        return zone.parent == parentZoneId and (not kind or zone.kind == kind)
    end)
end

function WorldBindingService:_areaIds()
    return sortZoneIds(self._areasConfig.zones or {}, function(_, zone)
        return zone.kind == "area"
    end)
end

function WorldBindingService:_createTravelHooks()
    local areaIds = self:_areaIds()
    for index, areaId in ipairs(areaIds) do
        local nextAreaId = areaIds[index + 1]
        local previousAreaId = areaIds[index - 1]
        if nextAreaId then
            self:_createTravelPad(areaId, nextAreaId, Vector3.new(52, 0.5, 0), "TeleportPad")
        end
        if previousAreaId then
            self:_createTravelPad(areaId, previousAreaId, Vector3.new(-52, 0.5, 0), "TeleportPad")
        end
    end

    for zoneId, zone in pairs(self._areasConfig.zones or {}) do
        if zone.kind ~= "area" then
            local children = self:_childrenOf(zone.parent, zone.kind)
            for index, childZoneId in ipairs(children) do
                if childZoneId == zoneId then
                    local nextZoneId = children[index + 1]
                    local previousZoneId = children[index - 1]
                    local sourceAreaId = self:GetPrimaryAreaForZone(zoneId)
                    if sourceAreaId and nextZoneId then
                        self:_createPortal(zoneId, nextZoneId, sourceAreaId, Vector3.new(0, 8, 52))
                    end
                    if sourceAreaId and previousZoneId then
                        self:_createPortal(
                            zoneId,
                            previousZoneId,
                            sourceAreaId,
                            Vector3.new(0, 8, -52)
                        )
                    end
                end
            end
        end
    end
end

function WorldBindingService:_synthesizeMissingHooks()
    local root = self:_getSyntheticRoot()
    for zoneId, zone in pairs(self._areasConfig.zones or {}) do
        self:_createZoneHook(root, zoneId, zone)
        if zone.kind == "area" then
            self:_createAreaFloor(root, zoneId)
            self:_createSpawnZone(zoneId)
            self:_createEggHooks(zoneId)
            self:_createPodiumHook(zoneId)
        end
    end
    self:_createTravelHooks()
end

function WorldBindingService:_validateAttribute(instance, attributeName, expectedType)
    local value = instance:GetAttribute(attributeName)
    if value == nil then
        return false, "missing attribute " .. attributeName
    end
    if typeof(value) ~= expectedType then
        return false,
            string.format(
                "attribute %s expected %s, got %s",
                attributeName,
                expectedType,
                typeof(value)
            )
    end
    return true
end

function WorldBindingService:_validateReference(instance, tagName)
    local zones = self._areasConfig.zones or {}
    if tagName == "Zone" then
        local zoneId = instance:GetAttribute("ZoneId")
        local kind = instance:GetAttribute("Kind")
        if not zones[zoneId] then
            return false, "ZoneId references missing areas.zones entry"
        end
        if zones[zoneId].kind ~= kind then
            return false, "Kind does not match areas.zones." .. tostring(zoneId)
        end
    elseif tagName == "AreaZone" then
        local areaId = instance:GetAttribute("AreaId")
        if not zones[areaId] or zones[areaId].kind ~= "area" then
            return false, "AreaId must reference an area zone"
        end
    elseif tagName == "SpawnZone" then
        local areaId = instance:GetAttribute("AreaId")
        if not zones[areaId] or zones[areaId].kind ~= "area" then
            return false, "AreaId must reference an area zone"
        end
        if not (self._breakablesConfig.worlds and self._breakablesConfig.worlds[areaId]) then
            return false, "AreaId has no matching breakables.worlds entry"
        end
    elseif tagName == "PlayerSpawn" then
        local areaId = instance:GetAttribute("AreaId")
        if not zones[areaId] or zones[areaId].kind ~= "area" then
            return false, "AreaId must reference an area zone"
        end
        local zoneId = instance:GetAttribute("ZoneId")
        if zoneId ~= nil and not zones[zoneId] then
            return false, "ZoneId references missing areas.zones entry"
        end
    elseif tagName == "TeleportPad" or tagName == "Portal" then
        local targetZoneId = instance:GetAttribute("TargetZoneId")
        if not zones[targetZoneId] then
            return false, "TargetZoneId references missing areas.zones entry"
        end
        if tagName == "TeleportPad" then
            local areaId = instance:GetAttribute("AreaId")
            if not zones[areaId] or zones[areaId].kind ~= "area" then
                return false, "AreaId must reference an area zone"
            end
        else
            local zoneId = instance:GetAttribute("ZoneId")
            if not zones[zoneId] then
                return false, "ZoneId references missing areas.zones entry"
            end
        end
    elseif tagName == "EggStand" then
        local eggId = instance:GetAttribute("EggId")
        if not (self._petsConfig.egg_sources and self._petsConfig.egg_sources[eggId]) then
            return false, "EggId references missing pets.egg_sources entry"
        end
    elseif tagName == "EnchanterStation" then
        local enchanterId = instance:GetAttribute("EnchanterId")
        if not (self._enchantsConfig.stations and self._enchantsConfig.stations[enchanterId]) then
            return false, "EnchanterId references missing enchants.stations entry"
        end
    end
    return true
end

function WorldBindingService:_bindInstance(tagName, instance)
    local tagConfig = self._markersConfig.tags[tagName]
    if not tagConfig then
        return
    end
    if not instance:IsDescendantOf(workspace) then
        return
    end

    for attributeName, expectedType in pairs(tagConfig.required_attributes or {}) do
        local ok, message = self:_validateAttribute(instance, attributeName, expectedType)
        if not ok then
            error(
                string.format(
                    "Invalid map hook %s [%s]: %s",
                    instance:GetFullName(),
                    tagName,
                    message
                )
            )
        end
    end

    for attributeName, expectedType in pairs(tagConfig.optional_attributes or {}) do
        local value = instance:GetAttribute(attributeName)
        if value ~= nil and typeof(value) ~= expectedType then
            error(
                string.format(
                    "Invalid map hook %s [%s]: attribute %s expected %s, got %s",
                    instance:GetFullName(),
                    tagName,
                    attributeName,
                    expectedType,
                    typeof(value)
                )
            )
        end
    end

    local ok, message = self:_validateReference(instance, tagName)
    if not ok then
        error(
            string.format("Invalid map hook %s [%s]: %s", instance:GetFullName(), tagName, message)
        )
    end

    self._boundByTag[tagName] = self._boundByTag[tagName] or {}
    table.insert(self._boundByTag[tagName], instance)

    if tagName == "Zone" then
        self._zoneById[instance:GetAttribute("ZoneId")] = instance
    elseif tagName == "AreaZone" then
        self._areaZoneById[instance:GetAttribute("AreaId")] = instance
        self:_connectAreaZone(instance)
    elseif tagName == "PlayerSpawn" then
        self._playerSpawnsByArea[instance:GetAttribute("AreaId")] = instance
    elseif tagName == "SpawnZone" then
        local areaId = instance:GetAttribute("AreaId")
        self._spawnZonesByArea[areaId] = self._spawnZonesByArea[areaId] or {}
        table.insert(self._spawnZonesByArea[areaId], instance)
    elseif tagName == "TeleportPad" then
        local areaId = instance:GetAttribute("AreaId")
        self._teleportPadsByArea[areaId] = self._teleportPadsByArea[areaId] or {}
        table.insert(self._teleportPadsByArea[areaId], instance)
    elseif tagName == "Portal" then
        local zoneId = instance:GetAttribute("ZoneId")
        self._portalsByZone[zoneId] = self._portalsByZone[zoneId] or {}
        table.insert(self._portalsByZone[zoneId], instance)
    end
end

function WorldBindingService:_connectAreaZone(areaZone)
    if areaZone:GetAttribute("WorldBindingConnected") then
        return
    end
    areaZone:SetAttribute("WorldBindingConnected", true)

    areaZone.Touched:Connect(function(hit)
        local character = hit and hit.Parent
        if not character then
            return
        end
        local player = Players:GetPlayerFromCharacter(character)
        if not player then
            return
        end

        local areaId = areaZone:GetAttribute("AreaId")
        if self._activeAreaByPlayer[player] ~= areaId then
            self._activeAreaByPlayer[player] = areaId
            self._areaEntered:Fire(player, areaId, areaZone)
        end
    end)

    areaZone.TouchEnded:Connect(function(hit)
        local character = hit and hit.Parent
        if not character then
            return
        end
        local player = Players:GetPlayerFromCharacter(character)
        if not player then
            return
        end

        local areaId = areaZone:GetAttribute("AreaId")
        if self._activeAreaByPlayer[player] == areaId then
            self._activeAreaByPlayer[player] = nil
            self._areaExited:Fire(player, areaId, areaZone)
        end
    end)
end

function WorldBindingService:RebuildBindings()
    table.clear(self._boundByTag)
    table.clear(self._zoneById)
    table.clear(self._areaZoneById)
    table.clear(self._playerSpawnsByArea)
    table.clear(self._spawnZonesByArea)
    table.clear(self._teleportPadsByArea)
    table.clear(self._portalsByZone)

    local hasAuthoredHooks = self:_hasAuthoredHooks()
    if self._mapMode == "synthetic" or (self._mapMode == "auto" and not hasAuthoredHooks) then
        self:_synthesizeMissingHooks()
    end

    for tagName in pairs(self._markersConfig.tags or {}) do
        for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
            self:_bindInstance(tagName, instance)
        end
    end

    self:_validateRequiredAreas()

    self._logger:Info("WorldBindingService bindings ready", {
        mapMode = self._mapMode,
        authoredHooks = hasAuthoredHooks,
        boundTags = self:_countBoundTags(),
    })
end

function WorldBindingService:_synthesizeMissingConfiguredHooks()
    local root = self:_getSyntheticRoot()
    for zoneId, zone in pairs(self._areasConfig.zones or {}) do
        if not self:_hasZoneHook(zoneId) then
            self:_createZoneHook(root, zoneId, zone)
        end
        if zone.kind == "area" and not self:_hasAreaHook(zoneId) then
            self:_createAreaFloor(root, zoneId)
            self:_createSpawnZone(zoneId)
            self:_createEggHooks(zoneId)
            self:_createPodiumHook(zoneId)
        end
    end
    self:_createTravelHooks()
end

function WorldBindingService:_hasZoneHook(zoneId)
    for _, instance in ipairs(CollectionService:GetTagged("Zone")) do
        if instance:IsDescendantOf(workspace) and instance:GetAttribute("ZoneId") == zoneId then
            return true
        end
    end
    return false
end

function WorldBindingService:_hasAreaHook(areaId)
    for _, instance in ipairs(CollectionService:GetTagged("AreaZone")) do
        if instance:IsDescendantOf(workspace) and instance:GetAttribute("AreaId") == areaId then
            return true
        end
    end
    return false
end

function WorldBindingService:_validateRequiredAreas()
    local missing = {}
    for zoneId, zone in pairs(self._areasConfig.zones or {}) do
        local missingZone = not self._zoneById[zoneId]
        local missingAreaZone = zone.kind == "area" and not self._areaZoneById[zoneId]
        if missingZone or missingAreaZone then
            table.insert(missing, zoneId)
        end
    end

    if #missing > 0 and self._mapMode == "authored" then
        error("Missing authored AreaZone hooks: " .. table.concat(missing, ", "))
    end
end

function WorldBindingService:_countBoundTags()
    local count = 0
    for _, instances in pairs(self._boundByTag) do
        count += #instances
    end
    return count
end

function WorldBindingService:GetBound(tagName, predicate)
    local results = {}
    for _, instance in ipairs(self._boundByTag[tagName] or {}) do
        if not predicate or predicate(instance) then
            table.insert(results, instance)
        end
    end
    return results
end

function WorldBindingService:GetAreaZone(areaId)
    return self._areaZoneById[areaId]
end

function WorldBindingService:GetZone(zoneId)
    return self._zoneById[zoneId]
end

function WorldBindingService:GetActiveArea(player)
    return self._activeAreaByPlayer[player]
end

function WorldBindingService:IsAreaActive(areaId)
    for _, activeAreaId in pairs(self._activeAreaByPlayer) do
        if activeAreaId == areaId then
            return true
        end
    end
    return false
end

function WorldBindingService:SetActiveArea(player, areaId)
    local previousAreaId = self._activeAreaByPlayer[player]
    if previousAreaId == areaId then
        return
    end

    if previousAreaId then
        self._areaExited:Fire(player, previousAreaId, self._areaZoneById[previousAreaId])
    end

    self._activeAreaByPlayer[player] = areaId

    if areaId then
        self._areaEntered:Fire(player, areaId, self._areaZoneById[areaId])
    end
end

function WorldBindingService:GetZoneConfig(zoneId)
    return self._areasConfig.zones and self._areasConfig.zones[zoneId]
end

function WorldBindingService:GetPrimaryAreaForZone(zoneId)
    local zones = self._areasConfig.zones or {}
    local zone = zones[zoneId]
    if not zone then
        return nil
    end
    if zone.kind == "area" then
        return zoneId
    end
    if zone.primary_area and zones[zone.primary_area] then
        return zone.primary_area
    end

    local children = self:_childrenOf(zoneId)
    for _, childZoneId in ipairs(children) do
        local childAreaId = self:GetPrimaryAreaForZone(childZoneId)
        if childAreaId then
            return childAreaId
        end
    end

    return nil
end

function WorldBindingService:GetSpawnCFrameForZone(zoneId)
    local areaId = self:GetPrimaryAreaForZone(zoneId)
    if not areaId then
        return nil
    end

    local groundPosition = self:_findGroundSpawnPosition(areaId)
    if groundPosition then
        return CFrame.new(groundPosition), areaId
    end

    return CFrame.new(self:_spawnPosition(areaId)), areaId
end

function WorldBindingService:GetTeleportPadsForArea(areaId)
    return table.clone(self._teleportPadsByArea[areaId] or {})
end

function WorldBindingService:GetPortalsForZone(zoneId)
    return table.clone(self._portalsByZone[zoneId] or {})
end

function WorldBindingService:GetSpawnZonesForArea(areaId)
    local zones = self._spawnZonesByArea[areaId] or {}
    local parts = {}
    for _, instance in ipairs(zones) do
        local part = getPrimaryPartOrSelf(instance)
        if part then
            table.insert(parts, part)
        end
    end
    return parts
end

function WorldBindingService:GetSpawnZonesForSpawner(areaId, spawnerId)
    return self:GetBound("SpawnZone", function(instance)
        return instance:GetAttribute("AreaId") == areaId
            and instance:GetAttribute("SpawnerId") == spawnerId
    end)
end

function WorldBindingService:Destroy()
    if self._areaEntered then
        self._areaEntered:Destroy()
    end
    if self._areaExited then
        self._areaExited:Destroy()
    end
end

return WorldBindingService
