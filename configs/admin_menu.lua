-- Ordered, supported Admin menu actions; legacy framework demos are not exposed.
local TEST_CATEGORIES = {
    effects = {
        title = "⚡ Effects Testing",
        tests = {
            { name = "Test Effect Stacking", action = "test_effect_stacking" },
            { name = "Start Hatch Luck Hour", action = "start_hatch_luck_hour" },
            { name = "Start Double Rewards Hour", action = "start_double_rewards_hour" },
            { name = "Start Crystal Rush", action = "start_crystal_rush" },
            { name = "Start Coin Shower", action = "start_coin_shower" },
            { name = "Show Active Global Events", action = "show_global_events" },
            { name = "Clear Global Events", action = "clear_global_events" },
        },
    },
    system = {
        title = "Diagnostics",
        tests = {
            { name = "Run Server Diagnostics", action = "run_diagnostics" },
            { name = "Show Local Player Data", action = "debug_print_data" },
        },
    },
    currency = {
        title = "💎 Currency Management",
        tests = {
            { name = "Add 1000 Coins", action = "add_coins_1000" },
            { name = "Add 100 Gems", action = "add_gems_100" },
            { name = "Add 50 Crystals", action = "add_crystals_50" },
            -- Grants 100k to EACH per-biome currency (grass/ice/lava/desert) in one click.
            -- The legacy "Add Coins" button grants the unused generic `coins`; the zone-unlock
            -- gates + egg costs run on biome coins, so use this to test progression.
            { name = "Add 100k Area Coins", action = "add_area_coins" },
            { name = "Reset All Currencies", action = "reset_currencies" },
        },
        customInputs = {
            {
                label = "Adjust Coins (+ to add, - to remove):",
                placeholder = "e.g. +1M, -500K, +2.5B, +42",
                currency = "coins",
                action = "adjust_coins_custom",
            },
            {
                label = "Adjust Gems (+ to add, - to remove):",
                placeholder = "e.g. +1M, -100K, +1T, +500",
                currency = "gems",
                action = "adjust_gems_custom",
            },
        },
    },
    developer = {
        title = "🧰 Developer Tools",
        tests = {
            { name = "📋 Snapshot Target Player", action = "admin_snapshot" },
            { name = "💾 Force Save Target Player", action = "admin_force_save" },
            {
                name = "🎫 Game Passes: checking…",
                action = "toggle_creator_game_passes",
                creatorOnly = true,
            },
            { name = "🗑️ Reset Pets (Target)", action = "admin_reset_pets" },
            -- label says what the guard actually protects: ALL unique pets (per-uid
            -- records — huges, secrets/dragons, exclusives), not just huges (Jason
            -- almost didn't click it: "am I gonna lose my dragon?")
            {
                name = "🔄 Reset to Beginning (keeps ALL unique pets)",
                action = "admin_reset_to_beginning",
            },
            {
                name = "🔎 Reset to Beginning — PREVIEW",
                action = "admin_reset_to_beginning_preview",
            },
            {
                name = "♻️ Full Respec (refund enhancements)",
                action = "admin_full_respec",
            },
            { name = "🐻 Grant Bear Basic", action = "grant_bear_basic" },
            { name = "🐉 Grant Dragon Basic", action = "grant_dragon_basic" },
            { name = "🐻 Grant Golden Bear", action = "grant_bear_golden" },
            { name = "👤 Grant Colorado", action = "grant_colorado_basic" },
            { name = "👑 Grant Golden Colorado", action = "grant_colorado_golden" },
            { name = "🌈 Grant Rainbow Colorado", action = "grant_colorado_rainbow" },
            { name = "⬆ Grant Huge Rainbow Colorado", action = "grant_colorado_huge" },
            { name = "👑 Grant CREATOR Colorado (apex)", action = "grant_colorado_creator" },
            { name = "👤 Grant Kade", action = "grant_kade_basic" },
            { name = "👑 Grant Golden Kade", action = "grant_kade_golden" },
            { name = "🌈 Grant Rainbow Kade", action = "grant_kade_rainbow" },
            { name = "⬆ Grant Huge Rainbow Kade", action = "grant_kade_huge" },
            { name = "🥚 Signal Seal Egg — Basic", action = "grant_beta_egg_basic" },
            { name = "🥚 Signal Seal Egg — Golden", action = "grant_beta_egg_golden" },
            { name = "🥚 Signal Seal Egg — Rainbow", action = "grant_beta_egg_rainbow" },
            { name = "🥚 Signal Seal Egg — Huge", action = "grant_beta_egg_huge" },
            { name = "🥚 Patch Phoenix Egg — Basic", action = "grant_patch_egg_basic" },
            { name = "🥚 Patch Phoenix Egg — Golden", action = "grant_patch_egg_golden" },
            { name = "🥚 Patch Phoenix Egg — Rainbow", action = "grant_patch_egg_rainbow" },
            { name = "🥚 Patch Phoenix Egg — Huge", action = "grant_patch_egg_huge" },
            { name = "🥚 Core Digger Egg — Basic", action = "grant_core_egg_basic" },
            { name = "🥚 Core Digger Egg — Golden", action = "grant_core_egg_golden" },
            { name = "🥚 Core Digger Egg — Rainbow", action = "grant_core_egg_rainbow" },
            { name = "🥚 Core Digger Egg — Huge", action = "grant_core_egg_huge" },
            { name = "🥚 Cache Bandit Egg — Basic", action = "grant_cache_egg_basic" },
            { name = "🥚 Cache Bandit Egg — Golden", action = "grant_cache_egg_golden" },
            { name = "🥚 Cache Bandit Egg — Rainbow", action = "grant_cache_egg_rainbow" },
            { name = "🥚 Cache Bandit Egg — Huge", action = "grant_cache_egg_huge" },
            { name = "🔮 Grant 3 Future Call Tokens", action = "grant_future_call_tokens" },
            { name = "🗺️ Toggle Meadow Lock", action = "toggle_zone_meadow" },
            { name = "🗺️ Lock Meadow", action = "lock_zone_meadow" },
            { name = "🗺️ Unlock Meadow", action = "unlock_zone_meadow" },
            { name = "🗺️ Bypass Unlock Meadow", action = "unlock_zone_meadow_bypass" },
            { name = "🎲 +100 Area Enhancements", action = "grant_enhancements_100" },
            { name = "🥚 Hatch Unlock Status", action = "hatch_entitlement_status" },
            { name = "🥚 Unlock All Hatch Modes", action = "hatch_entitlement_unlock_all" },
            { name = "🥚 Lock All Hatch Modes", action = "hatch_entitlement_lock_all" },
            { name = "🥚 Reset Hatch Unlocks", action = "hatch_entitlement_reset_all" },
            { name = "🥚 Toggle Golden Hatch", action = "hatch_entitlement_toggle_golden" },
            { name = "🥚 Toggle Charged Hatch", action = "hatch_entitlement_toggle_charged" },
            { name = "🥚 Set Max Hatch 99", action = "hatch_entitlement_max_99" },
            { name = "🥚 Recent Hatch History", action = "hatch_history_recent" },
            { name = "🥚 Simulate 25 Basic Egg", action = "hatch_simulation_basic_25" },
        },
        customInputs = {
            {
                label = "Grant Pet (pet:variant:quantity[:huge]):",
                placeholder = "e.g. bear:basic:3, colorado:basic:1:huge",
                action = "grant_pet_custom",
            },
            {
                label = "Set Zone Lock (zoneId:toggle|lock|unlock|bypass):",
                placeholder = "e.g. Meadow:toggle, Meadow:lock, meadow_island:bypass",
                action = "set_zone_lock_custom",
            },
            {
                label = "Set Hatch Unlock (name:mode/value):",
                placeholder = "e.g. goldenMode:unlock, chargedMode:lock, maxHatchCount:25",
                action = "set_hatch_entitlement_custom",
            },
            {
                label = "Set Max Hatch (3-99):",
                placeholder = "e.g. 25 (clamped to 3-99)",
                action = "set_max_hatch_count",
            },
        },
    },
    combat = {
        title = "⚔️ Combat (test enemies)",
        tests = {
            -- Earth faction (real art): melee dog · ranged crow/cat · support bunny · tank bear.
            -- BALANCE PACKS (Jason: "level balancing on a non-trash team" —
            -- 3 lieutenants + 5 minions at your level, per faction)
            { name = "⚔️ Balance Pack: LAVA (3LT+5M, Self)", action = "spawn_pack_lava" },
            {
                name = "⚔️ Balance Pack: CELESTIAL (3LT+5M, Self)",
                action = "spawn_pack_celestial",
            },
            { name = "⚔️ Balance Pack: EARTH (3LT+5M, Self)", action = "spawn_pack_earth" },
            { name = "🐕 Spawn Rabid Dog (melee)", action = "spawn_enemy_rabid_dog" },
            { name = "🐦 Spawn Murder Crow (ranged)", action = "spawn_enemy_murder_crow" },
            { name = "🐈 Spawn Vicious Cat (ranged)", action = "spawn_enemy_vicious_cat" },
            { name = "🐰 Spawn Jackalope (healer)", action = "spawn_enemy_rabid_bunny" },
            { name = "🐻 Spawn Raging Bear (tank)", action = "spawn_enemy_raging_bear" },
            -- Desert faction.
            { name = "🦊 Spawn Sand Jackal (melee)", action = "spawn_enemy_sand_jackal" },
            {
                name = "🦅 Spawn Carrion Vulture (ranged)",
                action = "spawn_enemy_carrion_vulture",
            },
            { name = "🪲 Spawn Golden Scarab (healer)", action = "spawn_enemy_golden_scarab" },
            { name = "🐢 Spawn Dune Tortoise (tank)", action = "spawn_enemy_dune_tortoise" },
            { name = "🦂 Spawn Sand Scorpion (boss)", action = "spawn_enemy_sand_scorpion" },
            -- Ice faction.
            { name = "🦊 Spawn Frost Fox (melee)", action = "spawn_enemy_frost_fox" },
            { name = "🦉 Spawn Snowy Owl (ranged)", action = "spawn_enemy_snowy_owl" },
            { name = "🦭 Spawn Aurora Seal (healer)", action = "spawn_enemy_aurora_seal" },
            { name = "🐘 Spawn Glacial Mammoth (tank)", action = "spawn_enemy_glacial_mammoth" },
            {
                name = "🐲 Spawn Glacial Leviathan (boss)",
                action = "spawn_enemy_glacial_leviathan",
            },
            -- Lava faction.
            { name = "🦎 Spawn Cinder Whelp (melee)", action = "spawn_enemy_lava_imp" },
            { name = "🦏 Spawn Ember Brute (tank)", action = "spawn_enemy_ember_brute" },
            { name = "🦋 Spawn Ember Moth (healer)", action = "spawn_enemy_ember_acolyte" },
            { name = "🐉 Spawn Magma Wyrm (boss)", action = "spawn_enemy_infernal_boss" },
        },
        customInputs = {
            {
                label = "Spawn Enemy (id):",
                placeholder = "e.g. rabid_dog, murder_crow, raging_bear, ember_brute",
                action = "spawn_enemy_custom",
            },
        },
    },
    logging = {
        title = "📊 Logging Controls",
        tests = {
            { name = "Show Current Log Config", action = "show_log_config" },
            { name = "Set All to INFO", action = "set_all_info" },
            { name = "Set All to DEBUG", action = "set_all_debug" },
            { name = "Set All to WARN", action = "set_all_warn" },
            { name = "Disable Console Output", action = "disable_console" },
            { name = "Enable Console Output", action = "enable_console" },
            { name = "Enable Performance Logs", action = "enable_performance" },
            { name = "Disable Performance Logs", action = "disable_performance" },
        },
        customInputs = {
            {
                label = "Set Service Log Level (service:level):",
                placeholder = "e.g. EggPetPreviewService:debug, BaseUI:warn",
                action = "set_service_log_level",
            },
        },
    },
    inventory = {
        title = "🎒 Inventory Management",
        tests = {
            { name = "🗑️ Remove Orphaned Buckets", action = "cleanup_inventory" },
            { name = "🔧 Fix Item Categories", action = "fix_item_categories" },
        },
    },
    eggHatching = {
        title = "🥚 Egg Hatching Simulation",
        tests = {
            { name = "🥚 Hatch 1 Egg (Random Pet)", action = "hatch_1_egg" },
            { name = "🥚🥚 Hatch 3 Eggs (Random Pets)", action = "hatch_3_eggs" },
            { name = "🥚🥚🥚 Hatch 5 Eggs (Random Pets)", action = "hatch_5_eggs" },
            { name = "🥚🥚🥚🥚 Hatch 10 Eggs (Random Pets)", action = "hatch_10_eggs" },
            { name = "🥚🥚🥚🥚🥚 Hatch 25 Eggs (Random Pets)", action = "hatch_25_eggs" },
            {
                name = "🥚🥚🥚🥚🥚🥚 Hatch 42 Eggs (Random Pets)",
                action = "hatch_42_eggs",
            },
            { name = "🎲 Hatch 99 Eggs (Random Pets)", action = "hatch_99_eggs" },
        },
        customInputs = {
            {
                label = "Custom Egg Count (1-99):",
                placeholder = "e.g. 15, 50, 99",
                action = "hatch_custom_eggs",
            },
            {
                label = "Specific Pet (petType:variant):",
                placeholder = "e.g. bear:basic, dragon:golden, kitty:rainbow",
                action = "hatch_specific_pet",
            },
        },
    },
}

TEST_CATEGORIES.logging.title = "Client Logging"
for _, test in ipairs(TEST_CATEGORIES.logging.tests) do
    if test.action == "set_all_info" then
        test.name = "Client Default Level: INFO"
    end
    if test.action == "set_all_debug" then
        test.name = "Client Default Level: DEBUG"
    end
    if test.action == "set_all_warn" then
        test.name = "Client Default Level: WARN"
    end
end
for _, test in ipairs(TEST_CATEGORIES.developer.tests) do
    if test.action == "grant_enhancements_100" or test.action == "grant_future_call_tokens" then
        test.name = test.name .. " (Self)"
    end
end
TEST_CATEGORIES.eggHatching.title = "Hatch Animation Preview (Local)"
return {
    categories = TEST_CATEGORIES,
    quick_grants = { enhancements = 100, future_call = 3 },
    command_results = {
        enhancements = "Granted %s area enhancements to you.",
        future_call = "Your Future Call tokens: %s.",
        spawn_pack = "Spawned %s pack near you: %s up, %s failed.",
        creator_pending = "Changing creator game-pass benefits…",
        unavailable = "Server commands are temporarily unavailable.",
        failed = "%s failed: %s",
    },
    creator_pass_labels = {
        enabled = "🎫 Game Passes: ON (tap to disable)",
        disabled = "🎫 Game Passes: OFF (tap to enable)",
    },
    logging_levels = {
        debug = true,
        info = true,
        warn = true,
        warning = true,
        error = true,
        disabled = true,
        off = true,
    },
    category_order = {
        "developer",
        "combat",
        "currency",
        "effects",
        "system",
        "logging",
        "inventory",
        "eggHatching",
    },
    category_labels = {
        developer = "Players & Grants",
        combat = "Combat",
        currency = "Currency",
        effects = "Server Events",
        system = "Diagnostics",
        logging = "Client Logging",
        inventory = "Inventory Repair",
        eggHatching = "Hatch Preview",
    },
    event_actions = {
        test_effect_stacking = {
            command = "start",
            eventId = "hatch_luck_hour",
            durationSeconds = 300,
        },
        start_hatch_luck_hour = { command = "start", eventId = "hatch_luck_hour" },
        start_double_rewards_hour = { command = "start", eventId = "double_rewards_hour" },
        start_crystal_rush = { command = "start", eventId = "crystal_rush" },
        start_coin_shower = { command = "start", eventId = "coin_shower" },
        show_global_events = { command = "snapshot" },
        clear_global_events = { command = "clear" },
    },
    logging_actions = {
        show_log_config = true,
        set_all_info = true,
        set_all_debug = true,
        set_all_warn = true,
        disable_console = true,
        enable_console = true,
        enable_performance = true,
        disable_performance = true,
    },
}
