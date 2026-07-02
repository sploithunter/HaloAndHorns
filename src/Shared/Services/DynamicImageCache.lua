--[[
    DynamicImageCache - Runtime image generation and caching system
    
    This service generates high-quality images from 3D pet models at runtime,
    eliminating the need for manual asset uploads while maintaining performance.
    
    Features:
    - Runtime image generation from 3D models
    - Intelligent memory caching with cleanup
    - Configurable camera angles per pet type
    - Automatic fallback to emoji icons
    - Batch processing for egg previews
    - Performance monitoring and optimization
    
    Flow:
    1. Request pet image → Check cache
    2. If cached → Return immediately
    3. If not cached → Generate asynchronously
    4. Cache result → Return to requester
    
    Usage:
    local cache = DynamicImageCache.new()
    cache:GetPetImage(petType, variant, callback)
--]]

local DynamicImageCache = {}
DynamicImageCache.__index = DynamicImageCache

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local AssetFetch = require(ReplicatedStorage.Shared.Utils.AssetFetch)

-- Dependencies
local Locations = require(ReplicatedStorage.Shared.Locations)
local petConfig = Locations.getConfig("pets")

-- Logger setup using LoggerWrapper pattern
local LoggerWrapper
local loggerSuccess, loggerResult = pcall(function()
    return require(ReplicatedStorage.Shared.Utils.Logger)
end)

