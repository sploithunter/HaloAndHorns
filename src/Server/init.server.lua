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

-- EVENT-BASED warp integrity (Jason: "no timeout shenanigans — the event
-- happens or it doesn't"): Workspace.StreamingIntegrityMode MUST be
-- PauseOutsideLoadedArea (a PLACE property — NotScriptable, set via the
-- Studio Properties panel; also in default.project.json $properties for
-- fresh builds). A client whose character is outside the streamed area gets
-- its physics PAUSED until the geometry arrives, so falling through an
-- unstreamed floor is structurally impossible. This replaces every
-- timeout-capped anchor tail in the warp paths (missions + realm portals).

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
local RuntimeServiceBindings = require(ServerScriptService.Server.Services.RuntimeServiceBindings)

-- Audio buses are created SERVER-side at boot so every peer shares ONE set of
-- SoundGroups. Otherwise the client lazily creates LOCAL groups at startup and
-- a later server-side assign (mission crate smash) creates replicated
-- DUPLICATES — the volume sliders then drive the client copies while
-- server-assigned sounds sit on the untouched replicas (2026-07-08: master
-- volume at zero couldn't silence crate breaks).
pcall(function()
    local SoundGroups = require(ReplicatedStorage.Shared.Effects.SoundGroups)
    SoundGroups.get("effects")
    SoundGroups.get("music")
    SoundGroups.get("ui")
end)

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
    appendIfEnabled(
        { "Logger", "ConfigLoader", "DataService", "EconomyService" },
        "modifiers",
        "ModifierService"
    )
)
registerFeatureModule(
    "player_progression",
    "PlayerProgressionService",
    ServerScriptService.Server.Services.PlayerProgressionService,
    appendIfEnabled(
        appendIfEnabled({ "Logger", "ConfigLoader", "DataService" }, "modifiers", "ModifierService"),
        "stats",
        "StatsService"
    )
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
    { "Logger", "ConfigLoader", "DataService", "EconomyService", "WorldBindingService" }
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
    { "Logger", "ConfigLoader", "EnemyService" }
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
        { "Logger", "ConfigLoader", "DataService", "EconomyService", "PetSerialService" },
        "stats",
        "StatsService"
    )
)
registerFeatureModule(
    "achievements",
    "AchievementsService",
    ServerScriptService.Server.Services.AchievementsService,
    appendIfEnabled(
        { "Logger", "ConfigLoader", "DataService", "EconomyService", "RewardService" },
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
    "EffectiveStatsService",
    ServerScriptService.Server.Services.EffectiveStatsService,
    -- SSOT stat publisher (Jason 2026-07-14): computes every derived player
    -- stat from the Shared EffectiveStats registry and publishes Eff_* attrs
    { "Logger", "ConfigLoader", "ModifierService" }
)
loader:RegisterModule(
    "MonetizationService",
    ServerScriptService.Server.Services.MonetizationService,
    -- InventoryService: capacity refresh after async pass benefits (paid slot)
    {
        "Logger",
        "DataService",
        "EconomyService",
        "ProductIdMapper",
        "PlayerEffectsService",
        "InventoryService",
    }
)
loader:RegisterModule(
    "InventoryService",
    ServerScriptService.Server.Services.InventoryService,
    appendIfEnabled(
        appendIfEnabled(
            appendIfEnabled(
                { "Logger", "DataService", "ConfigLoader" },
                "upgrades",
                "UpgradeService"
            ),
            "player_progression",
            "PlayerProgressionService"
        ),
        "stats",
        "StatsService"
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
            { "Logger", "ConfigLoader", "DataService", "InventoryService", "EconomyService" },
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
    "StarterPetService",
    ServerScriptService.Server.Services.StarterPetService,
    { "Logger", "ConfigLoader", "DataService", "InventoryService", "PetGrantService" }
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
            "EconomyService",
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
    { "Logger", "ConfigLoader", "DataService", "EconomyService" }
)
-- FloraService: FloraAnchor-tagged map flora restyled per layer/realm from
-- configs/flora.lua (Jason 2026-07-16 — style swaps are config, not map edits).
loader:RegisterModule(
    "FloraService",
    ServerScriptService.Server.Services.FloraService,
    { "Logger", "ConfigLoader" }
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
    appendIfEnabled(
        { "Logger", "ConfigLoader", "DataService", "EnhancementService", "PowerService" },
        "player_progression",
        "PlayerProgressionService"
    )
)
-- EnhancementService: CoH-style enhancements (inventory + slotting into power slots).
loader:RegisterModule(
    "EnhancementService",
    ServerScriptService.Server.Services.EnhancementService,
    appendIfEnabled(
        { "Logger", "ConfigLoader", "DataService", "InventoryService", "PowerService" },
        "stats",
        "StatsService"
    )
)
-- EnhancementShopService: buy/sell enhancements for gems (configs/enhancements.lua shop).
loader:RegisterModule(
    "EnhancementShopService",
    ServerScriptService.Server.Services.EnhancementShopService,
    {
        "Logger",
        "ConfigLoader",
        "DataService",
        "InventoryService",
        "EnhancementService",
        "EconomyService",
    }
)
-- PotionService: "brew charge" potions (drink->sip->drain) feeding BuffStack axis attributes.
loader:RegisterModule(
    "PotionService",
    ServerScriptService.Server.Services.PotionService,
    { "Logger", "ConfigLoader", "DataService", "InventoryService" }
)
-- PotionShopService: authored-tent prompts + authoritative 5-gem buy / 2-gem sell boundary.
loader:RegisterModule("PotionShopService", ServerScriptService.Server.Services.PotionShopService, {
    "Logger",
    "ConfigLoader",
    "DataService",
    "EconomyService",
    "InventoryService",
    "PotionService",
})
-- TutorialService: event-driven new-player tutorial (taps the GameEvents bus; configs/tutorial).
loader:RegisterModule(
    "TutorialService",
    ServerScriptService.Server.Services.TutorialService,
    appendIfEnabled({
        "Logger",
        "ConfigLoader",
        "DataService",
        "EnhancementService",
        "PotionService",
        "HotbarService",
    }, "player_progression", "PlayerProgressionService")
)
-- RetentionService: persisted activation milestones + Roblox onboarding/custom analytics.
loader:RegisterModule(
    "RetentionService",
    ServerScriptService.Server.Services.RetentionService,
    { "Logger", "ConfigLoader", "DataService" }
)
-- HotbarService: Halo & Horns hotbar / command bar (Feature 16).
loader:RegisterModule(
    "HotbarService",
    ServerScriptService.Server.Services.HotbarService,
    { "Logger", "ConfigLoader", "DataService", "PotionService", "EnemyService", "PowerService" }
)
-- RosterService: Halo & Horns named rosters + injury-rule deploy (Feature 17).
-- Resolves SpiritFormService at runtime for pet readiness.
loader:RegisterModule(
    "RosterService",
    ServerScriptService.Server.Services.RosterService,
    { "Logger", "ConfigLoader", "DataService", "SpiritFormService" }
)
-- PartyService: Halo & Horns group play (Feature 18) — membership + group math.
loader:RegisterModule(
    "PartyService",
    ServerScriptService.Server.Services.PartyService,
    { "Logger", "ConfigLoader", "LayerService" }
)
-- TradeService: Halo & Horns trading (Feature 19) — session offers, both-confirm
-- gate, atomic swap, and the trade-history audit log.
loader:RegisterModule(
    "PetTransferService",
    ServerScriptService.Server.Services.PetTransferService,
    { "InventoryService" }
)
loader:RegisterModule(
    "TradeService",
    ServerScriptService.Server.Services.TradeService,
    appendIfEnabled({
        "Logger",
        "ConfigLoader",
        "DataService",
        "EconomyService",
        "InventoryService",
        "PetTransferService",
        "RosterService",
        "EnhancementService",
    }, "stats", "StatsService")
)
-- FusionService: Halo & Horns Chaotic fusion (Feature 20) — Light + Shadow -> Chaotic.
loader:RegisterModule(
    "FusionService",
    ServerScriptService.Server.Services.FusionService,
    { "Logger", "ConfigLoader", "InventoryService", "PetGrantService" }
)
-- Reward spine (Phase 7): RewardService grants bundles; Quest/Daily/Shop gate them.
loader:RegisterModule("RewardService", ServerScriptService.Server.Services.RewardService, {
    "Logger",
    "ConfigLoader",
    "DataService",
    "EconomyService",
    "InventoryService",
    "PetGrantService",
    "PlayerEffectsService",
})
loader:RegisterModule(
    "QuestService",
    ServerScriptService.Server.Services.QuestService,
    appendIfEnabled(
        appendIfEnabled(
            { "Logger", "ConfigLoader", "DataService", "RewardService" },
            "player_progression",
            "PlayerProgressionService"
        ),
        "stats",
        "StatsService"
    )
)
loader:RegisterModule(
    "DailyService",
    ServerScriptService.Server.Services.DailyService,
    { "Logger", "ConfigLoader", "DataService", "RewardService" }
)
loader:RegisterModule(
    "ShopService",
    ServerScriptService.Server.Services.ShopService,
    { "Logger", "ConfigLoader", "DataService", "EconomyService", "RewardService" }
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
    appendIfEnabled(
        appendIfEnabled({
            "Logger",
            "ConfigLoader",
            "DataService",
            "EconomyService",
            "RewardService",
            "LayerService",
            "FocusService",
            "SpiritFormService",
        }, "player_progression", "PlayerProgressionService"),
        "modifiers",
        "ModifierService"
    )
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
    appendIfEnabled({ "Logger", "ConfigLoader" }, "player_progression", "PlayerProgressionService")
)
-- DailyRewardZoneService: the in-world Daily Reward pad — auto-claims the daily streak
-- when a player walks into the authored "Daily Reward" model (no prompt/menu), paying the
-- player's ORIGIN biome coin and floating an ~8s reward description. Resolves
-- DailyService/RewardService at runtime via the locator.
loader:RegisterModule(
    "DailyRewardZoneService",
    ServerScriptService.Server.Services.DailyRewardZoneService,
    { "Logger", "ConfigLoader", "DataService", "DailyService", "RewardService" }
)
-- BaddieSpawnerService: proximity enemy waves at map-authored BaddieSpawner* parts
-- (combat taste before the Heaven/Hell choice — Jason). Resolves EnemyService at runtime.
loader:RegisterModule(
    "BaddieSpawnerService",
    ServerScriptService.Server.Services.BaddieSpawnerService,
    {
        "Logger",
        "ConfigLoader",
        "EnemyService",
        "PlayerProgressionService",
        "StatsService",
    }
)
-- MeetCreatorService: first-time-in-a-server-with-a-creator -> their egg, once ever
-- (configs/creators.lua). Resolves Data/Inventory/PetGrant services at runtime.
loader:RegisterModule(
    "MeetCreatorService",
    ServerScriptService.Server.Services.MeetCreatorService,
    { "Logger", "ConfigLoader", "DataService", "InventoryService", "PetGrantService" }
)
-- RealmPortalService: binds named workspace portals (Portal_Halo1/Portal_Horn1) to a
-- ProximityPrompt that toggles the player into a heaven/hell realm via LayerService (World S3
-- test entry; resolves LayerService at runtime via the locator).
loader:RegisterModule(
    "RealmPortalService",
    ServerScriptService.Server.Services.RealmPortalService,
    { "Logger", "ConfigLoader", "LayerService", "AdminService" }
)
-- MissionInstanceService: CoH-style door missions — MissionDoor prompts open a
-- deterministic procedural instance (seeded tile-kit map) at a far-X slot and
-- teleport the party in (docs/MISSION_WORLDGEN.md).
loader:RegisterModule(
    "MissionInstanceService",
    ServerScriptService.Server.Services.MissionInstanceService,
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
-- docs/wiki/AUTOMATION_API_DESIGN.md). Its fixed adapter map is bound before Start.
loader:RegisterModule(
    "GameAPIService",
    ServerScriptService.Server.Services.GameAPIService,
    { "Logger", "EconomyService" }
)
if RunService:IsStudio() then
    -- AutomationService: Studio-only test driver. Depends on GameAPIService so it
    -- can register its automation.* commands onto the bus at Start time.
    loader:RegisterModule(
        "AutomationService",
        ServerScriptService.Server.Services.AutomationService,
        { "Logger", "DataService", "EconomyService", "GameAPIService" }
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

local eggServiceDependencies = {
    "Logger",
    "DataService",
    "InventoryService",
    "EconomyService",
    "EventService",
    "PetGrantService",
    "HatchEntitlementService",
}
appendIfEnabled(eggServiceDependencies, "stats", "StatsService")
appendIfEnabled(eggServiceDependencies, "modifiers", "ModifierService")
appendIfEnabled(eggServiceDependencies, "auto_target", "AutoTargetService")
appendIfEnabled(eggServiceDependencies, "pet_index", "PetIndexService")
appendIfEnabled(eggServiceDependencies, "player_progression", "PlayerProgressionService")
loader:RegisterModule(
    "EggService",
    ServerScriptService.Server.Services.EggService,
    eggServiceDependencies
)
loader:RegisterModule("EggSpawner", ReplicatedStorage.Shared.Services.EggSpawner, { "Logger" })
loader:RegisterModule(
    "PetEquipmentBridge",
    ServerScriptService.Server.Services.PetEquipmentBridge,
    { "Logger", "InventoryService" }
)

-- Register lazy services (loaded when needed)
-- loader:RegisterLazyModule("TradeService", ServerScriptService.Server.Services.TradeService, {"EconomyService", "DataService", "NetworkBridge"}) -- TODO: Create TradeService
-- loader:RegisterLazyModule("CombatService", ServerScriptService.Server.Services.CombatService, {"DataService", "NetworkBridge", "ConfigLoader"}) -- TODO: Create CombatService
-- loader:RegisterLazyModule("MatchmakingService", ServerScriptService.Server.Services.MatchmakingService, {"DataService", "NetworkBridge"}) -- TODO: Create MatchmakingService

-- Load all modules with error handling
-- Loading will be reported via Logger after initialization
local loadSuccess, loadOrderOrError = pcall(function()
    return loader:LoadAll(function(modules)
        if isFeatureEnabled("player_progression") then
            local progression = modules:Get("PlayerProgressionService")
            local reward = modules:Get("RewardService")
            progression:BindPeerServices({
                InventoryService = modules:Get("InventoryService"),
                RewardService = reward,
                EnhancementService = modules:Get("EnhancementService"),
            })
            reward:SetPlayerProgressionService(progression)
        end
        modules:Get("ActiveSquadService"):SetSpiritFormService(modules:Get("SpiritFormService"))
        if isFeatureEnabled("map_binding") then
            modules:Get("BreakableSpawner"):SetZoneService(modules:Get("ZoneService"))
        end
        if isFeatureEnabled("pet_index") then
            modules:Get("PetGrantService"):SetPetIndexService(modules:Get("PetIndexService"))
        end
        if isFeatureEnabled("pet_progression") and isFeatureEnabled("enchants") then
            modules:Get("PetProgressionService"):SetEnchantService(modules:Get("EnchantService"))
        end
        modules:Get("PetFollowService"):BindPeerServices({
            CombatService = modules:Get("CombatService"),
            EnemyService = modules:Get("EnemyService"),
        })
        modules:Get("EnemyService"):BindPeerServices({
            CombatService = modules:Get("CombatService"),
            PetFollowService = modules:Get("PetFollowService"),
            StatsService = isFeatureEnabled("stats") and modules:Get("StatsService") or nil,
            DropService = modules:Get("DropService"),
            DataService = modules:Get("DataService"),
            PowerService = modules:Get("PowerService"),
            EventService = isFeatureEnabled("global_events") and modules:Get("EventService") or nil,
        })
        modules:Get("MissionInstanceService"):BindPeerServices({
            QuestService = modules:Get("QuestService"),
            EnhancementService = modules:Get("EnhancementService"),
            DataService = modules:Get("DataService"),
            EnemyService = modules:Get("EnemyService"),
            InventoryService = modules:Get("InventoryService"),
            StatsService = isFeatureEnabled("stats") and modules:Get("StatsService") or nil,
            LayerService = modules:Get("LayerService"),
            BreakableSpawner = modules:Get("BreakableSpawner"),
            DropService = modules:Get("DropService"),
            EventService = isFeatureEnabled("global_events") and modules:Get("EventService") or nil,
        })
        if isFeatureEnabled("admin_tools") then
            modules:Get("AdminToolsService"):BindPeerServices({
                EnemyService = modules:Get("EnemyService"),
                PlayerProgressionService = isFeatureEnabled("player_progression") and modules:Get(
                    "PlayerProgressionService"
                ) or nil,
                ArchetypeService = modules:Get("ArchetypeService"),
                PowerService = modules:Get("PowerService"),
                TutorialService = modules:Get("TutorialService"),
                EnhancementService = modules:Get("EnhancementService"),
                HotbarService = modules:Get("HotbarService"),
                StarterPetService = modules:Get("StarterPetService"),
            })
        end
        modules:Get("PowerService"):BindPeerServices({
            FocusService = modules:Get("FocusService"),
            PetFollowService = modules:Get("PetFollowService"),
            SummonService = modules:Get("SummonService"),
            EnemyService = modules:Get("EnemyService"),
            PartyService = modules:Get("PartyService"),
            StatsService = isFeatureEnabled("stats") and modules:Get("StatsService") or nil,
            PlayerProgressionService = isFeatureEnabled("player_progression") and modules:Get(
                "PlayerProgressionService"
            ) or nil,
            HotbarService = modules:Get("HotbarService"),
        })
        modules:Get("PotionService"):BindPeerServices({
            HotbarService = modules:Get("HotbarService"),
            EnemyService = modules:Get("EnemyService"),
        })
        modules:Get("GameAPIService"):BindServices({
            AchievementsService = isFeatureEnabled("achievements") and modules:Get(
                "AchievementsService"
            ) or nil,
            ActiveSquadService = modules:Get("ActiveSquadService"),
            AdminService = modules:Get("AdminService"),
            AlignmentService = modules:Get("AlignmentService"),
            ArchetypeService = modules:Get("ArchetypeService"),
            AugmentationService = modules:Get("AugmentationService"),
            CombatService = modules:Get("CombatService"),
            DailyService = modules:Get("DailyService"),
            DataService = modules:Get("DataService"),
            EnemyService = modules:Get("EnemyService"),
            EnhancementService = modules:Get("EnhancementService"),
            EnhancementShopService = modules:Get("EnhancementShopService"),
            FocusService = modules:Get("FocusService"),
            FusionService = modules:Get("FusionService"),
            HotbarService = modules:Get("HotbarService"),
            InventoryService = modules:Get("InventoryService"),
            LayerService = modules:Get("LayerService"),
            MeetCreatorService = modules:Get("MeetCreatorService"),
            MissionInstanceService = modules:Get("MissionInstanceService"),
            PartyService = modules:Get("PartyService"),
            PetGrantService = modules:Get("PetGrantService"),
            PlayerProgressionService = isFeatureEnabled("player_progression") and modules:Get(
                "PlayerProgressionService"
            ) or nil,
            PotionService = modules:Get("PotionService"),
            PotionShopService = modules:Get("PotionShopService"),
            PowerService = modules:Get("PowerService"),
            QuestService = modules:Get("QuestService"),
            RetentionService = modules:Get("RetentionService"),
            RewardService = modules:Get("RewardService"),
            RosterService = modules:Get("RosterService"),
            ShopService = modules:Get("ShopService"),
            SpiritFormService = modules:Get("SpiritFormService"),
            StackPoolService = modules:Get("StackPoolService"),
            StatsService = isFeatureEnabled("stats") and modules:Get("StatsService") or nil,
            TradeService = modules:Get("TradeService"),
            TutorialService = modules:Get("TutorialService"),
            UpgradeService = isFeatureEnabled("upgrades") and modules:Get("UpgradeService") or nil,
            ZoneService = isFeatureEnabled("map_binding") and modules:Get("ZoneService") or nil,
        })
        RuntimeServiceBindings.configure({
            GameAPIService = modules:Get("GameAPIService"),
            ModifierService = isFeatureEnabled("modifiers") and modules:Get("ModifierService")
                or nil,
            PetFollowService = modules:Get("PetFollowService"),
        })
    end)
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
    "StarterPetService",
    "PetTransferService",
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
table.insert(requiredModules, "PotionShopService")
table.insert(requiredModules, "TutorialService")
table.insert(requiredModules, "RetentionService")
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
table.insert(requiredModules, "MissionInstanceService")
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
local EconomyService = loader:Get("EconomyService")

-- Set up cross-references to avoid circular dependencies
DataService:SetPlayerEffectsService(PlayerEffectsService)
EconomyService:SetInventoryService(InventoryService)

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

-- UserDisplayPreferences is now handled by SettingsService via ModuleLoader

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
