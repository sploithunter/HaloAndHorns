--[[
    Server Bootstrap - Initializes the server-side game systems
    
    This file:
    1. Sets up the module loader with dependencies
    2. Loads all services in the correct order
    3. Initializes Matter ECS world and systems
    4. Starts the game loop based on configuration
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Stacked realms live FAR below the homeworld (Hell_1 at Y -2000, deeper layers lower). Roblox's
-- default FallenPartsDestroyHeight (-500) sits ABOVE them, so a character/pet arriving in Hell is
-- instantly destroyed as a "fallen part" (HumanoidRootPart vanishes -> frozen). The AUTHORITATIVE
-- value is baked into the place (Workspace $properties in default.project.json). Writing it from a
-- Script can be capability-blocked in some run contexts (throws "lacking capability Plugin"), so
-- this best-effort runtime set is pcall-guarded — it must NEVER halt boot (an uncaught error here
-- aborts remote creation and breaks the whole client/server handshake).
pcall(function()
    Workspace.FallenPartsDestroyHeight = -50000
end)

-- Wait for packages to be available
local Packages = ReplicatedStorage:WaitForChild("Packages", 10)
if not Packages then
    error("Packages not found - make sure 'wally install' has been run")
end

-- Core dependencies
local Locations = require(ReplicatedStorage.Shared.Locations)
local Matter = Locations.getLibrary("Matter") -- Matter ECS framework (manual due to Wally/Rojo sync issues)
local Reflex = Locations.getPackage("Reflex") -- Redux-like state management (via Wally)
local ModuleLoader = require(Locations.SharedUtils.ModuleLoader)

-- Console noise reduction: defer logging until Logger is initialized

-- Create module loader
local loader = ModuleLoader.new()

local function loadBootFeatureFlags()
    local configsFolder = ReplicatedStorage:FindFirstChild("Configs")
    local gameConfigModule = configsFolder and configsFolder:FindFirstChild("game")
    if not gameConfigModule or not gameConfigModule:IsA("ModuleScript") then
        return {}
    end

    local ok, gameConfig = pcall(require, gameConfigModule)
    if not ok or type(gameConfig) ~= "table" or type(gameConfig.features) ~= "table" then
        return {}
    end

    return gameConfig.features
end

local bootFeatures = loadBootFeatureFlags()

local function isFeatureEnabled(featureName, defaultValue)
    local value = bootFeatures[featureName]
    if value == nil then
        return defaultValue ~= false
    end
    return value == true
end

local function appendIfEnabled(dependencies, featureName, moduleName, defaultValue)
    if isFeatureEnabled(featureName, defaultValue) then
        table.insert(dependencies, moduleName)
    end
    return dependencies
end

local function registerFeatureModule(
    featureName,
    moduleName,
    moduleScript,
    dependencies,
    defaultValue
)
    if isFeatureEnabled(featureName, defaultValue) then
        loader:RegisterModule(moduleName, moduleScript, dependencies)
    end
end

-- Register core utilities (loaded first)
loader:RegisterModule("Logger", ReplicatedStorage.Shared.Utils.Logger)
loader:RegisterModule("ConfigLoader", ReplicatedStorage.Shared.ConfigLoader, { "Logger" })
loader:RegisterModule(
    "ServerClockService",
    ServerScriptService.Server.Services.ServerClockService,
    { "Logger" }
)
-- Event-driven boot: validates the configs/boot.lua milestone graph, mirrors readiness to
-- ReplicatedStorage.BootStatus, and logs each milestone. Registered early so its observer is
-- attached (and the mirror exists) before any producer signals. See docs/BOOT_ORCHESTRATION.md.
loader:RegisterModule(
    "BootOrchestrator",
    ServerScriptService.Server.Services.BootOrchestrator,
    { "Logger", "ConfigLoader" }
)
-- NetworkConfig removed - using Signals instead

-- Register server services
loader:RegisterModule(
    "DataService",
    ServerScriptService.Server.Services.DataService,
    { "Logger", "ConfigLoader" }
)
registerFeatureModule(
    "stats",
    "StatsService",
    ServerScriptService.Server.Services.StatsService,
    { "Logger", "ConfigLoader", "DataService" }
)
registerFeatureModule(
    "stats",
    "StatEventCounters",
    ServerScriptService.Server.Services.StatEventCounters,
    { "Logger", "ConfigLoader", "StatsService" }
)
registerFeatureModule(
    "modifiers",
    "ModifierService",
    ServerScriptService.Server.Services.ModifierService,
    { "Logger", "ConfigLoader" }
)
registerFeatureModule(
    "upgrades",
    "UpgradeService",
    ServerScriptService.Server.Services.UpgradeService,
    appendIfEnabled({ "Logger", "ConfigLoader", "DataService" }, "modifiers", "ModifierService")
)
registerFeatureModule(
    "player_progression",
    "PlayerProgressionService",
    ServerScriptService.Server.Services.PlayerProgressionService,
    appendIfEnabled({ "Logger", "ConfigLoader", "DataService" }, "modifiers", "ModifierService")
)
loader:RegisterModule(
    "AdminService",
    ServerScriptService.Server.Services.AdminService,
    { "Logger", "ConfigLoader" }
)
loader:RegisterModule(
    "RateLimitService",
    ServerScriptService.Server.Services.RateLimitService,
    { "Logger", "ConfigLoader", "DataService", "ServerClockService" }
)
loader:RegisterModule(
    "AssetPreloadService",
    ServerScriptService.Server.Services.AssetPreloadService,
    { "Logger", "ConfigLoader" }
)
registerFeatureModule(
    "map_binding",
    "WorldBindingService",
    ServerScriptService.Server.Services.WorldBindingService,
    { "Logger", "ConfigLoader" }
)
registerFeatureModule(
    "map_binding",
    "ZoneService",
    ServerScriptService.Server.Services.ZoneService,
    { "Logger", "ConfigLoader", "DataService", "WorldBindingService" }
)
registerFeatureModule(
    "global_events",
    "EventService",
    ServerScriptService.Server.Services.EventService,
    appendIfEnabled(
        { "Logger", "ConfigLoader", "ServerClockService" },
        "modifiers",
        "ModifierService"
    )
)
loader:RegisterModule(
    "BreakableSpawner",
    ServerScriptService.Server.Services.BreakableSpawner,
    appendIfEnabled(
        appendIfEnabled(
            appendIfEnabled({ "Logger", "ConfigLoader" }, "global_events", "EventService"),
            "pet_progression",
            "PetProgressionService"
        ),
        "map_binding",
        "WorldBindingService"
    )
)
loader:RegisterModule(
    "BreakableService",
    ServerScriptService.Server.Services.BreakableService,
    { "Logger", "ConfigLoader" }
)
-- DropService (#167): physical coin pickups + Magnet collection. EconomyService resolved at runtime.
loader:RegisterModule(
    "DropService",
    ServerScriptService.Server.Services.DropService,
    -- DataService: the enhancement-drop origin gate reads data.Archetype. The
    -- loader only injects DECLARED deps into self._modules, so without this here
    -- self._dataService stayed nil and every drop was forced natural (Jason).
    { "Logger", "ConfigLoader", "DataService" }
)
-- SummonService (#178): capstone guardian summons (Gaia's Colossus / Genie of the Dunes).
loader:RegisterModule(
    "SummonService",
    ServerScriptService.Server.Services.SummonService,
    { "Logger", "ConfigLoader" }
)
loader:RegisterModule(
    "PlayerEffectsService",
    ServerScriptService.Server.Services.PlayerEffectsService,
    { "Logger", "ConfigLoader", "DataService", "ServerClockService" }
)
loader:RegisterModule(
    "GlobalEffectsService",
    ServerScriptService.Server.Services.GlobalEffectsService,
    { "Logger", "ConfigLoader", "DataService", "ServerClockService" }
)
loader:RegisterModule(
    "ProductIdMapper",
    ReplicatedStorage.Shared.Utils.ProductIdMapper,
    { "Logger", "ConfigLoader" }
)
loader:RegisterModule(
    "EconomyService",
    ServerScriptService.Server.Services.EconomyService,
    appendIfEnabled(
        appendIfEnabled({
            "Logger",
            "DataService",
            "ConfigLoader",
            "PlayerEffectsService",
            "GlobalEffectsService",
            "AdminService",
            "InventoryService",
        }, "stats", "StatsService"),
        "modifiers",
        "ModifierService"
    )
)
registerFeatureModule(
    "pet_index",
    "PetIndexService",
    ServerScriptService.Server.Services.PetIndexService,
    appendIfEnabled(
        { "Logger", "ConfigLoader", "DataService", "EconomyService" },
        "stats",
        "StatsService"
    )
)
registerFeatureModule(
    "achievements",
    "AchievementsService",
    ServerScriptService.Server.Services.AchievementsService,
    appendIfEnabled(
        { "Logger", "ConfigLoader", "DataService", "EconomyService" },
        "stats",
        "StatsService"
    )
)
registerFeatureModule(
    "leaderboards",
    "LeaderboardService",
    ServerScriptService.Server.Services.LeaderboardService,
    appendIfEnabled({ "Logger", "ConfigLoader", "DataService" }, "stats", "StatsService")
)
loader:RegisterModule(
    "MonetizationService",
    ServerScriptService.Server.Services.MonetizationService,
    { "Logger", "DataService", "EconomyService", "ProductIdMapper", "PlayerEffectsService" }
)
loader:RegisterModule(
    "InventoryService",
    ServerScriptService.Server.Services.InventoryService,
    appendIfEnabled(
        appendIfEnabled({ "Logger", "DataService", "ConfigLoader" }, "upgrades", "UpgradeService"),
        "player_progression",
        "PlayerProgressionService"
    )
)
registerFeatureModule(
    "pet_progression",
    "PetProgressionService",
    ServerScriptService.Server.Services.PetProgressionService,
    appendIfEnabled(
        { "Logger", "ConfigLoader", "DataService", "InventoryService" },
        "modifiers",
        "ModifierService"
    )
)
registerFeatureModule(
    "enchants",
    "EnchantService",
    ServerScriptService.Server.Services.EnchantService,
    appendIfEnabled(
        appendIfEnabled(
            { "Logger", "ConfigLoader", "DataService", "InventoryService" },
            "modifiers",
            "ModifierService"
        ),
        "map_binding",
        "WorldBindingService"
    )
)
loader:RegisterModule(
    "PetSerialService",
    ServerScriptService.Server.Services.PetSerialService,
    { "Logger", "ConfigLoader" }
)
loader:RegisterModule(
    "PetGrantService",
    ServerScriptService.Server.Services.PetGrantService,
    appendIfEnabled(
        appendIfEnabled(
            { "Logger", "ConfigLoader", "DataService", "InventoryService", "PetSerialService" },
            "enchants",
            "EnchantService"
        ),
        "pet_progression",
        "PetProgressionService"
    )
)
loader:RegisterModule(
    "SettingsService",
    ServerScriptService.Server.Services.SettingsService,
    { "Logger", "DataService", "ConfigLoader" }
)
loader:RegisterModule(
    "HatchEntitlementService",
    ServerScriptService.Server.Services.HatchEntitlementService,
    { "Logger", "ConfigLoader" }
)
loader:RegisterModule(
    "DiagnosticsService",
    ServerScriptService.Server.Services.DiagnosticsService,
    { "Logger", "InventoryService", "EconomyService", "RateLimitService", "DataService" }
)
registerFeatureModule(
    "admin_tools",
    "AdminToolsService",
    ServerScriptService.Server.Services.AdminToolsService,
    appendIfEnabled(
        appendIfEnabled({
            "Logger",
            "AdminService",
            "DataService",
            "InventoryService",
            "ConfigLoader",
            "PetGrantService",
            "HatchEntitlementService",
        }, "global_events", "EventService"),
        "map_binding",
        "ZoneService"
    )
)
-- AlignmentService: Halo & Horns Soul stat (Feature 2). Pure SoulMath core over
-- profile state; reads biomes/soul configs.
loader:RegisterModule(
    "AlignmentService",
    ServerScriptService.Server.Services.AlignmentService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- LayerService: Halo & Horns layer access (Feature 3). Server-authoritative
-- Soul/token-gated ascend/descend; sets profile.CurrentLayer.
loader:RegisterModule(
    "LayerService",
    ServerScriptService.Server.Services.LayerService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- Phase 3 party core (Halo & Horns): active squad, spirit form, stack pool.
loader:RegisterModule(
    "ActiveSquadService",
    ServerScriptService.Server.Services.ActiveSquadService,
    { "Logger", "ConfigLoader", "DataService", "InventoryService" }
)
loader:RegisterModule(
    "SpiritFormService",
    ServerScriptService.Server.Services.SpiritFormService,
    { "Logger", "ConfigLoader", "DataService", "InventoryService", "ActiveSquadService" }
)
loader:RegisterModule(
    "StackPoolService",
    ServerScriptService.Server.Services.StackPoolService,
    { "Logger", "ConfigLoader" }
)
-- ArchetypeService: Halo & Horns archetype selection + respec (Feature 13).
loader:RegisterModule(
    "ArchetypeService",
    ServerScriptService.Server.Services.ArchetypeService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- PowerService: Halo & Horns power selection at level-up (Feature 14). Resolves
-- PlayerProgressionService at runtime for the player's level.
loader:RegisterModule(
    "PowerService",
    ServerScriptService.Server.Services.PowerService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- AugmentationService: Halo & Horns augmentation slots (Feature 15).
loader:RegisterModule(
    "AugmentationService",
    ServerScriptService.Server.Services.AugmentationService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- EnhancementService: CoH-style enhancements (inventory + slotting into power slots).
loader:RegisterModule(
    "EnhancementService",
    ServerScriptService.Server.Services.EnhancementService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- EnhancementShopService: buy/sell enhancements for gems (configs/enhancements.lua shop).
loader:RegisterModule(
    "EnhancementShopService",
    ServerScriptService.Server.Services.EnhancementShopService,
    { "Logger", "ConfigLoader", "DataService", "InventoryService", "EnhancementService" }
)
-- PotionService: "brew charge" potions (drink->sip->drain) feeding BuffStack axis attributes.
loader:RegisterModule(
    "PotionService",
    ServerScriptService.Server.Services.PotionService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- TutorialService: event-driven new-player tutorial (taps the GameEvents bus; configs/tutorial).
loader:RegisterModule(
    "TutorialService",
    ServerScriptService.Server.Services.TutorialService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- HotbarService: Halo & Horns hotbar / command bar (Feature 16).
loader:RegisterModule(
    "HotbarService",
    ServerScriptService.Server.Services.HotbarService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- RosterService: Halo & Horns named rosters + injury-rule deploy (Feature 17).
-- Resolves SpiritFormService at runtime for pet readiness.
loader:RegisterModule(
    "RosterService",
    ServerScriptService.Server.Services.RosterService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- PartyService: Halo & Horns group play (Feature 18) — membership + group math.
loader:RegisterModule(
    "PartyService",
    ServerScriptService.Server.Services.PartyService,
    { "Logger", "ConfigLoader" }
)
-- TradeService: Halo & Horns trading (Feature 19) — session offers, both-confirm
-- gate, atomic swap, and the trade-history audit log.
loader:RegisterModule(
    "TradeService",
    ServerScriptService.Server.Services.TradeService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- FusionService: Halo & Horns Chaotic fusion (Feature 20) — Light + Shadow -> Chaotic.
loader:RegisterModule(
    "FusionService",
    ServerScriptService.Server.Services.FusionService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- Reward spine (Phase 7): RewardService grants bundles; Quest/Daily/Shop gate them.
loader:RegisterModule(
    "RewardService",
    ServerScriptService.Server.Services.RewardService,
    { "Logger", "ConfigLoader", "DataService" }
)
loader:RegisterModule(
    "QuestService",
    ServerScriptService.Server.Services.QuestService,
    { "Logger", "ConfigLoader", "DataService" }
)
loader:RegisterModule(
    "DailyService",
    ServerScriptService.Server.Services.DailyService,
    { "Logger", "ConfigLoader", "DataService" }
)
loader:RegisterModule(
    "ShopService",
    ServerScriptService.Server.Services.ShopService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- FocusService: Halo & Horns player Focus pool + invulnerability (Feature 12).
loader:RegisterModule(
    "FocusService",
    ServerScriptService.Server.Services.FocusService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- CombatService: Halo & Horns combat resolution (Feature 10). Resolves
-- FocusService/SpiritFormService at runtime via the locator (no boot dep), so it
-- only needs config + data to boot.
loader:RegisterModule(
    "CombatService",
    ServerScriptService.Server.Services.CombatService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- PetFollowService: service-owned pet follow/work loop (issue #4). Inert unless
-- configs/pet_follow.lua service_owned=true; resolves CombatService at runtime.
loader:RegisterModule(
    "PetFollowService",
    ServerScriptService.Server.Services.PetFollowService,
    { "Logger", "ConfigLoader" }
)
-- AscensionAltarService: the "trainer" station — places the Ascension Altar (tagged part +
-- ProximityPrompt) the player visits to claim TRAINING level-ups. Resolves
-- PlayerProgressionService at runtime via the locator.
loader:RegisterModule(
    "AscensionAltarService",
    ServerScriptService.Server.Services.AscensionAltarService,
    { "Logger", "ConfigLoader" }
)
-- DailyRewardZoneService: the in-world Daily Reward pad — auto-claims the daily streak
-- when a player walks into the authored "Daily Reward" model (no prompt/menu), paying the
-- player's ORIGIN biome coin and floating an ~8s reward description. Resolves
-- DailyService/RewardService at runtime via the locator.
loader:RegisterModule(
    "DailyRewardZoneService",
    ServerScriptService.Server.Services.DailyRewardZoneService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- BaddieSpawnerService: proximity enemy waves at map-authored BaddieSpawner* parts
-- (combat taste before the Heaven/Hell choice — Jason). Resolves EnemyService at runtime.
loader:RegisterModule(
    "BaddieSpawnerService",
    ServerScriptService.Server.Services.BaddieSpawnerService,
    { "Logger", "ConfigLoader" }
)
-- MeetCreatorService: first-time-in-a-server-with-a-creator -> their egg, once ever
-- (configs/creators.lua). Resolves Data/Inventory/PetGrant services at runtime.
loader:RegisterModule(
    "MeetCreatorService",
    ServerScriptService.Server.Services.MeetCreatorService,
    { "Logger", "ConfigLoader" }
)
-- RealmPortalService: binds named workspace portals (Portal_Halo1/Portal_Horn1) to a
-- ProximityPrompt that toggles the player into a heaven/hell realm via LayerService (World S3
-- test entry; resolves LayerService at runtime via the locator).
loader:RegisterModule(
    "RealmPortalService",
    ServerScriptService.Server.Services.RealmPortalService,
    { "Logger", "ConfigLoader" }
)
-- EnemyService: spawns live combat enemies pets attack like breakables (Feature 10,
-- slice 1a). Resolves CombatService at runtime via the locator for loot awards.
loader:RegisterModule(
    "EnemyService",
    ServerScriptService.Server.Services.EnemyService,
    { "Logger", "ConfigLoader" }
)
-- ZoneTrackerService: config-bounds "which area am I in" → CurrentArea SSOT attribute.
-- Drives area-scoped farming (AutoTargetService) and future area music / zone activation.
loader:RegisterModule(
    "ZoneTrackerService",
    ServerScriptService.Server.Services.ZoneTrackerService,
    { "Logger", "ConfigLoader" }
)
-- GameAPIService: the unified command-bus boundary (see
-- docs/wiki/AUTOMATION_API_DESIGN.md). Handlers resolve target services from the
-- _G.RBXTemplateServices locator at runtime, so it only needs Logger to boot.
loader:RegisterModule(
    "GameAPIService",
    ServerScriptService.Server.Services.GameAPIService,
    { "Logger" }
)
if RunService:IsStudio() then
    -- AutomationService: Studio-only test driver. Depends on GameAPIService so it
    -- can register its automation.* commands onto the bus at Start time.
    loader:RegisterModule(
        "AutomationService",
        ServerScriptService.Server.Services.AutomationService,
        { "Logger", "DataService", "GameAPIService" }
    )

    local studioSmokeDeps = {
        "Logger",
        "ConfigLoader",
        "DataService",
        "InventoryService",
        "EconomyService",
        "BreakableSpawner",
    }
    appendIfEnabled(studioSmokeDeps, "modifiers", "ModifierService")
    appendIfEnabled(studioSmokeDeps, "stats", "StatsService")
    appendIfEnabled(studioSmokeDeps, "upgrades", "UpgradeService")
    appendIfEnabled(studioSmokeDeps, "player_progression", "PlayerProgressionService")
    appendIfEnabled(studioSmokeDeps, "map_binding", "WorldBindingService")
    appendIfEnabled(studioSmokeDeps, "map_binding", "ZoneService")
    appendIfEnabled(studioSmokeDeps, "pet_index", "PetIndexService")
    appendIfEnabled(studioSmokeDeps, "achievements", "AchievementsService")
    appendIfEnabled(studioSmokeDeps, "leaderboards", "LeaderboardService")
    appendIfEnabled(studioSmokeDeps, "pet_progression", "PetProgressionService")
    appendIfEnabled(studioSmokeDeps, "enchants", "EnchantService")
    appendIfEnabled(studioSmokeDeps, "auto_target", "AutoTargetService")
    table.insert(studioSmokeDeps, "PetGrantService")

    loader:RegisterModule(
        "StudioSmokeTestService",
        ServerScriptService.Server.Services.StudioSmokeTestService,
        studioSmokeDeps
    )
end
registerFeatureModule(
    "auto_target",
    "AutoTargetService",
    ServerScriptService.Server.Services.AutoTargetService,
    {
        "Logger",
        "ConfigLoader",
        "DataService",
        "BreakableService",
        "MonetizationService",
        "ProductIdMapper",
    }
)

-- Register lazy services (loaded when needed)
-- loader:RegisterLazyModule("TradeService", ServerScriptService.Server.Services.TradeService, {"EconomyService", "DataService", "NetworkBridge"}) -- TODO: Create TradeService
-- loader:RegisterLazyModule("CombatService", ServerScriptService.Server.Services.CombatService, {"DataService", "NetworkBridge", "ConfigLoader"}) -- TODO: Create CombatService
-- loader:RegisterLazyModule("MatchmakingService", ServerScriptService.Server.Services.MatchmakingService, {"DataService", "NetworkBridge"}) -- TODO: Create MatchmakingService

-- Load all modules with error handling
-- Loading will be reported via Logger after initialization
local loadSuccess, loadOrderOrError = pcall(function()
    return loader:LoadAll()
end)

if not loadSuccess then
    error("CRITICAL STARTUP FAILURE: Module loading failed - " .. tostring(loadOrderOrError))
end

local loadOrder = loadOrderOrError

-- Heap-leak tracer: crawls the live service graph each interval and prints which Lua tables GREW.
-- It did its job (proved there's NO Lua leak — the instance bloat was the culprit), so it's now
-- OFF by default — it's very chatty. To re-arm for a future leak hunt, set `_G.HeapTrace = true`
-- in the server command bar BEFORE boot (or flip this gate). Filter Output on "[HeapTrace]".
if RunService:IsStudio() and _G.HeapTrace == true then
    local okHeap, HeapTrace = pcall(function()
        return require(ServerScriptService.Server.Diagnostics.HeapTrace)
    end)
    if okHeap and HeapTrace then
        HeapTrace.start({
            interval = 15,
            roots = { _G = _G, services = loader:GetLoadedModules() },
        })
    elseif not okHeap then
        warn("[HeapTrace] failed to load: " .. tostring(HeapTrace))
    end
end

-- Start services that need to be started
-- Service startup logs will be handled via Logger
local AssetPreloadService = loader:Get("AssetPreloadService")
if AssetPreloadService then
    -- noisy confirmation removed
else
    -- noisy warning removed (Logger will report if issues occur)
end

-- Validate critical modules loaded
local requiredModules = {
    "Logger",
    "ConfigLoader",
    "ServerClockService",
    "DataService",
    "PlayerEffectsService",
    "GlobalEffectsService",
    "EconomyService",
    "ProductIdMapper",
    "MonetizationService",
    "InventoryService",
    "PetSerialService",
    "PetGrantService",
    "SettingsService",
    "HatchEntitlementService",
    "DiagnosticsService",
}
appendIfEnabled(requiredModules, "stats", "StatsService")
appendIfEnabled(requiredModules, "modifiers", "ModifierService")
appendIfEnabled(requiredModules, "upgrades", "UpgradeService")
appendIfEnabled(requiredModules, "player_progression", "PlayerProgressionService")
appendIfEnabled(requiredModules, "map_binding", "WorldBindingService")
appendIfEnabled(requiredModules, "map_binding", "ZoneService")
appendIfEnabled(requiredModules, "global_events", "EventService")
appendIfEnabled(requiredModules, "admin_tools", "AdminToolsService")
appendIfEnabled(requiredModules, "auto_target", "AutoTargetService")
appendIfEnabled(requiredModules, "pet_index", "PetIndexService")
appendIfEnabled(requiredModules, "achievements", "AchievementsService")
appendIfEnabled(requiredModules, "leaderboards", "LeaderboardService")
appendIfEnabled(requiredModules, "pet_progression", "PetProgressionService")
appendIfEnabled(requiredModules, "enchants", "EnchantService")
table.insert(requiredModules, "AlignmentService")
table.insert(requiredModules, "LayerService")
table.insert(requiredModules, "ActiveSquadService")
table.insert(requiredModules, "SpiritFormService")
table.insert(requiredModules, "StackPoolService")
table.insert(requiredModules, "ArchetypeService")
table.insert(requiredModules, "PowerService")
table.insert(requiredModules, "AugmentationService")
table.insert(requiredModules, "EnhancementService")
table.insert(requiredModules, "EnhancementShopService")
table.insert(requiredModules, "PotionService")
table.insert(requiredModules, "TutorialService")
table.insert(requiredModules, "HotbarService")
table.insert(requiredModules, "RosterService")
table.insert(requiredModules, "PartyService")
table.insert(requiredModules, "TradeService")
table.insert(requiredModules, "FusionService")
table.insert(requiredModules, "RewardService")
table.insert(requiredModules, "QuestService")
table.insert(requiredModules, "DailyService")
table.insert(requiredModules, "ShopService")
table.insert(requiredModules, "FocusService")
table.insert(requiredModules, "CombatService")
table.insert(requiredModules, "PetFollowService")
table.insert(requiredModules, "DropService")
table.insert(requiredModules, "SummonService")
table.insert(requiredModules, "AscensionAltarService")
table.insert(requiredModules, "DailyRewardZoneService")
table.insert(requiredModules, "RealmPortalService")
table.insert(requiredModules, "ZoneTrackerService")
table.insert(requiredModules, "GameAPIService")
if RunService:IsStudio() then
    table.insert(requiredModules, "StudioSmokeTestService")
    table.insert(requiredModules, "AutomationService")
end
for _, moduleName in ipairs(requiredModules) do
    local module = loader:Get(moduleName)
    if not module then
        error("CRITICAL: Required module failed to load: " .. moduleName)
    end
end

-- Validation complete

-- Get loaded modules for easy access
local Logger = loader:Get("Logger")
local ConfigLoader = loader:Get("ConfigLoader")
local Players = game:GetService("Players")
-- NetworkConfig removed - using Signals instead
local DataService = loader:Get("DataService")
local PlayerEffectsService = loader:Get("PlayerEffectsService")
local MonetizationService = loader:Get("MonetizationService")
local InventoryService = loader:Get("InventoryService")

_G.RBXTemplateServices = {
    Get = function(_, moduleName)
        return loader:Get(moduleName)
    end,
}

-- Set up cross-references to avoid circular dependencies
DataService:SetPlayerEffectsService(PlayerEffectsService)

-- Legacy network handler connection removed - using Signals directly

-- Load game configuration
local gameConfig = ConfigLoader:LoadConfig("game")
Logger:Info("Game configuration loaded", {
    gameMode = gameConfig.GameMode,
    maxPlayers = gameConfig.MaxPlayers,
    enableTrading = gameConfig.EnableTrading,
    enablePvP = gameConfig.EnablePvP,
})

-- Validate monetization setup
local monetizationStatus = ConfigLoader:GetMonetizationStatus()
Logger:Info("Monetization status", monetizationStatus)

if #monetizationStatus.validation.errors > 0 then
    Logger:Error("MONETIZATION SETUP ERRORS:", { errors = monetizationStatus.validation.errors })
    error("Fix monetization configuration errors before starting")
end

if #monetizationStatus.validation.warnings > 0 then
    Logger:Warn(
        "MONETIZATION SETUP WARNINGS:",
        { warnings = monetizationStatus.validation.warnings }
    )
end

if monetizationStatus.validation.hasPlaceholders then
    Logger:Warn(
        "⚠️  MONETIZATION: Replace placeholder IDs with actual Roblox product/pass IDs from Creator Dashboard"
    )
end

-- Initialize Matter ECS World
local world = Matter.World.new()
local loop = Matter.Loop.new(world)

Logger:Info("Matter ECS world created")

-- TODO: Register Matter systems based on game mode
-- This would load different systems for FPS vs Simulator vs Tower Defense
local systems = {}

-- Add core systems that work for all game modes
-- systems.MovementSystem = require(ServerScriptService.Server.Systems.MovementSystem)
-- systems.PhysicsSystem = require(ServerScriptService.Server.Systems.PhysicsSystem)

-- Add game-mode specific systems
if gameConfig.GameMode == "Simulator" then
    Logger:Info("Loading Simulator systems")
    -- systems.CollectionSystem = require(...)
    -- systems.PetSystem = require(...)
elseif gameConfig.GameMode == "FPS" then
    Logger:Info("Loading FPS systems")
    -- systems.WeaponSystem = require(...)
    -- systems.DamageSystem = require(...)
elseif gameConfig.GameMode == "TowerDefense" then
    Logger:Info("Loading Tower Defense systems")
    -- systems.WaveSystem = require(...)
    -- systems.TowerSystem = require(...)
end

local ENABLE_LEGACY_GOLDEN_BEAR_CLEANUP = false

-- === Boot-time cleanup: remove legacy golden bear remnants ===
local function cleanupLegacyGoldenBear(player)
    local DataService = loader:Get("DataService")
    local profile = DataService and DataService:GetProfile(player)
    if not profile then
        return
    end
    local data = profile.Data
    if not data then
        return
    end
    local changed = false

    -- Delete persisted node Inventory/pets/items["equip_bear:golden"]
    local inv = data.Inventory and data.Inventory.pets
    if inv and inv.items and inv.items["equip_bear:golden"] then
        inv.items["equip_bear:golden"] = nil
        changed = true
    end

    -- Clear any Equipped slot that references golden bear (legacy or stack instance)
    local eq = data.Equipped and data.Equipped.pets
    if eq then
        for slotName, uid in pairs(eq) do
            if type(uid) == "string" then
                if
                    uid == "bear:golden"
                    or uid:match("^stack|bear:golden")
                    or uid == "equip_bear:golden"
                then
                    eq[slotName] = nil
                    changed = true
                end
            end
        end
    end

    if changed then
        Logger:Info("🧹 Cleanup: Removed legacy golden bear data", { player = player.Name })
        if
            InventoryService
            and InventoryService._updateBucketFolders
            and InventoryService._updateEquippedFolders
        then
            InventoryService:_updateBucketFolders(player, "pets")
            InventoryService:_updateEquippedFolders(player, "pets")
        end
    end
end

if ENABLE_LEGACY_GOLDEN_BEAR_CLEANUP then
    -- Run cleanup for players once their data is loaded
    Players.PlayerAdded:Connect(function(player)
        -- DataService sets attribute DataLoaded when profile is ready
        player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
            local ready = player:GetAttribute("DataLoaded")
            if ready then
                cleanupLegacyGoldenBear(player)
            end
        end)
        -- If already loaded (e.g., re-run), perform cleanup
        if player:GetAttribute("DataLoaded") then
            cleanupLegacyGoldenBear(player)
        end
    end)
end

-- Start Matter loop with systems
local systemsList = {}
for name, system in pairs(systems) do
    table.insert(systemsList, system)
    Logger:Debug("Registered system", { system = name })
end

-- Start the ECS loop (temporarily disabled for debugging)
-- loop:begin({
--     default = systemsList,
--     -- Add Matter debugger in Studio (disabled due to dependency issues)
--     -- debugger = game:GetService("RunService"):IsStudio() and Matter.Debugger.new() or nil
-- })

Logger:Info("Matter ECS loop started", { systemCount = #systemsList })

-- Initialize EggSpawner system
task.spawn(function()
    -- Small delay to ensure all dependencies are ready
    task.wait(1)

    Logger:Info("Starting EggSpawner initialization...")

    local success, eggSpawnerOrError = pcall(function()
        local Locations = require(ReplicatedStorage.Shared.Locations)
        return require(ReplicatedStorage.Shared.Services.EggSpawner)
    end)

    if success then
        Logger:Info("EggSpawner service loaded successfully")
        local EggSpawner = eggSpawnerOrError
        local initSuccess, initError = pcall(function()
            EggSpawner:Initialize()
        end)

        if initSuccess then
            Logger:Info("EggSpawner initialized successfully")
        else
            Logger:Error("Failed to initialize EggSpawner", { error = tostring(initError) })
        end
    else
        Logger:Error("Failed to load EggSpawner service", { error = tostring(eggSpawnerOrError) })
    end
end)

-- UserDisplayPreferences is now handled by SettingsService via ModuleLoader

-- Initialize EggService (following working game pattern)
task.spawn(function()
    task.wait(0.1) -- Small delay after UserDisplayPreferences

    Logger:Info("Starting EggService initialization...")

    local success, eggServiceOrError = pcall(function()
        local Locations = require(ReplicatedStorage.Shared.Locations)
        return require(script.Services.EggService)
    end)

    if success then
        Logger:Info("EggService loaded successfully")
        local EggService = eggServiceOrError
        local initSuccess, initError = pcall(function()
            EggService:Initialize(loader) -- Pass loader so EggService can access other services
        end)

        if initSuccess then
            Logger:Info("EggService initialized successfully")
        else
            Logger:Error("Failed to initialize EggService", { error = tostring(initError) })
        end
    else
        Logger:Error("Failed to load EggService", { error = tostring(eggServiceOrError) })
    end
end)

-- Player management
Players.PlayerAdded:Connect(function(player)
    Logger:Info("Player joined", {
        player = player.Name,
        userId = player.UserId,
        accountAge = player.AccountAge,
    })

    -- Player will be handled by DataService automatically
    -- DataService:LoadProfile(player) is called automatically
end)

Players.PlayerRemoving:Connect(function(player)
    Logger:Info("Player leaving", {
        player = player.Name,
        userId = player.UserId,
    })

    -- Cleanup handled by DataService automatically
end)

-- Set up global error handling (ScriptContext deprecated, using LogService instead)
local LogService = game:GetService("LogService")
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageError then
        -- Skip Studio plugin errors, and asset-access/load noise (Logger.isSuppressedConsoleError):
        -- those already print natively with a clickable "Click to share access" link — mirroring
        -- them as structured Logger lines strips the link and buries the originals.
        if
            not string.find(message, "plugin")
            and not string.find(message, "Plugin")
            and not Logger.isSuppressedConsoleError(message)
        then
            Logger:Error("Server script error", {
                message = message,
                messageType = messageType.Name,
            })
        end
    end
end)

-- Performance monitoring (configurable)
task.spawn(function()
    local loggingConfig = nil
    -- Safely attempt to load logging config from ReplicatedStorage.Configs.logging
    local ok, result = pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Configs = ReplicatedStorage:WaitForChild("Configs", 5)
        if Configs and Configs:FindFirstChild("logging") then
            return require(Configs.logging)
        end
        return nil
    end)
    if ok then
        loggingConfig = result
    end

    local perfCfg = (
        loggingConfig
        and loggingConfig.performance_monitor
        and loggingConfig.performance_monitor.server
    )
        or {
            enabled = true,
            interval_seconds = 30,
            target_frame_time_seconds = 1 / 60,
            warn_frame_time_seconds = 1 / 30,
            error_frame_time_seconds = 0.0667,
        }

    if not perfCfg.enabled then
        return
    end

    while true do
        task.wait(perfCfg.interval_seconds or 30)

        local heartbeatTime = game:GetService("RunService").Heartbeat:Wait()
        local stats = {
            playerCount = #Players:GetPlayers(),
            memoryUsage = game:GetService("Stats"):GetTotalMemoryUsageMb(),
            heartbeatTime = heartbeatTime,
        }

        Logger:Debug("Server performance", stats)

        local target = perfCfg.target_frame_time_seconds or (1 / 60)
        local warnAt = perfCfg.warn_frame_time_seconds or (1 / 30)
        local errorAt = perfCfg.error_frame_time_seconds or 0.0667

        if heartbeatTime > errorAt then
            Logger:Error("Server performance severely degraded", {
                frameTime = heartbeatTime,
                targetFrameTime = target,
                threshold = errorAt,
            })
        elseif heartbeatTime > warnAt then
            Logger:Warn("Server performance degraded", {
                frameTime = heartbeatTime,
                targetFrameTime = target,
                threshold = warnAt,
            })
        end
    end
end)

-- Graceful shutdown handling
game:BindToClose(function()
    Logger:Info("Server shutting down...")

    -- Give services time to clean up
    task.wait(1)

    -- Stop Matter loop
    loop:stop()

    Logger:Info("Server shutdown complete")
end)

Logger:Info("🎮 Game Template Server started successfully!", {
    gameMode = gameConfig.GameMode,
    maxPlayers = gameConfig.MaxPlayers,
    systemCount = #systemsList,
})
