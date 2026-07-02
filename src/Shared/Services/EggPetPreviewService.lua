--[[
    EggPetPreviewService - Shows pet preview with hatch chances when approaching eggs
    
    Displays pets and their calculated hatch percentages based on:
    - Base egg configuration chances
    - Player luck aggregates (from Player/Aggregates/ folder)
    - Player level, pets hatched, gamepass ownership
    - VIP status and other modifiers
    
    Features:
    - Real-time chance calculation including all player modifiers
    - Pet icons with percentage display
    - Shows "??" for very rare pets (<0.1% chance)
    - Follows working game's UI positioning pattern
]]

local EggPetPreviewService = {}

local RunService = game:GetService("RunService")
local AssetFetch = require(game:GetService("ReplicatedStorage").Shared.Utils.AssetFetch)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Dependencies
local Locations = require(ReplicatedStorage.Shared.Locations)
local petConfig = Locations.getConfig("pets")
local eggSystemConfig = Locations.getConfig("egg_system")
local petVisualsOk, PetVariantVisuals = pcall(function()
    return require(ReplicatedStorage.Shared.Services.PetVariantVisuals)
end)

-- Get player and camera
local player = Players.LocalPlayer or _G.__TEST_LOCAL_PLAYER or Players:GetPlayers()[1]
local camera = workspace.CurrentCamera

-- UI state
local petPreviewUI = nil
local currentEggType = nil
local iconCache = {}

-- Logger setup using LoggerWrapper pattern from memory
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
    -- Fallback LoggerWrapper implementation
    LoggerWrapper = {
        new = function(name)
            return {
                info = function(self, ...)
                    print("[INFO]", "[" .. name .. "]", ...)
                end,
                warn = function(self, ...)
                    warn("[WARN]", "[" .. name .. "]", ...)
                end,
                error = function(self, ...)
                    warn("[ERROR]", "[" .. name .. "]", ...)
                end,
                debug = function(self, ...)
                    print("[DEBUG]", "[" .. name .. "]", ...)
                end,
            }
        end,
    }
end

local logger = LoggerWrapper.new("EggPetPreviewService")

-- === PLAYER DATA GATHERING ===

-- Get player's current luck modifiers and stats
function EggPetPreviewService:GetPlayerData(targetPlayer)
    local p = targetPlayer or player

    local playerData = {
        level = (p and p.GetAttribute and p:GetAttribute("Level")) or 1,
        petsHatched = (p and p.GetAttribute and p:GetAttribute("PetsHatched")) or 0,
        hasLuckGamepass = false,
        hasGoldenGamepass = false,
        hasRainbowGamepass = false,
        isVIP = false,

        -- Aggregate luck values from Player/Aggregates/
        luckBoost = 0,
        rareLuckBoost = 0,
        ultraLuckBoost = 0,
    }

    -- Get aggregate values from Player/Aggregates/ folder
    if
        (typeof(p) == "Instance" and p:FindFirstChild("Aggregates"))
        or (type(p) == "table" and p.FindFirstChild and p:FindFirstChild("Aggregates"))
    then
        local aggregates = p:FindFirstChild("Aggregates")

        -- Read luck values from NumberValue objects (real-time aggregated)
        local luckObj = aggregates:FindFirstChild("luckBoost")
        if luckObj and luckObj.Value ~= nil then
            playerData.luckBoost = luckObj.Value
        end
        local rareLuckObj = aggregates:FindFirstChild("rareLuckBoost")
        if rareLuckObj and rareLuckObj.Value ~= nil then
            playerData.rareLuckBoost = rareLuckObj.Value
        end
        local ultraLuckObj = aggregates:FindFirstChild("ultraLuckBoost")
        if ultraLuckObj and ultraLuckObj.Value ~= nil then
            playerData.ultraLuckBoost = ultraLuckObj.Value
        end
    end

    -- TODO: Get gamepass ownership from DataService when available
    -- For now using placeholder values

    -- Check premium status
    if p and p.MembershipType == Enum.MembershipType.Premium then
        playerData.isVIP = true
    end

    return playerData
end

-- === PET CHANCE CALCULATION ===

