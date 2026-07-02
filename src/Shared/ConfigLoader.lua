--[[
    ConfigLoader - Loads and manages game configuration from Lua files
    
    Features:
    - Lua configuration loading
    - Configuration caching and hot reloading
    - Environment-specific configs (Dev/Prod)
    - Configuration validation
    - Default fallbacks
    
    Usage:
    local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
    local gameConfig = ConfigLoader:LoadConfig("game")
    local items = ConfigLoader:LoadConfig("items")
]]

local RunService = game:GetService("RunService")

local ConfigLoader = {}
ConfigLoader.__index = ConfigLoader

-- Configuration storage
local configs = {}
local configsLoaded = false
local configsValidated = false

local STABLE_CONFIG_ID_PATTERN = "^[a-z][a-z0-9_]*$"

local function isArray(value)
    if type(value) ~= "table" then
        return false
    end

    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        count = count + 1
    end

    for index = 1, count do
        if value[index] == nil then
            return false
        end
    end

    return true
end

local function isStableConfigId(value)
    return type(value) == "string" and value:match(STABLE_CONFIG_ID_PATTERN) ~= nil
end

local function hasId(list, id)
    if type(list) ~= "table" then
        return false
    end

    for _, entry in ipairs(list) do
        if type(entry) == "table" and entry.id == id then
            return true
        end
    end

    return false
end

-- Load configs from ReplicatedStorage
local function loadConfigsFromStorage()
    if configsLoaded then
        return
    end

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local configsFolder = ReplicatedStorage:FindFirstChild("Configs")

    if not configsFolder then
        warn("Configs folder not found in ReplicatedStorage - using hardcoded defaults")
        -- Hardcoded fallback configurations
        configs = {
            game = {
                GameMode = "Simulator", -- Options: Simulator, FPS, TowerDefense, Custom
                MaxPlayers = 20,
                EnableTrading = true,
                EnablePvP = false,
                RespawnTime = 5,
                StartingCurrency = {
                    coins = 100,
                    gems = 0,
                },
                WorldSettings = {
                    Gravity = 196.2,
                    WalkSpeed = 16,
                    JumpPower = 50,
                },
            },

            currencies = {
                {
                    id = "coins",
                    name = "Coins",
                    icon = "💰",
                    maxAmount = 1000000000,
                    defaultAmount = 100,
                    canPurchase = false,
                },
                {
                    id = "gems",
                    name = "Gems",
                    icon = "💎",
                    maxAmount = 100000,
                    defaultAmount = 0,
                    canPurchase = true,
                    premium = true,
                },
            },

            items = {
                {
                    id = "test_item",
                    name = "Test Item",
                    type = "consumable",
                    rarity = "common",
                    description = "A simple test item for debugging purchases",
                    price = {
                        currency = "coins",
                        amount = 50,
                    },
                    level_requirement = 1,
                    stackable = true,
                    max_stack = 99,
                },
                {
                    id = "wooden_sword",
                    name = "Wooden Sword",
                    type = "weapon",
                    rarity = "common",
                    stats = {
                        damage = 10,
                        speed = 1.5,
                        range = 5,
                    },
                    price = {
                        currency = "coins",
                        amount = 100,
                    },
                    level_requirement = 1,
                },
                {
                    id = "iron_sword",
                    name = "Iron Sword",
                    type = "weapon",
                    rarity = "uncommon",
                    stats = {
                        damage = 20,
                        speed = 1.3,
                        range = 5,
                    },
                    price = {
                        currency = "coins",
                        amount = 500,
                    },
                    level_requirement = 5,
                },
                {
                    id = "health_potion",
                    name = "Health Potion",
                    type = "consumable",
                    rarity = "common",
                    effects = {
                        health_restore = 50,
                    },
                    price = {
                        currency = "coins",
                        amount = 25,
                    },
                    stackable = true,
                    max_stack = 10,
                },
            },

            enemies = {
                {
                    id = "goblin",
                    name = "Goblin",
                    type = "melee",
                    level = 1,
                    stats = {
                        health = 50,
                        damage = 8,
                        speed = 12,
                        detection_range = 20,
                        attack_range = 3,
                    },
                    rewards = {
                        experience = 10,
                        currency = {
                            coins = { min = 5, max = 15 },
                        },
                    },
                    spawn_weight = 10,
                },
                {
                    id = "orc",
                    name = "Orc Warrior",
                    type = "melee",
                    level = 5,
                    stats = {
                        health = 150,
                        damage = 25,
                        speed = 10,
                        detection_range = 25,
                        attack_range = 4,
                    },
                    rewards = {
                        experience = 50,
                        currency = {
                            coins = { min = 20, max = 40 },
                        },
                    },
                    spawn_weight = 5,
                },
            },

            ui = {
                -- Fallback UI configuration
                version = "1.0.0",
                active_theme = "dark",
                themes = {
                    dark = {
                        primary = {
                            background = Color3.fromRGB(30, 30, 35),
                            surface = Color3.fromRGB(40, 40, 45),
                            accent = Color3.fromRGB(0, 120, 180),
                        },
                        text = {
                            primary = Color3.fromRGB(255, 255, 255),
                            secondary = Color3.fromRGB(200, 200, 200),
                        },
                        button = {
                            primary = Color3.fromRGB(0, 120, 180),
                        },
                    },
                },
                fonts = {
                    primary = Enum.Font.Gotham,
                    sizes = { md = 14 },
                },
                spacing = { md = 16 },
                radius = { md = 8 },
                animations = {
                    duration = { fast = 0.15 },
                },
                helpers = {
                    get_theme = function(config)
                        return config.themes[config.active_theme] or config.themes.dark
                    end,
                    get_spacing = function(config, key)
                        local value = config.spacing[key] or config.spacing.md
                        return UDim.new(0, value)
                    end,
                    get_radius = function(config, key)
                        local value = config.radius[key] or config.radius.md
                        return UDim.new(0, value)
                    end,
                },
            },

            monetization = {
                products = {
                    {
                        id = "gems_100",
                        name = "100 Gems",
                        price_robux = 100,
                        rewards = {
                            gems = 100,
                        },
                    },
                    {
                        id = "gems_500",
                        name = "500 Gems",
                        price_robux = 400,
                        rewards = {
                            gems = 500,
                            bonus_coins = 1000,
                        },
                    },
                    {
                        id = "starter_pack",
                        name = "Starter Pack",
                        price_robux = 200,
                        rewards = {
                            gems = 150,
                            coins = 2000,
                            items = { "iron_sword", "health_potion" },
                        },
                    },
                },

                passes = {
                    {
                        id = "vip",
                        name = "VIP Pass",
                        price_robux = 500,
                        benefits = {
                            daily_gems = 10,
                            experience_multiplier = 2,
                            exclusive_items = true,
                        },
                    },
                },
            },

            analytics = {
                events = {
                    "player_joined",
                    "player_left",
                    "level_up",
                    "item_purchased",
                    "currency_earned",
                    "enemy_defeated",
                    "quest_completed",
                },

                retention_milestones = {
                    tutorial_completed = 1,
                    first_purchase = 7,
                    level_10_reached = 3,
                    friend_invited = 14,
                },
            },
        }
        configsLoaded = true
        return
    end

    -- Load configs from files
    for _, child in ipairs(configsFolder:GetChildren()) do
        if child:IsA("ModuleScript") then
            local configName = child.Name
            local success, result = pcall(function()
                return require(child)
            end)

            if success then
                configs[configName] = result
            else
                warn("Failed to load config:", configName, result)
            end
        end
    end

    configsLoaded = true
end

function ConfigLoader:Init()
    -- Initialize caches
    self._monetizationCache = nil
    self._configCaches = {}
    loadConfigsFromStorage()
    self:ValidateAllConfigs()

    if self._modules and self._modules.Logger then
        self._modules.Logger:Info("ConfigLoader initialized", {
            configCount = self:_getConfigCount(),
        })
    end
end

function ConfigLoader:LoadConfig(configName)
    -- Load configs from storage if not already loaded
    loadConfigsFromStorage()

    if not configs[configName] then
        error(string.format("Config '%s' not found", configName))
    end

    -- Validate config before returning
    local config = configs[configName]
    local isValid, errorMessage = self:ValidateConfig(configName, config)

    if not isValid then
        error(
            string.format(
                "Invalid config '%s': %s",
                configName,
                errorMessage or "Unknown validation error"
            )
        )
    end

    return self:_deepCopy(config)
end

function ConfigLoader:GetItem(itemId)
    local items = self:LoadConfig("items")
    for _, item in ipairs(items) do
        if item.id == itemId then
            return item
        end
    end
    return nil
end

function ConfigLoader:GetEnemy(enemyId)
    local enemies = self:LoadConfig("enemies")
    for _, enemy in ipairs(enemies) do
        if enemy.id == enemyId then
            return enemy
        end
    end
    return nil
end

function ConfigLoader:GetCurrency(currencyId)
    local currencies = self:LoadConfig("currencies")
    for _, currency in ipairs(currencies) do
        if currency.id == currencyId then
            return currency
        end
    end
    return nil
end

function ConfigLoader:IsFeatureEnabled(featureName, defaultValue)
    local ok, gameConfig = pcall(function()
        return self:LoadConfig("game")
    end)

    if not ok or not gameConfig or type(gameConfig.features) ~= "table" then
        return defaultValue ~= false
    end

    local value = gameConfig.features[featureName]
    if value == nil then
        return defaultValue ~= false
    end

    return value == true
end

-- Monetization-specific config methods with caching
function ConfigLoader:GetProduct(productId)
    if not self._monetizationCache then
        self._monetizationCache = self:LoadConfig("monetization")
    end

    local monetization = self._monetizationCache
    if not monetization or not monetization.products then
        return nil
    end

    for _, product in ipairs(monetization.products) do
        if product.id == productId then
            return product
        end
    end
    return nil
end

function ConfigLoader:GetGamePass(passId)
    if not self._monetizationCache then
        self._monetizationCache = self:LoadConfig("monetization")
    end

    local monetization = self._monetizationCache
    if not monetization or not monetization.passes then
        return nil
    end

    for _, pass in ipairs(monetization.passes) do
        if pass.id == passId then
            return pass
        end
    end
    return nil
end

-- Get product by Roblox product ID
function ConfigLoader:GetProductByRobloxId(robloxProductId)
    if not self._monetizationCache then
        self._monetizationCache = self:LoadConfig("monetization")
    end

    local monetization = self._monetizationCache
    if not monetization or not monetization.product_id_mapping then
        return nil
    end

    -- Find config ID that maps to this Roblox ID
    local configId = nil
    for id, productId in pairs(monetization.product_id_mapping) do
        if productId == robloxProductId then
            configId = id
            break
        end
    end

    if configId then
        return self:GetProduct(configId)
    end

    return nil
end

-- Get all monetization products
function ConfigLoader:GetAllProducts()
    if not self._monetizationCache then
        self._monetizationCache = self:LoadConfig("monetization")
    end

    local monetization = self._monetizationCache
    return (monetization and monetization.products) or {}
end

-- Get all game passes
function ConfigLoader:GetAllGamePasses()
    if not self._monetizationCache then
        self._monetizationCache = self:LoadConfig("monetization")
    end

    local monetization = self._monetizationCache
    return (monetization and monetization.passes) or {}
end

-- Get product ID mapping
function ConfigLoader:GetProductIdMapping()
    if not self._monetizationCache then
        self._monetizationCache = self:LoadConfig("monetization")
    end

    local monetization = self._monetizationCache
    return (monetization and monetization.product_id_mapping) or {}
end

-- Get Roblox product/pass ID from config ID
function ConfigLoader:GetRobloxId(configId)
    local mapping = self:GetProductIdMapping()
    return mapping[configId]
end

-- Get premium benefits configuration
function ConfigLoader:GetPremiumBenefits()
    if not self._monetizationCache then
        self._monetizationCache = self:LoadConfig("monetization")
    end

    local monetization = self._monetizationCache
    return (monetization and monetization.premium_benefits) or {}
end

-- Get first purchase bonus configuration
function ConfigLoader:GetFirstPurchaseBonus()
    if not self._monetizationCache then
        self._monetizationCache = self:LoadConfig("monetization")
    end

    local monetization = self._monetizationCache
    return (monetization and monetization.first_purchase_bonus) or {}
end

-- Get validation rules
function ConfigLoader:GetValidationRules()
    if not self._monetizationCache then
        self._monetizationCache = self:LoadConfig("monetization")
    end

    local monetization = self._monetizationCache
    return (monetization and monetization.validation_rules) or {}
end

-- Get error messages
function ConfigLoader:GetErrorMessages()
    if not self._monetizationCache then
        self._monetizationCache = self:LoadConfig("monetization")
    end

    local monetization = self._monetizationCache
    return (monetization and monetization.error_messages) or {}
end

-- Get analytics configuration
function ConfigLoader:GetAnalyticsConfig()
    if not self._monetizationCache then
        self._monetizationCache = self:LoadConfig("monetization")
    end

    local monetization = self._monetizationCache
    return (monetization and monetization.analytics) or {}
end

-- Clear monetization cache (for hot reloading)
function ConfigLoader:ClearMonetizationCache()
    self._monetizationCache = nil
end

-- Validate monetization setup and warn about placeholder IDs
function ConfigLoader:ValidateMonetizationSetup()
    local monetization = self._monetizationCache or self:LoadConfig("monetization")
    local warnings = {}
    local errors = {}

    -- Check for placeholder product IDs
    for configId, robloxId in pairs(monetization.product_id_mapping) do
        if robloxId == 1234567890 or robloxId == 1234567891 or robloxId == 1234567892 then
            table.insert(
                warnings,
                "Product '" .. configId .. "' still uses placeholder ID " .. robloxId
            )
        elseif robloxId == 123456789 or robloxId == 123456790 or robloxId == 123456791 then
            table.insert(
                warnings,
                "Game pass '" .. configId .. "' still uses placeholder ID " .. robloxId
            )
        end

        if robloxId <= 0 then
            table.insert(errors, "Invalid Roblox ID for '" .. configId .. "': " .. robloxId)
        end
    end

    -- Check test mode configuration
    local validation = monetization.validation_rules
    if validation and validation.test_mode and validation.test_mode.enabled then
        table.insert(warnings, "Test mode is enabled - purchases will be free in Studio")
    end

    return {
        isValid = #errors == 0,
        errors = errors,
        warnings = warnings,
        hasPlaceholders = #warnings > 0,
    }
end

-- Get monetization setup status for debugging
function ConfigLoader:GetMonetizationStatus()
    local status = self:ValidateMonetizationSetup()
    local monetization = self._monetizationCache or self:LoadConfig("monetization")

    return {
        validation = status,
        productCount = #monetization.products,
        passCount = #monetization.passes,
        hasPremiumBenefits = monetization.premium_benefits.enabled,
        hasFirstPurchaseBonus = monetization.first_purchase_bonus.enabled,
        testModeEnabled = monetization.validation_rules.test_mode.enabled,
    }
end

function ConfigLoader:ValidateConfig(configName, config)
    if configName == "monetization" then
        return self:_validateMonetizationConfig(config)
    elseif configName == "items" then
        return self:_validateItemsConfig(config)
    elseif configName == "currencies" then
        return self:_validateCurrenciesConfig(config)
    elseif configName == "game" then
        return self:_validateGameConfig(config)
    elseif configName == "breakables" then
        return self:_validateBreakablesConfig(config)
    elseif configName == "pets" then
        return self:_validatePetsConfig(config)
    elseif configName == "events" then
        return self:_validateEventsConfig(config)
    elseif configName == "economy" then
        return self:_validateEconomyConfig(config)
    elseif configName == "egg_system" then
        return self:_validateEggSystemConfig(config)
    elseif configName == "stats" then
        return self:_validateStatsConfig(config)
    elseif configName == "ui" then
        return self:_validateUIConfig(config)
    elseif configName == "inventory" then
        return self:_validateInventoryConfig(config)
    elseif configName == "upgrades" then
        return self:_validateUpgradesConfig(config)
    elseif configName == "context_menus" then
        return self:_validateContextMenusConfig(config)
    elseif configName == "areas" then
        return self:_validateAreasConfig(config)
    elseif configName == "markers" then
        return self:_validateMarkersConfig(config)
    elseif configName == "pet_index" then
        return self:_validatePetIndexConfig(config)
    elseif configName == "pet_progression" then
        return self:_validatePetProgressionConfig(config)
    elseif configName == "player_progression" then
        return self:_validatePlayerProgressionConfig(config)
    elseif configName == "auto_systems" then
        return self:_validateAutoSystemsConfig(config)
    elseif configName == "enchants" then
        return self:_validateEnchantsConfig(config)
    elseif configName == "achievements" then
        return self:_validateAchievementsConfig(config)
    elseif configName == "leaderboards" then
        return self:_validateLeaderboardsConfig(config)
    elseif configName == "aggro" then
        return self:_validateAggroConfig(config)
    end

    -- Default validation for other configs
    return true
end

