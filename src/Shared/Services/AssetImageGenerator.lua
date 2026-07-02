--[[
    AssetImageGenerator - Generate high-quality images from 3D pet models
    
    This service creates pre-rendered images of pets for UI display, solving the
    performance issues of having 99+ ViewportFrames running simultaneously.
    
    Features:
    - Configurable camera angles per pet type
    - Multiple lighting presets
    - Batch generation capabilities
    - Direct integration with pet configuration
    - Automatic fallback for missing configurations
    
    Usage:
    local generator = AssetImageGenerator.new()
    generator:GenerateAllPetImages()  -- Batch generate all pets
    generator:GeneratePetImage("bear", "basic")  -- Generate single pet
--]]

local AssetImageGenerator = {}
AssetImageGenerator.__index = AssetImageGenerator

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local Lighting = game:GetService("Lighting")

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

function AssetImageGenerator.new()
    local self = setmetatable({}, AssetImageGenerator)

    self.logger = LoggerWrapper.new("AssetImageGenerator")
    self.generateWorkspace = nil
    self.originalLighting = {}

    return self
end

-- === CORE GENERATION METHODS ===

function AssetImageGenerator:GeneratePetImage(petType, variant)
    self.logger:info("Generating image for pet", {
        petType = petType,
        variant = variant,
    })

    -- Get pet data
    local petData = self:GetPetData(petType, variant)
    if not petData then
        self.logger:error("Pet data not found", {
            petType = petType,
            variant = variant,
        })
        return nil
    end

    -- Get camera configuration
    local cameraConfig = self:GetCameraConfig(petType)

    -- Setup generation workspace
    self:SetupGenerationWorkspace()

    -- Load the 3D model
    local model = self:LoadPetModel(petData.asset_id)
    if not model then
        self.logger:error("Failed to load pet model", {
            petType = petType,
            variant = variant,
            assetId = petData.asset_id,
        })
        self:CleanupGenerationWorkspace()
        return nil
    end

    -- Apply lighting preset
    self:ApplyLightingPreset(cameraConfig.lighting)

    -- Position model and camera
    local camera = self:SetupCamera(model, cameraConfig)

    -- Create ViewportFrame for image capture
    local viewport = self:CreateCaptureViewport(camera)

    -- Capture the image (this would be done manually or with Studio plugins)
    self.logger:info("Ready for image capture", {
        petType = petType,
        variant = variant,
        cameraPosition = camera.CFrame.Position,
        modelPosition = model:GetBoundingBox().Position,
    })

    -- Cleanup
    model:Destroy()
    viewport:Destroy()
    self:CleanupGenerationWorkspace()

    self.logger:info("Image generation setup complete", {
        petType = petType,
        variant = variant,
        note = "Manual capture required - see ViewportFrame in workspace",
    })

    return true
end

function AssetImageGenerator:GenerateAllPetImages()
    self.logger:info("Starting batch generation of all pet images")

    local successCount = 0
    local failureCount = 0
    local totalPets = 0

    for petType, petFamily in pairs(petConfig.pets) do
        for variant, petData in pairs(petFamily.variants) do
            totalPets = totalPets + 1

            self.logger:info("Processing pet", {
                petType = petType,
                variant = variant,
                progress = totalPets,
            })

            local success = self:GeneratePetImage(petType, variant)
            if success then
                successCount = successCount + 1
            else
                failureCount = failureCount + 1
            end

            -- Small delay between generations
            wait(0.1)
        end
    end

    self.logger:info("Batch generation complete", {
        successful = successCount,
        failed = failureCount,
        total = totalPets,
    })

    return {
        successful = successCount,
        failed = failureCount,
        total = totalPets,
    }
end

-- === HELPER METHODS ===

function AssetImageGenerator:GetPetData(petType, variant)
    if not petConfig.pets[petType] then
        return nil
    end

    if not petConfig.pets[petType].variants[variant] then
        return nil
    end

    return petConfig.pets[petType].variants[variant]
end

function AssetImageGenerator:GetCameraConfig(petType)
    local assetImageConfig = petConfig.asset_images

    -- Use pet-specific config if available, otherwise use default
    local cameraConfig = assetImageConfig.camera_configs[petType] or assetImageConfig.default_camera

    self.logger:debug("Using camera config", {
        petType = petType,
        distance = cameraConfig.distance,
        angle_y = cameraConfig.angle_y,
        angle_x = cameraConfig.angle_x,
        lighting = cameraConfig.lighting,
    })

    return cameraConfig
end

function AssetImageGenerator:LoadPetModel(assetId)
    if not assetId or assetId == "rbxassetid://0" then
        self.logger:warn("Invalid asset ID")
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
                            -- Check if this model matches our asset ID
                            -- This is a simplified check - in real implementation you'd need
                            -- a more robust way to match preloaded models to asset IDs
                            local clone = model:Clone()
                            clone.Parent = self.generateWorkspace
                            self.logger:debug("Loaded model from assets", { assetId = assetId })
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
        model.Parent = self.generateWorkspace
        asset:Destroy()

        return model
    end)

    if success then
        self.logger:debug("Loaded model from InsertService", { assetId = assetId })
        return result
    else
        self.logger:error("Failed to load model", {
            assetId = assetId,
            error = result,
        })
        return nil
    end
