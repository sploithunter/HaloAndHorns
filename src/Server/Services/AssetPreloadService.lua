--[[
    AssetPreloadService - Preloads all game assets into ReplicatedStorage.Assets
    
    This service:
    1. Extracts all asset IDs from configuration files
    2. Loads models via InsertService and places them in ReplicatedStorage.Assets.Models.Pets
    3. Creates organized folder structure for instant client access
    4. Handles asset loading failures gracefully
    
    Architecture:
    - Server loads models at startup into ReplicatedStorage.Assets.Models.Pets/
    - Client accesses models directly: ReplicatedStorage.Assets.Models.Pets.Bear.Basic
    - No RemoteFunction needed - simple direct access
]]

local AssetPreloadService = {}
AssetPreloadService.__index = AssetPreloadService

local InsertService = game:GetService("InsertService")
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetFetch = require(ReplicatedStorage.Shared.Utils.AssetFetch)
local PetVariantVisuals = require(ReplicatedStorage.Shared.Services.PetVariantVisuals)
local MeshAssembly = require(ReplicatedStorage.Shared.Assets.MeshAssembly)
local AssetReport = require(ReplicatedStorage.Shared.Game.AssetReport)
local BootReadiness = require(ReplicatedStorage.Shared.Boot.BootReadiness)

-- Record one model/mesh load attempt into the consolidated boot AssetReport. `kind` is inferred
-- from the target folder (Pets -> pet_model, etc.) so failures read as "what + where" in one log.
local function reportAsset(assetId, parentFolder, folderName, debugName, ok, err)
    local target = parentFolder and (parentFolder:GetFullName() .. "." .. tostring(folderName))
        or tostring(folderName)
    local kind = "model"
    if parentFolder then
        local pn = parentFolder.Name
        kind = (pn == "Pets" and "pet_model")
            or (pn == "Crystals" and "crystal_model")
            or (pn == "Eggs" and "egg_model")
            or pn
    end
    AssetReport.record({
        id = assetId,
        kind = kind,
        name = debugName or folderName,
        target = target,
        ok = ok,
        err = err,
    })
end

-- Service dependencies (injected)
local logger
local petConfig
local soundsConfig
local breakablesConfig

function AssetPreloadService:Init()
    logger = self._modules.Logger
    petConfig = self._modules.ConfigLoader:LoadConfig("pets")
    soundsConfig = self._modules.ConfigLoader:LoadConfig("sounds")

    -- Optional: breakables (crystals, etc.)
    local ok, cfg = pcall(function()
        return self._modules.ConfigLoader:LoadConfig("breakables")
    end)
    if ok then
        breakablesConfig = cfg
    else
        breakablesConfig = nil
    end

    logger:Info("AssetPreloadService initialized")
end

function AssetPreloadService:Start()
    -- Guard against multiple Start() calls (ModuleLoader already calls Start)
    if self._started then
        logger:Warn(
            "⚠️ AssetPreloadService:Start() called more than once - ignoring subsequent call"
        )
        return
    end
    self._started = true

    logger:Info("🚀 AssetPreloadService:Start() called")

    -- Create folder structure for assets
    logger:Info("📁 AssetPreloadService: Creating asset folders...")
    self:CreateAssetFolders()
    -- Readiness gate: flipped true at the end of LoadAllModelsIntoAssets, once every model
    -- template (pets/eggs/breakables) is built. Downstream consumers (e.g. EggStandPlacement)
    -- await this instead of racing the async build. Initialized false from the earliest boot.
    ReplicatedStorage.Assets:SetAttribute("ModelsReady", false)
    ReplicatedStorage.Assets:SetAttribute("PetThumbnailsReady", false)
    ReplicatedStorage.Assets:SetAttribute("PetThumbnailCount", 0)
    ReplicatedStorage.Assets:SetAttribute("PetThumbnailFailures", 0)

    -- Start loading models into ReplicatedStorage.Assets
    logger:Info("🔄 AssetPreloadService: Spawning LoadAllModelsIntoAssets task...")
    task.spawn(function()
        logger:Info("🔄 AssetPreloadService: LoadAllModelsIntoAssets task started")
        AssetReport.reset()
        self:LoadAllModelsIntoAssets()
        -- Load breakable models (e.g., crystals)
        self:LoadAllBreakableModelsIntoAssets()
        self:LoadAllSoundsIntoAssets()
        -- ONE consolidated boot report: every asset id that failed to load, what it is, and where
        -- it was being placed. Read this single block instead of scraping scattered warnings.
        AssetReport.flush(logger)
        logger:Info("✅ AssetPreloadService: LoadAllModelsIntoAssets task completed")
    end)

    -- Set up admin regeneration signal
    logger:Info("🔧 AssetPreloadService: Setting up admin regeneration signal...")
    self:SetupAdminRegenerationSignal()

    logger:Info("✅ AssetPreloadService:Start() completed")
end

-- Create folder structure in ReplicatedStorage.Assets
function AssetPreloadService:CreateAssetFolders()
    logger:Info("📁 CreateAssetFolders: Starting...")

    local assets = ReplicatedStorage:FindFirstChild("Assets")
    logger:Info("📁 CreateAssetFolders: Assets folder", {
        exists = assets ~= nil,
        path = assets and assets:GetFullName() or "nil",
    })

    if not assets then
        logger:Info("📁 CreateAssetFolders: Creating Assets folder...")
        assets = Instance.new("Folder")
        assets.Name = "Assets"
        assets.Parent = ReplicatedStorage
        logger:Info("✅ CreateAssetFolders: Assets folder created")
    end

    local models = assets:FindFirstChild("Models")
    logger:Info("📁 CreateAssetFolders: Models folder", {
        exists = models ~= nil,
        path = models and models:GetFullName() or "nil",
    })

    if not models then
        logger:Info("📁 CreateAssetFolders: Creating Models folder...")
        models = Instance.new("Folder")
        models.Name = "Models"
        models.Parent = assets
        logger:Info("✅ CreateAssetFolders: Models folder created")
    end

    local pets = models:FindFirstChild("Pets")
    logger:Info("📁 CreateAssetFolders: Pets folder", {
        exists = pets ~= nil,
        path = pets and pets:GetFullName() or "nil",
    })

    if not pets then
        logger:Info("📁 CreateAssetFolders: Creating Pets folder...")
        pets = Instance.new("Folder")
        pets.Name = "Pets"
        pets.Parent = models
        logger:Info("✅ CreateAssetFolders: Pets folder created")
    end

    -- Ensure Breakables/Crystals folder exists
    local breakables = models:FindFirstChild("Breakables")
    if not breakables then
        breakables = Instance.new("Folder")
        breakables.Name = "Breakables"
        breakables.Parent = models
    end
    local crystals = breakables:FindFirstChild("Crystals")
    if not crystals then
        crystals = Instance.new("Folder")
        crystals.Name = "Crystals"
        crystals.Parent = breakables
    end

    -- Ensure Sounds folder exists
    local sounds = assets:FindFirstChild("Sounds")
    if not sounds then
        sounds = Instance.new("Folder")
        sounds.Name = "Sounds"
        sounds.Parent = assets
    end

    logger:Info("✅ CreateAssetFolders: Asset folder structure complete", {
        path = "ReplicatedStorage.Assets",
    })
end