-- Unified aggro model (configs/aggro.lua): a symmetric `base` block × per-side multipliers.
-- Permissive (checks shape, not every field) so adding a knob never breaks Studio boot.
function ConfigLoader:_validateAggroConfig(config)
    if type(config) ~= "table" then
        return false, "Aggro config must be a table"
    end
    if type(config.base) ~= "table" then
        return false, "Aggro config missing required 'base' table"
    end
    for _, side in ipairs({ "pet", "enemy" }) do
        if config[side] ~= nil and type(config[side]) ~= "table" then
            return false, "Aggro config '" .. side .. "' must be a table when present"
        end
    end
    return true
end

function ConfigLoader:ValidateAllConfigs()
    loadConfigsFromStorage()

    if configsValidated then
        return true
    end

    for configName, config in pairs(configs) do
        local isValid, errorMessage = self:ValidateConfig(configName, config)
        if not isValid then
            local message = string.format(
                "Invalid config '%s': %s",
                configName,
                errorMessage or "Unknown validation error"
            )
            if self._modules and self._modules.Logger then
                self._modules.Logger:Error(message, { context = "ConfigLoader" })
            end
            error(message)
        end
    end

    configsValidated = true

    if self._modules and self._modules.Logger then
        self._modules.Logger:Info("All configs validated", {
            configCount = self:_getConfigCount(),
            context = "ConfigLoader",
        })
    end

    return true
end

function ConfigLoader:_configError(configName, path, message)
    return false, string.format("configs/%s.lua:%s %s", configName, path or "<root>", message)
end

function ConfigLoader:_requireType(configName, value, expectedType, path)
    if type(value) ~= expectedType then
        return self:_configError(
            configName,
            path,
            string.format("expected %s, got %s", expectedType, type(value))
        )
    end
    return true
end

function ConfigLoader:_requirePositiveNumber(configName, value, path)
    if type(value) ~= "number" or value <= 0 then
        return self:_configError(configName, path, "expected positive number")
    end
    return true
end

function ConfigLoader:_requireNonNegativeNumber(configName, value, path)
    if type(value) ~= "number" or value < 0 then
        return self:_configError(configName, path, "expected non-negative number")
    end
    return true
end

function ConfigLoader:_rawConfig(configName)
    return configs[configName]
end

function ConfigLoader:_validateMonetizationConfig(config)
    if not config then
        return false, "Monetization config is nil"
    end

    -- Check required sections
    local requiredSections = { "product_id_mapping", "products", "passes", "premium_benefits" }
    for _, section in ipairs(requiredSections) do
        if not config[section] then
            return false, "Missing required section: " .. section
        end
    end

    -- Validate products
    if type(config.products) ~= "table" then
        return false, "Products must be a table"
    end

    for i, product in ipairs(config.products) do
        if not product.id or type(product.id) ~= "string" then
            return false, "Product " .. i .. " missing or invalid id"
        end

        if not product.name or type(product.name) ~= "string" then
            return false, "Product " .. product.id .. " missing or invalid name"
        end

        if not product.price_robux or type(product.price_robux) ~= "number" then
            return false, "Product " .. product.id .. " missing or invalid price_robux"
        end

        if not product.rewards or type(product.rewards) ~= "table" then
            return false, "Product " .. product.id .. " missing or invalid rewards"
        end

        -- Check if product ID exists in mapping
        if not config.product_id_mapping[product.id] then
            return false, "Product " .. product.id .. " not found in product_id_mapping"
        end
    end

    -- Validate game passes
    if type(config.passes) ~= "table" then
        return false, "Passes must be a table"
    end

    for i, pass in ipairs(config.passes) do
        if not pass.id or type(pass.id) ~= "string" then
            return false, "Pass " .. i .. " missing or invalid id"
        end

        if not pass.name or type(pass.name) ~= "string" then
            return false, "Pass " .. pass.id .. " missing or invalid name"
        end

        if not pass.price_robux or type(pass.price_robux) ~= "number" then
            return false, "Pass " .. pass.id .. " missing or invalid price_robux"
        end

        if not pass.benefits or type(pass.benefits) ~= "table" then
            return false, "Pass " .. pass.id .. " missing or invalid benefits"
        end

        -- Check if pass ID exists in mapping
        if not config.product_id_mapping[pass.id] then
            return false, "Pass " .. pass.id .. " not found in product_id_mapping"
        end
    end

    -- Validate product ID mapping
    if type(config.product_id_mapping) ~= "table" then
        return false, "Product ID mapping must be a table"
    end

    for configId, robloxId in pairs(config.product_id_mapping) do
        if type(configId) ~= "string" then
            return false, "Config ID must be string: " .. tostring(configId)
        end

        if type(robloxId) ~= "number" then
            return false, "Roblox ID must be number for: " .. configId
        end
    end

    return true
end

function ConfigLoader:_validateItemsConfig(config)
    if not config or type(config) ~= "table" then
        return false, "Items config must be a table"
    end

    for i, item in ipairs(config) do
        if not item.id or type(item.id) ~= "string" then
            return false, "Item " .. i .. " missing or invalid id"
        end

        if not item.name or type(item.name) ~= "string" then
            return false, "Item " .. item.id .. " missing or invalid name"
        end
    end

    return true
end

function ConfigLoader:_validateCurrenciesConfig(config)
    if not config or type(config) ~= "table" then
        return false, "Currencies config must be a table"
    end

    local seen = {}

    for i, currency in ipairs(config) do
        if not currency.id or type(currency.id) ~= "string" then
            return false, "Currency " .. i .. " missing or invalid id"
        end

        if seen[currency.id] then
            return false, "Duplicate currency id: " .. currency.id
        end
        seen[currency.id] = true

        if not currency.name or type(currency.name) ~= "string" then
            return false, "Currency " .. currency.id .. " missing or invalid name"
        end

        if
            currency.maxAmount ~= nil
            and (type(currency.maxAmount) ~= "number" or currency.maxAmount <= 0)
        then
            return false, "Currency " .. currency.id .. " maxAmount must be a positive number"
        end

        if
            currency.defaultAmount ~= nil
            and (type(currency.defaultAmount) ~= "number" or currency.defaultAmount < 0)
        then
            return false,
                "Currency " .. currency.id .. " defaultAmount must be a non-negative number"
        end

        if
            currency.maxAmount ~= nil
            and currency.defaultAmount ~= nil
            and currency.defaultAmount > currency.maxAmount
        then
            return false, "Currency " .. currency.id .. " defaultAmount cannot exceed maxAmount"
        end
    end

    return true
end

