--[[
    GameStructureService - Builds Workspace.Game from configuration

    This service owns only the mechanics of creating folders, counters, and
    optional invisible spawn parts. The list of areas, caps, and generated
    spawner geometry lives in configs/breakables.lua.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local BootReadiness = require(ReplicatedStorage.Shared.Boot.BootReadiness)

local GameStructureService = {}

local CONTRACT_TAGS = {
    "Zone",
    "AreaZone",
    "PlayerSpawn",
    "SpawnZone",
    "TeleportPad",
    "Portal",
    "EggStand",
    "EnchanterStation",
    "PODPodium",
}

local function loadBreakablesConfig()
    local ok, config = pcall(function()
        local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
        return ConfigLoader:LoadConfig("breakables")
    end)
    if ok and type(config) == "table" then
        return config
    end

    local configsFolder = ReplicatedStorage:FindFirstChild("Configs")
    local breakablesModule = configsFolder and configsFolder:FindFirstChild("breakables")
    if breakablesModule and breakablesModule:IsA("ModuleScript") then
        local directOk, directConfig = pcall(require, breakablesModule)
        if directOk and type(directConfig) == "table" then
            return directConfig
        end
    end

    return {}
end

local function loadGameConfig()
    local ok, config = pcall(function()
        local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
        return ConfigLoader:LoadConfig("game")
    end)
    if ok and type(config) == "table" then
        return config
    end

    local configsFolder = ReplicatedStorage:FindFirstChild("Configs")
    local gameModule = configsFolder and configsFolder:FindFirstChild("game")
    if gameModule and gameModule:IsA("ModuleScript") then
        local directOk, directConfig = pcall(require, gameModule)
        if directOk and type(directConfig) == "table" then
            return directConfig
        end
    end

    return {}
end

local function hasAuthoredMapHooks()
    for _, tagName in ipairs(CONTRACT_TAGS) do
        for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
            if instance:IsDescendantOf(workspace) and not instance:GetAttribute("Synthetic") then
                return true
            end
        end
    end
    return false
end

local function shouldGenerateFallbackStructure()
    local gameConfig = loadGameConfig()
    local mapMode = (gameConfig.map and gameConfig.map.mode) or "auto"
    if mapMode == "synthetic" then
        return true
    end
    if mapMode == "authored" then
        return false
    end
    return not hasAuthoredMapHooks()
end

local function shallowCopy(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end

    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

local function mergeInto(target, source)
    if type(source) ~= "table" then
        return target
    end

    for key, value in pairs(source) do
        target[key] = value
    end
    return target
end

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

local function toColor3(value, fallback)
    fallback = fallback or Color3.new(1, 1, 1)
    if typeof(value) == "Color3" then
        return value
    end
    if type(value) ~= "table" then
        return fallback
    end

    local r = tonumber(value.r or value.R or value[1]) or fallback.R
    local g = tonumber(value.g or value.G or value[2]) or fallback.G
    local b = tonumber(value.b or value.B or value[3]) or fallback.B
    if r > 1 or g > 1 or b > 1 then
        return Color3.fromRGB(r, g, b)
    end
    return Color3.new(r, g, b)
end

local function applyCommonPartConfig(part, config)
    part.Anchored = config.anchored ~= false
    if config.can_collide ~= nil then
        part.CanCollide = config.can_collide == true
    end
    if config.can_query ~= nil then
        part.CanQuery = config.can_query == true
    end
    if config.can_touch ~= nil then
        part.CanTouch = config.can_touch == true
    end
    if config.transparency ~= nil then
        part.Transparency = tonumber(config.transparency) or part.Transparency
    end
    if config.size then
        part.Size = toVector3(config.size, part.Size)
    end
    if config.position then
        part.Position = toVector3(config.position, part.Position)
    end
    if config.color then
        part.Color = toColor3(config.color, part.Color)
    end
    if config.material and Enum.Material[config.material] then
        part.Material = Enum.Material[config.material]
    end
end

local function ensureSpawnIsland(structureConfig)
    local islandConfig = structureConfig.spawn_island or {}
    local island = workspace:FindFirstChild(islandConfig.name or "SpawnIsland")
    if not island then
        island = Instance.new("Part")
        island.Name = islandConfig.name or "SpawnIsland"
        island.Parent = workspace
    end
    applyCommonPartConfig(
        island,
        mergeInto({
            size = { x = 160, y = 4, z = 160 },
            position = { x = 0, y = -2, z = 0 },
            color = { r = 46, g = 158, b = 74 },
            material = "Grass",
        }, islandConfig)
    )

    local spawnConfig = structureConfig.start_spawn or {}
    local spawnLocation = workspace:FindFirstChild(spawnConfig.name or "StartSpawn")
    if not spawnLocation then
        spawnLocation = Instance.new("SpawnLocation")
        spawnLocation.Name = spawnConfig.name or "StartSpawn"
        spawnLocation.Parent = workspace
    end
    spawnLocation.Neutral = spawnConfig.neutral ~= false
    spawnLocation.Duration = tonumber(spawnConfig.duration) or 0
    applyCommonPartConfig(
        spawnLocation,
        mergeInto({
            size = { x = 12, y = 1, z = 12 },
            position = { x = 0, y = 2, z = 0 },
            transparency = 0.25,
            color = { r = 38, g = 115, b = 255 },
        }, spawnConfig)
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

local function ensureMinimalGameFolders()
    local gameFolder = ensureFolder(workspace, "Game")
    gameFolder:SetAttribute("GeneratedFromConfig", true)
    ensureFolder(gameFolder, "Music")
    ensureFolder(gameFolder, "SFX")
    local breakablesFolder = ensureFolder(gameFolder, "Breakables")
    local crystalsFolder = ensureFolder(breakablesFolder, "Crystals")
    local breakablesConfig = loadBreakablesConfig()
    for areaId in pairs(breakablesConfig.worlds or {}) do
        ensureFolder(crystalsFolder, areaId)
    end
    ensureFolder(gameFolder, "Eggs")
    ensureFolder(gameFolder, "Chaseables")
    return gameFolder
end

local function ensureEggSpawnPoints(gameFolder, structureConfig)
    local spawnPoints = structureConfig.egg_spawn_points
    if type(spawnPoints) ~= "table" then
        return
    end

    local eggsFolder = ensureFolder(gameFolder, "Eggs")
    local spawnFolder = ensureFolder(eggsFolder, "SpawnPoints")
    local seenIds = {}

    for index, pointConfig in ipairs(spawnPoints) do
        if type(pointConfig) == "table" then
            local spawnId = tostring(pointConfig.spawn_id or pointConfig.egg_type or index)
            seenIds[spawnId] = true

            local spawnPoint
            for _, child in ipairs(spawnFolder:GetChildren()) do
                if child:IsA("BasePart") and child:GetAttribute("SpawnId") == spawnId then
                    spawnPoint = child
                    break
                end
            end

            if not spawnPoint then
                spawnPoint = Instance.new("Part")
                spawnPoint.Parent = spawnFolder
            end

            spawnPoint.Name = pointConfig.name or "EggSpawnPoint"
            applyCommonPartConfig(
                spawnPoint,
                mergeInto({
                    size = { x = 3, y = 1, z = 3 },
                    position = { x = 0, y = 0.5, z = 0 },
                    transparency = 1,
                    can_collide = false,
                    can_query = false,
                    can_touch = false,
                }, pointConfig)
            )
            spawnPoint:SetAttribute("SpawnId", spawnId)
            spawnPoint:SetAttribute("EggType", pointConfig.egg_type or "basic_egg")
        end
    end

    for _, child in ipairs(spawnFolder:GetChildren()) do
        if child:IsA("BasePart") and child.Name == "EggSpawnPoint" then
            local spawnId = child:GetAttribute("SpawnId")
            if spawnId and not seenIds[spawnId] then
                child:Destroy()
            end
        end
    end
end

local function randomFromRange(range, fallback)
    if type(range) == "table" then
        local min = tonumber(range.min or range[1])
        local max = tonumber(range.max or range[2])
        if min and max then
            return math.random(min, max)
        end
    end
    return tonumber(range) or fallback
end

local function resolveSpawnerPosition(spawnerConfig, defaultConfig)
    if spawnerConfig.position then
        return toVector3(spawnerConfig.position, Vector3.zero)
    end

    local randomConfig = spawnerConfig.random_position or defaultConfig.random_position
    if type(randomConfig) == "table" then
        return Vector3.new(
            randomFromRange(randomConfig.x, 0),
            randomFromRange(randomConfig.y, 10),
            randomFromRange(randomConfig.z, 0)
        )
    end

    return Vector3.new(0, 10, 0)
end

local function createSpawner(worldFolder, spawnerConfig, defaultConfig)
    local config = shallowCopy(defaultConfig)
    mergeInto(config, spawnerConfig)

    local spawnerName = config.name or "Spawner"
    local spawner = worldFolder:FindFirstChild(spawnerName)
    if not spawner or not spawner:IsA("BasePart") then
        spawner = Instance.new("Part")
        spawner.Name = spawnerName
        spawner.Parent = worldFolder
    end

    spawner.Anchored = true
    spawner.CanCollide = false
    spawner.CanQuery = false
    spawner.CanTouch = false
    spawner.Transparency = tonumber(config.transparency) or 1
    spawner.Size = toVector3(config.size, Vector3.new(1, 1, 1))
    spawner.Position = resolveSpawnerPosition(config, defaultConfig)

    if not spawner:FindFirstChild("Attachment") then
        local attachment = Instance.new("Attachment")
        attachment.Name = "Attachment"
        attachment.Parent = spawner
    end
end

local function normalizeSpawnerSpecs(sectionName, groupName, worldOptions, groupConfig, worldConfig)
    if
        sectionName == "Breakables"
        and groupName == "Crystals"
        and type(worldConfig.spawn_area) == "table"
    then
        return { worldConfig.spawn_area }
    end

    local spawnerSpec = worldOptions.spawners
    if spawnerSpec == nil then
        spawnerSpec = groupConfig.spawners
    end
    if spawnerSpec == nil then
        spawnerSpec = false
    end
    if spawnerSpec == false then
        return {}
    end
    if spawnerSpec == true then
        return { {} }
    end
    if type(spawnerSpec) ~= "table" then
        return {}
    end
    if #spawnerSpec > 0 then
        return spawnerSpec
    end
    return { spawnerSpec }
end

local function createWorldFolder(parent, worldName, options)
    local worldFolder = parent:FindFirstChild(worldName)
    if not worldFolder or not worldFolder:IsA("Folder") then
        worldFolder = Instance.new("Folder")
        worldFolder.Name = worldName
        worldFolder.Parent = parent
    end

    local itemsFolder = worldFolder:FindFirstChild("Items")
    if not itemsFolder then
        itemsFolder = Instance.new("Folder")
        itemsFolder.Name = "Items"
        itemsFolder.Parent = worldFolder
    end

    local currentItems = worldFolder:FindFirstChild("CurrentItems")
    if not currentItems then
        currentItems = Instance.new("NumberValue")
        currentItems.Name = "CurrentItems"
        currentItems.Value = 0
        currentItems.Parent = worldFolder
    end

    local maxItems = worldFolder:FindFirstChild("Max")
    if not maxItems then
        maxItems = Instance.new("NumberValue")
        maxItems.Name = "Max"
        maxItems.Parent = worldFolder
    end
    maxItems.Value = tonumber(options.max) or 0

    for _, spawnerSpec in ipairs(options.spawners or {}) do
        createSpawner(worldFolder, spawnerSpec, options.spawner_defaults or {})
    end

    return worldFolder
end

local function addWorldSpec(worldSpecs, worldName, options)
    if type(worldName) ~= "string" or worldName == "" then
        return
    end
    if not worldSpecs[worldName] then
        worldSpecs[worldName] = options or {}
    else
        mergeInto(worldSpecs[worldName], options)
    end
end

local function collectWorldSpecs(sectionName, groupName, groupConfig, breakablesConfig)
    local specs = {}
    for _, entry in ipairs(groupConfig.worlds or {}) do
        if type(entry) == "string" then
            addWorldSpec(specs, entry, {})
        elseif type(entry) == "table" then
            addWorldSpec(specs, entry.name, shallowCopy(entry))
        end
    end

    if sectionName == "Breakables" and groupName == "Crystals" then
        for worldName in pairs(breakablesConfig.worlds or {}) do
            addWorldSpec(specs, worldName, {})
        end
    end

    return specs
end

local function createConfiguredGroup(
    sectionFolder,
    sectionName,
    groupName,
    groupConfig,
    structureConfig,
    breakablesConfig
)
    local groupFolder = sectionFolder:FindFirstChild(groupName)
    if not groupFolder then
        groupFolder = Instance.new("Folder")
        groupFolder.Name = groupName
        groupFolder.Parent = sectionFolder
    end

    local structureDefaults = structureConfig.defaults or {}
    local worldSpecs = collectWorldSpecs(sectionName, groupName, groupConfig, breakablesConfig)

    for worldName, worldOptions in pairs(worldSpecs) do
        local crystalWorldConfig = {}
        if sectionName == "Breakables" and groupName == "Crystals" then
            crystalWorldConfig = (breakablesConfig.worlds and breakablesConfig.worlds[worldName])
                or {}
        end

        local resolvedOptions = shallowCopy(groupConfig)
        resolvedOptions.worlds = nil
        mergeInto(resolvedOptions, worldOptions)
        resolvedOptions.max = tonumber(worldOptions.max)
            or tonumber(crystalWorldConfig.max)
            or tonumber(groupConfig.max)
            or tonumber(structureDefaults.max)
            or 0
        resolvedOptions.spawner_defaults = shallowCopy(structureDefaults.spawner)
        mergeInto(resolvedOptions.spawner_defaults, groupConfig.spawner_defaults)
        resolvedOptions.spawners = normalizeSpawnerSpecs(
            sectionName,
            groupName,
            resolvedOptions,
            groupConfig,
            crystalWorldConfig
        )

        createWorldFolder(groupFolder, worldName, resolvedOptions)
    end

    return groupFolder
end

function GameStructureService:CreateGameStructure()
    local breakablesConfig = loadBreakablesConfig()
    local structureConfig = breakablesConfig.structure or {}

    print("GameStructureService: Creating Game structure from config...")
    if not shouldGenerateFallbackStructure() then
        print("GameStructureService: Authored map hooks detected; creating folders only.")
        return ensureMinimalGameFolders()
    end

    ensureSpawnIsland(structureConfig)

    local gameFolder = workspace:FindFirstChild("Game")
    if not gameFolder then
        gameFolder = Instance.new("Folder")
        gameFolder.Name = "Game"
        gameFolder.Parent = workspace
    end
    gameFolder:SetAttribute("GeneratedFromConfig", true)
    ensureEggSpawnPoints(gameFolder, structureConfig)

    for sectionName, sectionConfig in pairs(structureConfig.folders or {}) do
        local sectionFolder = gameFolder:FindFirstChild(sectionName)
        if not sectionFolder then
            sectionFolder = Instance.new("Folder")
            sectionFolder.Name = sectionName
            sectionFolder.Parent = gameFolder
        end

        for groupName, groupConfig in pairs(sectionConfig) do
            createConfiguredGroup(
                sectionFolder,
                sectionName,
                groupName,
                groupConfig,
                structureConfig,
                breakablesConfig
            )
        end
    end

    print("GameStructureService: Game structure created successfully.")
    return gameFolder
end

function GameStructureService:Initialize()
    print("GameStructureService: Initializing...")
    BootReadiness.begin("world_structure") -- boot stage start (paired with signal below)
    if shouldGenerateFallbackStructure() then
        local breakablesConfig = loadBreakablesConfig()
        ensureSpawnIsland(breakablesConfig.structure or {})
    end
    task.wait(1)
    self:CreateGameStructure()
    print("GameStructureService: Initialized.")
    -- Event-driven boot: workspace.Game (incl. the Breakables folder) now exists. BreakableSpawner
    -- awaits this milestone instead of FindFirstChild-then-aborting. See docs/BOOT_ORCHESTRATION.md.
    BootReadiness.signal("world_structure")
end

GameStructureService:Initialize()

return GameStructureService
