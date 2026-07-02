--[[
    Locations - Single Source of Truth for Game Architecture
    
    This module provides centralized access to all game services, folders, and assets.
    Prevents path errors and makes refactoring easier by having all locations in one place.
    
    Usage:
    local Locations = require(ReplicatedStorage.Shared.Locations)
    local economyService = Locations.getService("EconomyService")
    local monetizationBridge = Locations.getBridge("Monetization")
]]

local Locations = {}

-- === CORE ROBLOX SERVICES ===
Locations.ReplicatedStorage = game:GetService("ReplicatedStorage")
Locations.ServerScriptService = game:GetService("ServerScriptService")
Locations.ServerStorage = game:GetService("ServerStorage")
Locations.Players = game:GetService("Players")
Locations.Workspace = game:GetService("Workspace")
Locations.RunService = game:GetService("RunService")
Locations.TweenService = game:GetService("TweenService")
Locations.UserInputService = game:GetService("UserInputService")
Locations.MarketplaceService = game:GetService("MarketplaceService")
Locations.MessagingService = game:GetService("MessagingService")

-- === PROJECT STRUCTURE ===
-- Root folders
Locations.Packages = Locations.ReplicatedStorage:WaitForChild("Packages", 5)
Locations.Shared = Locations.ReplicatedStorage:WaitForChild("Shared", 5)

-- Server folders (only on server)
if Locations.RunService:IsServer() then
    Locations.Server = Locations.ServerScriptService:WaitForChild("Server", 5)
    if Locations.Server then
        Locations.ServerServices = Locations.Server:WaitForChild("Services")
        Locations.ServerSystems = Locations.Server:WaitForChild("Systems")
        Locations.ServerMiddleware = Locations.Server:WaitForChild("Middleware")
    end
end

-- Shared folders (available on both client and server)
if Locations.Shared then
    Locations.SharedLibraries = Locations.Shared:WaitForChild("Libraries")
    Locations.SharedUtils = Locations.Shared:WaitForChild("Utils")
    Locations.SharedConstants = Locations.Shared:WaitForChild("Constants")
    Locations.SharedNetwork = Locations.Shared:WaitForChild("Network")
    Locations.SharedState = Locations.Shared:WaitForChild("State")
    -- Matter is managed by Wally - access via Packages.Matter instead of Shared.Matter
    Locations.SharedServices = Locations.Shared:WaitForChild("Services")
end

-- Client-specific folders (UI and Controllers)
if Locations.RunService:IsClient() then
    local starterPlayer = game:GetService("StarterPlayer")
    local clientFolder =
        starterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client", 5)

    if clientFolder then
        Locations.ClientUI = clientFolder:WaitForChild("UI")
        if Locations.ClientUI then
            Locations.ClientUIComponents = Locations.ClientUI:WaitForChild("Components")
            Locations.ClientUIScreens = Locations.ClientUI:WaitForChild("Screens")
            Locations.ClientUIMenus = Locations.ClientUI:WaitForChild("Menus")
        end
        Locations.ClientControllers = clientFolder:WaitForChild("Controllers")
        Locations.ClientSystems = clientFolder:WaitForChild("Systems")
        Locations.ClientEffects = clientFolder:WaitForChild("Effects")
    end
end

-- === CONFIGURATION FILES ===
Locations.Configs = game:GetService("ReplicatedStorage"):WaitForChild("Configs", 5)
Locations.ConfigFiles = {
    Game = "game",
    Currencies = "currencies",
    Items = "items",
    Monetization = "monetization",
    Network = "network",
    Effects = "effects",
    ui = "ui",
    pets = "pets",
    inventory = "inventory",
    egg_system = "egg_system",
    auto_systems = "auto_systems",
    logging = "logging",
}

-- === CORE MODULES ===
if Locations.SharedUtils then
    Locations.ModuleLoader = Locations.SharedUtils:WaitForChild("ModuleLoader")
    -- NetworkConfig removed - using Signals instead
    Locations.Logger = Locations.SharedUtils:WaitForChild("Logger")
    Locations.ProductIdMapper = Locations.SharedUtils:WaitForChild("ProductIdMapper")
end

if Locations.Shared then
    Locations.ConfigLoader = Locations.Shared:WaitForChild("ConfigLoader")
end

if Locations.SharedNetwork then
    -- NetworkBridge deprecated; use Signals instead
end

if Locations.SharedServices then
    Locations.TemplateManager = Locations.SharedServices:WaitForChild("TemplateManager")
end

-- === MANUAL LIBRARIES (Small utilities + Matter workaround) ===
Locations.Libraries = {}
if Locations.SharedLibraries then
    Locations.Libraries = {
        Maid = Locations.SharedLibraries:WaitForChild("Maid"),
        Signal = Locations.SharedLibraries:WaitForChild("Signal"),
        Sift = Locations.SharedLibraries:WaitForChild("Sift"),
        Matter = Locations.SharedLibraries:WaitForChild("Matter"), -- Manual copy due to Wally/Rojo issues
    }
end

