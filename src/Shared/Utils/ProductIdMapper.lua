--[[
    ProductIdMapper - Maps configuration IDs to Roblox product/game pass IDs
    
    This utility handles the mapping between our configuration-friendly IDs
    and the actual numeric IDs used by Roblox's MarketplaceService.
    
    Features:
    - Maps config IDs to Roblox IDs
    - Validates product configurations
    - Handles missing mappings gracefully
    - Supports both products and game passes
    - Test mode support for Studio
]]

local RunService = game:GetService("RunService")

local ProductIdMapper = {}
ProductIdMapper.__index = ProductIdMapper

-- Cache for loaded configuration
local monetizationConfig = nil
local configLoaded = false

function ProductIdMapper:Init()
    -- Get logger if available
    if self._modules and self._modules.Logger then
        self._logger = self._modules.Logger
    end

    -- Load monetization config
    self:_loadConfig()

    if self._logger then
        self._logger:Info("ProductIdMapper initialized", {
            productCount = self:_countProducts(),
            passCount = self:_countPasses(),
            testMode = self:IsTestMode(),
        })
    end
end

function ProductIdMapper:_loadConfig()
    if configLoaded then
        return
    end

    local success, result = pcall(function()
        -- Try to load from ConfigLoader if available
        if self._modules and self._modules.ConfigLoader then
            return self._modules.ConfigLoader:LoadConfig("monetization")
        else
            -- Fallback to direct require
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local configModule = ReplicatedStorage:FindFirstChild("Configs")
                :FindFirstChild("monetization")
            if configModule then
                return require(configModule)
            end
        end
    end)

    if success and result then
        monetizationConfig = result
        configLoaded = true
    else
        if self._logger then
            self._logger:Error("Failed to load monetization config", { error = tostring(result) })
        else
            warn("ProductIdMapper: Failed to load monetization config:", result)
        end
    end
end

-- Get Roblox product ID from config ID
function ProductIdMapper:GetProductId(configId)
    if not monetizationConfig then
        self:_loadConfig()
    end

    if not monetizationConfig or not monetizationConfig.product_id_mapping then
        if self._logger then
            self._logger:Warn("No product ID mapping found")
        end
        return nil
    end

    local productId = monetizationConfig.product_id_mapping[configId]

    if not productId then
        if self._logger then
            self._logger:Warn("No product ID found for config ID", { configId = configId })
        end
    end

    return productId
end

-- Get product configuration by config ID
function ProductIdMapper:GetProductConfig(configId)
    if not monetizationConfig then
        self:_loadConfig()
    end

    if not monetizationConfig or not monetizationConfig.products then
        return nil
    end

    for _, product in ipairs(monetizationConfig.products) do
        if product.id == configId then
            return product
        end
    end

    return nil
end

-- Get game pass configuration by config ID
function ProductIdMapper:GetPassConfig(configId)
    if not monetizationConfig then
        self:_loadConfig()
    end

    if not monetizationConfig or not monetizationConfig.passes then
        return nil
    end

    for _, pass in ipairs(monetizationConfig.passes) do
        if pass.id == configId then
            return pass
        end
    end

    return nil
end

-- Get product config by Roblox product ID
function ProductIdMapper:GetProductByRobloxId(robloxProductId)
    if not monetizationConfig then
        self:_loadConfig()
    end

    if not monetizationConfig then
        return nil
    end

    -- Find the config ID that maps to this Roblox ID
    local configId = nil
    for id, productId in pairs(monetizationConfig.product_id_mapping or {}) do
        if productId == robloxProductId then
            configId = id
            break
        end
    end

    if not configId then
        return nil
    end

    -- Return the product config
    return self:GetProductConfig(configId)
end

-- Get all products
function ProductIdMapper:GetAllProducts()
    if not monetizationConfig then
        self:_loadConfig()
    end

    return monetizationConfig and monetizationConfig.products or {}
end

-- Get all game passes
function ProductIdMapper:GetAllPasses()
    if not monetizationConfig then
        self:_loadConfig()
    end

    return monetizationConfig and monetizationConfig.passes or {}
end

-- Get premium benefits configuration
function ProductIdMapper:GetPremiumBenefits()
    if not monetizationConfig then
        self:_loadConfig()
    end

    return monetizationConfig and monetizationConfig.premium_benefits or {}
end

-- Get first purchase bonus configuration
function ProductIdMapper:GetFirstPurchaseBonus()
    if not monetizationConfig then
        self:_loadConfig()
    end

    return monetizationConfig and monetizationConfig.first_purchase_bonus or {}
end

-- Check if in test mode
function ProductIdMapper:IsTestMode()
    if not monetizationConfig then
        self:_loadConfig()
    end

    local validation = monetizationConfig and monetizationConfig.validation_rules
    return RunService:IsStudio()
        and validation
        and validation.test_mode
        and validation.test_mode.enabled
end

-- Validate a product purchase
function ProductIdMapper:ValidatePurchase(player, configId)
    local product = self:GetProductConfig(configId)
    if not product then
        return false, "product_not_found"
    end

    -- Check level requirements
    if product.level_requirement then
        local playerLevel = self:_getPlayerLevel(player)

        if product.level_requirement.min and playerLevel < product.level_requirement.min then
            return false, "level_too_low", { level = product.level_requirement.min }
        end

        if product.level_requirement.max and playerLevel > product.level_requirement.max then
            return false, "level_too_high"
        end
    end

    -- Check one-time purchase
    if product.one_time_only and self:_hasPlayerPurchased(player, configId) then
        return false, "one_time_only"
    end

    -- Check first time buyer restriction
    if product.first_time_buyer_only and self:_hasPlayerMadeAnyPurchase(player) then
        return false, "not_first_time_buyer"
    end

    return true, "valid"
end

-- Get error message
function ProductIdMapper:GetErrorMessage(errorCode, params)
    if not monetizationConfig or not monetizationConfig.error_messages then
        return "Purchase failed."
    end

    local message = monetizationConfig.error_messages[errorCode] or "Unknown error."

    -- Replace parameters
    if params then
        for key, value in pairs(params) do
            message = message:gsub("{" .. key .. "}", tostring(value))
        end
    end

    return message
end

-- Helper functions
function ProductIdMapper:_countProducts()
    local products = self:GetAllProducts()
    return #products
end

function ProductIdMapper:_countPasses()
    local passes = self:GetAllPasses()
    return #passes
end

function ProductIdMapper:_getPlayerLevel(player)
    -- This would integrate with your data service
    -- For now, return a default
    if self._modules and self._modules.DataService then
        return self._modules.DataService:GetStat(player, "Level") or 1
    end
    return 1
end

function ProductIdMapper:_hasPlayerPurchased(player, configId)
    -- This would check purchase history
    -- For now, return false
    if self._modules and self._modules.DataService then
        local purchases = self._modules.DataService:GetPurchaseHistory(player) or {}
        return purchases[configId] ~= nil
    end
    return false
end

function ProductIdMapper:_hasPlayerMadeAnyPurchase(player)
    -- This would check if player has made any Robux purchase
    -- For now, return false
    if self._modules and self._modules.DataService then
        return self._modules.DataService:HasMadeAnyPurchase(player)
    end
    return false
end

return ProductIdMapper
