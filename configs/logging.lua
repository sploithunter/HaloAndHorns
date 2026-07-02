--[[
    Logging Configuration - Controls debug output for different services
    
    This configuration allows fine-grained control over what gets logged
    to keep the console clean while debugging specific systems.
    
    Service Log Levels:
    - "disabled" = No logging (silent)
    - "error" = Only errors
    - "warn" = Warnings and above
    - "info" = Info and above (normal operation)
    - "debug" = Everything (detailed debugging)
    
    Global Settings:
    - default_level: Fallback level for services not explicitly configured
    - console_output: Show logs in Studio/server console
    - enable_performance_logs: Show timing and performance measurements
]]

return {
    -- === GLOBAL SETTINGS ===
    global = {
        default_level = "warn", -- Quieter default - only warnings and errors
        console_output = true, -- Show logs in console (set false for production)
        enable_performance_logs = false, -- Show performance timing logs
        max_log_history = 100, -- Number of logs to keep in memory
        enable_remote_logging = false, -- Send logs to external services
    },

    -- === PERFORMANCE MONITOR SETTINGS ===
    -- Controls server/client performance warning thresholds
    performance_monitor = {
        server = {
            enabled = true, -- Enable server performance monitoring
            interval_seconds = 30, -- How often to sample and report
            target_frame_time_seconds = 1 / 60, -- Ideal target (≈0.0167s, 60 FPS)
            warn_frame_time_seconds = 1 / 30, -- Warn when slower than ~30 FPS (≈0.0333s)
            error_frame_time_seconds = 0.0667, -- Error when slower than ~15 FPS (≈0.0667s)
        },
        -- Future: add client settings if needed
    },

    -- === SERVICE-SPECIFIC LOG LEVELS ===
    services = {
        -- === STARTUP & CORE (Minimal logging for clean boot) ===
        Logger = "warn", -- Quiet startup
        ConfigLoader = "warn", -- Only show config errors
        ModuleLoader = "warn", -- Only show loading issues
        NetworkBridge = "warn", -- Reduce network noise
        NetworkConfig = "warn", -- Only show config issues

        -- === CRITICAL SYSTEMS (Keep quiet unless needed) ===
        DataService = "info", -- Profile loading is important
        EconomyService = "warn", -- Suppress purchase spam
        MonetizationService = "warn", -- Keep monetization quiet unless issues
        PlayerEffectsService = "warn", -- Reduce effect application spam
        AdminService = "warn", -- Suppress admin debug unless issues
        RateLimitService = "warn", -- Only show rate limit violations
        ServerClockService = "warn", -- Clock sync issues only
        GlobalEffectsService = "warn", -- Reduce effect noise

        -- === ASSET & MODEL SYSTEMS ===
        AssetPreloadService = "info", -- Show model loading progress (important)
        EggPetPreviewService = "info", -- Keep egg UI previews visible

        -- === UI SYSTEMS (Very noisy - keep quiet) ===
        BaseUI = "error", -- Only show serious UI errors
        TemplateManager = "error", -- Reduce template spam
        MenuManager = "error", -- Only show menu failures
        AdminPanel = "warn", -- Suppress admin panel chatter
        EffectsPanel = "warn", -- Effects debugging
        SettingsPanel = "error", -- Settings are usually stable
        InventoryPanel = "error", -- Keep inventory UI silent

        -- === GAME SYSTEMS (Prioritize egg-related output) ===
        EggSpawner = "info", -- Show egg spawning (important for testing)
        EggCurrentTargetService = "info", -- Keep targeting info visible
        EggInteractionService = "info", -- Keep interaction info visible
        EggService = "info", -- Show egg system status
        EggHatchingService = "info", -- Future-proof if service switches to Logger
        InventoryService = "warn", -- Suppress inventory chatter

        -- === EXTERNAL PACKAGES (Very quiet) ===
        Matter = "error", -- ECS system - only errors
        Reflex = "error", -- State management - only errors
        ProfileStore = "error", -- Data persistence - only errors
        ProductIdMapper = "warn", -- Monetization mapping issues
    },

    -- === QUICK PRESETS ===
    -- To use a preset, uncomment one and comment out the main 'services' section above

    -- 🧹 CLEAN DEVELOPMENT (Current active preset)
    -- This preset minimizes console noise while keeping essential info
    -- Current configuration above implements this preset

    -- 🔧 DEBUGGING MODE (Uncomment to enable detailed debugging)
    -- presets = {
    --     debugging = {
    --         default_level = "warn",
    --         AssetPreloadService = "debug",      -- See asset loading details
    --         EggPetPreviewService = "debug",     -- See pet preview internals
    --         EggCurrentTargetService = "debug",  -- See egg targeting
    --         EggInteractionService = "debug",    -- See egg interactions
    --         BaseUI = "info",                    -- See UI updates
    --         DataService = "info",               -- See profile operations
    --     }
    -- },

    -- 🚀 PRODUCTION MODE (Uncomment for live deployment)
    -- presets = {
    --     production = {
    --         default_level = "error",
    --         console_output = false,             -- Silent console
    --         enable_performance_logs = false,
    --         DataService = "warn",               -- Profile issues only
    --         AssetPreloadService = "warn",       -- Asset loading issues only
    --     }
    -- },

    -- 🎨 AESTHETIC WORK MODE (Uncomment for pure UI/layout work)
    -- presets = {
    --     aesthetic = {
    --         default_level = "error",            -- Almost silent
    --         DataService = "warn",               -- Essential data operations
    --         AssetPreloadService = "warn",       -- Asset loading issues
    --         EggSpawner = "warn",                -- Egg spawning issues
    --         -- Everything else will be at 'error' level (silent)
    --     }
    -- }
}