-- === PACKAGES (Wally-managed) ===
Locations.PackageFiles = {
    TestEZ = "TestEZ",
    Promise = "Promise",
    Matter = "Matter",
    Reflex = "Reflex",
    ProfileStore = "ProfileStore",
}

-- === SERVICES (Server-side) ===
Locations.Services = {
    DataService = "DataService",
    EconomyService = "EconomyService",
    MonetizationService = "MonetizationService",
    PlayerEffectsService = "PlayerEffectsService",
    GlobalEffectsService = "GlobalEffectsService",
    RateLimitService = "RateLimitService",
    ServerClockService = "ServerClockService",
    InventoryService = "InventoryService",
    EggService = "EggService",
    EggSpawner = "EggSpawner",
}

-- === NETWORK BRIDGES ===
Locations.Bridges = {
    Economy = "Economy",
    Monetization = "Monetization",
    Combat = "Combat",
    PlayerData = "PlayerData",
}

-- === HELPER FUNCTIONS ===

-- Get a service through ModuleLoader (server-side only)
function Locations.getService(serviceName)
    if not Locations.Services[serviceName] then
        warn("Unknown service:", serviceName)
        return nil
    end

    if not Locations.ModuleLoader then
        warn("ModuleLoader not available")
        return nil
    end

    local success, moduleLoader = pcall(function()
        return require(Locations.ModuleLoader)
    end)

    if success then
        return moduleLoader:Get(serviceName)
    else
        warn("ModuleLoader not available for service:", serviceName)
        return nil
    end
end

-- Get a network bridge (deprecated, now maps to sleitnick/Net Signals)
function Locations.getBridge(bridgeName)
    local Signals = require(game:GetService("ReplicatedStorage").Shared.Network.Signals)
    return Signals[bridgeName]
end

-- Get config loader
function Locations.getConfigLoader()
    if not Locations.ConfigLoader then
        warn("ConfigLoader not available")
        return nil
    end

    local success, configLoader = pcall(function()
        return require(Locations.ConfigLoader)
    end)

    if success then
        return configLoader
    else
        warn("ConfigLoader not available")
        return nil
    end
end

-- Load a configuration file
function Locations.getConfig(configName)
    -- Look up the actual config file name
    local configFileName = Locations.ConfigFiles[configName]

    local configLoader = Locations.getConfigLoader()
    if configLoader then
        return configLoader:LoadConfig(configFileName)
    end
    return nil
end

-- Get a Wally package
function Locations.getPackage(packageName)
    if not Locations.PackageFiles[packageName] then
        warn("Unknown package:", packageName)
        return nil
    end

    if not Locations.Packages then
        warn("Packages folder not available")
        return nil
    end

    local packageModule = Locations.Packages:FindFirstChild(Locations.PackageFiles[packageName])
    if not packageModule then
        warn("Package not found:", packageName)
        return nil
    end

    local success, package = pcall(function()
        return require(packageModule)
    end)

    if success then
        return package
    else
        warn("Failed to load package:", packageName, package)
        return nil
    end
end

-- Get a manual library
function Locations.getLibrary(libraryName)
    if not Locations.Libraries[libraryName] then
        warn("Unknown library:", libraryName)
        return nil
    end

    local success, library = pcall(function()
        return require(Locations.Libraries[libraryName])
    end)

    if success then
        return library
    else
        warn("Failed to load library:", libraryName)
        return nil
    end
end

-- === PLAYER-SPECIFIC FUNCTIONS ===

-- Get PlayerGui for a player
function Locations.getPlayerGui(player)
    return player:WaitForChild("PlayerGui", 5)
end

-- Get a player's character
function Locations.getPlayerCharacter(player)
    return player.Character or player.CharacterAdded:Wait()
end

-- Get a player's humanoid
function Locations.getPlayerHumanoid(player)
    local character = Locations.getPlayerCharacter(player)
    return character and character:WaitForChild("Humanoid", 5)
end

-- === WORKSPACE LOCATIONS ===
Locations.WorkspaceFolders = {
    -- Add workspace folders as needed
    -- Example: Effects = workspace:WaitForChild("Effects")
}

-- === VALIDATION ===

-- Validate that all critical locations are available
function Locations.validateCriticalPaths()
    local critical = {
        "ReplicatedStorage",
        "ServerScriptService",
        "Shared",
        "ModuleLoader",
        "ConfigLoader",
        -- "NetworkBridge" removed - using Signals instead
    }

    local missing = {}

    for _, path in ipairs(critical) do
        if not Locations[path] then
            table.insert(missing, path)
        end
    end

    if #missing > 0 then
        error("Critical paths missing: " .. table.concat(missing, ", "))
    end

    return true
end

-- === RUNTIME CHECKS ===
function Locations.isServer()
    return game:GetService("RunService"):IsServer()
end

function Locations.isClient()
    return game:GetService("RunService"):IsClient()
end

function Locations.isStudio()
    return game:GetService("RunService"):IsStudio()
end

-- Auto-validate on require
if not pcall(Locations.validateCriticalPaths) then
    warn("Some critical paths are missing - check game structure")
end

return Locations