end

function AssetImageGenerator:SetupCamera(model, cameraConfig)
    -- Calculate model center and size
    local modelCFrame, modelSize = model:GetBoundingBox()
    local modelCenter = modelCFrame.Position

    -- Apply offset
    local adjustedCenter = modelCenter + cameraConfig.offset

    -- Calculate camera position based on angles and distance
    local angleYRad = math.rad(cameraConfig.angle_y)
    local angleXRad = math.rad(cameraConfig.angle_x)

    local cameraOffset = Vector3.new(
        math.sin(angleYRad) * cameraConfig.distance,
        math.sin(angleXRad) * cameraConfig.distance,
        math.cos(angleYRad) * cameraConfig.distance
    )

    local cameraPosition = adjustedCenter + cameraOffset

    -- Create camera
    local camera = Instance.new("Camera")
    camera.CFrame = CFrame.lookAt(cameraPosition, adjustedCenter)
    camera.Parent = self.generateWorkspace

    self.logger:debug("Camera positioned", {
        modelCenter = modelCenter,
        cameraPosition = cameraPosition,
        distance = cameraConfig.distance,
        angle_y = cameraConfig.angle_y,
        angle_x = cameraConfig.angle_x,
    })

    return camera
end

function AssetImageGenerator:CreateCaptureViewport(camera)
    local imageSize = petConfig.asset_images.image_size

    -- Create a ScreenGui to hold the viewport
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ImageCaptureGui"
    screenGui.Parent = Players.LocalPlayer.PlayerGui

    -- Create ViewportFrame for image capture
    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "CaptureViewport"
    viewport.Size = UDim2.new(0, imageSize, 0, imageSize)
    viewport.Position = UDim2.new(0, 50, 0, 50) -- Position for visibility
    viewport.BackgroundColor3 = petConfig.asset_images.background_color
    viewport.CurrentCamera = camera
    viewport.Parent = screenGui

    self.logger:info("Created capture viewport", {
        size = imageSize,
        note = "Right-click viewport and 'Copy Image' to capture",
    })

    return viewport
end

function AssetImageGenerator:SetupGenerationWorkspace()
    if self.generateWorkspace then
        self.generateWorkspace:Destroy()
    end

    self.generateWorkspace = Instance.new("Folder")
    self.generateWorkspace.Name = "ImageGenerationWorkspace"
    self.generateWorkspace.Parent = workspace

    self.logger:debug("Created generation workspace")
end

function AssetImageGenerator:CleanupGenerationWorkspace()
    if self.generateWorkspace then
        self.generateWorkspace:Destroy()
        self.generateWorkspace = nil
    end

    self.logger:debug("Cleaned up generation workspace")
end

function AssetImageGenerator:ApplyLightingPreset(presetName)
    local lightingPresets = petConfig.asset_images.lighting_presets
    local preset = lightingPresets[presetName] or lightingPresets.default

    -- Store original lighting for restoration
    self.originalLighting = {
        Ambient = Lighting.Ambient,
        Brightness = Lighting.Brightness,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
        ColorShift_Top = Lighting.ColorShift_Top,
        OutdoorAmbient = Lighting.OutdoorAmbient,
    }

    -- Apply preset lighting
    Lighting.Ambient = preset.ambient
    Lighting.OutdoorAmbient = preset.ambient

    -- You could add directional lights here based on the preset configuration

    self.logger:debug("Applied lighting preset", {
        preset = presetName,
        ambient = preset.ambient,
    })
end

function AssetImageGenerator:RestoreOriginalLighting()
    if next(self.originalLighting) then
        for property, value in pairs(self.originalLighting) do
            Lighting[property] = value
        end
        self.originalLighting = {}
        self.logger:debug("Restored original lighting")
    end
end

-- === CONFIGURATION TOOLS ===

function AssetImageGenerator:TestCameraAngle(petType, variant, distance, angleY, angleX)
    self.logger:info("Testing camera angle", {
        petType = petType,
        variant = variant,
        distance = distance,
        angleY = angleY,
        angleX = angleX,
    })

    -- Create temporary camera config
    local testConfig = {
        distance = distance or 7,
        angle_y = angleY or 25,
        angle_x = angleX or 0,
        offset = Vector3.new(0, 0, 0),
        lighting = "default",
    }

    -- Get pet data
    local petData = self:GetPetData(petType, variant)
    if not petData then
        self.logger:error("Pet data not found")
        return false
    end

    -- Setup workspace
    self:SetupGenerationWorkspace()

    -- Load model
    local model = self:LoadPetModel(petData.asset_id)
    if not model then
        self.logger:error("Failed to load model")
        self:CleanupGenerationWorkspace()
        return false
    end

    -- Setup camera with test config
    local camera = self:SetupCamera(model, testConfig)

    -- Create viewport for testing
    local viewport = self:CreateCaptureViewport(camera)

    self.logger:info("Test setup complete - check viewport in PlayerGui")

    return true
end

return AssetImageGenerator