-- Calculate visible pet species chances for an egg.
-- Variant odds are a second hidden roll, so the preview always displays basic-form pets.
function EggPetPreviewService:CalculatePetChances(eggType)
    local eggData = petConfig.egg_sources[eggType]
    if not eggData then
        logger:warn("Invalid egg type for chance calculation:", eggType)
        return {}
    end

    local playerData = self:GetPlayerData()
    local luckMultiplier = 1
    local petChances = {}

    -- Stage 1: Get pet type weights
    local totalWeight = 0
    for _, weight in pairs(eggData.pet_weights) do
        totalWeight = totalWeight + weight
    end

    -- Calculate chances from the same relative weights used by simulateHatch.
    -- Do not assume a fixed denominator such as 100 or 100000; weights are
    -- designer-authored relative values and only their sum defines the odds.
    for petType, weight in pairs(eggData.pet_weights) do
        local petTypeChance = weight / totalWeight

        -- The egg preview answers "which pet can this hatch?"
        -- Golden/rainbow is a second hidden variant roll handled by hatching config.
        local variantsToShow = { "basic" }

        local family = petConfig.pets[petType]
        -- SECRET pets are never advertised (Jason: "they shouldn't be there at all") —
        -- no row, not even "??". The "??" marking is reserved for sub-threshold
        -- NON-secret rares (min_chance_to_show). Secret weight still counts in
        -- totalWeight so the shown odds stay truthful (they just sum below 100%).
        local isSecret = family and family.rarity == "secret"

        if family and family.variants and not isSecret then
            for _, variant in ipairs(variantsToShow) do
                if family.variants[variant] then
                    table.insert(petChances, {
                        petType = petType,
                        variant = variant,
                        chance = petTypeChance,
                        petData = petConfig.getPet(petType, variant),
                    })
                end
            end
        end
    end

    -- Sort by chance (highest first) if configured
    if eggSystemConfig.pet_preview.sort_by_chance then
        table.sort(petChances, function(a, b)
            return a.chance > b.chance
        end)
    end

    logger:debug("Calculated pet chances", {
        eggType = eggType,
        playerLevel = playerData.level,
        luckMultiplier = luckMultiplier,
        totalPets = #petChances,
    })

    return petChances
end

-- === PET PREVIEW UI ===

-- Create the pet preview UI as BillboardGui
function EggPetPreviewService:CreatePetPreviewUI()
    if petPreviewUI then
        petPreviewUI:Destroy()
    end

    local config = eggSystemConfig.ui
    local previewConfig = eggSystemConfig.pet_preview

    -- Create BillboardGui for 3D world attachment
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "EggPetPreview"
    billboardGui.Size =
        UDim2.fromScale(previewConfig.billboard_size[1], previewConfig.billboard_size[2]) -- Configurable stud-based sizing
    billboardGui.StudsOffsetWorldSpace = Vector3.new(0, previewConfig.height_above_egg or 3, 0) -- Default height (will be updated per egg)
    billboardGui.AlwaysOnTop = true -- Always visible
    billboardGui.LightInfluence = 0 -- Unaffected by lighting
    billboardGui.Active = true -- Allow interactions
    billboardGui.StudsOffset = Vector3.new(0, 0, 0) -- No additional offset
    billboardGui.ClipsDescendants = false -- Don't clip content at edges
    billboardGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- Proper layering

    local frame = Instance.new("Frame")
    frame.Name = "PetPreviewFrame"
    frame.Size = UDim2.fromScale(1, 1) -- Fill the billboard
    frame.BackgroundColor3 = config.colors.pet_preview_bg
    frame.BackgroundTransparency = config.pet_preview_bg_transparency or 0
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = billboardGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, config.corner_radius)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = config.border_thickness
    stroke.Color = config.colors.pet_preview_border
    stroke.Transparency = config.pet_preview_border_transparency or 0
    stroke.Parent = frame

    -- Title (optional, based on configuration)
    local titleHeight = 0
    if previewConfig.show_title then
        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.Size = UDim2.new(1, -20, 0, 30)
        title.Position = UDim2.new(0, 10, 0, 10)
        title.BackgroundTransparency = 1
        title.Text = previewConfig.title_text
        title.TextColor3 = config.colors.text_primary
        title.TextScaled = true
        title.Font = config.fonts.title
        title.Parent = frame
        titleHeight = 40 -- 30px title + 10px spacing
    end

    -- Container frame for pets (no scrolling - fixed horizontal layout)
    local petContainer = Instance.new("Frame")
    petContainer.Name = "PetContainer"
    petContainer.Size = UDim2.new(1, -20, 1, -titleHeight - 10)
    petContainer.Position = UDim2.new(0, 10, 0, titleHeight)
    petContainer.BackgroundTransparency = 1
    petContainer.BorderSizePixel = 0
    petContainer.Parent = frame

    -- No grid layout - we'll manually position pets for perfect centering

    -- Parent to PlayerGui for interactions while using Adornee for positioning
    billboardGui.Parent = player.PlayerGui

    petPreviewUI = billboardGui
    logger:info("Pet preview BillboardGui created")
    return frame