local function createHealthBillboard(parentPart)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "BillboardGui"
    billboard.Size = UDim2.new(0, 110, 0, 16)
    billboard.StudsOffset = Vector3.new(0, 2.2, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 75
    billboard.Parent = parentPart

    local background = Instance.new("Frame")
    background.Name = "Background"
    background.Size = UDim2.new(0, 100, 0, 10)
    background.Position = UDim2.new(0, 5, 0, 3)
    background.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    background.BorderSizePixel = 0
    background.Parent = billboard

    local health = Instance.new("Frame")
    health.Name = "Health"
    health.Size = UDim2.new(0, 100, 0, 10)
    health.BackgroundColor3 = Color3.fromRGB(45, 220, 95)
    health.BorderSizePixel = 0
    health.Parent = background
end

local function createCoinStackModel()
    local model = Instance.new("Model")
    model.Name = "CoinStack"

    local hitbox = Instance.new("Part")
    hitbox.Name = "Hitbox"
    hitbox.Size = Vector3.new(3.5, 2.2, 3.5)
    hitbox.Transparency = 1
    hitbox.Anchored = true
    hitbox.CanCollide = false
    hitbox.CanTouch = false
    hitbox.CanQuery = true
    hitbox.Parent = model
    model.PrimaryPart = hitbox

    for i = 1, 6 do
        local coin = Instance.new("Part")
        coin.Name = "Coin" .. tostring(i)
        coin.Shape = Enum.PartType.Cylinder
        coin.Size = Vector3.new(2.7, 0.22, 2.7)
        coin.Anchored = true
        coin.CanCollide = false
        coin.CanTouch = false
        coin.CanQuery = true
        coin.Material = Enum.Material.Metal
        coin.Color = Color3.fromRGB(255, 205, 55)
        coin.CFrame = CFrame.new((i % 2) * 0.08, (i - 1) * 0.2, ((i + 1) % 2) * 0.08)
            * CFrame.Angles(0, math.rad(i * 19), 0)
        coin.Parent = model
    end

    local sparkle = Instance.new("PointLight")
    sparkle.Name = "CoinGlow"
    sparkle.Color = Color3.fromRGB(255, 220, 95)
    sparkle.Brightness = 0.8
    sparkle.Range = 8
    sparkle.Parent = hitbox

    createHealthBillboard(hitbox)
    model:PivotTo(CFrame.identity)
    return model
end

local function createProceduralBreakableModel(kind)
    if kind == "coin_stack" then
        return createCoinStackModel()
    end
    return nil
end

local function normalizedAssetTransform(transform)
    if type(transform) ~= "table" then
        return {}
    end

    local normalized = {}
    if tonumber(transform.scale) then
        normalized.scale = tonumber(transform.scale)
    end
    if tonumber(transform.huge_scale) then
        normalized.hugeScale = tonumber(transform.huge_scale)
    elseif tonumber(transform.hugeScale) then
        normalized.hugeScale = tonumber(transform.hugeScale)
    end

    if type(transform.orientation) == "table" then
        normalized.orientation = {
            x = tonumber(transform.orientation.x) or 0,
            y = tonumber(transform.orientation.y) or 0,
            z = tonumber(transform.orientation.z) or 0,
        }
    end

    return normalized
end

local function mergeAssetTransforms(baseTransform, overrideTransform)
    local merged = normalizedAssetTransform(baseTransform)
    local override = normalizedAssetTransform(overrideTransform)

    if override.scale ~= nil then
        merged.scale = override.scale
    end
    if override.hugeScale ~= nil then
        merged.hugeScale = override.hugeScale
    end
    if override.orientation ~= nil then
        merged.orientation = override.orientation
    end

    merged.scale = merged.scale or 1
    merged.hugeScale = merged.hugeScale or 1
    merged.orientation = merged.orientation or { x = 0, y = 0, z = 0 }
    return merged
end

function AssetPreloadService:ResolvePetAssetTransform(petData, variantData)
    return mergeAssetTransforms(
        petData and petData.asset_transform,
        variantData and variantData.asset_transform
    )
end

function AssetPreloadService:ApplyConfiguredModelTransform(model, options)
    if not model or not model:IsA("Model") or type(options) ~= "table" then
        return
    end

    local scale = tonumber(options.scale)
    if scale and scale > 0 and math.abs(scale - 1) > 0.001 then
        local ok, err = pcall(function()
            model:ScaleTo(scale)
        end)
        if not ok then
            logger:Warn("Failed to apply configured model scale", {
                model = model.Name,
                scale = scale,
                error = tostring(err),
            })
        end
    end

    local transformCF = options.transformCF
    if not transformCF and type(options.orientation) == "table" then
        local orientation = options.orientation
        transformCF = CFrame.Angles(
            math.rad(orientation.x or 0),
            math.rad(orientation.y or 0),
            math.rad(orientation.z or 0)
        )
    end

    if transformCF then
        pcall(function()
            model:PivotTo(transformCF)
        end)
    end
end

function AssetPreloadService:ApplyPetTransformAttributes(model, transformOptions)
    if not model or not model:IsA("Model") or type(transformOptions) ~= "table" then
        return
    end

    local orientation = transformOptions.orientation or {}
    model:SetAttribute("AssetScale", tonumber(transformOptions.scale) or 1)
    model:SetAttribute("HugeScale", tonumber(transformOptions.hugeScale) or 1)
    model:SetAttribute("OrientationX", tonumber(orientation.x) or 0)
    model:SetAttribute("OrientationY", tonumber(orientation.y) or 0)
    model:SetAttribute("OrientationZ", tonumber(orientation.z) or 0)
end

function AssetPreloadService:NormalizePetModelParts(model)
    if not model or not model:IsA("Model") then
        return
    end

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.Massless = true
            descendant.AssemblyLinearVelocity = Vector3.new()
            descendant.AssemblyAngularVelocity = Vector3.new()
        end
    end
end

-- Load all breakable (non-pet) models such as crystals
function AssetPreloadService:LoadAllBreakableModelsIntoAssets()
    logger:Info("🔄 LoadAllBreakableModelsIntoAssets: Starting...")

    if not breakablesConfig then
        logger:Warn("LoadAllBreakableModelsIntoAssets: No breakables config found; skipping")
        return
    end

    local modelsRoot = ReplicatedStorage.Assets
        and ReplicatedStorage.Assets:FindFirstChild("Models")
    if not modelsRoot then
        logger:Error("LoadAllBreakableModelsIntoAssets: Models root missing")
        return
    end

    local breakablesFolder = modelsRoot:FindFirstChild("Breakables")
    if not breakablesFolder then
        breakablesFolder = Instance.new("Folder")
        breakablesFolder.Name = "Breakables"
        breakablesFolder.Parent = modelsRoot
    end

    local crystalsFolder = breakablesFolder:FindFirstChild("Crystals")
    if not crystalsFolder then
        crystalsFolder = Instance.new("Folder")
        crystalsFolder.Name = "Crystals"
        crystalsFolder.Parent = breakablesFolder
    end

    local successCount = 0
    local failureCount = 0

    -- Iterate crystals/breakables in config
    for crystalName, crystalData in pairs(breakablesConfig.crystals or {}) do
        local existing = crystalsFolder:FindFirstChild(crystalName)
        local prebaked = existing ~= nil
            and existing:IsA("Model")
            and existing:FindFirstChildWhichIsA("BasePart", true) ~= nil
        if prebaked then
            -- PRE-BAKED FAST PATH: a valid crystal model is already present (the Rojo-synced
            -- ReplicatedStorage.Assets.Models.Breakables.Crystals). Adopt it as-is — do NOT destroy +
            -- regenerate / re-fetch. Without this the boot wipes + RE-PULLS every crystal asset, and
            -- until that finishes the on-entry fill has no templates, so crystals only appear on the 30s
            -- safety-net sweep — the "30s window" walk-in delay that came back after the model pre-bake.
            -- (Pets + eggs got this fix; breakables were missed.)
            successCount += 1
        elseif type(crystalData) == "table" and crystalData.procedural_asset then
            if existing then
                existing:Destroy()
            end

            local model = createProceduralBreakableModel(crystalData.procedural_asset)
            if model then
                model.Name = crystalName
                model.Parent = crystalsFolder
                successCount += 1
            else
                logger:Warn("LoadAllBreakableModelsIntoAssets: Unknown procedural breakable", {
                    name = tostring(crystalName),
                    proceduralAsset = tostring(crystalData.procedural_asset),
                })
                failureCount += 1
            end
        elseif
            type(crystalData) == "table"
            and crystalData.asset_id
            and crystalData.asset_id ~= "rbxassetid://0"
        then
            -- Replace any existing (empty/invalid) model with same name
            if existing then
                existing:Destroy()
            end

            local transformCF
            if
                crystalData.default_orientation
                and type(crystalData.default_orientation) == "table"
            then
                local ori = crystalData.default_orientation
                transformCF =
                    CFrame.Angles(math.rad(ori.x or 0), math.rad(ori.y or 0), math.rad(ori.z or 0))
            end
            local ok = self:LoadModelIntoFolder(
                crystalData.asset_id,
                crystalsFolder,
                crystalName,
                "crystal_" .. crystalName,
                { transformCF = transformCF }
            )
            if ok then
                successCount += 1
            else
                failureCount += 1
            end
        else
            logger:Warn(
                "LoadAllBreakableModelsIntoAssets: Crystal missing valid asset_id",
                { name = tostring(crystalName) }
            )
            failureCount += 1
        end
    end

    logger:Info("🔄 LoadAllBreakableModelsIntoAssets: Completed", {
        crystals = {
            successful = successCount,
            failed = failureCount,
        },
    })
end

-- Load all pet models and generate images into ReplicatedStorage.Assets
function AssetPreloadService:LoadAllModelsIntoAssets()
    logger:Info("🔄 LoadAllModelsIntoAssets: Starting...")
    BootReadiness.begin("models_ready") -- boot stage start (paired with signal below)
    ReplicatedStorage.Assets:SetAttribute("ModelsReady", false)
    ReplicatedStorage.Assets:SetAttribute("PetThumbnailsReady", false)
    ReplicatedStorage.Assets:SetAttribute("PetThumbnailCount", 0)
    ReplicatedStorage.Assets:SetAttribute("PetThumbnailFailures", 0)

    local startTime = tick()
    local modelSuccessCount = 0
    local modelFailureCount = 0
    local imageSuccessCount = 0
    local imageFailureCount = 0
    local totalAssets = 0
    -- Boot-speed instrumentation: how many models were adopted from the pre-bake (instant) vs
    -- fetched over the network (slow). adopted≈total → fast boot; high fetched → stale/missing bake.
    local adoptedCount = 0
    local fetchedCount = 0

    -- Pet/egg card thumbnails (ViewportFrames) are COSMETIC (inventory cards) and each costs a second
    -- clone of the model — they don't gate gameplay. We collect them here and generate them in a
    -- deferred, yielding pass AFTER ModelsReady flips, so world population (egg placement waits on
    -- ModelsReady) isn't stuck behind ~all-pet thumbnail rendering. Job = { model, parent, name, … }.
    local thumbnailJobs = {}

    logger:Info("🔄 LoadAllModelsIntoAssets: Checking dependencies...")
    logger:Info("🔄 LoadAllModelsIntoAssets: petConfig", {
        exists = petConfig ~= nil,
        type = petConfig and type(petConfig) or "nil",
    })

    local petsFolder = ReplicatedStorage.Assets.Models.Pets
    logger:Info("🔄 LoadAllModelsIntoAssets: Pets folder found", {
        petsFolderExists = petsFolder ~= nil,
        petsFolderPath = petsFolder and petsFolder:GetFullName() or "nil",
    })

    -- Create eggs folder if it doesn't exist
    local eggsFolder = ReplicatedStorage.Assets.Models:FindFirstChild("Eggs")
    if not eggsFolder then
        eggsFolder = Instance.new("Folder")
        eggsFolder.Name = "Eggs"
        eggsFolder.Parent = ReplicatedStorage.Assets.Models
    end

    -- Create Images folder structure if it doesn't exist
    local imagesRoot = ReplicatedStorage.Assets:FindFirstChild("Images")
    if not imagesRoot then
        imagesRoot = Instance.new("Folder")
        imagesRoot.Name = "Images"
        imagesRoot.Parent = ReplicatedStorage.Assets
    end

    local petImagesFolder = imagesRoot:FindFirstChild("Pets")
    if not petImagesFolder then
        petImagesFolder = Instance.new("Folder")
        petImagesFolder.Name = "Pets"
        petImagesFolder.Parent = imagesRoot
    end

    local eggImagesFolder = imagesRoot:FindFirstChild("Eggs")
    if not eggImagesFolder then
        eggImagesFolder = Instance.new("Folder")
        eggImagesFolder.Name = "Eggs"
        eggImagesFolder.Parent = imagesRoot
    end

    -- Load pet models and generate images
    logger:Info("🔄 LoadAllModelsIntoAssets: Pet config loaded", {
        petConfigExists = petConfig ~= nil,
        petsTableExists = petConfig and petConfig.pets ~= nil,
        petCount = petConfig and petConfig.pets and #petConfig.pets or 0,
    })

    if not petConfig or not petConfig.pets then
        logger:Error("❌ LoadAllModelsIntoAssets: No pet config found!")
        return
    end

    logger:Info("🔄 LoadAllModelsIntoAssets: Starting pet loop...")
    for petType, petData in pairs(petConfig.pets) do
        logger:Info("🔄 LoadAllModelsIntoAssets: Processing pet type", {
            petType = petType,
            hasVariants = petData.variants ~= nil,
            variantsCount = petData.variants and #petData.variants or 0,
        })

        if petData.variants then
            -- Create pet type folders (e.g., "Bear")
            local petTypeFolder = petsFolder:FindFirstChild(petType)
            if not petTypeFolder then
                petTypeFolder = Instance.new("Folder")
                petTypeFolder.Name = petType
                petTypeFolder.Parent = petsFolder
            end

            local petImageTypeFolder = petImagesFolder:FindFirstChild(petType)
            if not petImageTypeFolder then
                petImageTypeFolder = Instance.new("Folder")
                petImageTypeFolder.Name = petType
                petImageTypeFolder.Parent = petImagesFolder
            end

            for variant, variantData in pairs(petData.variants) do
                totalAssets = totalAssets + 1
                local transformOptions = self:ResolvePetAssetTransform(petData, variantData)

                local hasMeshAsset = type(variantData.mesh_asset) == "string"
                    and variantData.mesh_asset ~= ""
                    and variantData.mesh_asset ~= "rbxassetid://0"
                local hasAssetId = variantData.asset_id and variantData.asset_id ~= "rbxassetid://0"

                if hasMeshAsset or hasAssetId then
                    local existingVariant = petTypeFolder:FindFirstChild(variant)
                    local modelSuccess

                    if
                        existingVariant
                        and existingVariant:IsA("Model")
                        and existingVariant:FindFirstChildWhichIsA("BasePart", true)
                    then
                        -- PRE-BAKED FAST PATH (mesh-combine AND asset_id pets alike): a valid model is
                        -- already present (the Rojo-synced ReplicatedStorage.Assets.Models, captured from
                        -- a fully-loaded runtime). Adopt it as-is — no fetch, no mesh-combine, no
                        -- weld/normalize (it's the already-processed runtime output). MUST be the FIRST
                        -- branch: otherwise meshy pets fall into the combine branch below and rebuild
                        -- every model (the actual ~25s boot cost — the bug Jason caught).
                        adoptedCount = adoptedCount + 1
                        modelSuccess = true
                    elseif hasMeshAsset then
                        -- Combine path: textured MeshPart from a separately-uploaded mesh + texture
                        -- (FBX->Model uploads come out untextured). Mirrors the enemy/gem combine.
                        if existingVariant then
                            existingVariant:Destroy()
                        end
                        fetchedCount = fetchedCount + 1
                        modelSuccess = self:BuildMeshPartModelIntoFolder(
                            variantData.mesh_asset,
                            variantData.texture_asset,
                            petTypeFolder,
                            variant,
                            petType .. "_" .. variant,
                            transformOptions
                        )
                    elseif variantData.asset_source == "rojo" then
                        if existingVariant and existingVariant:IsA("Model") then
                            logger:Info("Using Rojo-managed pet model", {
                                petType = petType,
                                variant = variant,
                                path = existingVariant:GetFullName(),
                            })
                            self:SetPreferredPrimaryPart(existingVariant)
                            existingVariant:PivotTo(CFrame.identity)
                            self:ApplyConfiguredModelTransform(existingVariant, transformOptions)
                            self:WeldModelParts(existingVariant)
                            self:NormalizePetModelParts(existingVariant)
                            self:AddPetSystemComponents(existingVariant)
                            modelSuccess = true
                        else
                            logger:Warn("Rojo-managed pet model missing", {
                                petType = petType,
                                variant = variant,
                                expectedPath = petTypeFolder:GetFullName() .. "." .. variant,
                            })
                            modelSuccess = false
                        end
                    else
                        -- No usable pre-bake — replace any empty placeholder and fetch normally.
                        if existingVariant then
                            existingVariant:Destroy()
                        end
                        fetchedCount = fetchedCount + 1
                        -- Load 3D model
                        modelSuccess = self:LoadModelIntoFolder(
                            variantData.asset_id,
                            petTypeFolder,
                            variant,
                            petType .. "_" .. variant,
                            transformOptions
                        )
                    end

                    if modelSuccess then
                        modelSuccessCount = modelSuccessCount + 1

                        -- Inject per-variant stats (power/health/type/variant) for runtime use
                        do
                            local variantModel = petTypeFolder:FindFirstChild(variant)
                            if variantModel then
                                local resolvedPetData = petConfig.getPet
                                    and petConfig.getPet(petType, variant)
                                local powerValue = (resolvedPetData and resolvedPetData.power)
                                    or petData.base_power
                                    or 1
                                local healthValue = (resolvedPetData and resolvedPetData.health)
                                    or petData.base_health
                                    or 100
                                -- Set as attributes for quick access and clone carryover
                                variantModel:SetAttribute("PetType", petType)
                                variantModel:SetAttribute("Variant", variant)
                                variantModel:SetAttribute("Power", powerValue)
                                variantModel:SetAttribute("BaseHealth", healthValue)
                                -- DAMAGE targeting (PetTargeting SSOT): per-pet override carried as
                                -- an attribute so both the squad badge ring AND the attack splash
                                -- (PetFollowService) read one value. Defaults single (no splash);
                                -- a role-default resolve folds in here once an AoE role exists.
                                variantModel:SetAttribute(
                                    "AttackTargeting",
                                    petData.attack_targeting or "single"
                                )
                                -- DoT (burn/poison/bleed) — orthogonal to targeting. A pet with an
                                -- attack_dot { fraction, tick, duration } stamps a ticking burn on
                                -- whatever its attack hits (composes with single/targeted_aoe/etc).
                                -- Carried as flat attributes (tables can't be attributes); 0 fraction
                                -- = no DoT (the default for every pet).
                                local dot = petData.attack_dot
                                if type(dot) == "table" then
                                    variantModel:SetAttribute(
                                        "DotFraction",
                                        tonumber(dot.fraction) or 0
                                    )
                                    variantModel:SetAttribute("DotTick", tonumber(dot.tick) or 1)
                                    variantModel:SetAttribute(
                                        "DotDuration",
                                        tonumber(dot.duration) or 0
                                    )
                                    -- SPREAD (contagion as an orthogonal burn modifier): presence of
                                    -- attack_dot.spread makes THIS burn contagious regardless of the
                                    -- hit geometry, so targeted_aoe + spread = AoE-contagion. Per-pet
                                    -- radius/interval/max (studs/seconds/hops) override the global
                                    -- pet_contagion defaults; DotSpreadMax > 0 is the "is contagious"
                                    -- flag the combat loop reads.
                                    local spread = dot.spread
                                    if type(spread) == "table" then
                                        variantModel:SetAttribute(
                                            "DotSpreadRadius",
                                            tonumber(spread.radius) or 0
                                        )
                                        variantModel:SetAttribute(
                                            "DotSpreadInterval",
                                            tonumber(spread.interval) or 0
                                        )
                                        variantModel:SetAttribute(
                                            "DotSpreadMax",
                                            math.floor(tonumber(spread.max) or 0)
                                        )
                                    end
                                end
                                -- AoE override (PetTargeting): an aoe/targeted_aoe pet can tune its
                                -- own splash (radius/fraction/targets) instead of the global pet_aoe
                                -- defaults — the knob board for a "wider/harder splash" pet.
                                local aoe = petData.attack_aoe
                                if type(aoe) == "table" then
                                    variantModel:SetAttribute(
                                        "AoeSplashRadius",
                                        tonumber(aoe.splash_radius) or 0
                                    )
                                    variantModel:SetAttribute(
                                        "AoeSplashFraction",
                                        tonumber(aoe.splash_fraction) or 0
                                    )
                                    variantModel:SetAttribute(
                                        "AoeMaxTargets",
                                        math.floor(tonumber(aoe.max_targets) or 0)
                                    )
                                end
                                -- ON-HIT enemy effects (orthogonal — compose with any geometry; the
                                -- combat loop applies them to each enemy the swing touches, so a
                                -- targeted_aoe pet shreds/controls its whole splash). All opt-in.
                                -- CONTROL (Anvil): slow/root/hold the enemy on hit.
                                local control = petData.attack_control
                                if type(control) == "table" then
                                    variantModel:SetAttribute(
                                        "HitControlKind",
                                        tostring(control.kind or "")
                                    )
                                    variantModel:SetAttribute(
                                        "HitControlFactor",
                                        tonumber(control.factor) or 1
                                    )
                                    variantModel:SetAttribute(
                                        "HitControlDuration",
                                        tonumber(control.duration) or 0
                                    )
                                end
                                -- SHRED (Amplifier): a vulnerability debuff — enemy takes +X% from
                                -- EVERYONE (team multiplier), same VulnerableMult seam as the powers.
                                local debuff = petData.attack_debuff
                                if type(debuff) == "table" then
                                    variantModel:SetAttribute(
                                        "HitVulnerable",
                                        tonumber(debuff.vulnerable) or 0
                                    )
                                    variantModel:SetAttribute(
                                        "HitDebuffDuration",
                                        tonumber(debuff.duration) or 0
                                    )
                                end
                                self:ApplyPetTransformAttributes(variantModel, transformOptions)
                                -- Also create NumberValues for scripts that expect Values on the model
                                local powerNV = variantModel:FindFirstChild("Power")
                                if not powerNV then
                                    powerNV = Instance.new("NumberValue")
                                    powerNV.Name = "Power"
                                    powerNV.Value = powerValue
                                    powerNV.Parent = variantModel
                                else
                                    powerNV.Value = powerValue
                                end
                                local typeSV = variantModel:FindFirstChild("PetType")
                                if not typeSV then
                                    typeSV = Instance.new("StringValue")
                                    typeSV.Name = "PetType"
                                    typeSV.Value = petType
                                    typeSV.Parent = variantModel
                                else
                                    typeSV.Value = petType
                                end
                                local varSV = variantModel:FindFirstChild("Variant")
                                if not varSV then
                                    varSV = Instance.new("StringValue")
                                    varSV.Name = "Variant"
                                    varSV.Value = variant
                                    varSV.Parent = variantModel
                                else
                                    varSV.Value = variant
                                end
                            end
                        end

                        -- Defer the thumbnail (cosmetic) — see thumbnailJobs note above.
                        table.insert(thumbnailJobs, {
                            model = petTypeFolder:FindFirstChild(variant),
                            parent = petImageTypeFolder,
                            name = variant,
                            petType = petType,
                            variant = variant,
                        })
                        -- A second, HUGE-framed thumbnail (any pet can roll huge — orthogonal). Stored
                        -- under "<variant>__huge" in the same type folder; the card picks it when the
                        -- pet record is huge, else falls back to the normal one. Same baked path, no
                        -- live-viewport huge card.
                        table.insert(thumbnailJobs, {
                            model = petTypeFolder:FindFirstChild(variant),
                            parent = petImageTypeFolder,
                            name = variant .. "__huge",
                            petType = petType,
                            variant = variant,
                            huge = true,
                        })
                    else
                        modelFailureCount = modelFailureCount + 1
                    end
                else
                    logger:Warn("Pet has no valid asset ID", {
                        petType = petType,
                        variant = variant,
                    })
                    modelFailureCount = modelFailureCount + 1
                    imageFailureCount = imageFailureCount + 1
                end
            end
        end
    end

    -- Load egg models and generate images
    for eggType, eggData in pairs(petConfig.egg_sources or {}) do
        totalAssets = totalAssets + 1

        local hasEggMesh = type(eggData.mesh_asset) == "string"
            and eggData.mesh_asset ~= ""
            and eggData.mesh_asset ~= "rbxassetid://0"
        local hasEggModel = eggData.asset_id and eggData.asset_id ~= "rbxassetid://0"

        if hasEggMesh or hasEggModel then
            -- Adopt a valid pre-baked egg (Rojo-synced Assets.Models.Eggs) as-is; otherwise replace
            -- any empty placeholder and build/fetch it. Same fast path as pets — see the note above.
            local existingEgg = eggsFolder:FindFirstChild(eggType)
            local prebakedEgg = existingEgg ~= nil
                and existingEgg:IsA("Model")
                and existingEgg:FindFirstChildWhichIsA("BasePart", true) ~= nil
            if existingEgg and not prebakedEgg then
                existingEgg:Destroy()
            end

            local modelSuccess = nil
            if prebakedEgg then
                adoptedCount = adoptedCount + 1
                modelSuccess = true
            else
                fetchedCount = fetchedCount + 1
            end
            if not prebakedEgg and hasEggMesh then
                -- THE single combine path: FBX->Model egg uploads import untextured (grey), so an
                -- egg ships mesh_asset (+ texture_asset) and we build the textured Model here, the
                -- same way pets/enemies/gems do, then store it in Assets.Models.Eggs like any model.
                local eggModel = MeshAssembly.build(
                    eggData.mesh_asset,
                    eggData.texture_asset,
                    { modelName = eggType }
                )
                if eggModel then
                    eggModel.Parent = eggsFolder
                    modelSuccess = true
                else
                    logger:Warn("Egg mesh combine failed; trying asset_id", { eggType = eggType })
                end
            end
            if not modelSuccess and hasEggModel then
                -- Fallback: packaged Model (may be untextured for FBX uploads).
                modelSuccess = self:LoadModelIntoFolder(
                    eggData.asset_id,
                    eggsFolder,
                    eggType,
                    eggType .. "_egg"
                )
            end

            if modelSuccess then
                modelSuccessCount = modelSuccessCount + 1

                -- Defer the egg-card thumbnail (cosmetic) — see thumbnailJobs note above.
                table.insert(thumbnailJobs, {
                    model = eggsFolder:FindFirstChild(eggType),
                    parent = eggImagesFolder,
                    name = eggType,
                    petType = eggType, -- petType parameter (for eggs, use eggType)
                    variant = "egg", -- variant parameter (all eggs are "egg" variant)
                })
            else
                modelFailureCount = modelFailureCount + 1
            end
        else
            logger:Warn("Egg has no valid asset ID", {
                eggType = eggType,
            })
            modelFailureCount = modelFailureCount + 1
            imageFailureCount = imageFailureCount + 1
        end
    end

    -- All model TEMPLATES (pets/eggs/breakables) are built by this point — open the gameplay gate
    -- NOW, before the cosmetic thumbnail pass. Egg placement (and anything else waiting on
    -- ModelsReady) no longer sits behind ~all-pet ViewportFrame rendering.
    logger:Info("Asset model templates loaded (gate open)", {
        models = { successful = modelSuccessCount, failed = modelFailureCount },
        prebake = { adopted = adoptedCount, fetched = fetchedCount },
        thumbnailJobs = #thumbnailJobs,
        total = totalAssets,
        duration = tick() - startTime,
    })
    ReplicatedStorage.Assets:SetAttribute("ModelsReady", true)
    -- Event-driven boot gate: every consumer (pets, crystals, eggs) awaits this milestone instead
    -- of polling the attribute / waiting on a fire-once event. See docs/BOOT_ORCHESTRATION.md.
    BootReadiness.signal("models_ready")
    -- Unmissable boot-speed readout (this service's Logger output is suppressed in Studio).
    print(
        string.format(
            "[PREBAKE] model pass done in %.1fs — adopted=%d fetched=%d (adopted≈total = fast)",
            tick() - startTime,
            adoptedCount,
            fetchedCount
        )
    )

    -- Deferred, yielding thumbnail pass. Generates the inventory-card ViewportFrames off the boot
    -- critical path, yielding every few so it never monopolizes the server thread, and bumping
    -- PetThumbnailCount incrementally so the client prewarm can release as soon as enough exist.
    task.spawn(function()
        BootReadiness.begin("icons_ready") -- background boot stage start (paired with signal below)
        local thumbStart = tick()
        for i, job in ipairs(thumbnailJobs) do
            if job.model then
                local okThumb = self:GenerateImageFromModel(
                    job.model,
                    job.parent,
                    job.name,
                    job.petType,
                    job.variant,
                    job.huge
                )
                if okThumb then
                    imageSuccessCount = imageSuccessCount + 1
                else
                    imageFailureCount = imageFailureCount + 1
                end
            else
                imageFailureCount = imageFailureCount + 1
            end
            if i % 8 == 0 then
                ReplicatedStorage.Assets:SetAttribute("PetThumbnailCount", imageSuccessCount)
                task.wait()
            end
        end
        ReplicatedStorage.Assets:SetAttribute("PetThumbnailCount", imageSuccessCount)
        ReplicatedStorage.Assets:SetAttribute("PetThumbnailFailures", imageFailureCount)
        ReplicatedStorage.Assets:SetAttribute("PetThumbnailsReady", true)
        -- Background milestone (off the critical path): the loading screen shows "Baking the icons"
        -- but does not gate play on it.
        BootReadiness.signal("icons_ready")
        logger:Info("Pet/egg card thumbnails generated (deferred)", {
            successful = imageSuccessCount,
            failed = imageFailureCount,
            duration = tick() - thumbStart,
        })
    end)

    -- (Asset readiness is now the BootReadiness "models_ready" milestone signalled above; the old
    -- _G.AssetsLoadingComplete flag + _G.AssetsLoadedEvent BindableEvent are retired.)
end

-- Preload all configured sounds into ReplicatedStorage.Assets.Sounds
function AssetPreloadService:LoadAllSoundsIntoAssets()
    logger:Info("🔊 LoadAllSoundsIntoAssets: Starting...")
    local soundsFolder = ReplicatedStorage.Assets:FindFirstChild("Sounds")
    if not soundsFolder then
        logger:Error("❌ LoadAllSoundsIntoAssets: Sounds folder missing")
        return
    end

    local count = 0
    local soundInstances = {}
    local idToName = {}
    for name, soundData in pairs(soundsConfig or {}) do
        if type(soundData) == "table" and soundData.id then
            local sound = soundsFolder:FindFirstChild(name)
            if sound then
                sound:Destroy()
            end
            local s = Instance.new("Sound")
            s.Name = name
            s.SoundId = soundData.id
            if soundData.volume then
                s.Volume = soundData.volume
            end
            if soundData.playback_speed then
                s.PlaybackSpeed = soundData.playback_speed
            end
            s.Parent = soundsFolder
            count += 1
            soundInstances[#soundInstances + 1] = s
            local digits = tostring(soundData.id):match("%d+")
            if digits then
                idToName[digits] = name
            end
        end
    end

    -- Verify the sounds actually LOAD and record each into the boot AssetReport. Audio is
    -- permission-locked to its owner, so personal-owned sounds fail to load for a non-owner
    -- account in Studio (or a fork) — PreloadAsync surfaces that per-asset status so a silent
    -- "no sound" becomes a named entry in the one consolidated report.
    pcall(function()
        local ContentProvider = game:GetService("ContentProvider")
        ContentProvider:PreloadAsync(soundInstances, function(contentId, status)
            local digits = tostring(contentId):match("%d+")
            local name = (digits and idToName[digits]) or tostring(contentId)
            local ok = (status == Enum.AssetFetchStatus.Success)
            AssetReport.record({
                id = digits or contentId,
                kind = "sound",
                name = name,
                target = "Assets.Sounds." .. name,
                ok = ok,
                err = (not ok) and ("preload status: " .. tostring(status)) or nil,
            })
        end)
    end)

    logger:Info("🔊 LoadAllSoundsIntoAssets: Completed", { count = count })
end

-- Load a single model into a folder
-- Build a textured pet model from a separately-uploaded MESH + TEXTURE — the same combine enemies
-- and gems use (AssetService:CreateMeshPartAsync + MeshPart.TextureID = imageId). FBX->Model uploads
-- come out untextured, so meshy pets ship `mesh_asset` (+ optional `texture_asset`) instead of a
-- packaged `asset_id` Model. Parents a Model (named folderName, PrimaryPart = the mesh) into
-- parentFolder and runs the SAME pet post-processing as LoadModelIntoFolder. Returns true on success.
function AssetPreloadService:BuildMeshPartModelIntoFolder(
    meshId,
    textureId,
    parentFolder,
    folderName,
    debugName,
    options
)
    if not meshId or not parentFolder then
        return false
    end

    local success, result = pcall(function()
        -- THE single combine path (shared with enemies/gems/eggs): mesh + texture -> textured Model.
        local modelClone = MeshAssembly.build(meshId, textureId, { modelName = folderName })
        if not modelClone then
            error("MeshAssembly.build returned nil for " .. tostring(meshId))
        end

        -- Identical post-processing to LoadModelIntoFolder so meshy pets behave the same.
        self:SetPreferredPrimaryPart(modelClone)
        modelClone:PivotTo(CFrame.identity)
        self:ApplyConfiguredModelTransform(modelClone, options)
        self:WeldModelParts(modelClone)

        local isPetFolder = (parentFolder.Name == "Pets")
            or (parentFolder.Parent and parentFolder.Parent.Name == "Pets")
        if isPetFolder then
            self:NormalizePetModelParts(modelClone)
            self:AddPetSystemComponents(modelClone)
        end

        modelClone.Parent = parentFolder
        return true
    end)

    if not success then
        logger:Warn("Failed to build mesh-combine pet model", {
            meshId = tostring(meshId),
            textureId = tostring(textureId),
            debugName = debugName,
            error = tostring(result),
        })
        AssetReport.record({
            id = meshId,
            kind = "pet_mesh",
            name = debugName or folderName,
            target = parentFolder:GetFullName() .. "." .. tostring(folderName),
            ok = false,
            err = tostring(result),
        })
        return false
    end

    logger:Info("✅ BuildMeshPartModelIntoFolder: textured pet model built", {
        meshId = tostring(meshId),
        debugName = debugName,
        path = parentFolder:GetFullName() .. "." .. tostring(folderName),
    })
    AssetReport.record({
        id = meshId,
        kind = "pet_mesh",
        name = debugName or folderName,
        target = parentFolder:GetFullName() .. "." .. tostring(folderName),
        ok = true,
    })
    return true
end

function AssetPreloadService:LoadModelIntoFolder(
    assetId,
    parentFolder,
    folderName,
    debugName,
    options
)
    -- PRE-BAKED CACHE FAST PATH: if a model with real geometry is already present (the Rojo-synced
    -- ReplicatedStorage.Assets.Models, captured from a fully-loaded runtime and committed as
    -- assets/place/Models.rbxm), skip the slow InsertService:LoadAsset + welding/normalizing AND the
    -- chatty per-model logging entirely. This turns the boot model pass into ~instant presence checks
    -- (a cached clone is ~1500x faster than a network fetch). Models NOT in the pre-bake — a newly
    -- added pet, a changed asset_id — fall through and load normally, so the cache self-heals.
    -- Regenerate the pre-bake by saving ReplicatedStorage.Assets.Models from a fully-booted session.
    local prebaked = parentFolder and parentFolder:FindFirstChild(folderName)
    if prebaked and prebaked:FindFirstChildWhichIsA("BasePart", true) then
        reportAsset(assetId, parentFolder, folderName, debugName, true)
        return true
    end

    logger:Info("🔄 LoadModelIntoFolder: Starting", {
        assetId = assetId,
        debugName = debugName,
        targetFolder = folderName,
        parentFolder = parentFolder and parentFolder.Name or "nil",
    })

    local cleanId = assetId:match("%d+")
    if not cleanId then
        logger:Error("❌ LoadModelIntoFolder: Invalid asset ID format", {
            assetId = assetId,
            debugName = debugName,
        })
        reportAsset(assetId, parentFolder, folderName, debugName, false, "invalid asset id format")
        return false
    end

    logger:Info("🔄 LoadModelIntoFolder: Clean ID extracted", {
        cleanId = cleanId,
        assetId = assetId,
    })

    local success, result = pcall(function()
        logger:Info("🔄 LoadModelIntoFolder: Loading asset via InsertService", {
            cleanId = cleanId,
        })

        local loadedAsset = AssetFetch.load(tonumber(cleanId))
        if not loadedAsset then
            error("Failed to load asset: " .. cleanId)
        end

        logger:Info("✅ LoadModelIntoFolder: Asset loaded successfully", {
            cleanId = cleanId,
            loadedAssetExists = loadedAsset ~= nil,
        })

        local model = loadedAsset:FindFirstChildOfClass("Model")
        if not model then
            -- Some uploads are a bare MeshPart/part (mesh-only asset, like the enemy meshes)
            -- rather than a packaged Model. Wrap the first BasePart in a Model so mesh-based pets
            -- and eggs load instead of failing. Errors only if there's no usable part at all.
            local part = loadedAsset:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local wrap = Instance.new("Model")
                wrap.Name = folderName or "WrappedMesh"
                part.Parent = wrap
                wrap.PrimaryPart = part
                wrap.Parent = loadedAsset
                model = wrap
                logger:Info("🔧 LoadModelIntoFolder: wrapped a bare MeshPart in a Model", {
                    cleanId = cleanId,
                    partClass = part.ClassName,
                })
            end
        end
        if not model then
            error("No Model or MeshPart found in asset: " .. cleanId)
        end

        logger:Info("✅ LoadModelIntoFolder: Model found in asset", {
            modelName = model.Name,
            modelType = model.ClassName,
        })

        -- Clone and organize the model
        local modelClone = model:Clone()
        modelClone.Name = folderName

        logger:Info("✅ LoadModelIntoFolder: Model cloned", {
            originalName = model.Name,
            newName = modelClone.Name,
        })

        -- Choose a stable PrimaryPart and pivot model to origin before welding
        self:SetPreferredPrimaryPart(modelClone)
        modelClone:PivotTo(CFrame.identity)

        self:ApplyConfiguredModelTransform(modelClone, options)

        -- Weld all parts together to prevent falling apart
        logger:Info("🔧 LoadModelIntoFolder: Welding model parts...")
        self:WeldModelParts(modelClone)

        -- If this is a pet model, add all the required pet system components
        local isPetFolder = false
        if parentFolder then
            -- We are called with parentFolder either being `Pets` or a child of it (pet type folder)
            isPetFolder = (parentFolder.Name == "Pets")
                or (parentFolder.Parent and parentFolder.Parent.Name == "Pets")
        end
        if isPetFolder then
            self:NormalizePetModelParts(modelClone)
            logger:Info("🔧 LoadModelIntoFolder: Adding pet system components...")
            self:AddPetSystemComponents(modelClone)
        end

        modelClone.Parent = parentFolder

        logger:Info("✅ LoadModelIntoFolder: Model parented to folder", {
            modelName = modelClone.Name,
            parentFolder = parentFolder.Name,
        })

        -- Clean up the original asset
        loadedAsset:Destroy()

        logger:Info("✅ LoadModelIntoFolder: Model successfully loaded into folder", {
            assetId = assetId,
            debugName = debugName,
            modelName = modelClone.Name,
            path = parentFolder:GetFullName() .. "." .. folderName,
        })

        return true
    end)

    if not success then
        logger:Warn("Failed to load model", {
            assetId = assetId,
            debugName = debugName,
            error = tostring(result),
        })
        reportAsset(assetId, parentFolder, folderName, debugName, false, tostring(result))
        return false
    end

    reportAsset(assetId, parentFolder, folderName, debugName, true)
    return true
end

-- Prefer Face/Head as PrimaryPart when available
function AssetPreloadService:SetPreferredPrimaryPart(model)
    if not model or not model:IsA("Model") then
        return
    end
    local chosen = model.PrimaryPart
    local firstPart = nil
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            firstPart = firstPart or d
            local n = string.lower(d.Name)
            if string.find(n, "face") or string.find(n, "head") then
                chosen = d
                break
            end
        end
    end
    chosen = chosen or firstPart
    if chosen then
        model.PrimaryPart = chosen
    end
end

-- Generate a ViewportFrame image from a loaded model (works for both pets and eggs)
function AssetPreloadService:GenerateImageFromModel(
    model,
    parentFolder,
    folderName,
    itemType,
    variant,
    huge -- when true, frame an up-close HUGE shot via configs/pets.lua huge_face (zoom + per-model aim)
)
    if not model or not model:IsA("Model") then
        logger:Warn("Invalid model for image generation", {
            itemType = itemType,
            variant = variant,
            modelExists = model ~= nil,
            modelType = model and model.ClassName or "nil",
        })
        return false
    end

    local success, result = pcall(function()
        -- Get camera configuration (works for both pets and eggs)
        local cameraConfig = self:GetCameraConfig(itemType)

        -- Position model for image capture - RESET BOTH POSITION AND ROTATION
        local modelClone = model:Clone()
        if petConfig.pets[itemType] then
            PetVariantVisuals.ApplyServerMetadata(modelClone, itemType, variant)
            PetVariantVisuals.ApplyStaticVisuals(modelClone)
        end
        local modelCFrame, modelSize = modelClone:GetBoundingBox()

        -- Always reset to identity CFrame (0,0,0 position + no rotation)
        if modelClone.PrimaryPart then
            modelClone:SetPrimaryPartCFrame(CFrame.identity)
        else
            -- For models without PrimaryPart, manually set each part to origin with no rotation
            local modelCenter = modelClone:GetBoundingBox()

            -- Set each part to identity CFrame (0,0,0 position, no rotation)
            for _, part in pairs(modelClone:GetDescendants()) do
                if part:IsA("BasePart") then
                    -- Calculate offset from model center
                    local offset = part.Position - modelCenter.Position
                    -- Set to origin plus offset, with no rotation
                    part.CFrame = CFrame.new(offset)
                end
            end
        end

        -- Calculate camera position based on configuration using proper spherical coordinates
        local angleYRad = math.rad(cameraConfig.angle_y) -- Horizontal rotation (around Y-axis)
        local angleXRad = math.rad(cameraConfig.angle_x) -- Vertical rotation (elevation)

        -- NORMALIZE distance by model size so apparent card size is consistent regardless of mesh/scale.
        -- cameraConfig.distance was tuned for the standard ~3-stud pet, but the camera previously sat at
        -- a FIXED distance — so big meshes (dragons measure 6-7.6 studs vs the 3.04 norm) overfilled the
        -- card (fill 1.6-2.2 vs the normal 0.87), reading as "Huge" (Jason). Scaling the distance by
        -- extent/REF lands every pet at the same fill: a 3.04 pet is unchanged, a 6.08 dragon doubles
        -- its distance. The per-pet camera.distance still applies as the base (preserves intended framing).
        local REF_EXTENT = 3.04 -- the standard pet max-extent (most pets normalize to ~3 studs; measured live)
        -- SOFTENING exponent (<1): a pet at the reference extent is unchanged (1^p = 1), but bigger
        -- models (dragons, ratio ~2-2.5) get pulled back LESS than a pure ratio would, so they read a
        -- touch larger in the card (Jason: dragons were a tiny bit small after the first normalize).
        local NORMALIZE_POWER = 0.85
        local maxExtent = math.max(modelSize.X, modelSize.Y, modelSize.Z)
        local ratio = (maxExtent > 0.05) and (maxExtent / REF_EXTENT) or 1
        local extentFactor = math.clamp(ratio ^ NORMALIZE_POWER, 0.5, 3.5) -- guard degenerate/stray extents
        local effectiveDistance = cameraConfig.distance * extentFactor

        -- Use spherical coordinates: distance, horizontal angle, vertical angle
        local cameraOffset = Vector3.new(
            math.sin(angleYRad) * math.cos(angleXRad) * effectiveDistance, -- X: affected by both angles
            math.sin(angleXRad) * effectiveDistance, -- Y: vertical elevation
            math.cos(angleYRad) * math.cos(angleXRad) * effectiveDistance -- Z: affected by both angles
        )

        local cameraPosition = cameraOffset + cameraConfig.offset

        -- Remove existing ViewportFrame if it exists (for regeneration)
        local existingViewport = parentFolder:FindFirstChild(folderName)
        if existingViewport then
            existingViewport:Destroy()
        end

        -- Create ViewportFrame for this pet
        local viewport = Instance.new("ViewportFrame")
        viewport.Name = folderName
        viewport.Size = UDim2.new(1, 0, 1, 0) -- Full size, will be scaled by UI
        viewport.BackgroundTransparency = 1
        viewport.Parent = parentFolder

        -- Default framing: look at the model centre from the normalized spherical position.
        local camCFrame = CFrame.lookAt(cameraPosition, Vector3.new(0, 0, 0))
        local camFov = nil

        -- HUGE framing: an up-close shot aimed at the pet's face. `huge_face` (configs/pets.lua) is the
        -- per-pet aim/zoom — y raises the look-at toward the face (quadrupeds), dist is the zoom, fov
        -- the lens. Same math the old live-viewport huge card used, now baked into the static thumbnail
        -- so huges keep the one shared card path. Defaults reproduce the old framing.
        if huge then
            local petData = petConfig.pets[itemType]
            local face = (petData and petData.huge_face) or {}
            local bbCFrame, bbSize = modelClone:GetBoundingBox()
            local target = bbCFrame.Position
                + Vector3.new(
                    bbSize.X * (face.x or 0),
                    bbSize.Y * (face.y or 0.22),
                    bbSize.Z * (face.z or 0)
                )
            local closeDistance = math.max(0.8, math.max(bbSize.X, bbSize.Z) * (face.dist or 0.7))
            local dir = (cameraOffset.Magnitude > 0) and cameraOffset.Unit or Vector3.new(0, 0, 1)
            camCFrame = CFrame.lookAt(target + dir * closeDistance, target)
            camFov = face.fov or 58
        end

        -- Create and configure camera
        local camera = Instance.new("Camera")
        camera.CFrame = camCFrame
        if camFov then
            camera.FieldOfView = camFov
        end
        camera.Parent = viewport
        viewport.CurrentCamera = camera

        -- Add model to viewport
        modelClone.Parent = viewport

        logger:Info("Generated ViewportFrame image", {
            itemType = itemType,
            variant = variant,
            cameraConfig = {
                distance = cameraConfig.distance,
                angle_y = cameraConfig.angle_y,
                angle_x = cameraConfig.angle_x,
                offset = cameraConfig.offset,
            },
            calculatedPosition = cameraPosition,
            modelSize = modelSize,
            isEgg = petConfig.egg_sources[itemType] ~= nil,
        })

        return true
    end)

    if success then
        return true
    else
        logger:Error("Failed to generate image", {
            itemType = itemType,
            variant = variant,
            error = result,
        })
        return false
    end
end

-- Note: Eggs now use the same GenerateImageFromModel function as pets

-- Get camera configuration for pet type or egg type
function AssetPreloadService:GetCameraConfig(itemType)
    local assetImageConfig = petConfig.asset_images

    -- Check if it's an egg first
    local eggData = petConfig.egg_sources[itemType]
    if eggData then
        -- It's an egg - use egg camera config or egg default
        return (eggData and eggData.camera) or assetImageConfig.default_egg_camera
    end

    -- It's a pet - use pet camera config or pet default
    local petData = petConfig.pets[itemType]
    local cameraConfig = (petData and petData.camera) or assetImageConfig.default_camera

    return cameraConfig
end

-- Get model from ReplicatedStorage.Assets (for external access if needed)
function AssetPreloadService:GetModelFromAssets(petType, variant)
    local petsFolder = ReplicatedStorage.Assets.Models.Pets
    local petTypeFolder = petsFolder:FindFirstChild(petType)

    if petTypeFolder then
        local model = petTypeFolder:FindFirstChild(variant)
        if model then
            return model:Clone()
        end
    end

    logger:Warn("Model not found in assets", {
        petType = petType,
        variant = variant,
        path = "ReplicatedStorage.Assets.Models.Pets." .. petType .. "." .. variant,
    })

    return nil
end

-- Check if a model is available in assets
function AssetPreloadService:IsModelInAssets(petType, variant)
    local petsFolder = ReplicatedStorage.Assets.Models.Pets
    local petTypeFolder = petsFolder:FindFirstChild(petType)

    if petTypeFolder then
        return petTypeFolder:FindFirstChild(variant) ~= nil
    end

    return false
end

-- Get image from ReplicatedStorage.Assets (for external access)
function AssetPreloadService:GetImageFromAssets(petType, variant)
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then
        return nil
    end

    local imagesRoot = assetsFolder:FindFirstChild("Images")
    if not imagesRoot then
        return nil
    end

    local imagesFolder = imagesRoot:FindFirstChild("Pets")
    if not imagesFolder then
        return nil
    end

    local petTypeFolder = imagesFolder:FindFirstChild(petType)
    if petTypeFolder then
        local image = petTypeFolder:FindFirstChild(variant)
        if image then
            return image:Clone()
        end
    end

    logger:Warn("Image not found in assets", {
        petType = petType,
        variant = variant,
        path = "ReplicatedStorage.Assets.Images.Pets." .. petType .. "." .. variant,
    })

    return nil
end

-- Get egg image from ReplicatedStorage.Assets (for external access)
function AssetPreloadService:GetEggImageFromAssets(eggType)
    local imagesRoot = ReplicatedStorage.Assets:FindFirstChild("Images")
    if not imagesRoot then
        return nil
    end

    local eggImagesFolder = imagesRoot:FindFirstChild("Eggs")
    if not eggImagesFolder then
        return nil
    end

    local eggImage = eggImagesFolder:FindFirstChild(eggType)
    if eggImage then
        return eggImage:Clone()
    end

    logger:Warn("Egg image not found in assets", {
        eggType = eggType,
        path = "ReplicatedStorage.Assets.Images.Eggs." .. eggType,
    })

    return nil
end

-- Check if an image is available in assets
function AssetPreloadService:IsImageInAssets(petType, variant)
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then
        return false
    end

    local imagesRoot = assetsFolder:FindFirstChild("Images")
    if not imagesRoot then
        return false
    end

    local imagesFolder = imagesRoot:FindFirstChild("Pets")
    if not imagesFolder then
        return false
    end

    local petTypeFolder = imagesFolder:FindFirstChild(petType)
    if petTypeFolder then
        return petTypeFolder:FindFirstChild(variant) ~= nil
    end

    return false
end

-- Get loading statistics
function AssetPreloadService:GetLoadingStats()
    local petsFolder = ReplicatedStorage.Assets.Models.Pets
    local petCount = 0
    local variantCount = 0

    for _, petTypeFolder in ipairs(petsFolder:GetChildren()) do
        if petTypeFolder:IsA("Folder") then
            petCount = petCount + 1
            for _, variant in ipairs(petTypeFolder:GetChildren()) do
                if variant:IsA("Model") then
                    variantCount = variantCount + 1
                end
            end
        end
    end

    return {
        petTypes = petCount,
        totalVariants = variantCount,
        folderPath = petsFolder:GetFullName(),
    }
end

-- Set up admin signal for force regeneration
function AssetPreloadService:SetupAdminRegenerationSignal()
    local Signals = require(ReplicatedStorage.Shared.Network.Signals)
    local AdminChecker = require(ReplicatedStorage.Shared.Utils.AdminChecker)

    Signals.ForceRegenerateAssets.OnServerEvent:Connect(function(player, data)
        if not AdminChecker:IsAdmin(player) then
            logger:Warn("Non-admin attempted asset regeneration", {
                player = player.Name,
                userId = player.UserId,
            })
            return
        end

        logger:Info("Admin force regeneration triggered", {
            player = player.Name,
            userId = player.UserId,
        })

        -- Force regenerate all assets
        self:LoadAllModelsIntoAssets()
    end)
end

-- Weld all parts in a model together to prevent them from falling apart
function AssetPreloadService:WeldModelParts(model)
    if not model or not model:IsA("Model") then
        return
    end

    -- Get all BaseParts in the model
    local parts = {}
    for _, descendant in pairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            table.insert(parts, descendant)
        end
    end

    if #parts <= 1 then
        return -- Nothing to weld
    end

    -- Determine the root part to weld everything to
    local rootPart = model.PrimaryPart

    -- If no PrimaryPart, try to find a part named "Head", "Face", or use the first part
    if not rootPart then
        for _, part in pairs(parts) do
            if part.Name:lower():find("head") or part.Name:lower():find("face") then
                rootPart = part
                break
            end
        end

        -- If still no root part, use the first part
        if not rootPart and #parts > 0 then
            rootPart = parts[1]
        end
    end

    if not rootPart then
        logger:Warn("Could not determine root part for welding", {
            modelName = model.Name,
        })
        return
    end

    -- Weld all other parts to the root part
    local weldCount = 0
    for _, part in pairs(parts) do
        if part ~= rootPart and part.Parent then
            -- If the initial separation from root is excessive, snap the part to the root
            local delta = (part.Position - rootPart.Position)
            if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 or math.abs(delta.Z) > 5 then
                part.CFrame = rootPart.CFrame
            end
            -- Create a WeldConstraint to join the parts
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = rootPart
            weld.Part1 = part
            weld.Parent = rootPart

            -- Unanchor the part since it's now welded
            part.Anchored = false

            weldCount = weldCount + 1
        end
    end

    -- Ensure the root part is unanchored so the whole model can move
    rootPart.Anchored = false

    -- Set the PrimaryPart if it wasn't already set
    if not model.PrimaryPart then
        model.PrimaryPart = rootPart
    end

    logger:Debug("Welded model parts", {
        modelName = model.Name,
        rootPart = rootPart.Name,
        totalParts = #parts,
        weldsCreated = weldCount,
    })
end

-- Add all required pet system components to a pet model
function AssetPreloadService:AddPetSystemComponents(petModel)
    logger:Info("🔧 AddPetSystemComponents: Starting...", {
        modelExists = petModel ~= nil,
        modelType = petModel and petModel.ClassName or "nil",
        modelName = petModel and petModel.Name or "nil",
    })

    if not petModel or not petModel:IsA("Model") then
        logger:Error("❌ AddPetSystemComponents: Invalid pet model for component addition", {
            modelExists = petModel ~= nil,
            modelType = petModel and petModel.ClassName or "nil",
        })
        return
    end

    logger:Info("🔧 AddPetSystemComponents: Adding components to model", {
        modelName = petModel.Name,
    })

    -- 1. Create the values the service-owned pet system reads (PetFollowService /
    -- PetFollowController + EnemyService). The legacy follow Values (Pos/Refresh/Timer/AttackPos)
    -- and the `Follow` script are gone — that whole code path was deleted.
    local values = {
        { name = "TargetID", class = "NumberValue", value = 0 },
        { name = "PetID", class = "NumberValue", value = 0 },
        { name = "PetSize", class = "Vector3Value", value = Vector3.new(1, 1, 1) },
        { name = "PositionNumber", class = "NumberValue", value = 0 },
        { name = "TargetType", class = "StringValue", value = "" },
        { name = "TargetWorld", class = "StringValue", value = "" },
    }

    for _, valueData in pairs(values) do
        local value = petModel:FindFirstChild(valueData.name)
        if not value or not value:IsA(valueData.class) then
            if value then
                value:Destroy()
            end
            value = Instance.new(valueData.class)
            value.Name = valueData.name
            value.Parent = petModel
        end
        value.Value = valueData.value
    end

    -- 2. Strip any `Follow` script baked into the uploaded pet ASSET. The repo no longer
    -- contains, creates, or enables this legacy script anywhere — but it can ride along inside
    -- the LoadAsset'd pet model (the original game shipped it in the asset). LoadAsset content
    -- isn't in the repo, so the only way to keep it off spawned pets is to delete it on load.
    do
        local stale = petModel:FindFirstChild("Follow")
        while stale do
            stale:Destroy()
            stale = petModel:FindFirstChild("Follow")
        end
    end

    -- 3. Add attachmentPet to the pet model's PrimaryPart
    if petModel.PrimaryPart then
        local attachmentPet = petModel.PrimaryPart:FindFirstChild("attachmentPet")
        if not attachmentPet or not attachmentPet:IsA("Attachment") then
            if attachmentPet then
                attachmentPet:Destroy()
            end
            attachmentPet = Instance.new("Attachment")
            attachmentPet.Name = "attachmentPet"
            attachmentPet.Parent = petModel.PrimaryPart
        end
    end

    -- 4. Set initial pet size
    petModel.PetSize.Value = petModel:GetExtentsSize()

    logger:Info("✅ AddPetSystemComponents: Pet system components added to model", {
        modelName = petModel.Name,
        valuesCreated = #values,
        hasFollowScript = petModel:FindFirstChild("Follow") ~= nil,
        hasAttachmentPet = petModel.PrimaryPart
            and petModel.PrimaryPart:FindFirstChild("attachmentPet") ~= nil,
        totalChildren = #petModel:GetChildren(),
    })
end

return AssetPreloadService
