--[[
    EggSpawner Service
    
    Handles dynamic egg spawning and management using asset IDs.
    Creates egg instances at specified spawn points based on configuration.
    
    Usage:
    - Place spawn point parts in Workspace where eggs should appear (configurable name)
    - Use EggSpawner:SpawnEgg() to create eggs dynamically
    - Eggs are loaded from asset IDs in pet configuration
--]]

local EggSpawner = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local InsertService = game:GetService("InsertService")
local CollectionService = game:GetService("CollectionService")

local AssetFetch = require(ReplicatedStorage.Shared.Utils.AssetFetch)

-- Dependencies
local Locations = require(ReplicatedStorage.Shared.Locations)
local Logger
do
    local ok, mod = pcall(function()
        return require(ReplicatedStorage.Shared.Utils.Logger)
    end)
    if ok and mod then
        Logger = mod
    else
        Logger = {
            Info = function() end,
            Warn = function(_, ...)
                warn(...)
            end,
        }
    end
end
local petConfig = Locations.getConfig("pets")
local eggSystemConfig = Locations.getConfig("egg_system")
local EggWorldQuery = require(ReplicatedStorage.Shared.Services.EggWorldQuery)

-- Active eggs in the world
local activeEggs = {}

-- === EGG SPAWNING SYSTEM ===

local function getPreloadedEggTemplate(eggType)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local models = assets and assets:FindFirstChild("Models")
    local eggs = models and models:FindFirstChild("Eggs")
    local template = eggs and eggs:FindFirstChild(eggType)
    if template and template:IsA("Model") then
        return template
    end
    return nil
end

local function loadEggTemplateFromAsset(eggType, eggData)
    local assetId = eggData.asset_id
    if not assetId or assetId == "rbxassetid://0" then
        warn("No asset ID configured for egg type: " .. eggType)
        return nil
    end

    local cleanId = assetId:match("%d+")
    if not cleanId then
        warn("Invalid egg asset ID: " .. tostring(assetId))
        return nil
    end

    local success, eggAsset = pcall(function()
        return AssetFetch.load(tonumber(cleanId))
    end)

    if not success or not eggAsset then
        warn("Failed to load egg asset: " .. assetId)
        return nil
    end

    local template = eggAsset:FindFirstChildOfClass("Model")
    if not template then
        warn("Asset doesn't contain a Model: " .. assetId)
        eggAsset:Destroy()
        return nil
    end

    local clone = template:Clone()
    eggAsset:Destroy()
    return clone
end

local function getEggModel(eggType, eggData)
    local preloadedTemplate = getPreloadedEggTemplate(eggType)
    if preloadedTemplate then
        return preloadedTemplate:Clone(), "preloaded"
    end

    return loadEggTemplateFromAsset(eggType, eggData), "insert_service_fallback"
end

-- Spawn an egg at a specific position
function EggSpawner:SpawnEgg(eggType, position, spawnPoint)
    local eggData = petConfig.egg_sources[eggType]
    if not eggData then
        warn("Unknown egg type: " .. tostring(eggType))
        return nil
    end

    local egg, source = getEggModel(eggType, eggData)
    if not egg then
        return nil
    end

    -- Setup the egg
    egg.Name = eggData.name
    egg.Parent = workspace

    -- Position the egg
    if egg.PrimaryPart then
        egg:SetPrimaryPartCFrame(CFrame.new(position))
    elseif egg:FindFirstChild("Base") then
        egg.Base.CFrame = CFrame.new(position)
    end

    -- Add metadata
    local existingEggInfo = egg:FindFirstChild("EggType")
    if existingEggInfo then
        existingEggInfo:Destroy()
    end
    local eggInfo = Instance.new("StringValue")
    eggInfo.Name = "EggType"
    eggInfo.Value = eggType
    eggInfo.Parent = egg

    local existingSpawnPointRef = egg:FindFirstChild("SpawnPoint")
    if existingSpawnPointRef then
        existingSpawnPointRef:Destroy()
    end
    local spawnPointRef = Instance.new("ObjectValue")
    spawnPointRef.Name = "SpawnPoint"
    spawnPointRef.Value = spawnPoint
    spawnPointRef.Parent = egg

    Logger:Info("Egg spawned", {
        context = "EggSpawner",
        name = eggData.name,
        eggType = eggType,
        source = source,
        spawnPoint = spawnPoint.Name,
    })

    -- Add to active eggs
    activeEggs[egg] = {
        eggType = eggType,
        spawnPoint = spawnPoint,
        spawnTime = tick(),
        eggData = eggData,
    }

    -- Client will automatically detect this egg via distance-based system

    -- Spawn animation
    self:PlaySpawnAnimation(egg)

    -- Cleanup when destroyed
    egg.AncestryChanged:Connect(function()
        if not egg.Parent then
            activeEggs[egg] = nil
        end
    end)
    return egg