end

-- Get effective configuration with per-egg overrides
function EggPetPreviewService:GetEffectiveConfig(eggType)
    local baseConfig = eggSystemConfig
    local eggOverrides = baseConfig.pet_preview.egg_display_overrides[eggType] or {}

    -- Create merged configuration
    local effectiveConfig = {
        ui = baseConfig.ui,
        pet_preview = {},
    }

    -- Merge base pet_preview with egg-specific overrides
    for key, value in pairs(baseConfig.pet_preview) do
        effectiveConfig.pet_preview[key] = eggOverrides[key] or value
    end

    -- Merge UI colors with egg-specific overrides
    effectiveConfig.ui.colors = {}
    for key, value in pairs(baseConfig.ui.colors) do
        effectiveConfig.ui.colors[key] = eggOverrides[key] or value
    end

    return effectiveConfig
end

-- Smart percentage formatting - shows meaningful digits
function EggPetPreviewService:FormatPercentage(chance, previewConfig)
    local chancePercent = chance * 100

    if not previewConfig.smart_percentage_formatting then
        -- Fallback to traditional fixed precision
        return string.format(
            "%." .. (previewConfig.fallback_precision or 2) .. "f%%",
            chancePercent
        )
    end

    -- Smart formatting based on magnitude
    if chancePercent >= 10 then
        -- 10%+ : Show as whole numbers (25%, 67%)
        return string.format("%.0f%%", chancePercent)
    elseif chancePercent >= 1 then
        -- 1-9.9% : Show one decimal if needed (5%, 2.5%, 1.2%)
        local rounded = math.floor(chancePercent * 10 + 0.5) / 10
        if rounded == math.floor(rounded) then
            return string.format("%.0f%%", rounded)
        else
            return string.format("%.1f%%", rounded)
        end
    elseif chancePercent >= 0.1 then
        -- 0.1-0.99% : Show two decimals (0.25%, 0.50%)
        return string.format("%.2f%%", chancePercent)
    elseif chancePercent >= 0.01 then
        -- 0.01-0.099% : Show three decimals (0.025%, 0.050%)
        return string.format("%.3f%%", chancePercent)
    else
        -- Below 0.01% : This should be handled by min_chance_to_show threshold
        return string.format("%.4f%%", chancePercent)
    end
end