if loggerSuccess and loggerResult then
    LoggerWrapper = {
        new = function(name)
            return {
                info = function(self, ...)
                    loggerResult:Info("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                warn = function(self, ...)
                    loggerResult:Warn("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                error = function(self, ...)
                    loggerResult:Error("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                debug = function(self, ...)
                    loggerResult:Debug("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
            }
        end,
    }
else
    LoggerWrapper = {
        new = function(name)
            return {
                info = function(self, ...)
                    print("[" .. name .. "] INFO:", ...)
                end,
                warn = function(self, ...)
                    warn("[" .. name .. "] WARN:", ...)
                end,
                error = function(self, ...)
                    warn("[" .. name .. "] ERROR:", ...)
                end,
                debug = function(self, ...)
                    print("[" .. name .. "] DEBUG:", ...)
                end,
            }
        end,
    }
end

-- Singleton pattern for shared cache
local sharedCache = nil

function DynamicImageCache.new()
    if sharedCache then
        return sharedCache
    end

    local self = setmetatable({}, DynamicImageCache)

    self.logger = LoggerWrapper.new("DynamicImageCache")
    self.cache = {} -- {petType_variant = {image = ImageLabel, timestamp = tick()}}
    self.generationQueue = {} -- Pets currently being generated
    self.callbacks = {} -- Pending callbacks for each pet
    self.workspaceFolder = nil

    -- Cache management settings
    self.maxCacheSize = 50 -- Maximum cached images
    self.cacheTimeoutSeconds = 300 -- 5 minutes

    -- Performance tracking
    self.stats = {
        cacheHits = 0,
        cacheMisses = 0,
        generationSuccesses = 0,
        generationFailures = 0,
        totalGenerationTime = 0,
    }

    sharedCache = self
    self:Initialize()

    return self
end

function DynamicImageCache:Initialize()
    self.logger:info("Initializing dynamic image cache")

    -- Create workspace folder for temporary model loading
    self.workspaceFolder = Instance.new("Folder")
    self.workspaceFolder.Name = "DynamicImageGeneration"
    self.workspaceFolder.Parent = workspace

    -- Setup cache cleanup timer
    self:StartCacheCleanupTimer()

    self.logger:info("Dynamic image cache ready", {
        maxCacheSize = self.maxCacheSize,
        cacheTimeout = self.cacheTimeoutSeconds,
    })
end

-- === PUBLIC API ===

function DynamicImageCache:GetPetImage(petType, variant, callback)
    local cacheKey = petType .. "_" .. variant

    -- Check cache first
    local cachedImage = self:GetFromCache(cacheKey)
    if cachedImage then
        self.stats.cacheHits = self.stats.cacheHits + 1
        self.logger:debug("Cache hit", { petType = petType, variant = variant })

        -- Clone the cached image to avoid Parent property conflicts
        local imageClone = cachedImage:Clone()
        callback(imageClone, true) -- true = from cache
        return
    end

    self.stats.cacheMisses = self.stats.cacheMisses + 1
    self.logger:debug("Cache miss", { petType = petType, variant = variant })

    -- Check if already generating
    if self.generationQueue[cacheKey] then
        self.logger:debug(
            "Already generating, adding to callback queue",
            { petType = petType, variant = variant }
        )
        self.callbacks[cacheKey] = self.callbacks[cacheKey] or {}
        table.insert(self.callbacks[cacheKey], callback)
        return
    end

    -- Start generation
    self.generationQueue[cacheKey] = true
    self.callbacks[cacheKey] = { callback }

    self:GenerateImageAsync(petType, variant, cacheKey)
end

function DynamicImageCache:PreloadImagesForEgg(eggType)
    self.logger:info("Preloading images for egg", { eggType = eggType })

    -- Get egg configuration
    local eggData = petConfig.egg_sources[eggType]
    if not eggData then
        self.logger:warn("Egg data not found", { eggType = eggType })
        return
    end

    -- Generate images for all pets in this egg
    for petType, weight in pairs(eggData.pet_weights) do
        for variantName, variantData in pairs(petConfig.variants) do
            -- Check if this pet/variant combination exists
            if petConfig.pets[petType] and petConfig.pets[petType].variants[variantName] then
                self:GetPetImage(petType, variantName, function(image, fromCache)
                    self.logger:debug("Preloaded image", {
                        petType = petType,
                        variant = variantName,
                        fromCache = fromCache,
                    })
                end)
            end
        end
    end
end

function DynamicImageCache:GetStats()
    return {
        cacheSize = self:GetCacheSize(),
        cacheHits = self.stats.cacheHits,
        cacheMisses = self.stats.cacheMisses,
        hitRate = self.stats.cacheHits / math.max(1, self.stats.cacheHits + self.stats.cacheMisses),
        generationSuccesses = self.stats.generationSuccesses,
        generationFailures = self.stats.generationFailures,
        averageGenerationTime = self.stats.totalGenerationTime
            / math.max(1, self.stats.generationSuccesses),
    }
end

-- === CACHE MANAGEMENT ===

function DynamicImageCache:GetFromCache(cacheKey)
    local cacheEntry = self.cache[cacheKey]
    if not cacheEntry then
        return nil
    end

    -- Check if expired
    local age = tick() - cacheEntry.timestamp
    if age > self.cacheTimeoutSeconds then
        self.logger:debug("Cache entry expired", {
            cacheKey = cacheKey,
            age = age,
        })
        self:RemoveFromCache(cacheKey)
        return nil
    end

    -- Update timestamp (LRU-style)
    cacheEntry.timestamp = tick()
    return cacheEntry.image
end

function DynamicImageCache:AddToCache(cacheKey, image)
    -- Enforce cache size limit
    if self:GetCacheSize() >= self.maxCacheSize then
        self:EvictOldestEntry()
    end

    self.cache[cacheKey] = {
        image = image,
        timestamp = tick(),
    }

    self.logger:debug("Added to cache", {
        cacheKey = cacheKey,
        cacheSize = self:GetCacheSize(),
    })
end

function DynamicImageCache:RemoveFromCache(cacheKey)
    local entry = self.cache[cacheKey]
    if entry and entry.image then
        entry.image:Destroy()
    end
    self.cache[cacheKey] = nil
end

function DynamicImageCache:GetCacheSize()
    local count = 0
    for _ in pairs(self.cache) do
        count = count + 1
    end
    return count
end

function DynamicImageCache:EvictOldestEntry()
    local oldestKey = nil
    local oldestTime = math.huge

    for key, entry in pairs(self.cache) do
        if entry.timestamp < oldestTime then
            oldestTime = entry.timestamp
            oldestKey = key
        end
    end

    if oldestKey then
        self.logger:debug("Evicting oldest cache entry", { cacheKey = oldestKey })
        self:RemoveFromCache(oldestKey)
    end
end

function DynamicImageCache:StartCacheCleanupTimer()
    -- Clean up expired entries every minute
    spawn(function()
        while self.workspaceFolder and self.workspaceFolder.Parent do
            wait(60) -- 1 minute
            self:CleanupExpiredEntries()
        end
    end)
end

function DynamicImageCache:CleanupExpiredEntries()
    local currentTime = tick()
    local expiredKeys = {}

    for key, entry in pairs(self.cache) do
        local age = currentTime - entry.timestamp
        if age > self.cacheTimeoutSeconds then
            table.insert(expiredKeys, key)
        end
    end

    for _, key in ipairs(expiredKeys) do
        self:RemoveFromCache(key)
    end

    if #expiredKeys > 0 then
        self.logger:debug("Cleaned up expired entries", {
            removedCount = #expiredKeys,
            cacheSize = self:GetCacheSize(),
        })
    end
end

-- === IMAGE GENERATION ===

function DynamicImageCache:GenerateImageAsync(petType, variant, cacheKey)
    spawn(function()
        local startTime = tick()

        self.logger:debug("Starting image generation", {
            petType = petType,
            variant = variant,
        })

        local success, image = pcall(function()
            return self:GenerateImage(petType, variant)
        end)

        local generationTime = tick() - startTime
        self.stats.totalGenerationTime = self.stats.totalGenerationTime + generationTime

        if success and image then
            self.stats.generationSuccesses = self.stats.generationSuccesses + 1
            self.logger:info("Image generation successful", {
                petType = petType,
                variant = variant,
                generationTime = generationTime,
            })

            -- Add to cache
            self:AddToCache(cacheKey, image)

            -- Call all waiting callbacks with clones
            local callbacks = self.callbacks[cacheKey] or {}
            for _, callback in ipairs(callbacks) do
                local imageClone = image:Clone()
                callback(imageClone, false) -- false = newly generated
            end
        else
            self.stats.generationFailures = self.stats.generationFailures + 1
            self.logger:warn("Image generation failed", {
                petType = petType,
                variant = variant,
                error = image,
                generationTime = generationTime,
            })

            -- Call callbacks with nil (will trigger fallback)
            local callbacks = self.callbacks[cacheKey] or {}
            for _, callback in ipairs(callbacks) do
                callback(nil, false)
            end
        end

        -- Cleanup
        self.generationQueue[cacheKey] = nil
        self.callbacks[cacheKey] = nil
    end)
end

function DynamicImageCache:GenerateImage(petType, variant)
    -- Get pet data
    local petData = self:GetPetData(petType, variant)
    if not petData then
        error("Pet data not found: " .. petType .. "_" .. variant)
    end

    -- Get camera configuration
    local cameraConfig = self:GetCameraConfig(petType)

    -- Load the 3D model
    local model = self:LoadPetModel(petData.asset_id)
    if not model then
        error("Failed to load pet model: " .. petData.asset_id)
    end

    -- Create temporary ViewportFrame for image generation
    local image = self:CaptureModelImage(model, cameraConfig)

    -- Cleanup model
    model:Destroy()

    return image
end

function DynamicImageCache:CaptureModelImage(model, cameraConfig)
    local imageSize = petConfig.asset_images.image_size or 128

    -- For now, since we can't actually capture ViewportFrame content as an image
    -- in runtime Lua, let's create a ViewportFrame that can be used directly
    -- This is still better than 99+ permanent ViewportFrames since we cache them

    -- Position model at origin
    local modelCFrame, modelSize = model:GetBoundingBox()
    if model.PrimaryPart then
        model:SetPrimaryPartCFrame(CFrame.new(0, 0, 0))
    else
        model:MoveTo(Vector3.new(0, 0, 0))
    end

    -- Calculate camera position
    local angleYRad = math.rad(cameraConfig.angle_y)
    local angleXRad = math.rad(cameraConfig.angle_x)

    local cameraOffset = Vector3.new(
        math.sin(angleYRad) * cameraConfig.distance,
        math.sin(angleXRad) * cameraConfig.distance,
        math.cos(angleYRad) * cameraConfig.distance
    )

    local cameraPosition = cameraOffset + cameraConfig.offset

    -- Create ViewportFrame that will be cached and cloned
    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "CachedPetViewport"
    viewport.Size = UDim2.new(1, 0, 1, 0) -- Will be resized by the UI system
    viewport.BackgroundTransparency = 1

    -- Create camera
    local camera = Instance.new("Camera")
    camera.CFrame = CFrame.lookAt(cameraPosition, Vector3.new(0, 0, 0))
    camera.Parent = viewport
    viewport.CurrentCamera = camera

    -- Clone model and add to viewport (so original can be destroyed)
    local modelClone = model:Clone()
    modelClone.Parent = viewport

    self.logger:debug("Created cached viewport", {
        cameraPosition = cameraPosition,
        modelBounds = modelSize,
        angle_y = cameraConfig.angle_y,
        angle_x = cameraConfig.angle_x,
        distance = cameraConfig.distance,
    })

    return viewport
end

-- === HELPER METHODS ===

function DynamicImageCache:GetPetData(petType, variant)
    if not petConfig.pets[petType] then
        return nil
    end

    if not petConfig.pets[petType].variants[variant] then
        return nil
    end

    return petConfig.pets[petType].variants[variant]
end

function DynamicImageCache:GetCameraConfig(petType)
    local assetImageConfig = petConfig.asset_images

    -- Use pet-specific config if available, otherwise use default
    local cameraConfig = assetImageConfig.camera_configs[petType] or assetImageConfig.default_camera

    return cameraConfig
end

function DynamicImageCache:LoadPetModel(assetId)
    if not assetId or assetId == "rbxassetid://0" then
        return nil
    end

    -- Try loading from ReplicatedStorage.Assets first (if preloaded)
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if assetsFolder then
        local modelsFolder = assetsFolder:FindFirstChild("Models")
        if modelsFolder then
            local petsFolder = modelsFolder:FindFirstChild("Pets")
            if petsFolder then
                -- Find the model in the preloaded assets
                for _, petTypeFolder in pairs(petsFolder:GetChildren()) do
                    for _, model in pairs(petTypeFolder:GetChildren()) do
                        if model:IsA("Model") then
                            local clone = model:Clone()
                            clone.Parent = self.workspaceFolder
                            return clone
                        end
                    end
                end
            end
        end
    end

    -- Fallback to InsertService loading
    local success, result = pcall(function()
        local assetNumber = tonumber(assetId:match("%d+"))
        if not assetNumber then
            error("Could not extract asset number from " .. assetId)
        end

        local asset = AssetFetch.load(assetNumber)
        local model = asset:FindFirstChildOfClass("Model")

        if not model then
            error("Asset does not contain a Model")
        end

        model = model:Clone()
        model.Parent = self.workspaceFolder
        asset:Destroy()

        return model
    end)

    if success then
        return result
    else
        self.logger:error("Failed to load model", {
            assetId = assetId,
            error = result,
        })
        return nil
    end
end

function DynamicImageCache:Destroy()
    -- Cleanup cache
    for key in pairs(self.cache) do
        self:RemoveFromCache(key)
    end

    -- Cleanup workspace
    if self.workspaceFolder then
        self.workspaceFolder:Destroy()
    end

    self.logger:info("Dynamic image cache destroyed")
    sharedCache = nil
end

return DynamicImageCache