end

-- Legacy interaction system removed - now using EggInteractionService

-- Play spawn animation
function EggSpawner:PlaySpawnAnimation(egg)
    -- Start small and grow to normal size
    local originalSize = {}
    local parts = {}

    for _, part in pairs(egg:GetChildren()) do
        if part:IsA("BasePart") then
            table.insert(parts, part)
            originalSize[part] = part.Size
            part.Size = Vector3.new(0.1, 0.1, 0.1)
        end
    end

    -- Animate growth
    for _, part in pairs(parts) do
        local tween = TweenService:Create(
            part,
            TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Size = originalSize[part] }
        )
        tween:Play()
    end
end

-- === SPAWN POINT MANAGEMENT ===

-- Find all egg spawn points in workspace
function EggSpawner:GetSpawnPoints()
    local spawnPoints = {}

    for _, instance in ipairs(CollectionService:GetTagged("EggStand")) do
        if
            instance:IsDescendantOf(workspace)
            and EggWorldQuery.ShouldSpawnVisualAtHook(
                instance,
                eggSystemConfig.spawning.spawn_point_name
            )
        then
            table.insert(spawnPoints, instance)
        end
    end

    -- Fallback for older template maps with invisible parts named "EggSpawnPoint".
    local function searchForSpawnPoints(parent)
        for _, child in pairs(parent:GetChildren()) do
            if
                child:IsA("BasePart")
                and child.Name == eggSystemConfig.spawning.spawn_point_name
                and not CollectionService:HasTag(child, "EggStand")
                and EggWorldQuery.ShouldSpawnVisualAtHook(
                    child,
                    eggSystemConfig.spawning.spawn_point_name
                )
            then
                table.insert(spawnPoints, child)
            end
            searchForSpawnPoints(child)
        end
    end

    searchForSpawnPoints(workspace)
    return spawnPoints
end

-- Spawn eggs at all available spawn points
function EggSpawner:PopulateSpawnPoints()
    local spawnPoints = self:GetSpawnPoints()

    for _, spawnPoint in pairs(spawnPoints) do
        -- Check if this spawn point has an egg type attribute
        local eggType = spawnPoint:GetAttribute("EggType") or "basic_egg"

        -- Only spawn if no egg is already there
        if not self:HasEggAtSpawnPoint(spawnPoint) then
            self:SpawnEgg(eggType, spawnPoint.Position + Vector3.new(0, 3, 0), spawnPoint)
        end
    end
end

-- Check if spawn point already has an egg
function EggSpawner:HasEggAtSpawnPoint(spawnPoint)
    for egg, info in pairs(activeEggs) do
        if info.spawnPoint == spawnPoint then
            return true
        end
    end
    return false
end

-- === UTILITY FUNCTIONS ===

-- Get all active eggs of a specific type
function EggSpawner:GetEggsByType(eggType)
    local eggs = {}
    for egg, info in pairs(activeEggs) do
        if info.eggType == eggType then
            table.insert(eggs, egg)
        end
    end
    for _, egg in ipairs(EggWorldQuery.GetEggsByType(eggType)) do
        table.insert(eggs, egg.instance)
    end
    return eggs
end

-- Remove an egg (for when it's purchased/hatched)
function EggSpawner:RemoveEgg(egg)
    if activeEggs[egg] then
        activeEggs[egg] = nil
        egg:Destroy()
    end
end

-- Get egg information
function EggSpawner:GetEggInfo(egg)
    return activeEggs[egg]
end

-- Initialize the system
function EggSpawner:Initialize()
    Logger:Info("Initializing", { context = "EggSpawner" })

    -- Check workspace first
    Logger:Debug("Searching for spawn points...", { context = "EggSpawner" })
    local spawnPoints = self:GetSpawnPoints()
    local waited = 0
    while #spawnPoints == 0 and waited < 5 do
        task.wait(0.5)
        waited += 0.5
        spawnPoints = self:GetSpawnPoints()
    end
    Logger:Debug("Found spawn points", { context = "EggSpawner", count = #spawnPoints })

    if #spawnPoints == 0 then
        -- Normal for authored-stand maps: EggStandPlacement places + tags (EggStand) its eggs
        -- after this scan (it gates on Assets.ModelsReady). The EggSpawnPoint path here is only a
        -- fallback for legacy template maps, so an empty result is not a problem worth warning.
        Logger:Debug("No EggSpawnPoint parts; EggStandPlacement owns egg placement", {
            context = "EggSpawner",
        })
        return
    end

    -- Populate initial spawn points
    self:PopulateSpawnPoints()

    Logger:Info("Initialized", { context = "EggSpawner", spawnPointCount = #spawnPoints })
end

return EggSpawner