-- Update pet preview display
function EggPetPreviewService:UpdatePetPreview(eggType, eggAnchor)
    if not eggSystemConfig.pet_preview.enabled then
        return
    end

    if not petPreviewUI then
        self:CreatePetPreviewUI()
    end

    local frame = petPreviewUI.PetPreviewFrame
    local container = frame.PetContainer
    local effectiveConfig = self:GetEffectiveConfig(eggType)
    local previewConfig = effectiveConfig.pet_preview

    if eggType and eggType ~= "None" and eggAnchor then
        -- Attach BillboardGui to the egg anchor (EggSpawnPoint)
        petPreviewUI.Adornee = eggAnchor

        -- Set height based on egg type (use override if configured, otherwise use default)
        local height = previewConfig.egg_height_overrides[eggType] or previewConfig.height_above_egg
        petPreviewUI.StudsOffsetWorldSpace = Vector3.new(0, height, 0)

        -- Calculate chances for this egg
        local petChances = self:CalculatePetChances(eggType)

        -- Clear existing pet displays
        for _, child in ipairs(container:GetChildren()) do
            child:Destroy()
        end

        -- Show pets up to max display limit
        local displayCount = math.min(#petChances, previewConfig.max_pets_to_display)

        -- Create pets with center-out positioning algorithm
        self:CreateCenteredPetLayout(
            container,
            petChances,
            displayCount,
            previewConfig,
            effectiveConfig
        )

        -- Show the frame
        frame.Visible = true
        currentEggType = eggType
    else
        -- Hide when no egg in range
        frame.Visible = false
        petPreviewUI.Adornee = nil
        currentEggType = nil
    end
end

--[[
    Create centered pet layout with scale-based positioning
    
    CRITICAL FIX: This function solves the BillboardGui scaling issue where:
    - BillboardGui scales with camera distance (grows when closer, shrinks when farther)
    - Fixed pixel sizing (UDim2.new) doesn't scale with the billboard
    - Result: Different numbers of pets visible at different distances
    
    SOLUTION: Use UDim2.fromScale for ALL sizing - everything scales together
--]]
function EggPetPreviewService:CreateCenteredPetLayout(
    container,
    petChances,
    displayCount,
    previewConfig,
    effectiveConfig
)
    if displayCount == 0 then
        return
    end

    local config = eggSystemConfig.ui

    -- Scale-based sizing calculations (percentages, not pixels)
    -- This ensures all elements scale together with BillboardGui distance changes
    local petWidthScale = 1 / displayCount * 0.9 -- Each pet: 90% of space divided by count
    local spacingScale = 1 / displayCount * 0.1 / math.max(1, displayCount - 1) -- 10% for spacing

    -- Calculate perfect centering for any number of pets (1-6)
    local totalContentScale = (petWidthScale * displayCount)
        + (spacingScale * math.max(0, displayCount - 1))
    local startX = (1 - totalContentScale) / 2 -- Center the entire group

    -- Create pets with scale-based positioning (maintains layout at any camera distance)
    for i = 1, displayCount do
        local petInfo = petChances[i]
        local xPositionScale = startX + ((i - 1) * (petWidthScale + spacingScale))

        self:CreatePetDisplayAtPosition(
            container,
            petInfo,
            i,
            xPositionScale,
            petWidthScale,
            previewConfig,
            effectiveConfig
        )
    end
end

--[[
    Create individual pet display element with scale-based positioning
    
    IMPORTANT: All sizing uses UDim2.fromScale() to ensure consistent scaling
    with the parent BillboardGui at any camera distance.
--]]
function EggPetPreviewService:CreatePetDisplayAtPosition(
    parent,
    petInfo,
    layoutOrder,
    xPositionScale,
    petWidthScale,
    previewConfig,
    effectiveConfig
)
    -- Pet frame with scale-based dimensions (grows/shrinks with billboard)
    local petFrame = Instance.new("Frame")
    petFrame.Name = "Pet_" .. layoutOrder
    petFrame.Size = UDim2.fromScale(petWidthScale, 0.8) -- Width calculated dynamically, 80% height
    petFrame.Position = UDim2.new(xPositionScale, 0, 0.5, 0) -- X calculated, Y centered
    petFrame.AnchorPoint = Vector2.new(0, 0.5) -- Anchor from left edge, vertical center

    -- Apply pet-specific display settings with fallbacks
    local petData = petInfo.petData
    local petDefaults = petConfig.viewport

    -- Background color (pet override > egg override > pet default > "rarity")
    local bgColor = petData.display_container_bg
        or effectiveConfig.ui.colors.pet_container_bg
        or petDefaults.default_container_bg
        or "rarity"
    if bgColor == "rarity" then
        petFrame.BackgroundColor3 = petInfo.petData.rarity.color
    else
        petFrame.BackgroundColor3 = bgColor
    end

    -- Transparency (pet override > egg override > pet default > fallback)
    petFrame.BackgroundTransparency = petData.display_container_transparency
        or effectiveConfig.ui.colors.pet_container_transparency
        or petDefaults.default_container_transparency
        or 0.8
    petFrame.BorderSizePixel = 0
    petFrame.Parent = parent

    local petCorner = Instance.new("UICorner")
    petCorner.CornerRadius = UDim.new(0, 8)
    petCorner.Parent = petFrame

    -- Call the pet content creation logic
    self:CreatePetContent(petFrame, petInfo, previewConfig, effectiveConfig)
end

--[[
    Create pet content (icon, name, chance) with scale-based layout
    
    ALL ELEMENTS use UDim2.fromScale() to maintain proportions at any camera distance.
    This ensures ViewportFrames and text scale consistently with the BillboardGui.
--]]
function EggPetPreviewService:CreatePetContent(petFrame, petInfo, previewConfig, effectiveConfig)
    -- Pet display using preloaded images from ReplicatedStorage.Assets
    if previewConfig.load_pet_icons then
        -- Check configuration to determine display method
        local displayMethod = self:GetDisplayMethod("egg_preview")

        if displayMethod == "images" then
            -- Try to get preloaded image from assets first
            local image = self:GetPetImageFromAssets(petInfo.petType, petInfo.variant)

            if image then
                -- Use the preloaded image (ViewportFrame)
                image.Name = "PetImage"
                image.Size = UDim2.fromScale(0.9, 0.65)
                image.Position = UDim2.fromScale(0.05, 0.05)
                image.Parent = petFrame

                logger:info("Loaded preloaded pet image", {
                    petType = petInfo.petType,
                    variant = petInfo.variant,
                    source = "ReplicatedStorage.Assets.Images",
                })
            else
                -- Fallback to emoji if preloaded image not available
                self:CreateEmojiPetIcon(petFrame, petInfo, effectiveConfig)
            end
        elseif displayMethod == "viewports" then
            -- 3D ViewportFrame creation (restored from working implementation)
            if petInfo.petData.asset_id and petInfo.petData.asset_id ~= "rbxassetid://0" then
                -- Scale-based ViewportFrame (fixes the core scaling issue)
                local viewport = Instance.new("ViewportFrame")
                viewport.Name = "PetViewport"
                viewport.Size = UDim2.fromScale(0.9, 0.65) -- 90% width, 65% height - reserve space for text
                viewport.Position = UDim2.fromScale(0.05, 0.05) -- 5% margins from top
                -- Viewport background with fallbacks
                viewport.BackgroundColor3 = effectiveConfig.ui.colors.pet_icon_bg
                    or Color3.fromRGB(0, 0, 0)
                viewport.BackgroundTransparency = effectiveConfig.ui.colors.pet_icon_transparency
                    or 1
                viewport.Parent = petFrame

                -- Create camera for the viewport
                local camera = Instance.new("Camera")
                camera.Parent = viewport
                viewport.CurrentCamera = camera

                logger:info("Loading 3D pet model for viewport", {
                    petType = petInfo.petType,
                    variant = petInfo.variant,
                    assetId = petInfo.petData.asset_id,
                })

                -- Load the 3D model asynchronously
                self:Load3DPetModel(
                    petInfo.petData.asset_id,
                    viewport,
                    camera,
                    petInfo.petType,
                    petInfo.variant,
                    petInfo
                )
            else
                -- No valid asset ID, use emoji fallback
                self:CreateEmojiPetIcon(petFrame, petInfo, effectiveConfig)
            end
        else
            -- Unknown config, default to images
            logger:warn("Unknown display method, defaulting to emoji", {
                displayMethod = displayMethod,
                petType = petInfo.petType,
            })
            self:CreateEmojiPetIcon(petFrame, petInfo, effectiveConfig)
        end
    else
        -- Icons disabled in config - use emoji fallback
        logger:debug("Pet icons disabled in config", {
            petType = petInfo.petType,
        })
        self:CreateEmojiPetIcon(petFrame, petInfo, effectiveConfig)
    end

    -- Pet name (if enabled) - scale-based and configurable per pet
    local petData = petInfo.petData
    local petDefaults = petConfig.viewport
    local showName = petData.display_show_name
    if showName == nil then -- Check for nil explicitly since false is valid
        showName = previewConfig.show_variant_names or petDefaults.default_show_name
    end

    if showName then
        local petName = Instance.new("TextLabel")
        petName.Name = "Name"
        petName.Size = UDim2.fromScale(1, 0.15) -- Full width, 15% height
        petName.Position = UDim2.fromScale(0, 0.7) -- Below the icon area (65% + 5% gap)
        petName.BackgroundTransparency = 1
        petName.Text = petInfo.petData.name
        -- Apply pet-specific name color with fallbacks
        petName.TextColor3 = petData.display_name_color
            or effectiveConfig.ui.colors.text_primary
            or petDefaults.default_name_color
            or Color3.fromRGB(0, 0, 139)
        petName.TextScaled = true
        petName.Font = effectiveConfig.ui.fonts.pet_name or Enum.Font.Gotham
        petName.Parent = petFrame
    end

    -- Chance percentage - scale-based
    local chanceLabel = Instance.new("TextLabel")
    chanceLabel.Name = "Chance"
    chanceLabel.Size = UDim2.fromScale(1, 0.15) -- Full width, 15% height
    chanceLabel.Position = UDim2.fromScale(0, 0.85) -- Bottom 15% of frame
    chanceLabel.BackgroundTransparency = 1
    chanceLabel.Font = effectiveConfig.ui.fonts.pet_chance or Enum.Font.Bangers
    chanceLabel.Parent = petFrame

    -- Format chance display with smart formatting and configurable threshold
    local minThreshold = effectiveConfig.pet_preview.min_chance_to_show
        or previewConfig.min_chance_to_show

    if petInfo.chance < minThreshold then
        chanceLabel.Text = "??"
        chanceLabel.TextColor3 = petData.display_chance_color
            or effectiveConfig.ui.colors.very_rare_text
            or petDefaults.default_chance_color
            or Color3.fromRGB(139, 0, 0)
    else
        chanceLabel.Text = self:FormatPercentage(petInfo.chance, effectiveConfig.pet_preview)
        chanceLabel.TextColor3 = petData.display_chance_color
            or effectiveConfig.ui.colors.text_secondary
            or petDefaults.default_chance_color
            or Color3.fromRGB(139, 0, 0)
    end
    chanceLabel.TextScaled = true
end

-- Load 3D pet model into ViewportFrame with configurable zoom (using ReplicatedStorage.Assets)
function EggPetPreviewService:Load3DPetModel(assetId, viewport, camera, petType, variant, petInfo)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    task.spawn(function()
        local success, result = pcall(function()
            logger:debug("Loading 3D model from ReplicatedStorage.Assets", {
                assetId = assetId,
                petType = petType,
                variant = variant,
            })

            -- Try to get model from ReplicatedStorage.Assets.Models.Pets first
            local modelClone = nil
            local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")

            if assetsFolder then
                local modelsFolder = assetsFolder:FindFirstChild("Models")
                if modelsFolder then
                    local petsFolder = modelsFolder:FindFirstChild("Pets")
                    if petsFolder then
                        local petTypeFolder = petsFolder:FindFirstChild(petType)
                        if petTypeFolder then
                            local petModel = petTypeFolder:FindFirstChild(variant)
                            if petModel then
                                modelClone = petModel:Clone()
                                logger:debug("Got model from ReplicatedStorage.Assets", {
                                    petType = petType,
                                    variant = variant,
                                    modelName = modelClone.Name,
                                    path = petModel:GetFullName(),
                                })
                            end
                        end
                    end
                end
            end

            -- Fallback to runtime loading if not in assets
            if not modelClone then
                local InsertService = game:GetService("InsertService")
                local cleanId = assetId:match("%d+")

                if not cleanId then
                    error("Invalid asset ID format: " .. tostring(assetId))
                end

                logger:debug(
                    "Model not found in Assets, falling back to runtime InsertService loading",
                    {
                        assetId = cleanId,
                        petType = petType,
                        variant = variant,
                    }
                )

                local loadedAsset = AssetFetch.load(tonumber(cleanId))
                if not loadedAsset then
                    error("Failed to load asset: " .. cleanId)
                end

                -- Find the model inside the asset
                local petModel = loadedAsset:FindFirstChildOfClass("Model")
                if not petModel then
                    error("No Model found in asset: " .. cleanId)
                end

                -- Clone and set up the model
                modelClone = petModel:Clone()
                loadedAsset:Destroy() -- Clean up the original asset
            end

            if petVisualsOk and PetVariantVisuals then
                PetVariantVisuals.ApplyServerMetadata(modelClone, petType, variant)
                PetVariantVisuals.ApplyStaticVisuals(modelClone)
            end

            -- Position the model at the origin
            local pos = Vector3.new(0, 0, 0)
            if modelClone.PrimaryPart then
                modelClone:SetPrimaryPartCFrame(CFrame.new(pos))
            elseif modelClone:FindFirstChild("HumanoidRootPart") then
                modelClone.HumanoidRootPart.CFrame = CFrame.new(pos)
            elseif modelClone:FindFirstChildOfClass("Part") then
                modelClone:FindFirstChildOfClass("Part").CFrame = CFrame.new(pos)
            end

            -- Parent to viewport
            modelClone.Parent = viewport

            --[[
                Calculate camera distance with configurable zoom system
                
                ZOOM SYSTEM:
                - Higher zoom values = closer camera = larger pet appearance
                - zoom 1.0 = default distance, zoom 1.5 = 1.5x closer, zoom 2.0 = 2x closer
                - Per-pet overrides allow fine-tuning for specific pets
                - Distance = baseDistance / zoomMultiplier
            --]]
            local modelSize = modelClone:GetExtentsSize()
            local previewConfig = eggSystemConfig.pet_preview

            -- Get zoom multiplier from pet data with proper fallback to default
            local zoomMultiplier = petInfo.petData.viewport_zoom or petConfig.viewport.default_zoom

            -- Calculate base distance (standard 1.5x model size) and apply zoom
            local baseDistance = math.max(modelSize.X, modelSize.Y, modelSize.Z) * 1.5
            local distance = baseDistance / zoomMultiplier -- Higher zoom = closer camera = bigger pet

            -- Safety clamp for extreme zoom levels
            if distance < 2 then
                distance = 2 -- Prevent camera from getting too close and clipping
            end

            logger:info("3D model loaded successfully", {
                petType = petType,
                modelSize = modelSize,
                baseDistance = baseDistance,
                zoomMultiplier = zoomMultiplier,
                finalCameraDistance = distance,
            })

            -- Set up camera (spinning or static based on config)
            if eggSystemConfig.pet_preview.enable_model_spinning then
                -- Spinning animation (like MCP)
                local cameraAngle = 0
                local rotationSpeed = eggSystemConfig.pet_preview.model_rotation_speed
                local connection
                connection = game:GetService("RunService").Heartbeat:Connect(function()
                    if viewport.Parent and modelClone.Parent then
                        -- Rotate camera around the model
                        camera.CFrame = CFrame.Angles(0, math.rad(cameraAngle), 0)
                            * CFrame.new(pos + Vector3.new(0, 0, distance), pos)
                        cameraAngle = cameraAngle + rotationSpeed
                        if cameraAngle >= 360 then
                            cameraAngle = 0
                        end
                    else
                        -- Clean up if viewport or model is destroyed
                        connection:Disconnect()
                    end
                end)
            else
                -- Static camera position
                local staticAngle = eggSystemConfig.pet_preview.static_camera_angle
                camera.CFrame = CFrame.Angles(0, math.rad(staticAngle), 0)
                    * CFrame.new(pos + Vector3.new(0, 0, distance), pos)
            end
        end)

        if not success then
            logger:warn("Failed to load 3D model, falling back to emoji", {
                assetId = assetId,
                petType = petType,
                error = tostring(result),
            })

            -- Fallback to emoji if 3D loading fails
            viewport:Destroy()
            local fallbackIcon = Instance.new("TextLabel")
            fallbackIcon.Name = "FallbackIcon"
            fallbackIcon.Size = UDim2.new(
                0,
                eggSystemConfig.pet_preview.pet_icon_size,
                0,
                eggSystemConfig.pet_preview.pet_icon_size
            )
            fallbackIcon.Position =
                UDim2.new(0.5, -eggSystemConfig.pet_preview.pet_icon_size / 2, 0, 5)
            fallbackIcon.BackgroundTransparency = 1
            fallbackIcon.Text = self:GetPetEmojiIcon(petType)
            fallbackIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
            fallbackIcon.TextScaled = true
            fallbackIcon.Font = eggSystemConfig.ui.fonts.pet_icon_fallback
            fallbackIcon.Parent = viewport.Parent
        end
    end)
end

-- Get pet asset image ID for display
function EggPetPreviewService:GetPetAssetImage(assetId)
    logger:debug("Processing asset ID", { inputAssetId = assetId, inputType = type(assetId) })

    if not assetId or assetId == "rbxassetid://0" or assetId == "" then
        logger:info("Invalid asset ID detected, will use emoji fallback", {
            assetId = assetId,
            reason = "nil, empty, or placeholder asset",
        })
        return "" -- Will trigger emoji fallback
    end

    -- Extract just the numbers from the asset ID
    local cleanId = assetId:match("%d+")
    logger:debug("Extracted ID from asset string", {
        originalAssetId = assetId,
        extractedId = cleanId,
        extractedIdType = type(cleanId),
    })

    if not cleanId or cleanId == "0" then
        logger:warn("Could not extract valid ID from asset string", {
            assetId = assetId,
            extractedId = cleanId,
            reason = "regex match failed or extracted zero",
        })
        return "" -- Will trigger emoji fallback
    end

    -- For 3D model assets, we need to use a different approach
    -- ImageLabels can't directly display 3D models, but we can try the asset ID directly
    -- Roblox sometimes auto-generates thumbnails for models
    local finalAssetId = "rbxassetid://" .. cleanId
    logger:info("Processed asset ID for ImageLabel", {
        originalAssetId = assetId,
        extractedId = cleanId,
        finalAssetId = finalAssetId,
        note = "This may fail if asset is a 3D model rather than an image",
    })
    return finalAssetId
end

-- Get pet emoji icon (fallback when asset loading fails)
function EggPetPreviewService:GetPetEmojiIcon(petType)
    local petIcons = {
        bear = "🐻",
        bunny = "🐰",
        doggy = "🐶",
        kitty = "🐱",
        dragon = "🐲",
    }

    return petIcons[petType] or "🐾"
end

-- Get pet image from preloaded assets
function EggPetPreviewService:GetPetImageFromAssets(petType, variant)
    -- Try to get from ReplicatedStorage.Assets.Images.Pets first
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if assetsFolder then
        local imagesFolder = assetsFolder:FindFirstChild("Images")
        if imagesFolder then
            local petsFolder = imagesFolder:FindFirstChild("Pets")
            if petsFolder then
                local petTypeFolder = petsFolder:FindFirstChild(petType)
                if petTypeFolder then
                    local image = petTypeFolder:FindFirstChild(variant)
                    if image then
                        return image:Clone()
                    end
                end
            end
        end
    end

    logger:debug("Preloaded image not found in assets", {
        petType = petType,
        variant = variant,
        path = "ReplicatedStorage.Assets.Images.Pets." .. petType .. "." .. variant,
    })

    return nil
end

-- === PUBLIC API ===

-- Show pet preview for an egg anchor (EggSpawnPoint)
function EggPetPreviewService:ShowPetPreview(eggType, eggAnchor)
    self:UpdatePetPreview(eggType, eggAnchor)
end

-- Hide pet preview
function EggPetPreviewService:HidePetPreview()
    self:UpdatePetPreview(nil, nil)
end

-- Update preview position (BillboardGui handles this automatically via Adornee)
function EggPetPreviewService:UpdatePreviewPosition(eggAnchor)
    if petPreviewUI and currentEggType and eggAnchor then
        -- BillboardGui automatically follows the Adornee, so just update the target
        petPreviewUI.Adornee = eggAnchor
    end
end

-- Get current preview state
function EggPetPreviewService:GetCurrentEggType()
    return currentEggType
end

-- Get UI display method based on user preferences + configuration
function EggPetPreviewService:GetDisplayMethod(context)
    local Players = game:GetService("Players")

    local AssetFetch = require(ReplicatedStorage.Shared.Utils.AssetFetch)
    local player = Players.LocalPlayer

    if not player then
        -- Server-side or no player, use config fallback
        if petConfig.ui_display.context_overrides[context] then
            return petConfig.ui_display.context_overrides[context]
        end
        return petConfig.ui_display[context] or "images"
    end

    -- Client-side: Read from replicated player folders
    if RunService:IsClient() then
        local success, result = pcall(function()
            -- Read from replicated Settings folders (same logic as DisplayPreferences utility)
            local settingsFolder = player:FindFirstChild("Settings")
            if settingsFolder then
                local displayPrefFolder = settingsFolder:FindFirstChild("DisplayPreferences")
                if displayPrefFolder then
                    local contextValue = displayPrefFolder:FindFirstChild(context)
                    if contextValue and contextValue.Value ~= "" then
                        return contextValue.Value
                    end
                end
            end

            -- Fallback to config defaults
            if petConfig.ui_display and petConfig.ui_display[context] then
                local contextConfig = petConfig.ui_display[context]

                if contextConfig == "images" or contextConfig == "viewports" then
                    return contextConfig
                elseif contextConfig == "user" then
                    -- User choice - check defaults
                    local userPrefs = petConfig.ui_display.user_preferences
                    if userPrefs and userPrefs.defaults and userPrefs.defaults[context] then
                        return userPrefs.defaults[context]
                    end
                end
            end

            -- Final fallback
            return "images"
        end)

        if success then
            logger:info("Using display preference", {
                context = context,
                method = result,
                player = player.Name,
                source = "SettingsService",
            })
            return result
        else
            logger:warn("Error reading display preferences, using config fallback", {
                context = context,
                error = result,
            })
        end
    else
        -- Server-side fallback to configuration-only
        logger:info("Server-side, using config fallback", {
            context = context,
        })

        -- Check for context override first
        if petConfig.ui_display.context_overrides[context] then
            return petConfig.ui_display.context_overrides[context]
        end

        -- Use default setting for context
        return petConfig.ui_display[context] or "images" -- Default to images
    end
end

-- Create emoji pet icon (extracted from inline code)
function EggPetPreviewService:CreateEmojiPetIcon(petFrame, petInfo, effectiveConfig)
    logger:debug("Creating emoji pet icon", {
        petType = petInfo.petType,
        variant = petInfo.variant,
    })

    local petIcon = Instance.new("TextLabel")
    petIcon.Name = "Icon"
    petIcon.Size = UDim2.fromScale(0.9, 0.65)
    petIcon.Position = UDim2.fromScale(0.05, 0.05)
    petIcon.BackgroundTransparency = 1
    petIcon.Text = self:GetPetEmojiIcon(petInfo.petType)
    petIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
    petIcon.TextScaled = true
    petIcon.Font = effectiveConfig.ui.fonts.pet_icon_fallback
    petIcon.Parent = petFrame
end

-- Initialize service
function EggPetPreviewService:Initialize()
    logger:info("EggPetPreviewService initializing...")

    -- Service is ready - EggCurrentTargetService will call our methods
    logger:info("EggPetPreviewService initialized successfully")
end

-- Cleanup
function EggPetPreviewService:Destroy()
    if petPreviewUI then
        petPreviewUI:Destroy()
        petPreviewUI = nil
    end

    currentEggType = nil
    iconCache = {}

    logger:info("EggPetPreviewService destroyed")
end

return EggPetPreviewService