function ConfigLoader:_validateGameConfig(config)
    local ok, err = self:_requireType("game", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    local required = {
        GameMode = "string",
        MaxPlayers = "number",
        RespawnTime = "number",
        WorldSettings = "table",
    }

    for key, expectedType in pairs(required) do
        ok, err = self:_requireType("game", config[key], expectedType, key)
        if not ok then
            return ok, err
        end
    end

    if config.MaxPlayers <= 0 then
        return self:_configError("game", "MaxPlayers", "must be greater than 0")
    end

    if config.RespawnTime < 0 then
        return self:_configError("game", "RespawnTime", "must be non-negative")
    end

    if config.features ~= nil then
        ok, err = self:_requireType("game", config.features, "table", "features")
        if not ok then
            return ok, err
        end

        for featureName, enabled in pairs(config.features) do
            if type(featureName) ~= "string" then
                return self:_configError("game", "features", "feature names must be strings")
            end
            if type(enabled) ~= "boolean" then
                return self:_configError("game", "features." .. featureName, "expected boolean")
            end
        end
    end

    for _, key in ipairs({ "Gravity", "WalkSpeed", "JumpPower" }) do
        ok, err =
            self:_requirePositiveNumber("game", config.WorldSettings[key], "WorldSettings." .. key)
        if not ok then
            return ok, err
        end
    end

    return true
end

function ConfigLoader:_validateBreakablesConfig(config)
    local ok, err = self:_requireType("breakables", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    ok, err = self:_requireType("breakables", config.crystals, "table", "crystals")
    if not ok then
        return ok, err
    end

    local currencies = self:_rawConfig("currencies")
    local crystalIds = {}

    for breakableId, breakable in pairs(config.crystals) do
        local basePath = "crystals." .. tostring(breakableId)
        ok, err = self:_requireType("breakables", breakable, "table", basePath)
        if not ok then
            return ok, err
        end

        if type(breakable.display_name) ~= "string" or breakable.display_name == "" then
            return self:_configError(
                "breakables",
                basePath .. ".display_name",
                "expected non-empty string"
            )
        end

        if
            type(breakable.asset_id) ~= "string"
            and type(breakable.procedural_asset) ~= "string"
        then
            return self:_configError(
                "breakables",
                basePath,
                "expected asset_id or procedural_asset"
            )
        end

        ok, err = self:_requirePositiveNumber("breakables", breakable.scale, basePath .. ".scale")
        if not ok then
            return ok, err
        end

        ok, err = self:_requirePositiveNumber("breakables", breakable.health, basePath .. ".health")
        if not ok then
            return ok, err
        end

        ok, err =
            self:_requireNonNegativeNumber("breakables", breakable.value, basePath .. ".value")
        if not ok then
            return ok, err
        end

        if type(breakable.currency) ~= "string" or not hasId(currencies, breakable.currency) then
            return self:_configError(
                "breakables",
                basePath .. ".currency",
                "must reference configs/currencies.lua"
            )
        end

        if breakable.placement ~= nil and type(breakable.placement) ~= "table" then
            return self:_configError(
                "breakables",
                basePath .. ".placement",
                "expected table when provided"
            )
        end

        crystalIds[breakableId] = true
    end

    ok, err = self:_requireType("breakables", config.worlds, "table", "worlds")
    if not ok then
        return ok, err
    end

    local areas = self:_rawConfig("areas")
    for worldId, world in pairs(config.worlds) do
        local basePath = "worlds." .. tostring(worldId)
        ok, err = self:_requireType("breakables", world, "table", basePath)
        if not ok then
            return ok, err
        end

        -- Realm worlds (Heaven_N / Hell_N) are not biome area zones; they are
        -- gated by the realm rule in BreakableSpawner._isWorldActive, not by an
        -- areas.lua zone unlock. Exempt them from the area-zone requirement.
        local isRealmWorld = tostring(worldId):match("^Heaven_%d")
            or tostring(worldId):match("^Hell_%d")

        if
            not isRealmWorld
            and areas
            and areas.zones
            and (not areas.zones[worldId] or areas.zones[worldId].kind ~= "area")
        then
            return self:_configError(
                "breakables",
                basePath,
                "must reference an area zone in configs/areas.lua"
            )
        end

        ok, err = self:_requireNonNegativeNumber("breakables", world.max, basePath .. ".max")
        if not ok then
            return ok, err
        end

        ok, err = self:_requirePositiveNumber("breakables", world.interval, basePath .. ".interval")
        if not ok then
            return ok, err
        end

        if world.spawn_table ~= nil then
            if not isArray(world.spawn_table) then
                return self:_configError("breakables", basePath .. ".spawn_table", "expected array")
            end

            for index, entry in ipairs(world.spawn_table) do
                local entryPath = basePath .. ".spawn_table[" .. index .. "]"
                if type(entry) ~= "table" then
                    return self:_configError("breakables", entryPath, "expected table")
                end
                if type(entry.name) ~= "string" or not crystalIds[entry.name] then
                    return self:_configError(
                        "breakables",
                        entryPath .. ".name",
                        "must reference breakables.crystals"
                    )
                end
                ok, err =
                    self:_requirePositiveNumber("breakables", entry.weight, entryPath .. ".weight")
                if not ok then
                    return ok, err
                end
            end
        end
    end

    return true
end

function ConfigLoader:_validateAreasConfig(config)
    local ok, err = self:_requireType("areas", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    ok, err = self:_requireType("areas", config.zones, "table", "zones")
    if not ok then
        return ok, err
    end

    local zoneIds = {}
    for zoneId, zone in pairs(config.zones) do
        local basePath = "zones." .. tostring(zoneId)
        ok, err = self:_requireType("areas", zone, "table", basePath)
        if not ok then
            return ok, err
        end

        if type(zone.id) ~= "string" or zone.id == "" then
            return self:_configError("areas", basePath .. ".id", "expected non-empty string")
        end
        if zone.id ~= zoneId then
            return self:_configError("areas", basePath .. ".id", "must match table key")
        end
        if zoneIds[zone.id] then
            return self:_configError("areas", basePath .. ".id", "duplicate zone id")
        end
        zoneIds[zone.id] = true

        if zone.kind ~= "world" and zone.kind ~= "island" and zone.kind ~= "area" then
            return self:_configError(
                "areas",
                basePath .. ".kind",
                "expected world, island, or area"
            )
        end
        if zone.parent ~= nil and type(zone.parent) ~= "string" then
            return self:_configError("areas", basePath .. ".parent", "expected string")
        end
        if zone.boosts ~= nil and type(zone.boosts) ~= "table" then
            return self:_configError("areas", basePath .. ".boosts", "expected table")
        end
        if zone.synthetic ~= nil and type(zone.synthetic) ~= "table" then
            return self:_configError("areas", basePath .. ".synthetic", "expected table")
        end
        if zone.unlock ~= nil then
            ok, err = self:_requireType("areas", zone.unlock, "table", basePath .. ".unlock")
            if not ok then
                return ok, err
            end

            if
                zone.unlock.unlocked_by_default ~= nil
                and type(zone.unlock.unlocked_by_default) ~= "boolean"
            then
                return self:_configError(
                    "areas",
                    basePath .. ".unlock.unlocked_by_default",
                    "expected boolean"
                )
            end

            if zone.unlock.required_zone ~= nil and type(zone.unlock.required_zone) ~= "string" then
                return self:_configError(
                    "areas",
                    basePath .. ".unlock.required_zone",
                    "expected string"
                )
            end

            if zone.unlock.currency ~= nil then
                local currencies = self:_rawConfig("currencies")
                if
                    type(zone.unlock.currency) ~= "string"
                    or not hasId(currencies, zone.unlock.currency)
                then
                    return self:_configError(
                        "areas",
                        basePath .. ".unlock.currency",
                        "must reference configs/currencies.lua"
                    )
                end
            end

            if zone.unlock.cost ~= nil then
                ok, err = self:_requireNonNegativeNumber(
                    "areas",
                    zone.unlock.cost,
                    basePath .. ".unlock.cost"
                )
                if not ok then
                    return ok, err
                end
            end
        end
    end

    for zoneId, zone in pairs(config.zones) do
        if zone.parent and not zoneIds[zone.parent] then
            return self:_configError(
                "areas",
                "zones." .. tostring(zoneId) .. ".parent",
                "must reference an existing zone"
            )
        end
        if zone.unlock and zone.unlock.required_zone and not zoneIds[zone.unlock.required_zone] then
            return self:_configError(
                "areas",
                "zones." .. tostring(zoneId) .. ".unlock.required_zone",
                "must reference an existing zone"
            )
        end
    end

    local visiting = {}
    local visited = {}
    local function visit(zoneId)
        if visiting[zoneId] then
            return false, "cycle detected at " .. tostring(zoneId)
        end
        if visited[zoneId] then
            return true
        end
        visiting[zoneId] = true
        local zone = config.zones[zoneId]
        if zone and zone.parent then
            local success, message = visit(zone.parent)
            if not success then
                return false, message
            end
        end
        visiting[zoneId] = nil
        visited[zoneId] = true
        return true
    end

    for zoneId in pairs(config.zones) do
        ok, err = visit(zoneId)
        if not ok then
            return self:_configError("areas", "zones." .. tostring(zoneId), err)
        end
    end

    return true
end

function ConfigLoader:_validateUpgradesConfig(config)
    local ok, err = self:_requireType("upgrades", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    ok, err = self:_requireType("upgrades", config.version, "string", "version")
    if not ok then
        return ok, err
    end

    ok, err = self:_requireType("upgrades", config.upgrades, "table", "upgrades")
    if not ok then
        return ok, err
    end

    local currencies = self:_rawConfig("currencies")
    local inventory = self:_rawConfig("inventory")
    local economy = self:_rawConfig("economy")

    for upgradeId, upgrade in pairs(config.upgrades) do
        local basePath = "upgrades." .. tostring(upgradeId)
        ok, err = self:_requireType("upgrades", upgrade, "table", basePath)
        if not ok then
            return ok, err
        end

        if type(upgrade.id) ~= "string" or upgrade.id == "" then
            return self:_configError("upgrades", basePath .. ".id", "expected non-empty string")
        end
        if upgrade.id ~= upgradeId then
            return self:_configError("upgrades", basePath .. ".id", "must match table key")
        end
        if type(upgrade.display_name) ~= "string" or upgrade.display_name == "" then
            return self:_configError(
                "upgrades",
                basePath .. ".display_name",
                "expected non-empty string"
            )
        end
        if
            type(upgrade.max_level) ~= "number"
            or upgrade.max_level < 1
            or upgrade.max_level % 1 ~= 0
        then
            return self:_configError(
                "upgrades",
                basePath .. ".max_level",
                "expected positive integer"
            )
        end

        ok, err = self:_requireType("upgrades", upgrade.cost, "table", basePath .. ".cost")
        if not ok then
            return ok, err
        end
        if
            type(upgrade.cost.currency) ~= "string" or not hasId(currencies, upgrade.cost.currency)
        then
            return self:_configError(
                "upgrades",
                basePath .. ".cost.currency",
                "must reference configs/currencies.lua"
            )
        end
        if upgrade.cost.type ~= "linear" and upgrade.cost.type ~= "exponential" then
            return self:_configError(
                "upgrades",
                basePath .. ".cost.type",
                "expected linear or exponential"
            )
        end
        ok, err =
            self:_requireNonNegativeNumber("upgrades", upgrade.cost.base, basePath .. ".cost.base")
        if not ok then
            return ok, err
        end
        if upgrade.cost.type == "linear" then
            ok, err = self:_requireNonNegativeNumber(
                "upgrades",
                upgrade.cost.increment,
                basePath .. ".cost.increment"
            )
            if not ok then
                return ok, err
            end
        else
            ok, err = self:_requirePositiveNumber(
                "upgrades",
                upgrade.cost.growth,
                basePath .. ".cost.growth"
            )
            if not ok then
                return ok, err
            end
        end

        if not isArray(upgrade.effects) or #upgrade.effects == 0 then
            return self:_configError("upgrades", basePath .. ".effects", "expected non-empty array")
        end

        for index, effect in ipairs(upgrade.effects) do
            local effectPath = basePath .. ".effects[" .. index .. "]"
            ok, err = self:_requireType("upgrades", effect, "table", effectPath)
            if not ok then
                return ok, err
            end

            if effect.type == "equip_slots" then
                if
                    type(effect.category) ~= "string"
                    or not inventory
                    or not inventory.equipped
                    or not inventory.equipped[effect.category]
                then
                    return self:_configError(
                        "upgrades",
                        effectPath .. ".category",
                        "must reference inventory.equipped"
                    )
                end
            elseif effect.type == "storage_slots" then
                if
                    type(effect.bucket) ~= "string"
                    or not inventory
                    or not inventory.buckets
                    or not inventory.buckets[effect.bucket]
                then
                    return self:_configError(
                        "upgrades",
                        effectPath .. ".bucket",
                        "must reference inventory.buckets"
                    )
                end
            elseif effect.type == "modifier" then
                if
                    type(effect.stage) ~= "string"
                    or not economy
                    or not economy.modifier_pipeline
                    or not economy.modifier_pipeline.stages
                    or not economy.modifier_pipeline.stages[effect.stage]
                then
                    return self:_configError(
                        "upgrades",
                        effectPath .. ".stage",
                        "must reference economy.modifier_pipeline.stages"
                    )
                end
            else
                return self:_configError(
                    "upgrades",
                    effectPath .. ".type",
                    "expected equip_slots, storage_slots, or modifier"
                )
            end

            ok, err = self:_requirePositiveNumber(
                "upgrades",
                effect.amount_per_level,
                effectPath .. ".amount_per_level"
            )
            if not ok then
                return ok, err
            end
        end
    end

    return true
end

function ConfigLoader:_validateMarkersConfig(config)
    local ok, err = self:_requireType("markers", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    ok, err = self:_requireType("markers", config.tags, "table", "tags")
    if not ok then
        return ok, err
    end

    local allowedAttributeTypes = {
        string = true,
        number = true,
        boolean = true,
    }

    for tagName, tagConfig in pairs(config.tags) do
        local basePath = "tags." .. tostring(tagName)
        if type(tagName) ~= "string" or tagName == "" then
            return self:_configError("markers", "tags", "tag names must be non-empty strings")
        end
        ok, err = self:_requireType("markers", tagConfig, "table", basePath)
        if not ok then
            return ok, err
        end
        for _, sectionName in ipairs({ "required_attributes", "optional_attributes" }) do
            local attributes = tagConfig[sectionName]
            if attributes ~= nil then
                ok, err = self:_requireType(
                    "markers",
                    attributes,
                    "table",
                    basePath .. "." .. sectionName
                )
                if not ok then
                    return ok, err
                end
                for attributeName, expectedType in pairs(attributes) do
                    if type(attributeName) ~= "string" or attributeName == "" then
                        return self:_configError(
                            "markers",
                            basePath .. "." .. sectionName,
                            "attribute names must be non-empty strings"
                        )
                    end
                    if not allowedAttributeTypes[expectedType] then
                        return self:_configError(
                            "markers",
                            basePath .. "." .. sectionName .. "." .. attributeName,
                            "unsupported expected type"
                        )
                    end
                end
            end
        end
        if tagConfig.id_attribute ~= nil and type(tagConfig.id_attribute) ~= "string" then
            return self:_configError("markers", basePath .. ".id_attribute", "expected string")
        end
        if tagConfig.config ~= nil and type(tagConfig.config) ~= "string" then
            return self:_configError("markers", basePath .. ".config", "expected string")
        end
    end

    if config.synthetic ~= nil then
        ok, err = self:_requireType("markers", config.synthetic, "table", "synthetic")
        if not ok then
            return ok, err
        end
    end

    return true
end

function ConfigLoader:_validatePetAssetTransform(transform, path)
    if transform == nil then
        return true
    end
    if type(transform) ~= "table" then
        return self:_configError("pets", path, "expected table")
    end

    local ok, err
    if transform.scale ~= nil then
        ok, err = self:_requirePositiveNumber("pets", transform.scale, path .. ".scale")
        if not ok then
            return ok, err
        end
    end
    if transform.huge_scale ~= nil then
        ok, err = self:_requirePositiveNumber("pets", transform.huge_scale, path .. ".huge_scale")
        if not ok then
            return ok, err
        end
    end

    if transform.orientation ~= nil then
        if type(transform.orientation) ~= "table" then
            return self:_configError("pets", path .. ".orientation", "expected table")
        end
        for _, axis in ipairs({ "x", "y", "z" }) do
            local value = transform.orientation[axis]
            if value ~= nil and type(value) ~= "number" then
                return self:_configError("pets", path .. ".orientation." .. axis, "expected number")
            end
        end
    end

    return true
end

function ConfigLoader:_validatePetEternalConfig(eternalConfig, path)
    if eternalConfig == nil then
        return true
    end
    if type(eternalConfig) ~= "table" then
        return self:_configError("pets", path, "expected table")
    end
    if eternalConfig.enabled ~= nil and type(eternalConfig.enabled) ~= "boolean" then
        return self:_configError("pets", path .. ".enabled", "expected boolean")
    end

    local ok, err
    if eternalConfig.power_percent ~= nil then
        ok, err = self:_requirePositiveNumber(
            "pets",
            eternalConfig.power_percent,
            path .. ".power_percent"
        )
        if not ok then
            return ok, err
        end
    end
    if
        eternalConfig.baseline ~= nil
        and eternalConfig.baseline ~= "strongest_equipped"
        and eternalConfig.baseline ~= "top_team_average"
    then
        return self:_configError(
            "pets",
            path .. ".baseline",
            "must be strongest_equipped or top_team_average"
        )
    end

    return true
end

function ConfigLoader:_validatePetEnchantingConfig(config)
    if config.enchanting == nil then
        return true
    end
    if type(config.enchanting) ~= "table" then
        return self:_configError("pets", "enchanting", "expected table")
    end

    local maxByRarity = config.enchanting.max_enchantments_by_rarity
    if type(maxByRarity) ~= "table" then
        return self:_configError("pets", "enchanting.max_enchantments_by_rarity", "expected table")
    end
    for rarityId, maxEnchantments in pairs(maxByRarity) do
        if type(rarityId) ~= "string" or not config.rarities[rarityId] then
            return self:_configError(
                "pets",
                "enchanting.max_enchantments_by_rarity." .. tostring(rarityId),
                "must reference rarities"
            )
        end
        if
            type(maxEnchantments) ~= "number"
            or maxEnchantments < 0
            or math.floor(maxEnchantments) ~= maxEnchantments
        then
            return self:_configError(
                "pets",
                "enchanting.max_enchantments_by_rarity." .. rarityId,
                "expected non-negative integer"
            )
        end
    end

    local maxEnchantments = config.enchanting.default_max_enchantments
    if maxEnchantments ~= nil then
        if
            type(maxEnchantments) ~= "number"
            or maxEnchantments < 0
            or math.floor(maxEnchantments) ~= maxEnchantments
        then
            return self:_configError(
                "pets",
                "enchanting.default_max_enchantments",
                "expected non-negative integer"
            )
        end
    end

    if
        config.enchanting.hatch_rolls_enabled ~= nil
        and type(config.enchanting.hatch_rolls_enabled) ~= "boolean"
    then
        return self:_configError("pets", "enchanting.hatch_rolls_enabled", "expected boolean")
    end

    return true
end

function ConfigLoader:_validatePetProvenanceConfig(config)
    if config.provenance == nil then
        return true
    end
    if type(config.provenance) ~= "table" then
        return self:_configError("pets", "provenance", "expected table")
    end

    local minEnchantments = config.provenance.hatcher_source_min_enchantments
    if minEnchantments ~= nil then
        if
            type(minEnchantments) ~= "number"
            or minEnchantments < 0
            or math.floor(minEnchantments) ~= minEnchantments
        then
            return self:_configError(
                "pets",
                "provenance.hatcher_source_min_enchantments",
                "expected non-negative integer"
            )
        end
    end

    local explicitRarities = config.provenance.hatcher_source_rarities
    if explicitRarities ~= nil then
        if not isArray(explicitRarities) then
            return self:_configError("pets", "provenance.hatcher_source_rarities", "expected array")
        end
        for index, rarityId in ipairs(explicitRarities) do
            if type(rarityId) ~= "string" or not config.rarities[rarityId] then
                return self:_configError(
                    "pets",
                    "provenance.hatcher_source_rarities[" .. index .. "]",
                    "must reference rarities"
                )
            end
        end
    end

    return true
end

function ConfigLoader:_validatePetsConfig(config)
    local ok, err = self:_requireType("pets", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    for _, key in ipairs({ "version", "rarities", "variants", "pets", "abilities", "egg_sources" }) do
        local expectedType = key == "version" and "string" or "table"
        ok, err = self:_requireType("pets", config[key], expectedType, key)
        if not ok then
            return ok, err
        end
    end

    if config.serials ~= nil then
        if type(config.serials) ~= "table" then
            return self:_configError("pets", "serials", "expected table")
        end
        if
            config.serials.store_name ~= nil
            and (type(config.serials.store_name) ~= "string" or config.serials.store_name == "")
        then
            return self:_configError("pets", "serials.store_name", "expected non-empty string")
        end
    end

    for rarityId, rarity in pairs(config.rarities) do
        local path = "rarities." .. tostring(rarityId)
        if not isStableConfigId(rarityId) then
            return self:_configError("pets", path, "id must match " .. STABLE_CONFIG_ID_PATTERN)
        end
        if type(rarity) ~= "table" then
            return self:_configError("pets", path, "expected table")
        end
        if type(rarity.name) ~= "string" or rarity.name == "" then
            return self:_configError("pets", path .. ".name", "expected non-empty string")
        end
    end

    ok, err = self:_validatePetEnchantingConfig(config)
    if not ok then
        return ok, err
    end
    ok, err = self:_validatePetProvenanceConfig(config)
    if not ok then
        return ok, err
    end

    for variantId, variant in pairs(config.variants) do
        local path = "variants." .. tostring(variantId)
        if not isStableConfigId(variantId) then
            return self:_configError("pets", path, "id must match " .. STABLE_CONFIG_ID_PATTERN)
        end
        if type(variant) ~= "table" then
            return self:_configError("pets", path, "expected table")
        end
        if type(variant.name) ~= "string" or variant.name == "" then
            return self:_configError("pets", path .. ".name", "expected non-empty string")
        end
        if type(variant.rarity) ~= "string" or not config.rarities[variant.rarity] then
            return self:_configError("pets", path .. ".rarity", "must reference rarities")
        end
        if variant.power_multiplier ~= nil then
            ok, err = self:_requirePositiveNumber(
                "pets",
                variant.power_multiplier,
                path .. ".power_multiplier"
            )
            if not ok then
                return ok, err
            end
        end
        if variant.health_multiplier ~= nil then
            ok, err = self:_requirePositiveNumber(
                "pets",
                variant.health_multiplier,
                path .. ".health_multiplier"
            )
            if not ok then
                return ok, err
            end
        end
    end

    for petId, pet in pairs(config.pets) do
        local basePath = "pets." .. tostring(petId)
        if not isStableConfigId(petId) then
            return self:_configError("pets", basePath, "id must match " .. STABLE_CONFIG_ID_PATTERN)
        end
        if type(pet) ~= "table" then
            return self:_configError("pets", basePath, "expected table")
        end

        for _, key in ipairs({ "display_name", "category" }) do
            if type(pet[key]) ~= "string" or pet[key] == "" then
                return self:_configError(
                    "pets",
                    basePath .. "." .. key,
                    "expected non-empty string"
                )
            end
        end
        if pet.name ~= nil and type(pet.name) ~= "string" then
            return self:_configError("pets", basePath .. ".name", "expected string")
        end

        ok, err = self:_requirePositiveNumber("pets", pet.base_power, basePath .. ".base_power")
        if not ok then
            return ok, err
        end
        ok, err = self:_requirePositiveNumber("pets", pet.base_health, basePath .. ".base_health")
        if not ok then
            return ok, err
        end
        if type(pet.rarity) ~= "string" or not config.rarities[pet.rarity] then
            return self:_configError("pets", basePath .. ".rarity", "must reference rarities")
        end

        ok, err =
            self:_validatePetAssetTransform(pet.asset_transform, basePath .. ".asset_transform")
        if not ok then
            return ok, err
        end
        ok, err = self:_validatePetEternalConfig(pet.eternal, basePath .. ".eternal")
        if not ok then
            return ok, err
        end

        if type(pet.variants) ~= "table" then
            return self:_configError("pets", basePath .. ".variants", "expected table")
        end

        for variantId, petVariant in pairs(pet.variants) do
            local variantPath = basePath .. ".variants." .. tostring(variantId)
            if not config.variants[variantId] then
                return self:_configError("pets", variantPath, "variant key must exist in variants")
            end
            if type(petVariant) ~= "table" then
                return self:_configError("pets", variantPath, "expected table")
            end
            -- A variant supplies its art EITHER as a packaged Model (`asset_id`, loaded via
            -- InsertService) OR as a separately-uploaded mesh+texture (`mesh_asset` [+ optional
            -- `texture_asset`], combined at load via AssetService:CreateMeshPartAsync — the same
            -- path enemies/gems use). FBX→Model uploads come out untextured, so meshy pets use
            -- the combine. Require at least one art source.
            if
                type(petVariant.asset_id) ~= "string"
                and type(petVariant.mesh_asset) ~= "string"
            then
                return self:_configError(
                    "pets",
                    variantPath,
                    "expected asset_id (Model) or mesh_asset (combine) string"
                )
            end
            if petVariant.mesh_asset ~= nil and type(petVariant.mesh_asset) ~= "string" then
                return self:_configError("pets", variantPath .. ".mesh_asset", "expected string")
            end
            if petVariant.texture_asset ~= nil and type(petVariant.texture_asset) ~= "string" then
                return self:_configError("pets", variantPath .. ".texture_asset", "expected string")
            end
            if type(petVariant.display_name) ~= "string" or petVariant.display_name == "" then
                return self:_configError(
                    "pets",
                    variantPath .. ".display_name",
                    "expected non-empty string"
                )
            end
            if petVariant.power ~= nil then
                ok, err =
                    self:_requirePositiveNumber("pets", petVariant.power, variantPath .. ".power")
                if not ok then
                    return ok, err
                end
            end
            if petVariant.health ~= nil then
                ok, err =
                    self:_requirePositiveNumber("pets", petVariant.health, variantPath .. ".health")
                if not ok then
                    return ok, err
                end
            end
            if petVariant.power_multiplier ~= nil then
                ok, err = self:_requirePositiveNumber(
                    "pets",
                    petVariant.power_multiplier,
                    variantPath .. ".power_multiplier"
                )
                if not ok then
                    return ok, err
                end
            end
            if petVariant.health_multiplier ~= nil then
                ok, err = self:_requirePositiveNumber(
                    "pets",
                    petVariant.health_multiplier,
                    variantPath .. ".health_multiplier"
                )
                if not ok then
                    return ok, err
                end
            end
            ok, err = self:_validatePetAssetTransform(
                petVariant.asset_transform,
                variantPath .. ".asset_transform"
            )
            if not ok then
                return ok, err
            end
            ok, err = self:_validatePetEternalConfig(petVariant.eternal, variantPath .. ".eternal")
            if not ok then
                return ok, err
            end
            if
                petVariant.rarity_override ~= nil
                and not config.rarities[petVariant.rarity_override]
            then
                return self:_configError(
                    "pets",
                    variantPath .. ".rarity_override",
                    "must reference rarities"
                )
            end
            if petVariant.abilities ~= nil then
                if not isArray(petVariant.abilities) then
                    return self:_configError("pets", variantPath .. ".abilities", "expected array")
                end
                for index, abilityId in ipairs(petVariant.abilities) do
                    if type(abilityId) ~= "string" or not config.abilities[abilityId] then
                        return self:_configError(
                            "pets",
                            variantPath .. ".abilities[" .. index .. "]",
                            "must reference abilities"
                        )
                    end
                end
            end
        end
    end

    local currencies = self:_rawConfig("currencies")
    for eggId, egg in pairs(config.egg_sources) do
        local basePath = "egg_sources." .. tostring(eggId)
        if type(egg) ~= "table" then
            return self:_configError("pets", basePath, "expected table")
        end
        if type(egg.name) ~= "string" or egg.name == "" then
            return self:_configError("pets", basePath .. ".name", "expected non-empty string")
        end
        ok, err = self:_requireNonNegativeNumber("pets", egg.cost, basePath .. ".cost")
        if not ok then
            return ok, err
        end
        if type(egg.currency) ~= "string" or not hasId(currencies, egg.currency) then
            return self:_configError(
                "pets",
                basePath .. ".currency",
                "must reference configs/currencies.lua"
            )
        end
        if type(egg.pet_weights) ~= "table" then
            return self:_configError("pets", basePath .. ".pet_weights", "expected table")
        end
        if egg.unlock_requirement ~= nil then
            if type(egg.unlock_requirement) ~= "table" then
                return self:_configError(
                    "pets",
                    basePath .. ".unlock_requirement",
                    "expected table"
                )
            end
            if
                type(egg.unlock_requirement.type) ~= "string"
                or egg.unlock_requirement.type == ""
            then
                return self:_configError(
                    "pets",
                    basePath .. ".unlock_requirement.type",
                    "expected non-empty string"
                )
            end
            ok, err = self:_requireNonNegativeNumber(
                "pets",
                egg.unlock_requirement.amount,
                basePath .. ".unlock_requirement.amount"
            )
            if not ok then
                return ok, err
            end
            for _, key in ipairs({ "counter", "stat" }) do
                local value = egg.unlock_requirement[key]
                if value ~= nil and (type(value) ~= "string" or value == "") then
                    return self:_configError(
                        "pets",
                        basePath .. ".unlock_requirement." .. key,
                        "expected non-empty string"
                    )
                end
            end
        end
        if egg.variant_rolls ~= nil then
            if type(egg.variant_rolls) ~= "table" then
                return self:_configError("pets", basePath .. ".variant_rolls", "expected table")
            end
            for _, key in ipairs({
                "enabled",
                "allow_basic",
                "allow_golden",
                "allow_rainbow",
            }) do
                local value = egg.variant_rolls[key]
                if value ~= nil and type(value) ~= "boolean" then
                    return self:_configError(
                        "pets",
                        basePath .. ".variant_rolls." .. key,
                        "expected boolean"
                    )
                end
            end
            if egg.variant_rolls.cost_multiplier ~= nil then
                ok, err = self:_requirePositiveNumber(
                    "pets",
                    egg.variant_rolls.cost_multiplier,
                    basePath .. ".variant_rolls.cost_multiplier"
                )
                if not ok then
                    return ok, err
                end
            end
        end
        for petId, weight in pairs(egg.pet_weights) do
            if not config.pets[petId] then
                return self:_configError(
                    "pets",
                    basePath .. ".pet_weights." .. tostring(petId),
                    "must reference pets"
                )
            end
            ok, err = self:_requirePositiveNumber(
                "pets",
                weight,
                basePath .. ".pet_weights." .. tostring(petId)
            )
            if not ok then
                return ok, err
            end
        end
    end

    return true
end

function ConfigLoader:_validateEventsConfig(config)
    local ok, err = self:_requireType("events", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    ok, err = self:_requirePositiveNumber("events", config.tick_seconds, "tick_seconds")
    if not ok then
        return ok, err
    end

    for _, key in ipairs({ "workspace", "modifiers", "global_events" }) do
        ok, err = self:_requireType("events", config[key], "table", key)
        if not ok then
            return ok, err
        end
    end

    for key, value in pairs(config.workspace) do
        if type(value) ~= "string" or value == "" then
            return self:_configError(
                "events",
                "workspace." .. tostring(key),
                "expected non-empty string"
            )
        end
    end

    local modifierIds = {}
    for modifierId, modifier in pairs(config.modifiers) do
        local path = "modifiers." .. tostring(modifierId)
        if type(modifier) ~= "table" then
            return self:_configError("events", path, "expected table")
        end
        if type(modifier.display_name) ~= "string" or modifier.display_name == "" then
            return self:_configError("events", path .. ".display_name", "expected non-empty string")
        end
        if type(modifier.base) ~= "number" then
            return self:_configError("events", path .. ".base", "expected number")
        end
        modifierIds[modifierId] = true
    end

    local eventIds = {}
    local allowedStacking = {
        extend_duration = true,
        reset = true,
        stack = true,
        ignore = true,
    }

    for eventId, event in pairs(config.global_events) do
        local path = "global_events." .. tostring(eventId)
        if type(event) ~= "table" then
            return self:_configError("events", path, "expected table")
        end
        if type(event.display_name) ~= "string" or event.display_name == "" then
            return self:_configError("events", path .. ".display_name", "expected non-empty string")
        end
        if type(event.duration_seconds) ~= "number" then
            return self:_configError("events", path .. ".duration_seconds", "expected number")
        end
        if event.duration_seconds == 0 or event.duration_seconds < -1 then
            return self:_configError(
                "events",
                path .. ".duration_seconds",
                "must be positive seconds or -1 for scheduled indefinite events"
            )
        end
        if type(event.stacking) ~= "string" or not allowedStacking[event.stacking] then
            return self:_configError(
                "events",
                path .. ".stacking",
                "must be extend_duration, reset, stack, or ignore"
            )
        end
        if type(event.modifiers) ~= "table" then
            return self:_configError("events", path .. ".modifiers", "expected table")
        end
        for modifierId, amount in pairs(event.modifiers) do
            if not modifierIds[modifierId] then
                return self:_configError(
                    "events",
                    path .. ".modifiers." .. tostring(modifierId),
                    "must reference modifiers"
                )
            end
            if type(amount) ~= "number" then
                return self:_configError(
                    "events",
                    path .. ".modifiers." .. tostring(modifierId),
                    "expected number"
                )
            end
        end
        eventIds[eventId] = true
    end

    if config.scheduled_global_events ~= nil then
        if type(config.scheduled_global_events) ~= "table" then
            return self:_configError("events", "scheduled_global_events", "expected table")
        end

        for scheduleId, schedule in pairs(config.scheduled_global_events) do
            local path = "scheduled_global_events." .. tostring(scheduleId)
            if type(schedule) ~= "table" then
                return self:_configError("events", path, "expected table")
            end
            if type(schedule.event_id) ~= "string" or not eventIds[schedule.event_id] then
                return self:_configError(
                    "events",
                    path .. ".event_id",
                    "must reference global_events"
                )
            end
            -- weekdays = MOUNTAIN weekdays (1=Sun..7=Sat); weekdays_utc kept as a legacy alias.
            local weekdays = schedule.weekdays or schedule.weekdays_utc
            local field = schedule.weekdays ~= nil and "weekdays" or "weekdays_utc"
            if not isArray(weekdays) then
                return self:_configError("events", path .. "." .. field, "expected array")
            end
            for index, weekday in ipairs(weekdays) do
                if type(weekday) ~= "number" or weekday < 1 or weekday > 7 or weekday % 1 ~= 0 then
                    return self:_configError(
                        "events",
                        path .. "." .. field .. "[" .. index .. "]",
                        "must be integer 1..7"
                    )
                end
            end
        end
    end

    return true
end

function ConfigLoader:_validateEconomyConfig(config)
    local ok, err = self:_requireType("economy", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    if config.modifier_pipeline ~= nil then
        ok, err =
            self:_requireType("economy", config.modifier_pipeline, "table", "modifier_pipeline")
        if not ok then
            return ok, err
        end

        local pipeline = config.modifier_pipeline
        if not isArray(pipeline.stage_order) then
            return self:_configError("economy", "modifier_pipeline.stage_order", "expected array")
        end

        ok, err = self:_requireType("economy", pipeline.stages, "table", "modifier_pipeline.stages")
        if not ok then
            return ok, err
        end

        local allowedCombine = {
            add = true,
            multiply = true,
            override = true,
            cap = true,
        }

        for index, stageName in ipairs(pipeline.stage_order) do
            if type(stageName) ~= "string" then
                return self:_configError(
                    "economy",
                    "modifier_pipeline.stage_order[" .. index .. "]",
                    "expected string"
                )
            end
            if stageName ~= "base" and not pipeline.stages[stageName] then
                return self:_configError(
                    "economy",
                    "modifier_pipeline.stage_order[" .. index .. "]",
                    "must reference modifier_pipeline.stages"
                )
            end
        end

        for stageName, stageConfig in pairs(pipeline.stages) do
            local combine = stageConfig and stageConfig.combine
            if type(combine) ~= "string" or not allowedCombine[combine] then
                return self:_configError(
                    "economy",
                    "modifier_pipeline.stages." .. tostring(stageName) .. ".combine",
                    "must be add, multiply, override, or cap"
                )
            end
        end
    end

    if config.currency_exchange == nil then
        return true
    end

    local exchange = config.currency_exchange
    ok, err = self:_requireType("economy", exchange, "table", "currency_exchange")
    if not ok then
        return ok, err
    end

    if exchange.enabled ~= nil and type(exchange.enabled) ~= "boolean" then
        return self:_configError("economy", "currency_exchange.enabled", "expected boolean")
    end

    if exchange.conversions ~= nil then
        ok, err = self:_requireType(
            "economy",
            exchange.conversions,
            "table",
            "currency_exchange.conversions"
        )
        if not ok then
            return ok, err
        end
    end

    local currencies = self:_rawConfig("currencies")
    local hasDefault = false

    for conversionId, conversion in pairs(exchange.conversions or {}) do
        local path = "currency_exchange.conversions." .. tostring(conversionId)
        if conversionId == exchange.default_conversion then
            hasDefault = true
        end
        if type(conversion) ~= "table" then
            return self:_configError("economy", path, "expected table")
        end
        if type(conversion.from) ~= "string" or not hasId(currencies, conversion.from) then
            return self:_configError(
                "economy",
                path .. ".from",
                "must reference configs/currencies.lua"
            )
        end
        if type(conversion.to) ~= "string" or not hasId(currencies, conversion.to) then
            return self:_configError(
                "economy",
                path .. ".to",
                "must reference configs/currencies.lua"
            )
        end
        ok, err =
            self:_requirePositiveNumber("economy", conversion.from_amount, path .. ".from_amount")
        if not ok then
            return ok, err
        end
        ok, err = self:_requirePositiveNumber("economy", conversion.to_amount, path .. ".to_amount")
        if not ok then
            return ok, err
        end
        ok, err = self:_requirePositiveNumber(
            "economy",
            conversion.max_batches_per_request,
            path .. ".max_batches_per_request"
        )
        if not ok then
            return ok, err
        end
    end

    if exchange.default_conversion ~= nil and not hasDefault then
        return self:_configError(
            "economy",
            "currency_exchange.default_conversion",
            "must reference currency_exchange.conversions"
        )
    end

    return true
end

function ConfigLoader:_validateEggSystemConfig(config)
    local ok, err = self:_requireType("egg_system", config, "table", "<root>")
    if not ok then
        return ok, err
    end
    local pets = self:_rawConfig("pets") or {}

    for _, key in ipairs({
        "version",
        "proximity",
        "performance",
        "cooldowns",
        "hatching",
        "ui",
        "pet_preview",
        "messages",
        "spawning",
        "validation",
    }) do
        local expectedType = key == "version" and "string" or "table"
        ok, err = self:_requireType("egg_system", config[key], expectedType, key)
        if not ok then
            return ok, err
        end
    end

    ok, err = self:_requirePositiveNumber(
        "egg_system",
        config.proximity.max_distance,
        "proximity.max_distance"
    )
    if not ok then
        return ok, err
    end
    ok, err = self:_requirePositiveNumber(
        "egg_system",
        config.performance.update_interval,
        "performance.update_interval"
    )
    if not ok then
        return ok, err
    end
    ok, err = self:_requireNonNegativeNumber(
        "egg_system",
        config.cooldowns.purchase_cooldown,
        "cooldowns.purchase_cooldown"
    )
    if not ok then
        return ok, err
    end
    ok, err =
        self:_requirePositiveNumber("egg_system", config.hatching.max_count, "hatching.max_count")
    if not ok then
        return ok, err
    end
    ok, err = self:_requirePositiveNumber(
        "egg_system",
        config.hatching.default_requested_count,
        "hatching.default_requested_count"
    )
    if not ok then
        return ok, err
    end
    ok, err = self:_requireNonNegativeNumber(
        "egg_system",
        config.hatching.transaction_lock_seconds,
        "hatching.transaction_lock_seconds"
    )
    if not ok then
        return ok, err
    end
    ok, err = self:_requirePositiveNumber(
        "egg_system",
        config.hatching.auto_loop_delay or 1,
        "hatching.auto_loop_delay"
    )
    if not ok then
        return ok, err
    end
    if config.hatching.max_count > 99 then
        return self:_configError("egg_system", "hatching.max_count", "must be 99 or lower")
    end
    if config.hatching.default_requested_count > config.hatching.max_count then
        return self:_configError(
            "egg_system",
            "hatching.default_requested_count",
            "must be less than or equal to hatching.max_count"
        )
    end
    if config.hatching.default_max_entitled_count ~= nil then
        ok, err = self:_requirePositiveNumber(
            "egg_system",
            config.hatching.default_max_entitled_count,
            "hatching.default_max_entitled_count"
        )
        if not ok then
            return ok, err
        end
        if config.hatching.default_max_entitled_count > config.hatching.max_count then
            return self:_configError(
                "egg_system",
                "hatching.default_max_entitled_count",
                "must be less than or equal to hatching.max_count"
            )
        end
    end
    if
        config.hatching.allow_partial ~= nil
        and type(config.hatching.allow_partial) ~= "boolean"
    then
        return self:_configError("egg_system", "hatching.allow_partial", "expected boolean")
    end
    if config.hatching.failed_request_lock_seconds ~= nil then
        ok, err = self:_requireNonNegativeNumber(
            "egg_system",
            config.hatching.failed_request_lock_seconds,
            "hatching.failed_request_lock_seconds"
        )
        if not ok then
            return ok, err
        end
    end
    local debugConfig = config.hatching.debug or {}
    if type(debugConfig) ~= "table" then
        return self:_configError("egg_system", "hatching.debug", "expected table")
    end
    for _, fieldName in ipairs({ "history_limit", "result_sample_limit" }) do
        if debugConfig[fieldName] ~= nil then
            ok, err = self:_requirePositiveNumber(
                "egg_system",
                debugConfig[fieldName],
                "hatching.debug." .. fieldName
            )
            if not ok then
                return ok, err
            end
        end
    end
    local animation = config.hatching.animation or {}
    if type(animation) ~= "table" then
        return self:_configError("egg_system", "hatching.animation", "expected table")
    end
    if animation.max_visible_eggs ~= nil then
        ok, err = self:_requirePositiveNumber(
            "egg_system",
            animation.max_visible_eggs,
            "hatching.animation.max_visible_eggs"
        )
        if not ok then
            return ok, err
        end
        if animation.max_visible_eggs > config.hatching.max_count then
            return self:_configError(
                "egg_system",
                "hatching.animation.max_visible_eggs",
                "must be less than or equal to hatching.max_count"
            )
        end
    end
    if
        animation.use_authored_egg_visual ~= nil
        and type(animation.use_authored_egg_visual) ~= "boolean"
    then
        return self:_configError(
            "egg_system",
            "hatching.animation.use_authored_egg_visual",
            "expected boolean"
        )
    end
    if animation.authored_visual_scale ~= nil then
        ok, err = self:_requirePositiveNumber(
            "egg_system",
            animation.authored_visual_scale,
            "hatching.animation.authored_visual_scale"
        )
        if not ok then
            return ok, err
        end
    end
    if animation.fast_hatch_speed_scale ~= nil then
        ok, err = self:_requirePositiveNumber(
            "egg_system",
            animation.fast_hatch_speed_scale,
            "hatching.animation.fast_hatch_speed_scale"
        )
        if not ok then
            return ok, err
        end
        if animation.fast_hatch_speed_scale > 1 then
            return self:_configError(
                "egg_system",
                "hatching.animation.fast_hatch_speed_scale",
                "must be less than or equal to 1"
            )
        end
    end
    local layout = animation.layout or {}
    if type(layout) ~= "table" then
        return self:_configError("egg_system", "hatching.animation.layout", "expected table")
    end
    for _, fieldName in ipairs({
        "padding",
        "min_egg_size",
        "compact_min_egg_size",
        "max_egg_size",
    }) do
        if layout[fieldName] ~= nil then
            ok, err = self:_requirePositiveNumber(
                "egg_system",
                layout[fieldName],
                "hatching.animation.layout." .. fieldName
            )
            if not ok then
                return ok, err
            end
        end
    end
    if layout.compact_threshold ~= nil then
        ok, err = self:_requirePositiveNumber(
            "egg_system",
            layout.compact_threshold,
            "hatching.animation.layout.compact_threshold"
        )
        if not ok then
            return ok, err
        end
    end
    if
        layout.min_egg_size
        and layout.max_egg_size
        and layout.min_egg_size > layout.max_egg_size
    then
        return self:_configError(
            "egg_system",
            "hatching.animation.layout.min_egg_size",
            "must be less than or equal to hatching.animation.layout.max_egg_size"
        )
    end
    if
        layout.compact_min_egg_size
        and layout.max_egg_size
        and layout.compact_min_egg_size > layout.max_egg_size
    then
        return self:_configError(
            "egg_system",
            "hatching.animation.layout.compact_min_egg_size",
            "must be less than or equal to hatching.animation.layout.max_egg_size"
        )
    end
    if
        animation.special_reveal_enabled ~= nil
        and type(animation.special_reveal_enabled) ~= "boolean"
    then
        return self:_configError(
            "egg_system",
            "hatching.animation.special_reveal_enabled",
            "expected boolean"
        )
    end
    if animation.special_world_fx ~= nil and type(animation.special_world_fx) ~= "boolean" then
        return self:_configError(
            "egg_system",
            "hatching.animation.special_world_fx",
            "expected boolean"
        )
    end
    if
        animation.respect_silent_for_special ~= nil
        and type(animation.respect_silent_for_special) ~= "boolean"
    then
        return self:_configError(
            "egg_system",
            "hatching.animation.respect_silent_for_special",
            "expected boolean"
        )
    end
    ok, err = self:_requireNonNegativeNumber(
        "egg_system",
        animation.special_reveal_min_duration or 0,
        "hatching.animation.special_reveal_min_duration"
    )
    if not ok then
        return ok, err
    end
    local specialRarities = animation.special_rarities or {}
    if type(specialRarities) ~= "table" then
        return self:_configError(
            "egg_system",
            "hatching.animation.special_rarities",
            "expected table"
        )
    end
    for rarityId, enabled in pairs(specialRarities) do
        if type(rarityId) ~= "string" or rarityId == "" then
            return self:_configError(
                "egg_system",
                "hatching.animation.special_rarities",
                "expected non-empty string keys"
            )
        end
        if pets.rarities and not pets.rarities[rarityId] then
            return self:_configError(
                "egg_system",
                "hatching.animation.special_rarities." .. rarityId,
                "must reference pets.rarities"
            )
        end
        if type(enabled) ~= "boolean" then
            return self:_configError(
                "egg_system",
                "hatching.animation.special_rarities." .. rarityId,
                "expected boolean"
            )
        end
    end
    local specialGlow = animation.special_glow or {}
    if type(specialGlow) ~= "table" then
        return self:_configError("egg_system", "hatching.animation.special_glow", "expected table")
    end
    for _, fieldName in ipairs({ "enabled", "pulse_enabled" }) do
        if specialGlow[fieldName] ~= nil and type(specialGlow[fieldName]) ~= "boolean" then
            return self:_configError(
                "egg_system",
                "hatching.animation.special_glow." .. fieldName,
                "expected boolean"
            )
        end
    end
    for _, fieldName in ipairs({
        "stroke_thickness",
        "pulse_scale",
        "pulse_duration",
    }) do
        if specialGlow[fieldName] ~= nil then
            ok, err = self:_requirePositiveNumber(
                "egg_system",
                specialGlow[fieldName],
                "hatching.animation.special_glow." .. fieldName
            )
            if not ok then
                return ok, err
            end
        end
    end
    if specialGlow.stroke_transparency ~= nil then
        ok, err = self:_requireNonNegativeNumber(
            "egg_system",
            specialGlow.stroke_transparency,
            "hatching.animation.special_glow.stroke_transparency"
        )
        if not ok then
            return ok, err
        end
        if specialGlow.stroke_transparency > 1 then
            return self:_configError(
                "egg_system",
                "hatching.animation.special_glow.stroke_transparency",
                "must be less than or equal to 1"
            )
        end
    end
    if specialGlow.pulse_repeats ~= nil then
        ok, err = self:_requireNonNegativeNumber(
            "egg_system",
            specialGlow.pulse_repeats,
            "hatching.animation.special_glow.pulse_repeats"
        )
        if not ok then
            return ok, err
        end
    end
    local specialBackdrop = animation.special_backdrop or {}
    if type(specialBackdrop) ~= "table" then
        return self:_configError(
            "egg_system",
            "hatching.animation.special_backdrop",
            "expected table"
        )
    end
    if specialBackdrop.enabled ~= nil and type(specialBackdrop.enabled) ~= "boolean" then
        return self:_configError(
            "egg_system",
            "hatching.animation.special_backdrop.enabled",
            "expected boolean"
        )
    end
    for _, fieldName in ipairs({ "pulse_scale", "pulse_duration" }) do
        if specialBackdrop[fieldName] ~= nil then
            ok, err = self:_requirePositiveNumber(
                "egg_system",
                specialBackdrop[fieldName],
                "hatching.animation.special_backdrop." .. fieldName
            )
            if not ok then
                return ok, err
            end
        end
    end
    if specialBackdrop.transparency ~= nil then
        ok, err = self:_requireNonNegativeNumber(
            "egg_system",
            specialBackdrop.transparency,
            "hatching.animation.special_backdrop.transparency"
        )
        if not ok then
            return ok, err
        end
        if specialBackdrop.transparency > 1 then
            return self:_configError(
                "egg_system",
                "hatching.animation.special_backdrop.transparency",
                "must be less than or equal to 1"
            )
        end
    end
    local resultStack = animation.result_stack or {}
    if type(resultStack) ~= "table" then
        return self:_configError("egg_system", "hatching.animation.result_stack", "expected table")
    end
    for _, fieldName in ipairs({ "enabled", "show_name", "show_count" }) do
        if resultStack[fieldName] ~= nil and type(resultStack[fieldName]) ~= "boolean" then
            return self:_configError(
                "egg_system",
                "hatching.animation.result_stack." .. fieldName,
                "expected boolean"
            )
        end
    end
    for _, fieldName in ipairs({
        "count_minimum",
        "move_tween_seconds",
        "recenter_tween_seconds",
        "hold_seconds",
    }) do
        if resultStack[fieldName] ~= nil then
            ok, err = self:_requirePositiveNumber(
                "egg_system",
                resultStack[fieldName],
                "hatching.animation.result_stack." .. fieldName
            )
            if not ok then
                return ok, err
            end
        end
    end
    local revealBadges = animation.reveal_badges or {}
    if type(revealBadges) ~= "table" then
        return self:_configError("egg_system", "hatching.animation.reveal_badges", "expected table")
    end
    for _, fieldName in ipairs({
        "enabled",
        "show_rarity",
        "show_variant",
        "show_basic_variant",
        "show_auto_deleted",
    }) do
        if revealBadges[fieldName] ~= nil and type(revealBadges[fieldName]) ~= "boolean" then
            return self:_configError(
                "egg_system",
                "hatching.animation.reveal_badges." .. fieldName,
                "expected boolean"
            )
        end
    end
    for _, fieldName in ipairs({ "special_badge_text", "auto_deleted_text" }) do
        if revealBadges[fieldName] ~= nil and type(revealBadges[fieldName]) ~= "string" then
            return self:_configError(
                "egg_system",
                "hatching.animation.reveal_badges." .. fieldName,
                "expected string"
            )
        end
    end
    local shopStubs = config.hatching.shop_stubs or {}
    if type(shopStubs) ~= "table" then
        return self:_configError("egg_system", "hatching.shop_stubs", "expected table")
    end
    for _, stubName in ipairs({
        "auto_hatch",
        "fast_hatch",
        "skip_hatch",
        "golden_mode",
        "charged_mode",
        "luck_bonus",
        "secret_luck_bonus",
        "max_hatch_count",
    }) do
        local stub = shopStubs[stubName] or {}
        if type(stub) ~= "table" then
            return self:_configError(
                "egg_system",
                "hatching.shop_stubs." .. stubName,
                "expected table"
            )
        end
        if stub.enabled ~= nil and type(stub.enabled) ~= "boolean" then
            return self:_configError(
                "egg_system",
                "hatching.shop_stubs." .. stubName .. ".enabled",
                "expected boolean"
            )
        end
        if stub.owned_by_default ~= nil and type(stub.owned_by_default) ~= "boolean" then
            return self:_configError(
                "egg_system",
                "hatching.shop_stubs." .. stubName .. ".owned_by_default",
                "expected boolean"
            )
        end
        if stub.cost_multiplier ~= nil then
            ok, err = self:_requirePositiveNumber(
                "egg_system",
                stub.cost_multiplier,
                "hatching.shop_stubs." .. stubName .. ".cost_multiplier"
            )
            if not ok then
                return ok, err
            end
        end
        for _, fieldName in ipairs({ "luck_bonus", "secret_luck_bonus", "default_multiplier" }) do
            if stub[fieldName] ~= nil then
                ok, err = self:_requireNonNegativeNumber(
                    "egg_system",
                    stub[fieldName],
                    "hatching.shop_stubs." .. stubName .. "." .. fieldName
                )
                if not ok then
                    return ok, err
                end
            end
        end
        if stubName == "max_hatch_count" and stub.default_value ~= nil then
            ok, err = self:_requirePositiveNumber(
                "egg_system",
                stub.default_value,
                "hatching.shop_stubs.max_hatch_count.default_value"
            )
            if not ok then
                return ok, err
            end
            if stub.default_value > config.hatching.max_count then
                return self:_configError(
                    "egg_system",
                    "hatching.shop_stubs.max_hatch_count.default_value",
                    "must be less than or equal to hatching.max_count"
                )
            end
        end
    end
    local interactionPrompt = config.ui.interaction_prompt or {}
    if type(interactionPrompt) ~= "table" then
        return self:_configError("egg_system", "ui.interaction_prompt", "expected table")
    end
    local promptMode = interactionPrompt.mode or "clean"
    if promptMode ~= "clean" and promptMode ~= "advertised_hotkeys" then
        return self:_configError(
            "egg_system",
            "ui.interaction_prompt.mode",
            "must be clean or advertised_hotkeys"
        )
    end
    for _, fieldName in ipairs({
        "clean_text",
        "clean_max_text",
        "clean_auto_text",
        "advertised_text",
    }) do
        if
            interactionPrompt[fieldName] ~= nil
            and type(interactionPrompt[fieldName]) ~= "string"
        then
            return self:_configError(
                "egg_system",
                "ui.interaction_prompt." .. fieldName,
                "expected string"
            )
        end
    end

    if type(config.ui.hatch_panel) ~= "table" then
        return self:_configError("egg_system", "ui.hatch_panel", "expected table")
    end
    if
        config.ui.hatch_panel.enabled ~= nil
        and type(config.ui.hatch_panel.enabled) ~= "boolean"
    then
        return self:_configError("egg_system", "ui.hatch_panel.enabled", "expected boolean")
    end
    ok, err = self:_requirePositiveNumber(
        "egg_system",
        config.ui.hatch_panel.width,
        "ui.hatch_panel.width"
    )
    if not ok then
        return ok, err
    end
    ok, err = self:_requirePositiveNumber(
        "egg_system",
        config.ui.hatch_panel.height,
        "ui.hatch_panel.height"
    )
    if not ok then
        return ok, err
    end
    ok, err = self:_requirePositiveNumber(
        "egg_system",
        config.ui.hatch_panel.settings_height or 1,
        "ui.hatch_panel.settings_height"
    )
    if not ok then
        return ok, err
    end
    ok, err = self:_requirePositiveNumber(
        "egg_system",
        config.ui.hatch_panel.count_step or 1,
        "ui.hatch_panel.count_step"
    )
    if not ok then
        return ok, err
    end
    ok, err = self:_requirePositiveNumber(
        "egg_system",
        config.ui.hatch_panel.count_large_step or 1,
        "ui.hatch_panel.count_large_step"
    )
    if not ok then
        return ok, err
    end
    ok, err = self:_requirePositiveNumber(
        "egg_system",
        config.ui.hatch_panel.default_selected_count or 1,
        "ui.hatch_panel.default_selected_count"
    )
    if not ok then
        return ok, err
    end
    if
        config.ui.hatch_panel.default_selected_count ~= nil
        and config.ui.hatch_panel.default_selected_count > config.hatching.max_count
    then
        return self:_configError(
            "egg_system",
            "ui.hatch_panel.default_selected_count",
            "must be less than or equal to hatching.max_count"
        )
    end
    local validActionModes = { single = true, max = true, auto = true }
    if
        config.ui.hatch_panel.default_action_mode ~= nil
        and not validActionModes[config.ui.hatch_panel.default_action_mode]
    then
        return self:_configError(
            "egg_system",
            "ui.hatch_panel.default_action_mode",
            "must be one of single, max, or auto"
        )
    end
    if
        config.ui.hatch_panel.show_inline_controls ~= nil
        and type(config.ui.hatch_panel.show_inline_controls) ~= "boolean"
    then
        return self:_configError(
            "egg_system",
            "ui.hatch_panel.show_inline_controls",
            "expected boolean"
        )
    end
    local actionModes = config.ui.hatch_panel.action_modes or {}
    if type(actionModes) ~= "table" then
        return self:_configError("egg_system", "ui.hatch_panel.action_modes", "expected table")
    end
    for _, actionName in ipairs({ "single", "max", "auto" }) do
        local actionConfig = actionModes[actionName]
        if actionConfig ~= nil then
            if type(actionConfig) ~= "table" then
                return self:_configError(
                    "egg_system",
                    "ui.hatch_panel.action_modes." .. actionName,
                    "expected table"
                )
            end
            for _, fieldName in ipairs({ "label", "description" }) do
                if actionConfig[fieldName] ~= nil and type(actionConfig[fieldName]) ~= "string" then
                    return self:_configError(
                        "egg_system",
                        "ui.hatch_panel.action_modes." .. actionName .. "." .. fieldName,
                        "expected string"
                    )
                end
            end
        end
    end
    ok, err = self:_requireNonNegativeNumber(
        "egg_system",
        config.ui.hatch_panel.status_display_time or 0,
        "ui.hatch_panel.status_display_time"
    )
    if not ok then
        return ok, err
    end
    local responsive = config.ui.hatch_panel.responsive or {}
    if type(responsive) ~= "table" then
        return self:_configError("egg_system", "ui.hatch_panel.responsive", "expected table")
    end
    ok, err = self:_requireNonNegativeNumber(
        "egg_system",
        responsive.margin or 0,
        "ui.hatch_panel.responsive.margin"
    )
    if not ok then
        return ok, err
    end
    ok, err = self:_requirePositiveNumber(
        "egg_system",
        responsive.min_scale or 0.64,
        "ui.hatch_panel.responsive.min_scale"
    )
    if not ok then
        return ok, err
    end
    ok, err = self:_requirePositiveNumber(
        "egg_system",
        responsive.max_scale or 1,
        "ui.hatch_panel.responsive.max_scale"
    )
    if not ok then
        return ok, err
    end
    if responsive.min_scale ~= nil and responsive.min_scale > 1 then
        return self:_configError(
            "egg_system",
            "ui.hatch_panel.responsive.min_scale",
            "must be less than or equal to 1"
        )
    end
    if responsive.max_scale ~= nil and responsive.max_scale < (responsive.min_scale or 0) then
        return self:_configError(
            "egg_system",
            "ui.hatch_panel.responsive.max_scale",
            "must be greater than or equal to responsive.min_scale"
        )
    end
    local buttons = config.ui.hatch_panel.buttons or {}
    if type(buttons) ~= "table" then
        return self:_configError("egg_system", "ui.hatch_panel.buttons", "expected table")
    end
    for _, buttonName in ipairs({ "hatch", "max", "auto", "settings" }) do
        local value = buttons[buttonName]
        if type(value) ~= "string" or value == "" then
            return self:_configError(
                "egg_system",
                "ui.hatch_panel.buttons." .. buttonName,
                "expected non-empty string"
            )
        end
    end
    local autoDelete = config.ui.hatch_panel.auto_delete or {}
    if type(autoDelete) ~= "table" then
        return self:_configError("egg_system", "ui.hatch_panel.auto_delete", "expected table")
    end
    for _, fieldName in ipairs({
        "description",
        "enabled_description",
        "summary_empty",
        "summary_enabled_format",
        "summary_disabled_format",
        "rarity_description",
        "pet_type_description",
        "variant_description",
    }) do
        if autoDelete[fieldName] ~= nil and type(autoDelete[fieldName]) ~= "string" then
            return self:_configError(
                "egg_system",
                "ui.hatch_panel.auto_delete." .. fieldName,
                "expected string"
            )
        end
    end
    local autoDeleteFilterRefs = {
        rarity_filters = {
            allowed = pets.rarities,
            target = "pets.rarities",
        },
        pet_type_filters = {
            allowed = pets.pets,
            target = "pets.pets",
        },
        variant_filters = {
            allowed = pets.variants,
            target = "pets.variants",
        },
    }
    for _, listName in ipairs({ "rarity_filters", "pet_type_filters", "variant_filters" }) do
        local values = autoDelete[listName] or {}
        if type(values) ~= "table" then
            return self:_configError(
                "egg_system",
                "ui.hatch_panel.auto_delete." .. listName,
                "expected table"
            )
        end
        for index, id in ipairs(values) do
            if type(id) ~= "string" or id == "" then
                return self:_configError(
                    "egg_system",
                    "ui.hatch_panel.auto_delete." .. listName .. "." .. tostring(index),
                    "expected non-empty string"
                )
            end
            local ref = autoDeleteFilterRefs[listName]
            if ref and ref.allowed and not ref.allowed[id] then
                return self:_configError(
                    "egg_system",
                    "ui.hatch_panel.auto_delete." .. listName .. "." .. tostring(index),
                    "must reference " .. ref.target
                )
            end
        end
    end

    local modes = config.ui.hatch_panel.modes or {}
    if type(modes) ~= "table" then
        return self:_configError("egg_system", "ui.hatch_panel.modes", "expected table")
    end
    for modeName, mode in pairs(modes) do
        if type(modeName) ~= "string" or modeName == "" then
            return self:_configError("egg_system", "ui.hatch_panel.modes", "expected string keys")
        end
        if type(mode) ~= "table" then
            return self:_configError(
                "egg_system",
                "ui.hatch_panel.modes." .. modeName,
                "expected table"
            )
        end
        for _, fieldName in ipairs({
            "label",
            "option",
            "description",
            "locked_description",
            "active_description",
            "available_description",
        }) do
            if mode[fieldName] ~= nil and type(mode[fieldName]) ~= "string" then
                return self:_configError(
                    "egg_system",
                    "ui.hatch_panel.modes." .. modeName .. "." .. fieldName,
                    "expected string"
                )
            end
        end
        if mode.default_enabled ~= nil and type(mode.default_enabled) ~= "boolean" then
            return self:_configError(
                "egg_system",
                "ui.hatch_panel.modes." .. modeName .. ".default_enabled",
                "expected boolean"
            )
        end
    end

    local help = config.ui.hatch_panel.help or {}
    if type(help) ~= "table" then
        return self:_configError("egg_system", "ui.hatch_panel.help", "expected table")
    end
    for fieldName, value in pairs(help) do
        if type(fieldName) ~= "string" or fieldName == "" then
            return self:_configError("egg_system", "ui.hatch_panel.help", "expected string keys")
        end
        if type(value) ~= "string" then
            return self:_configError(
                "egg_system",
                "ui.hatch_panel.help." .. fieldName,
                "expected string"
            )
        end
    end

    if
        type(config.spawning.spawn_point_name) ~= "string"
        or config.spawning.spawn_point_name == ""
    then
        return self:_configError(
            "egg_system",
            "spawning.spawn_point_name",
            "expected non-empty string"
        )
    end

    return true
end

function ConfigLoader:_validateStatsConfig(config)
    local ok, err = self:_requireType("stats", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    ok, err = self:_requireType("stats", config.counters, "table", "counters")
    if not ok then
        return ok, err
    end

    local allowedScopes = {
        lifetime = true,
        session = true,
        daily = true,
    }

    for counterId, counter in pairs(config.counters) do
        local path = "counters." .. tostring(counterId)
        if type(counter) ~= "table" then
            return self:_configError("stats", path, "expected table")
        end
        if type(counter.display_name) ~= "string" or counter.display_name == "" then
            return self:_configError("stats", path .. ".display_name", "expected non-empty string")
        end
        if type(counter.scope) ~= "string" or not allowedScopes[counter.scope] then
            return self:_configError(
                "stats",
                path .. ".scope",
                "must be lifetime, session, or daily"
            )
        end
        if counter.default ~= nil and type(counter.default) ~= "number" then
            return self:_configError("stats", path .. ".default", "expected number")
        end
    end

    return true
end

function ConfigLoader:_counterExists(counterId)
    local statsConfig = self:_rawConfig("stats")
    return type(statsConfig) == "table"
        and type(statsConfig.counters) == "table"
        and statsConfig.counters[counterId] ~= nil
end

function ConfigLoader:_currencyExists(currencyId)
    return hasId(self:_rawConfig("currencies"), currencyId)
end

function ConfigLoader:_validateReward(configName, reward, path)
    local ok, err = self:_requireType(configName, reward, "table", path)
    if not ok then
        return ok, err
    end

    -- BUNDLE shape ({ bundle = { currencies = {...}, pets = {...}, items = {...} } }) — routed through
    -- the reward spine (RewardService:Grant), so achievements can award PETS (capstones), not just
    -- currency. Validate the currencies map + that pets/items are tables; the spine handles the rest.
    if type(reward.bundle) == "table" then
        local b = reward.bundle
        if b.currencies ~= nil then
            ok, err =
                self:_requireType(configName, b.currencies, "table", path .. ".bundle.currencies")
            if not ok then
                return ok, err
            end
            for cur, amt in pairs(b.currencies) do
                if not self:_currencyExists(cur) then
                    return self:_configError(
                        configName,
                        path .. ".bundle.currencies." .. tostring(cur),
                        "must reference configs/currencies.lua"
                    )
                end
                ok, err = self:_requirePositiveNumber(
                    configName,
                    amt,
                    path .. ".bundle.currencies." .. tostring(cur)
                )
                if not ok then
                    return ok, err
                end
            end
        end
        if b.pets ~= nil then
            ok, err = self:_requireType(configName, b.pets, "table", path .. ".bundle.pets")
            if not ok then
                return ok, err
            end
        end
        return true
    end

    if reward.type ~= "currency" then
        return self:_configError(
            configName,
            path .. ".type",
            "must be 'currency' or provide a bundle"
        )
    end

    if type(reward.currency) ~= "string" or reward.currency == "" then
        return self:_configError(configName, path .. ".currency", "expected non-empty string")
    end
    if not self:_currencyExists(reward.currency) then
        return self:_configError(
            configName,
            path .. ".currency",
            "must reference configs/currencies.lua"
        )
    end

    return self:_requirePositiveNumber(configName, reward.amount, path .. ".amount")
end

function ConfigLoader:_validatePetIndexConfig(config)
    local ok, err = self:_requireType("pet_index", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    ok, err = self:_requireType("pet_index", config.milestones, "table", "milestones")
    if not ok then
        return ok, err
    end

    local seen = {}
    for index, milestone in ipairs(config.milestones) do
        local path = "milestones[" .. index .. "]"
        if type(milestone.id) ~= "string" or milestone.id == "" then
            return self:_configError("pet_index", path .. ".id", "expected non-empty string")
        end
        if seen[milestone.id] then
            return self:_configError("pet_index", path .. ".id", "duplicate milestone id")
        end
        seen[milestone.id] = true

        ok, err = self:_requirePositiveNumber("pet_index", milestone.goal, path .. ".goal")
        if not ok then
            return ok, err
        end
        ok, err = self:_validateReward("pet_index", milestone.reward, path .. ".reward")
        if not ok then
            return ok, err
        end
    end

    return true
end

function ConfigLoader:_validatePetProgressionConfig(config)
    local ok, err = self:_requireType("pet_progression", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    ok, err = self:_requireType("pet_progression", config.version, "string", "version")
    if not ok then
        return ok, err
    end

    if config.enabled ~= nil and type(config.enabled) ~= "boolean" then
        return self:_configError("pet_progression", "enabled", "expected boolean")
    end
    if config.unique_only ~= nil and type(config.unique_only) ~= "boolean" then
        return self:_configError("pet_progression", "unique_only", "expected boolean")
    end
    ok, err = self:_requirePositiveNumber(
        "pet_progression",
        config.default_max_level or 1,
        "default_max_level"
    )
    if not ok then
        return ok, err
    end
    if (config.default_max_level or 1) % 1 ~= 0 then
        return self:_configError(
            "pet_progression",
            "default_max_level",
            "expected positive integer"
        )
    end

    local pets = self:_rawConfig("pets")
    local rarities = pets and pets.rarities or {}
    if type(config.max_level_by_rarity) ~= "table" then
        return self:_configError("pet_progression", "max_level_by_rarity", "expected table")
    end
    for rarityId, maxLevel in pairs(config.max_level_by_rarity) do
        if not rarities[rarityId] then
            return self:_configError(
                "pet_progression",
                "max_level_by_rarity." .. tostring(rarityId),
                "must reference pets.rarities"
            )
        end
        ok, err = self:_requirePositiveNumber(
            "pet_progression",
            maxLevel,
            "max_level_by_rarity." .. tostring(rarityId)
        )
        if not ok then
            return ok, err
        end
        if maxLevel % 1 ~= 0 then
            return self:_configError(
                "pet_progression",
                "max_level_by_rarity." .. tostring(rarityId),
                "expected positive integer"
            )
        end
    end

    local curve = config.xp_curve
    if type(curve) ~= "table" then
        return self:_configError("pet_progression", "xp_curve", "expected table")
    end
    if curve.type ~= "linear" and curve.type ~= "exponential" then
        return self:_configError(
            "pet_progression",
            "xp_curve.type",
            "expected linear or exponential"
        )
    end
    ok, err = self:_requirePositiveNumber("pet_progression", curve.base, "xp_curve.base")
    if not ok then
        return ok, err
    end
    if curve.type == "exponential" then
        ok, err = self:_requirePositiveNumber("pet_progression", curve.growth, "xp_curve.growth")
        if not ok then
            return ok, err
        end
    elseif curve.increment ~= nil then
        ok, err =
            self:_requireNonNegativeNumber("pet_progression", curve.increment, "xp_curve.increment")
        if not ok then
            return ok, err
        end
    end

    local powerScaling = config.power_scaling
    if type(powerScaling) ~= "table" then
        return self:_configError("pet_progression", "power_scaling", "expected table")
    end
    -- normalized_cap (2026-06-12): bonus = max_bonus x (level-1)/(maxLevel-1); only
    -- the cap is configured. percent_per_level remains valid for the legacy form.
    if powerScaling.type ~= "percent_per_level" and powerScaling.type ~= "normalized_cap" then
        return self:_configError(
            "pet_progression",
            "power_scaling.type",
            "expected percent_per_level or normalized_cap"
        )
    end
    if powerScaling.type == "percent_per_level" then
        ok, err = self:_requireNonNegativeNumber(
            "pet_progression",
            powerScaling.percent_per_level,
            "power_scaling.percent_per_level"
        )
        if not ok then
            return ok, err
        end
    end
    ok, err = self:_requireNonNegativeNumber(
        "pet_progression",
        powerScaling.max_bonus_percent,
        "power_scaling.max_bonus_percent"
    )
    if not ok then
        return ok, err
    end

    local enchantSlots = config.enchant_slots
    if type(enchantSlots) ~= "table" then
        return self:_configError("pet_progression", "enchant_slots", "expected table")
    end
    ok, err = self:_requireNonNegativeNumber(
        "pet_progression",
        enchantSlots.default_unlocked_slots or 0,
        "enchant_slots.default_unlocked_slots"
    )
    if not ok then
        return ok, err
    end
    if (enchantSlots.default_unlocked_slots or 0) % 1 ~= 0 then
        return self:_configError(
            "pet_progression",
            "enchant_slots.default_unlocked_slots",
            "expected non-negative integer"
        )
    end
    local unlocksByRarity = enchantSlots.unlocks_by_rarity or {}
    if type(unlocksByRarity) ~= "table" then
        return self:_configError(
            "pet_progression",
            "enchant_slots.unlocks_by_rarity",
            "expected table"
        )
    end
    for rarityId, unlocks in pairs(unlocksByRarity) do
        if not rarities[rarityId] then
            return self:_configError(
                "pet_progression",
                "enchant_slots.unlocks_by_rarity." .. tostring(rarityId),
                "must reference pets.rarities"
            )
        end
        if not isArray(unlocks) then
            return self:_configError(
                "pet_progression",
                "enchant_slots.unlocks_by_rarity." .. tostring(rarityId),
                "expected array"
            )
        end
        for index, unlock in ipairs(unlocks) do
            local path = "enchant_slots.unlocks_by_rarity."
                .. tostring(rarityId)
                .. "["
                .. index
                .. "]"
            if type(unlock) ~= "table" then
                return self:_configError("pet_progression", path, "expected table")
            end
            ok, err = self:_requirePositiveNumber("pet_progression", unlock.level, path .. ".level")
            if not ok then
                return ok, err
            end
            if unlock.level % 1 ~= 0 then
                return self:_configError(
                    "pet_progression",
                    path .. ".level",
                    "expected positive integer"
                )
            end
            ok, err =
                self:_requireNonNegativeNumber("pet_progression", unlock.slots, path .. ".slots")
            if not ok then
                return ok, err
            end
            if unlock.slots % 1 ~= 0 then
                return self:_configError(
                    "pet_progression",
                    path .. ".slots",
                    "expected non-negative integer"
                )
            end
        end
    end

    return true
end

function ConfigLoader:_validatePlayerProgressionConfig(config)
    local ok, err = self:_requireType("player_progression", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    ok, err = self:_requireType("player_progression", config.version, "string", "version")
    if not ok then
        return ok, err
    end

    if config.enabled ~= nil and type(config.enabled) ~= "boolean" then
        return self:_configError("player_progression", "enabled", "expected boolean")
    end

    local teamPower = config.team_power
    if type(teamPower) ~= "table" then
        return self:_configError("player_progression", "team_power", "expected table")
    end
    if teamPower.enabled ~= nil and type(teamPower.enabled) ~= "boolean" then
        return self:_configError("player_progression", "team_power.enabled", "expected boolean")
    end
    local economy = self:_rawConfig("economy")
    local stages = economy and economy.modifier_pipeline and economy.modifier_pipeline.stages or {}
    if not stages[teamPower.stage or "boosts"] then
        return self:_configError(
            "player_progression",
            "team_power.stage",
            "must reference economy.modifier_pipeline.stages"
        )
    end
    if type(teamPower.kind) ~= "string" or teamPower.kind == "" then
        return self:_configError(
            "player_progression",
            "team_power.kind",
            "expected non-empty string"
        )
    end
    ok, err = self:_requirePositiveNumber(
        "player_progression",
        teamPower.start_level or 1,
        "team_power.start_level"
    )
    if not ok then
        return ok, err
    end
    ok, err = self:_requireNonNegativeNumber(
        "player_progression",
        teamPower.percent_per_level,
        "team_power.percent_per_level"
    )
    if not ok then
        return ok, err
    end
    ok, err = self:_requireNonNegativeNumber(
        "player_progression",
        teamPower.max_bonus_percent,
        "team_power.max_bonus_percent"
    )
    if not ok then
        return ok, err
    end

    local rewards = config.level_rewards
    if type(rewards) ~= "table" then
        return self:_configError("player_progression", "level_rewards", "expected table")
    end
    local equipSlots = rewards.equip_slots
    if type(equipSlots) ~= "table" then
        return self:_configError(
            "player_progression",
            "level_rewards.equip_slots",
            "expected table"
        )
    end
    for category, reward in pairs(equipSlots) do
        local path = "level_rewards.equip_slots." .. tostring(category)
        if type(reward) ~= "table" then
            return self:_configError("player_progression", path, "expected table")
        end
        if reward.enabled ~= nil and type(reward.enabled) ~= "boolean" then
            return self:_configError("player_progression", path .. ".enabled", "expected boolean")
        end
        ok, err = self:_requirePositiveNumber(
            "player_progression",
            reward.start_level or 1,
            path .. ".start_level"
        )
        if not ok then
            return ok, err
        end
        ok, err = self:_requirePositiveNumber(
            "player_progression",
            reward.every_levels or 1,
            path .. ".every_levels"
        )
        if not ok then
            return ok, err
        end
        ok, err = self:_requireNonNegativeNumber(
            "player_progression",
            reward.slots_per_milestone or 0,
            path .. ".slots_per_milestone"
        )
        if not ok then
            return ok, err
        end
        ok, err = self:_requireNonNegativeNumber(
            "player_progression",
            reward.max_bonus_slots or 0,
            path .. ".max_bonus_slots"
        )
        if not ok then
            return ok, err
        end
    end

    return true
end

function ConfigLoader:_validateAutoSystemsConfig(config)
    local ok, err = self:_requireType("auto_systems", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    ok, err = self:_requireType("auto_systems", config.version, "string", "version")
    if not ok then
        return ok, err
    end

    if config.enabled ~= nil and type(config.enabled) ~= "boolean" then
        return self:_configError("auto_systems", "enabled", "expected boolean")
    end

    local pets = self:_rawConfig("pets") or {}
    local currencies = {}
    local currencyConfig = self:_rawConfig("currencies") or {}
    for _, currency in ipairs(currencyConfig) do
        currencies[currency.id] = true
    end

    local autoTarget = config.auto_target
    if type(autoTarget) ~= "table" then
        return self:_configError("auto_systems", "auto_target", "expected table")
    end
    if autoTarget.enabled ~= nil and type(autoTarget.enabled) ~= "boolean" then
        return self:_configError("auto_systems", "auto_target.enabled", "expected boolean")
    end
    if autoTarget.default_enabled ~= nil and type(autoTarget.default_enabled) ~= "boolean" then
        return self:_configError("auto_systems", "auto_target.default_enabled", "expected boolean")
    end
    if
        autoTarget.current_world_only ~= nil
        and type(autoTarget.current_world_only) ~= "boolean"
    then
        return self:_configError(
            "auto_systems",
            "auto_target.current_world_only",
            "expected boolean"
        )
    end
    if
        type(autoTarget.default_selected_currency) ~= "string"
        or not currencies[autoTarget.default_selected_currency]
    then
        return self:_configError(
            "auto_systems",
            "auto_target.default_selected_currency",
            "must reference currencies"
        )
    end
    ok, err = self:_requirePositiveNumber(
        "auto_systems",
        autoTarget.request_interval_seconds or 0.3,
        "auto_target.request_interval_seconds"
    )
    if not ok then
        return ok, err
    end

    local modes = autoTarget.modes
    if type(modes) ~= "table" then
        return self:_configError("auto_systems", "auto_target.modes", "expected table")
    end
    if type(autoTarget.default_mode) ~= "string" or not modes[autoTarget.default_mode] then
        return self:_configError(
            "auto_systems",
            "auto_target.default_mode",
            "must reference auto_target.modes"
        )
    end
    local validSorts = {
        distance_asc = true,
        value_desc = true,
        hp_asc = true,
        hp_desc = true,
    }
    for modeId, modeConfig in pairs(modes) do
        local path = "auto_target.modes." .. tostring(modeId)
        if not tostring(modeId):match(STABLE_CONFIG_ID_PATTERN) then
            return self:_configError("auto_systems", path, "expected stable snake_case id")
        end
        if type(modeConfig) ~= "table" then
            return self:_configError("auto_systems", path, "expected table")
        end
        if type(modeConfig.display_name) ~= "string" or modeConfig.display_name == "" then
            return self:_configError(
                "auto_systems",
                path .. ".display_name",
                "expected non-empty string"
            )
        end
        if type(modeConfig.sort) ~= "string" or not validSorts[modeConfig.sort] then
            return self:_configError("auto_systems", path .. ".sort", "expected supported sort")
        end
        if
            modeConfig.requires_currency ~= nil
            and type(modeConfig.requires_currency) ~= "boolean"
        then
            return self:_configError(
                "auto_systems",
                path .. ".requires_currency",
                "expected boolean"
            )
        end
    end

    local toggles = autoTarget.compatibility_toggles or {}
    if type(toggles) ~= "table" then
        return self:_configError(
            "auto_systems",
            "auto_target.compatibility_toggles",
            "expected table"
        )
    end
    for _, key in ipairs({ "free_mode", "paid_mode" }) do
        if toggles[key] ~= nil and not modes[toggles[key]] then
            return self:_configError(
                "auto_systems",
                "auto_target.compatibility_toggles." .. key,
                "must reference auto_target.modes"
            )
        end
    end

    local autoDelete = config.auto_delete
    if type(autoDelete) ~= "table" then
        return self:_configError("auto_systems", "auto_delete", "expected table")
    end
    for _, key in ipairs({
        "enabled",
        "default_enabled",
        "allow_rarity_filters",
        "allow_pet_type_filters",
        "allow_variant_filters",
        "protect_unique",
    }) do
        if autoDelete[key] ~= nil and type(autoDelete[key]) ~= "boolean" then
            return self:_configError("auto_systems", "auto_delete." .. key, "expected boolean")
        end
    end

    local protectedRarities = autoDelete.protected_rarities or {}
    if type(protectedRarities) ~= "table" then
        return self:_configError("auto_systems", "auto_delete.protected_rarities", "expected table")
    end
    for rarityId, enabled in pairs(protectedRarities) do
        if not (pets.rarities and pets.rarities[rarityId]) then
            return self:_configError(
                "auto_systems",
                "auto_delete.protected_rarities." .. tostring(rarityId),
                "must reference pets.rarities"
            )
        end
        if type(enabled) ~= "boolean" then
            return self:_configError(
                "auto_systems",
                "auto_delete.protected_rarities." .. tostring(rarityId),
                "expected boolean"
            )
        end
    end

    local defaults = autoDelete.defaults or {}
    if type(defaults) ~= "table" then
        return self:_configError("auto_systems", "auto_delete.defaults", "expected table")
    end
    local defaultSets = {
        rarities = pets.rarities or {},
        pet_types = pets.pets or {},
        variants = pets.variants or {},
    }
    for setName, allowed in pairs(defaultSets) do
        local set = defaults[setName] or {}
        if type(set) ~= "table" then
            return self:_configError(
                "auto_systems",
                "auto_delete.defaults." .. setName,
                "expected table"
            )
        end
        for id, enabled in pairs(set) do
            if not allowed[id] then
                return self:_configError(
                    "auto_systems",
                    "auto_delete.defaults." .. setName .. "." .. tostring(id),
                    "must reference pets config"
                )
            end
            if enabled ~= true then
                return self:_configError(
                    "auto_systems",
                    "auto_delete.defaults." .. setName .. "." .. tostring(id),
                    "expected true"
                )
            end
        end
    end

    return true
end

function ConfigLoader:_validateEnchantStrength(config, path)
    if type(config) ~= "table" then
        return self:_configError("enchants", path, "expected table")
    end

    local ok, err = self:_requirePositiveNumber("enchants", config.low, path .. ".low")
    if not ok then
        return ok, err
    end
    ok, err = self:_requirePositiveNumber("enchants", config.high, path .. ".high")
    if not ok then
        return ok, err
    end
    ok, err = self:_requirePositiveNumber("enchants", config.scale, path .. ".scale")
    if not ok then
        return ok, err
    end

    for _, key in ipairs({ "low", "high", "scale" }) do
        if config[key] % 1 ~= 0 then
            return self:_configError("enchants", path .. "." .. key, "expected positive integer")
        end
    end
    if config.high < config.low then
        return self:_configError("enchants", path .. ".high", "must be >= low")
    end

    return true
end

function ConfigLoader:_validateEnchantsConfig(config)
    local ok, err = self:_requireType("enchants", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    ok, err = self:_requireType("enchants", config.version, "string", "version")
    if not ok then
        return ok, err
    end
    if config.enabled ~= nil and type(config.enabled) ~= "boolean" then
        return self:_configError("enchants", "enabled", "expected boolean")
    end

    local hatchRolls = config.hatch_rolls
    if type(hatchRolls) ~= "table" then
        return self:_configError("enchants", "hatch_rolls", "expected table")
    end
    if hatchRolls.enabled ~= nil and type(hatchRolls.enabled) ~= "boolean" then
        return self:_configError("enchants", "hatch_rolls.enabled", "expected boolean")
    end
    if
        hatchRolls.require_unlocked_slot ~= nil
        and type(hatchRolls.require_unlocked_slot) ~= "boolean"
    then
        return self:_configError(
            "enchants",
            "hatch_rolls.require_unlocked_slot",
            "expected boolean"
        )
    end

    local reroll = config.reroll
    if type(reroll) ~= "table" then
        return self:_configError("enchants", "reroll", "expected table")
    end
    if reroll.enabled ~= nil and type(reroll.enabled) ~= "boolean" then
        return self:_configError("enchants", "reroll.enabled", "expected boolean")
    end
    if reroll.requires_station ~= nil and type(reroll.requires_station) ~= "boolean" then
        return self:_configError("enchants", "reroll.requires_station", "expected boolean")
    end
    ok, err = self:_requireNonNegativeNumber(
        "enchants",
        reroll.station_grace_seconds or 0,
        "reroll.station_grace_seconds"
    )
    if not ok then
        return ok, err
    end
    ok, err =
        self:_requirePositiveNumber("enchants", reroll.default_slot or 1, "reroll.default_slot")
    if not ok then
        return ok, err
    end
    if (reroll.default_slot or 1) % 1 ~= 0 then
        return self:_configError("enchants", "reroll.default_slot", "expected positive integer")
    end
    if type(reroll.cost) ~= "table" then
        return self:_configError("enchants", "reroll.cost", "expected table")
    end
    if not self:_currencyExists(reroll.cost.currency) then
        return self:_configError("enchants", "reroll.cost.currency", "must reference currencies")
    end
    ok, err = self:_requireNonNegativeNumber("enchants", reroll.cost.amount, "reroll.cost.amount")
    if not ok then
        return ok, err
    end

    local stations = config.stations or {}
    if type(stations) ~= "table" then
        return self:_configError("enchants", "stations", "expected table")
    end
    for stationId, station in pairs(stations) do
        local path = "stations." .. tostring(stationId)
        if not isStableConfigId(stationId) then
            return self:_configError("enchants", path, "id must match " .. STABLE_CONFIG_ID_PATTERN)
        end
        if type(station) ~= "table" then
            return self:_configError("enchants", path, "expected table")
        end
        if
            station.display_name ~= nil
            and (type(station.display_name) ~= "string" or station.display_name == "")
        then
            return self:_configError(
                "enchants",
                path .. ".display_name",
                "expected non-empty string"
            )
        end
        if
            station.touch_part_name ~= nil
            and (type(station.touch_part_name) ~= "string" or station.touch_part_name == "")
        then
            return self:_configError(
                "enchants",
                path .. ".touch_part_name",
                "expected non-empty string"
            )
        end

        local prompt = station.prompt or {}
        if type(prompt) ~= "table" then
            return self:_configError("enchants", path .. ".prompt", "expected table")
        end
        if prompt.enabled ~= nil and type(prompt.enabled) ~= "boolean" then
            return self:_configError("enchants", path .. ".prompt.enabled", "expected boolean")
        end
        for _, fieldName in ipairs({ "action_text", "object_text", "key" }) do
            if
                prompt[fieldName] ~= nil
                and (type(prompt[fieldName]) ~= "string" or prompt[fieldName] == "")
            then
                return self:_configError(
                    "enchants",
                    path .. ".prompt." .. fieldName,
                    "expected non-empty string"
                )
            end
        end
        ok, err = self:_requireNonNegativeNumber(
            "enchants",
            prompt.max_distance or 0,
            path .. ".prompt.max_distance"
        )
        if not ok then
            return ok, err
        end
        ok, err = self:_requireNonNegativeNumber(
            "enchants",
            prompt.hold_duration or 0,
            path .. ".prompt.hold_duration"
        )
        if not ok then
            return ok, err
        end

        local animation = station.animation or {}
        if type(animation) ~= "table" then
            return self:_configError("enchants", path .. ".animation", "expected table")
        end
        if animation.enabled ~= nil and type(animation.enabled) ~= "boolean" then
            return self:_configError("enchants", path .. ".animation.enabled", "expected boolean")
        end
        if animation.active_when_near ~= nil and type(animation.active_when_near) ~= "boolean" then
            return self:_configError(
                "enchants",
                path .. ".animation.active_when_near",
                "expected boolean"
            )
        end
        if
            animation.script_name ~= nil
            and (type(animation.script_name) ~= "string" or animation.script_name == "")
        then
            return self:_configError(
                "enchants",
                path .. ".animation.script_name",
                "expected non-empty string"
            )
        end
        local lightning = animation.lightning or {}
        if type(lightning) ~= "table" then
            return self:_configError("enchants", path .. ".animation.lightning", "expected table")
        end
        if lightning.enabled ~= nil and type(lightning.enabled) ~= "boolean" then
            return self:_configError(
                "enchants",
                path .. ".animation.lightning.enabled",
                "expected boolean"
            )
        end
        if lightning.core_enabled ~= nil and type(lightning.core_enabled) ~= "boolean" then
            return self:_configError(
                "enchants",
                path .. ".animation.lightning.core_enabled",
                "expected boolean"
            )
        end
        for _, fieldName in ipairs({
            "center_part_name",
            "origin_part_name",
            "sound_name",
            "sound_id",
        }) do
            if
                lightning[fieldName] ~= nil
                and (type(lightning[fieldName]) ~= "string" or lightning[fieldName] == "")
            then
                return self:_configError(
                    "enchants",
                    path .. ".animation.lightning." .. fieldName,
                    "expected non-empty string"
                )
            end
        end
        for _, fieldName in ipairs({ "origin_part_paths", "origin_part_names" }) do
            local values = lightning[fieldName]
            if values ~= nil and not isArray(values) then
                return self:_configError(
                    "enchants",
                    path .. ".animation.lightning." .. fieldName,
                    "expected array"
                )
            end
            if values ~= nil then
                for index, value in ipairs(values) do
                    if type(value) ~= "string" or value == "" then
                        return self:_configError(
                            "enchants",
                            path .. ".animation.lightning." .. fieldName .. "[" .. index .. "]",
                            "expected non-empty string"
                        )
                    end
                end
            end
        end
        for _, fieldName in ipairs({
            "origin_limit",
            "strands_per_origin",
            "segments",
            "jitter",
            "max_radius",
            "thickness",
            "min_thickness_multiplier",
            "max_thickness_multiplier",
            "frequency",
            "animation_speed",
            "curve_size0",
            "curve_size1",
            "core_thickness_multiplier",
            "core_opacity_multiplier",
            "fade_out_seconds",
            "duration",
            "result_delay_seconds",
            "volume",
            "playback_speed",
            "roll_off_max_distance",
            "sound_lifetime_seconds",
        }) do
            if lightning[fieldName] ~= nil then
                ok, err = self:_requirePositiveNumber(
                    "enchants",
                    lightning[fieldName],
                    path .. ".animation.lightning." .. fieldName
                )
                if not ok then
                    return ok, err
                end
            end
        end
        for _, fieldName in ipairs({ "min_radius", "flicker", "neon_lift" }) do
            if lightning[fieldName] ~= nil then
                ok, err = self:_requireNonNegativeNumber(
                    "enchants",
                    lightning[fieldName],
                    path .. ".animation.lightning." .. fieldName
                )
                if not ok then
                    return ok, err
                end
            end
        end
        for _, fieldName in ipairs({ "flicker", "neon_lift" }) do
            if lightning[fieldName] ~= nil and lightning[fieldName] > 1 then
                return self:_configError(
                    "enchants",
                    path .. ".animation.lightning." .. fieldName,
                    "expected number from 0 to 1"
                )
            end
        end
        if
            lightning.core_enabled == false
            and (
                lightning.core_thickness_multiplier ~= nil
                or lightning.core_opacity_multiplier ~= nil
            )
        then
            return self:_configError(
                "enchants",
                path .. ".animation.lightning.core_enabled",
                "core tuning fields require core_enabled"
            )
        end
        for _, fieldName in ipairs({ "center_offset", "target_offset" }) do
            if lightning[fieldName] ~= nil and typeof(lightning[fieldName]) ~= "Vector3" then
                return self:_configError(
                    "enchants",
                    path .. ".animation.lightning." .. fieldName,
                    "expected Vector3"
                )
            end
        end
        if lightning.colors ~= nil then
            if not isArray(lightning.colors) then
                return self:_configError(
                    "enchants",
                    path .. ".animation.lightning.colors",
                    "expected array"
                )
            end
            for index, color in ipairs(lightning.colors) do
                if typeof(color) ~= "Color3" then
                    return self:_configError(
                        "enchants",
                        path .. ".animation.lightning.colors[" .. index .. "]",
                        "expected Color3"
                    )
                end
            end
        end
        local displayPet = lightning.display_pet or {}
        if type(displayPet) ~= "table" then
            return self:_configError(
                "enchants",
                path .. ".animation.lightning.display_pet",
                "expected table"
            )
        end
        if displayPet.enabled ~= nil and type(displayPet.enabled) ~= "boolean" then
            return self:_configError(
                "enchants",
                path .. ".animation.lightning.display_pet.enabled",
                "expected boolean"
            )
        end
        if displayPet.offset ~= nil and typeof(displayPet.offset) ~= "Vector3" then
            return self:_configError(
                "enchants",
                path .. ".animation.lightning.display_pet.offset",
                "expected Vector3"
            )
        end
        if displayPet.yaw_degrees ~= nil then
            ok, err = self:_requireNonNegativeNumber(
                "enchants",
                displayPet.yaw_degrees,
                path .. ".animation.lightning.display_pet.yaw_degrees"
            )
            if not ok then
                return ok, err
            end
        end
        for _, fieldName in ipairs({ "scale", "huge_scale", "lifetime_seconds" }) do
            if displayPet[fieldName] ~= nil then
                ok, err = self:_requirePositiveNumber(
                    "enchants",
                    displayPet[fieldName],
                    path .. ".animation.lightning.display_pet." .. fieldName
                )
                if not ok then
                    return ok, err
                end
            end
        end
    end

    local effects = config.effects
    if type(effects) ~= "table" then
        return self:_configError("enchants", "effects", "expected table")
    end

    local economy = self:_rawConfig("economy")
    local stages = economy and economy.modifier_pipeline and economy.modifier_pipeline.stages or {}
    local allowedCombine = {
        add = true,
        multiply = true,
        override = true,
        cap = true,
    }
    for effectId, effect in pairs(effects) do
        local path = "effects." .. tostring(effectId)
        if not isStableConfigId(effectId) then
            return self:_configError("enchants", path, "id must match " .. STABLE_CONFIG_ID_PATTERN)
        end
        if type(effect) ~= "table" then
            return self:_configError("enchants", path, "expected table")
        end
        if type(effect.display_name) ~= "string" or effect.display_name == "" then
            return self:_configError(
                "enchants",
                path .. ".display_name",
                "expected non-empty string"
            )
        end
        local modifier = effect.modifier
        if type(modifier) ~= "table" then
            return self:_configError("enchants", path .. ".modifier", "expected table")
        end
        if not stages[modifier.stage] then
            return self:_configError(
                "enchants",
                path .. ".modifier.stage",
                "must reference economy.modifier_pipeline.stages"
            )
        end
        if type(modifier.kind) ~= "string" or modifier.kind == "" then
            return self:_configError(
                "enchants",
                path .. ".modifier.kind",
                "expected non-empty string"
            )
        end
        if modifier.currency ~= nil and not self:_currencyExists(modifier.currency) then
            return self:_configError(
                "enchants",
                path .. ".modifier.currency",
                "must reference currencies"
            )
        end
        if type(modifier.combine) ~= "string" or not allowedCombine[modifier.combine] then
            return self:_configError(
                "enchants",
                path .. ".modifier.combine",
                "must be add, multiply, override, or cap"
            )
        end
        ok, err = self:_requireNonNegativeNumber(
            "enchants",
            modifier.amount_per_strength,
            path .. ".modifier.amount_per_strength"
        )
        if not ok then
            return ok, err
        end
        -- strength roll now lives on the effect ({low,high,scale}, rarity-independent +5 cap).
        ok, err = self:_validateEnchantStrength(effect.roll, path .. ".roll")
        if not ok then
            return ok, err
        end
    end

    local pets = self:_rawConfig("pets")
    local rarities = pets and pets.rarities or {}
    local rarityProfiles = config.rarity_profiles
    if type(rarityProfiles) ~= "table" then
        return self:_configError("enchants", "rarity_profiles", "expected table")
    end
    for rarityId, profileId in pairs(rarityProfiles) do
        if not rarities[rarityId] then
            return self:_configError(
                "enchants",
                "rarity_profiles." .. tostring(rarityId),
                "must reference pets.rarities"
            )
        end
        if type(profileId) ~= "string" then
            return self:_configError(
                "enchants",
                "rarity_profiles." .. tostring(rarityId),
                "expected string"
            )
        end
    end

    local profiles = config.roll_profiles
    if type(profiles) ~= "table" then
        return self:_configError("enchants", "roll_profiles", "expected table")
    end
    for profileId, profile in pairs(profiles) do
        local profilePath = "roll_profiles." .. tostring(profileId)
        if not isStableConfigId(profileId) then
            return self:_configError(
                "enchants",
                profilePath,
                "id must match " .. STABLE_CONFIG_ID_PATTERN
            )
        end
        if type(profile) ~= "table" then
            return self:_configError("enchants", profilePath, "expected table")
        end
        ok, err = self:_requireNonNegativeNumber(
            "enchants",
            profile.min_rolls,
            profilePath .. ".min_rolls"
        )
        if not ok then
            return ok, err
        end
        ok, err = self:_requireNonNegativeNumber(
            "enchants",
            profile.max_rolls,
            profilePath .. ".max_rolls"
        )
        if not ok then
            return ok, err
        end
        if profile.min_rolls % 1 ~= 0 or profile.max_rolls % 1 ~= 0 then
            return self:_configError("enchants", profilePath, "roll counts must be integers")
        end
        if profile.max_rolls < profile.min_rolls then
            return self:_configError(
                "enchants",
                profilePath .. ".max_rolls",
                "must be >= min_rolls"
            )
        end
        ok, err = self:_requireNonNegativeNumber(
            "enchants",
            profile.initial_roll_chance,
            profilePath .. ".initial_roll_chance"
        )
        if not ok then
            return ok, err
        end
        if profile.initial_roll_chance > 1 then
            return self:_configError(
                "enchants",
                profilePath .. ".initial_roll_chance",
                "must be between 0 and 1"
            )
        end
        if
            profile.prevent_duplicate_effects ~= nil
            and type(profile.prevent_duplicate_effects) ~= "boolean"
        then
            return self:_configError(
                "enchants",
                profilePath .. ".prevent_duplicate_effects",
                "expected boolean"
            )
        end
        if not isArray(profile.chances) then
            return self:_configError("enchants", profilePath .. ".chances", "expected array")
        end
        for index, chance in ipairs(profile.chances) do
            local path = profilePath .. ".chances[" .. index .. "]"
            if type(chance) ~= "table" then
                return self:_configError("enchants", path, "expected table")
            end
            if type(chance.effect) ~= "string" or not effects[chance.effect] then
                return self:_configError("enchants", path .. ".effect", "must reference effects")
            end
            ok, err = self:_requirePositiveNumber("enchants", chance.weight, path .. ".weight")
            if not ok then
                return ok, err
            end
            -- strength now lives on the EFFECT (effects[id].roll), not per chances entry — only
            -- validate a legacy per-entry strength if one is still present.
            if chance.strength ~= nil then
                ok, err = self:_validateEnchantStrength(chance.strength, path .. ".strength")
                if not ok then
                    return ok, err
                end
            end
        end
    end

    for rarityId, profileId in pairs(rarityProfiles) do
        if not profiles[profileId] then
            return self:_configError(
                "enchants",
                "rarity_profiles." .. tostring(rarityId),
                "must reference roll_profiles"
            )
        end
    end

    return true
end

function ConfigLoader:_validateAchievementsConfig(config)
    local ok, err = self:_requireType("achievements", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    ok, err = self:_requireType("achievements", config.achievements, "table", "achievements")
    if not ok then
        return ok, err
    end

    for achievementKey, achievement in pairs(config.achievements) do
        local path = "achievements." .. tostring(achievementKey)
        if type(achievement.id) ~= "string" or achievement.id == "" then
            return self:_configError("achievements", path .. ".id", "expected non-empty string")
        end
        if type(achievement.stat) ~= "string" or achievement.stat == "" then
            return self:_configError("achievements", path .. ".stat", "expected non-empty string")
        end
        if not self:_counterExists(achievement.stat) then
            return self:_configError(
                "achievements",
                path .. ".stat",
                "must reference configs/stats.lua counters"
            )
        end

        ok, err = self:_requireType("achievements", achievement.tiers, "table", path .. ".tiers")
        if not ok then
            return ok, err
        end

        local seenTiers = {}
        local previousGoal = 0
        for tierIndex, tier in ipairs(achievement.tiers) do
            local tierPath = path .. ".tiers[" .. tierIndex .. "]"
            if type(tier.id) ~= "string" or tier.id == "" then
                return self:_configError(
                    "achievements",
                    tierPath .. ".id",
                    "expected non-empty string"
                )
            end
            if seenTiers[tier.id] then
                return self:_configError("achievements", tierPath .. ".id", "duplicate tier id")
            end
            seenTiers[tier.id] = true

            ok, err = self:_requirePositiveNumber("achievements", tier.goal, tierPath .. ".goal")
            if not ok then
                return ok, err
            end
            if tier.goal <= previousGoal then
                return self:_configError(
                    "achievements",
                    tierPath .. ".goal",
                    "must increase by tier"
                )
            end
            previousGoal = tier.goal

            ok, err = self:_validateReward("achievements", tier.reward, tierPath .. ".reward")
            if not ok then
                return ok, err
            end
        end
    end

    return true
end

function ConfigLoader:_validateLeaderboardsConfig(config)
    local ok, err = self:_requireType("leaderboards", config, "table", "<root>")
    if not ok then
        return ok, err
    end

    ok, err = self:_requireType("leaderboards", config.boards, "table", "boards")
    if not ok then
        return ok, err
    end

    local seen = {}
    for index, board in ipairs(config.boards) do
        local path = "boards[" .. index .. "]"
        if type(board.id) ~= "string" or board.id == "" then
            return self:_configError("leaderboards", path .. ".id", "expected non-empty string")
        end
        if seen[board.id] then
            return self:_configError("leaderboards", path .. ".id", "duplicate board id")
        end
        seen[board.id] = true

        if type(board.stat) ~= "string" or board.stat == "" then
            return self:_configError("leaderboards", path .. ".stat", "expected non-empty string")
        end
        if not self:_counterExists(board.stat) then
            return self:_configError(
                "leaderboards",
                path .. ".stat",
                "must reference configs/stats.lua counters"
            )
        end

        if board.sort ~= "asc" and board.sort ~= "desc" then
            return self:_configError("leaderboards", path .. ".sort", "must be asc or desc")
        end

        ok, err =
            self:_requirePositiveNumber("leaderboards", board.max_entries, path .. ".max_entries")
        if not ok then
            return ok, err
        end

        if board.global ~= nil then
            ok, err = self:_requireType("leaderboards", board.global, "table", path .. ".global")
            if not ok then
                return ok, err
            end
            if type(board.global.enabled) ~= "boolean" then
                return self:_configError(
                    "leaderboards",
                    path .. ".global.enabled",
                    "expected boolean"
                )
            end
            if board.global.enabled then
                if
                    type(board.global.ordered_store) ~= "string"
                    or board.global.ordered_store == ""
                then
                    return self:_configError(
                        "leaderboards",
                        path .. ".global.ordered_store",
                        "expected non-empty string"
                    )
                end
                ok, err = self:_requirePositiveNumber(
                    "leaderboards",
                    board.global.refresh_seconds,
                    path .. ".global.refresh_seconds"
                )
                if not ok then
                    return ok, err
                end
            end
        end
    end

    return true
end

function ConfigLoader:_validateUIConfig(config)
    if not config or type(config) ~= "table" then
        return false, "UI config must be a table"
    end

    -- Check required sections
    local requiredSections =
        { "themes", "active_theme", "fonts", "spacing", "radius", "animations", "helpers" }
    for _, section in ipairs(requiredSections) do
        if not config[section] then
            return false, "Missing required section: " .. section
        end
    end

    -- Validate themes
    if not config.themes or type(config.themes) ~= "table" then
        return false, "Themes must be a table"
    end

    if not config.themes.dark or not config.themes.light then
        return false, "Dark and light themes are required"
    end

    -- Validate active theme exists
    if not config.themes[config.active_theme] then
        return false, "Active theme '" .. tostring(config.active_theme) .. "' not found in themes"
    end

    return true
end

function ConfigLoader:_validateContextMenusConfig(config)
    if not config or type(config) ~= "table" then
        return false, "Context menus config must be a table"
    end

    -- Check required sections
    if not config.global then
        return false, "Missing required section: global"
    end

    if not config.item_types then
        return false, "Missing required section: item_types"
    end

    if not config.fallback then
        return false, "Missing required section: fallback"
    end

    -- Validate item_types structure
    if type(config.item_types) ~= "table" then
        return false, "item_types must be a table"
    end

    -- Check that each item type has actions
    for itemType, typeConfig in pairs(config.item_types) do
        if not typeConfig.actions or type(typeConfig.actions) ~= "table" then
            return false, "Item type '" .. itemType .. "' must have actions table"
        end

        -- Validate each action
        for i, action in ipairs(typeConfig.actions) do
            if not action.action or not action.text or not action.color then
                return false,
                    "Action "
                        .. i
                        .. " in item type '"
                        .. itemType
                        .. "' missing required fields (action, text, color)"
            end
        end
    end

    return true
end

function ConfigLoader:ReloadConfig(configName)
    -- Clear specific config cache
    if configName == "monetization" then
        self:ClearMonetizationCache()
    end
    configsValidated = false

    if self._configCaches then
        self._configCaches[configName] = nil
    end

    if self._modules and self._modules.Logger then
        self._modules.Logger:Info("Config reloaded", { config = configName })
    end

    return self:LoadConfig(configName)
end

function ConfigLoader:_deepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = self:_deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function ConfigLoader:_getConfigCount()
    local count = 0
    for _ in pairs(configs) do
        count = count + 1
    end
    return count
end

-- Environment-specific config loading
function ConfigLoader:GetEnvironment()
    if RunService:IsStudio() then
        return "development"
    else
        return "production"
    end
end

function ConfigLoader:IsProduction()
    return self:GetEnvironment() == "production"
end

function ConfigLoader:IsDevelopment()
    return self:GetEnvironment() == "development"
end

function ConfigLoader:_validateInventoryConfig(config)
    if not config then
        return false, "Inventory config is nil"
    end

    -- Check required top-level fields
    local requiredFields = { "version", "enabled_buckets", "buckets", "settings" }
    for _, field in ipairs(requiredFields) do
        if not config[field] then
            return false, "Missing required field: " .. field
        end
    end

    -- Validate version
    if type(config.version) ~= "string" then
        return false, "Version must be a string"
    end

    -- Validate enabled_buckets
    if type(config.enabled_buckets) ~= "table" then
        return false, "enabled_buckets must be a table"
    end

    -- Validate buckets
    if type(config.buckets) ~= "table" then
        return false, "buckets must be a table"
    end

    -- Check that each enabled bucket has a corresponding bucket definition
    for bucketName, enabled in pairs(config.enabled_buckets) do
        if enabled and not config.buckets[bucketName] then
            return false, "Enabled bucket '" .. bucketName .. "' has no bucket definition"
        end

        if enabled then
            local bucket = config.buckets[bucketName]

            -- Validate required bucket fields (support mixed storage type)
            local requiredBaseFields = { "display_name", "icon", "base_limit", "storage_type" }
            for _, field in ipairs(requiredBaseFields) do
                if not bucket[field] then
                    return false, "Bucket '" .. bucketName .. "' missing required field: " .. field
                end
            end

            -- Per-storage-type validation
            if bucket.storage_type == "unique" or bucket.storage_type == "stackable" then
                if not bucket.stack_size then
                    return false, "Bucket '" .. bucketName .. "' missing required field: stack_size"
                end
                if type(bucket.item_schema) ~= "table" then
                    return false, "Bucket '" .. bucketName .. "' item_schema must be a table"
                end
                if
                    not bucket.item_schema.required
                    or type(bucket.item_schema.required) ~= "table"
                then
                    return false,
                        "Bucket '" .. bucketName .. "' item_schema must have 'required' array"
                end
                if
                    not bucket.item_schema.optional
                    or type(bucket.item_schema.optional) ~= "table"
                then
                    return false,
                        "Bucket '" .. bucketName .. "' item_schema must have 'optional' array"
                end
            elseif bucket.storage_type == "mixed" then
                if type(bucket.schema) ~= "table" then
                    return false,
                        "Bucket '"
                            .. bucketName
                            .. "' missing or invalid 'schema' for mixed storage"
                end
                if
                    type(bucket.schema.stacks) ~= "table"
                    or type(bucket.schema.special) ~= "table"
                then
                    return false,
                        "Bucket '"
                            .. bucketName
                            .. "' schema must contain 'stacks' and 'special' tables"
                end
                if bucket.stack_key_fields and type(bucket.stack_key_fields) ~= "table" then
                    return false,
                        "Bucket '"
                            .. bucketName
                            .. "' stack_key_fields must be an array when provided"
                end
            else
                return false,
                    "Bucket '"
                        .. bucketName
                        .. "' storage_type must be 'unique', 'stackable', or 'mixed'"
            end

            -- Validate bucket field types
            if type(bucket.display_name) ~= "string" then
                return false, "Bucket '" .. bucketName .. "' display_name must be a string"
            end

            if type(bucket.base_limit) ~= "number" or bucket.base_limit <= 0 then
                return false, "Bucket '" .. bucketName .. "' base_limit must be a positive number"
            end
            -- Additional checks handled per storage type above
        end
    end

    -- Validate equipped configuration
    if config.equipped then
        if type(config.equipped) ~= "table" then
            return false, "equipped must be a table"
        end

        for equipCategory, equipConfig in pairs(config.equipped) do
            if type(equipConfig) ~= "table" then
                return false, "Equipped category '" .. equipCategory .. "' must be a table"
            end

            if not equipConfig.slots then
                return false, "Equipped category '" .. equipCategory .. "' missing slots field"
            end

            if not equipConfig.display_name or type(equipConfig.display_name) ~= "string" then
                return false,
                    "Equipped category '" .. equipCategory .. "' missing or invalid display_name"
            end
        end
    end

    -- Validate settings
    if type(config.settings) ~= "table" then
        return false, "settings must be a table"
    end

    if self._modules and self._modules.Logger then
        self._modules.Logger:Info("Inventory config validated", { context = "ConfigLoader" })
    end
    return true
end

return ConfigLoader
