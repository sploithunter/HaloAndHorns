-- Egg System Configuration
-- Centralized settings for egg interaction, UI, and performance

return {
    -- XP per egg hatched (Jason: "one XP point per egg") — granted per batch
    -- (hatch 9 = 9 XP) at RecordHatchSuccess; 0 disables
    xp_per_hatch = 1,

    -- The player's VERY FIRST egg ever (lifetime eggs_hatched == 0) rolls with this
    -- luck multiplier, applied AFTER the luck cap and consumed by exactly ONE roll —
    -- a great first impression (Jason: "extremely lucky... but only the very first
    -- egg"). 1 disables. Hits BOTH channels: species (full) + variant (damped by
    -- variant_luck_weight). Verified via scripts/hatch_progression-style sim.
    -- 50x (Jason, 2026-06-13, "radically increase it"): the variant_luck_weight=0.5
    -- damping had quietly cut the old 10x from ~40% to ~28% golden. At 50x the
    -- first pet is GUARANTEED shiny (~87% golden + ~13% rainbow = ~100% non-basic),
    -- with a 1-in-4 shot at a legendary species. golden% actually PEAKS near 50x —
    -- past it, rainbow (rolled first) steals from golden. Was 50 before the
    -- species-reweight change; this restores + re-grounds it under the new math.
    first_hatch_luck_multiplier = 50,

    version = "1.0.0",

    -- === PROXIMITY & INTERACTION SETTINGS ===
    proximity = {
        max_distance = 18, -- Maximum distance to show egg UI and allow interaction (studs)
        interaction_key = Enum.KeyCode.E, -- Key for egg interaction
        hatch_max_key = Enum.KeyCode.R,
        auto_hatch_key = Enum.KeyCode.T,
    },

    -- === PERFORMANCE SETTINGS ===
    performance = {
        update_interval = 0.1, -- How often to check for nearby eggs (seconds) - 10fps
        server_update_threshold = 30, -- Frames before calling setLastEgg on server
        ui_position_update_rate = 0.05, -- How often to update UI position for smooth movement
    },

    -- === COOLDOWN SETTINGS ===
    cooldowns = {
        purchase_cooldown = 3, -- Seconds between egg purchases per player
        ui_error_display_time = 3, -- How long error messages stay on screen
        success_notification_time = 5, -- How long success notifications stay on screen
    },

    -- Server-authoritative hatch transaction settings. The client may request any
    -- count up to max_count, but the server resolves the actual count from
    -- entitlements, currency, storage, and this config.
    hatching = {
        max_count = 99,
        default_requested_count = 1,
        allow_partial = true,
        transaction_lock_seconds = 0.35,
        failed_request_lock_seconds = 0.2,
        auto_loop_delay = 3,
        default_max_entitled_count = 3,
        debug = {
            history_limit = 12,
            result_sample_limit = 20,
        },
        compat_purchase_types = {
            Single = 1,
            Triple = 3,
            Auto = 99,
            Max = 99,
        },
        animation = {
            max_visible_eggs = 99,
            use_authored_egg_visual = true,
            authored_visual_scale = 1.25,
            fast_hatch_speed_scale = 0.5,
            layout = {
                padding = 20,
                min_egg_size = 100,
                compact_min_egg_size = 70,
                compact_threshold = 37,
                max_egg_size = 300,
            },
            special_reveal_enabled = true,
            special_world_fx = true,
            respect_silent_for_special = false,
            special_reveal_min_duration = 1.1,
            special_rarities = {
                mythic = true,
                secret = true,
                exclusive = true,
                huge = true,
            },
            special_glow = {
                enabled = true,
                stroke_thickness = 5,
                stroke_transparency = 0.12,
                pulse_enabled = true,
                pulse_scale = 1.45,
                pulse_duration = 0.55,
                pulse_repeats = 3,
            },
            special_backdrop = {
                enabled = true,
                transparency = 0.82,
                pulse_scale = 1.18,
                pulse_duration = 0.35,
            },
            result_stack = {
                enabled = true,
                show_name = true,
                show_count = true,
                count_minimum = 2,
                move_tween_seconds = 0.35,
                recenter_tween_seconds = 0.45,
                hold_seconds = 1,
            },
            reveal_badges = {
                enabled = true,
                show_rarity = true,
                show_variant = true,
                show_basic_variant = false,
                show_auto_deleted = true,
                special_badge_text = "SPECIAL",
                auto_deleted_text = "AUTO-DELETED",
            },
        },
        shop_stubs = {
            max_hatch_count = {
                enabled = true,
                default_value = 3,
                source = "config",
            },
            auto_hatch = {
                enabled = true,
                owned_by_default = true,
                source = "stub",
            },
            fast_hatch = {
                enabled = true,
                owned_by_default = false,
                source = "stub",
            },
            skip_hatch = {
                enabled = true,
                owned_by_default = false,
                source = "stub",
            },
            golden_mode = {
                enabled = true,
                owned_by_default = false,
                cost_multiplier = 20,
                source = "stub",
            },
            charged_mode = {
                enabled = true,
                owned_by_default = false,
                cost_multiplier = 5,
                luck_bonus = 1,
                secret_luck_bonus = 0.25,
                source = "stub",
            },
            luck_bonus = {
                enabled = true,
                default_multiplier = 0,
                source = "stub",
            },
            secret_luck_bonus = {
                enabled = true,
                default_multiplier = 0,
                source = "stub",
            },
        },
    },

    -- === UI CONFIGURATION ===
    ui = {
        -- Egg Preview UI Dimensions
        preview_size = {
            width = 200,
            height = 120, -- Increased height for three-line layout (name, price, prompt)
        },

        interaction_prompt = {
            -- "clean" follows the player's configured E-key hatch action.
            -- "advertised_hotkeys" teaches the legacy E/R/T shortcut surface.
            mode = "clean",
            clean_text = "%s Hatch",
            clean_max_text = "%s Max Hatch",
            clean_auto_text = "Hatch (%s)", -- the card IS the button; key in parens (Jason)
            advertised_text = "%s Hatch | %s Max | %s Auto",
        },

        hatch_panel = {
            enabled = true,
            width = 500,
            height = 176,
            settings_height = 336,
            bottom_offset = 126,
            count_step = 1,
            count_large_step = 10,
            default_selected_count = 1,
            default_action_mode = "single",
            -- BUTTONS are primary input (Jason, after mobile playtest: "no way to
            -- click it... couldn't hatch an egg"); keyboard E/M/T remain as shortcuts
            show_inline_controls = true,
            -- floating action bar OFF (Jason: the proximity card IS the hatch button;
            -- MAX/AUTO live on the card itself now). Flip any back on to resurrect it.
            action_bar = { hatch = false, max = false, auto = false },
            status_display_time = 3,
            action_modes = {
                single = {
                    label = "Single Hatch",
                    description = "Press E to hatch one egg.",
                },
                max = {
                    label = "Max Hatch",
                    description = "Press E to hatch as many eggs as your unlocks, currency, and storage allow.",
                },
                auto = {
                    label = "Auto Hatch",
                    description = "Press E to start or stop auto hatching at the current egg.",
                },
            },
            responsive = {
                margin = 16,
                min_scale = 0.64,
                max_scale = 1,
            },
            buttons = {
                hatch = "Hatch",
                max = "Max",
                auto = "Auto",
                settings = "Filters",
            },
            auto_delete = {
                description = "Choose pets that should be deleted as they hatch. Protected special rarities are still kept.",
                enabled_description = "Turns hatch-time deletion on or off without changing the selected filters.",
                summary_empty = "Auto-delete: Off (no filters)",
                summary_enabled_format = "Auto-delete: On (%d filters)",
                summary_disabled_format = "Auto-delete: Off (%d filters saved)",
                rarity_description = "Delete hatched pets whose rarity matches the selected rarity filters.",
                pet_type_description = "Delete hatched pets whose pet family matches the selected pet filters.",
                variant_description = "Delete hatched pets whose Basic, Golden, or Rainbow variant matches.",
                rarity_filters = {
                    "common",
                    "uncommon",
                    "rare",
                    "epic",
                },
                pet_type_filters = {
                    "bear",
                    "doggy",
                    "bunny",
                    "colorado",
                },
                variant_filters = {
                    "basic",
                    "golden",
                    "rainbow",
                },
            },
            modes = {
                show = {
                    label = "Show",
                    option = "showHatch",
                    default_enabled = true,
                    description = "Shows hatch animations for manual and auto hatches.",
                    active_description = "Active: hatch animations are shown.",
                    available_description = "Available: turn on Show to see hatch animations.",
                },
                golden = {
                    label = "Golden",
                    option = "goldenMode",
                    description = "Premium hatch mode: costs more and removes Basic variant rolls.",
                    locked_description = "Locked: Golden hatch mode removes Basic variant rolls and uses the configured premium cost.",
                    active_description = "Active: Golden hatch mode removes Basic variant rolls for this hatch request.",
                    available_description = "Available: turn on Golden hatch mode to remove Basic variant rolls.",
                },
                charged = {
                    label = "Charge",
                    option = "chargedMode",
                    description = "Premium hatch mode: costs more and adds hatch luck and secret luck.",
                    locked_description = "Locked: Charged hatch mode spends extra currency for configured hatch-luck and secret-luck bonuses.",
                    active_description = "Active: Charged hatch mode adds configured hatch-luck and secret-luck bonuses.",
                    available_description = "Available: turn on Charged hatch mode for configured luck bonuses.",
                },
                fast = {
                    label = "Fast",
                    option = "fastHatch",
                    description = "Presentation option for faster hatch animations when unlocked.",
                    locked_description = "Locked: Fast hatch shortens the hatch animation when the player owns it.",
                    active_description = "Active: hatch animations play faster.",
                    available_description = "Available: turn on Fast hatch to shorten hatch animations.",
                },
                skip = {
                    label = "Skip",
                    option = "skipHatch",
                    description = "Skips hatch animations, useful while auto-hatching.",
                    locked_description = "Locked: Skip hatch hides hatch animations when the player owns it.",
                    active_description = "Active: hatch animations are skipped.",
                    available_description = "Available: turn on Skip hatch to hide hatch animations.",
                },
                silent = {
                    label = "Silent",
                    option = "silentHatch",
                    description = "Suppresses hatch audio while preserving server-side results.",
                    active_description = "Active: hatch audio is suppressed.",
                    available_description = "Available: turn on Silent hatch to suppress hatch audio.",
                },
            },
            help = {
                default = "Hover a hatch mode or filter to see what it changes.",
                count = "Select how many eggs to request. The server hatches only what your unlocks, currency, and storage allow.",
                hatch = "Hatch the selected count once.",
                max = "Request the configured maximum hatch count.",
                auto = "Keep hatching the selected count until you stop, move away, run out of currency, or fill storage.",
                settings = "Open hatch modes and auto-delete filters.",
            },
        },

        -- Pet Preview UI Dimensions
        pet_preview_size = {
            width = 600,
            height = 100,
        },

        -- UI Positioning (offset from egg world position)
        position_offset = {
            x = -100, -- Pixels left of egg center
            y = -50, -- Pixels above egg center
        },

        -- Pet Preview Positioning (offset from egg world position)
        pet_preview_offset = {
            x = -300, -- Pixels left of egg center (centers 600px wide panel)
            y = -250, -- Pixels above egg (enough space to clear egg interaction UI)
        },

        -- Colors and Styling
        colors = {
            background = Color3.fromRGB(255, 255, 255), -- White background for pet preview frame
            border = Color3.fromRGB(0, 0, 0), -- Black border for contrast
            text_primary = Color3.fromRGB(0, 0, 0), -- Black primary text
            text_secondary = Color3.fromRGB(100, 100, 100), -- Dark gray secondary text
            success_bg = Color3.fromRGB(34, 139, 34),
            error_bg = Color3.fromRGB(220, 53, 69),

            -- Pet preview colors
            pet_preview_bg = Color3.fromRGB(255, 255, 255), -- White background (same as main background)
            pet_preview_border = Color3.fromRGB(0, 100, 200), -- Blue border
            very_rare_text = Color3.fromRGB(150, 0, 0), -- Dark red for very low chances

            -- Pet container colors (individual pet frames)
            pet_container_bg = "rarity", -- "rarity" = use rarity color, or set Color3 for uniform
            pet_container_transparency = 0.7, -- Slightly more opaque for better visibility
            pet_container_border = Color3.fromRGB(200, 200, 200), -- Light gray border

            -- Pet icon/viewport colors
            pet_icon_bg = Color3.fromRGB(240, 240, 240), -- Light gray viewport background
            pet_icon_transparency = 0.2, -- Semi-transparent to show slight background
        },

        -- Corner Radius
        corner_radius = 12,
        border_thickness = 2,

        -- Pet-preview billboard background/border opacity (QoL). 1 = fully transparent
        -- (just the floating pet cards, no box); 0 = solid. Applies to the EggPetPreview
        -- BillboardGui frame in EggPetPreviewService.
        pet_preview_bg_transparency = 1,
        pet_preview_border_transparency = 1,

        -- Fonts
        fonts = {
            title = Enum.Font.GothamBold,
            prompt = Enum.Font.Gotham,
            notification = Enum.Font.Gotham,
            pet_name = Enum.Font.GothamBold,
            pet_chance = Enum.Font.Bangers,

            -- Pet container fonts (for individual pet displays)
            pet_icon_fallback = Enum.Font.GothamBold, -- Font for emoji fallback icons (currently used)
            pet_name_secondary = Enum.Font.Gotham, -- Alternative pet name font (available for future use)
            pet_stats = Enum.Font.RobotoMono, -- For detailed pet stats (available for future use)
            rarity_label = Enum.Font.GothamBold, -- For rarity indicators (available for future use)

            -- Available font options (you can swap any of the above to these):
            -- Standard fonts that work reliably:
            -- Enum.Font.Gotham                         - Clean, readable (being replaced by Montserrat)
            -- Enum.Font.GothamBold                     - Bold version of Gotham
            -- Enum.Font.GothamBlack                    - Extra bold Gotham
            -- Enum.Font.Montserrat                     - Replacement for Gotham
            -- Enum.Font.MontserratBold                 - Bold Montserrat
            -- Enum.Font.Arimo                          - Replacement for Arial
            -- Enum.Font.ArimoBold                      - Bold Arimo
            -- Enum.Font.SourceSans                     - Clean, readable
            -- Enum.Font.SourceSansBold                 - Bold Source Sans
            -- Enum.Font.RobotoMono                     - Monospace alternative
            -- Enum.Font.SpecialElite                   - Typewriter style
            -- Enum.Font.Creepster                      - Horror/spooky theme
            -- Enum.Font.Bangers                        - Comic book style
            -- Enum.Font.Kalam                          - Handwritten style
            -- Enum.Font.PatrickHand                    - Casual handwritten
            --
            -- Note: Builder fonts may require special installation or may not be
            -- available by default. Use the fonts listed above for guaranteed compatibility.
        },

        -- Animation Settings
        animations = {
            slide_in_time = 0.3,
            slide_in_style = Enum.EasingStyle.Back,
            slide_in_direction = Enum.EasingDirection.Out,
        },
    },

    -- === PET PREVIEW SETTINGS ===
    pet_preview = {
        enabled = true, -- Whether to show pet preview when approaching eggs
        show_title = false, -- Whether to show title (saves space when false)
        title_text = "Pet Chances", -- Text to display in title (configurable)
        height_above_egg = 7, -- Default studs above egg to position billboard
        billboard_size = { 15, 4.5 }, -- BillboardGui size in studs [width, height]

        -- Per-egg height adjustments (optional - overrides default height_above_egg)
        -- Useful for eggs of different sizes that need custom spacing
        egg_height_overrides = {
            -- ["basic_egg"] = 2.5,          -- Basic egg uses 2.5 studs instead of default 7
            -- ["rare_egg"] = 8,             -- Rare egg uses 8 studs (taller egg needs more space)
            -- ["legendary_egg"] = 10,       -- Legendary egg uses 10 studs (very tall egg)
        },

        min_chance_to_show = 0.0001, -- Minimum chance (0.01%) to show pet, lower shows as "??"
        max_pets_to_display = 6, -- Maximum number of pets to show in preview (fits horizontal layout)
        grid_columns = 5, -- Number of columns in pet grid (horizontal row)
        pet_icon_size = 60, -- Size of each pet icon in pixels
        pet_spacing = 15, -- Horizontal spacing between pets in pixels
        smart_percentage_formatting = true, -- Use intelligent digit formatting (25%, 1%, 0.01%)
        fallback_precision = 2, -- Fallback decimal places if smart formatting disabled

        -- Display settings
        show_variant_names = true, -- Show "Golden Bear" vs just "Bear"
        group_by_rarity = true, -- Group pets by rarity in display
        sort_by_chance = true, -- Sort pets by chance (highest first)

        -- Per-egg display overrides (optional - overrides global settings)
        egg_display_overrides = {
            -- Per-egg customization examples:
            -- ["basic_egg"] = {
            --     show_variant_names = false,        -- Hide pet names for this egg
            --     pet_container_transparency = 1.0,  -- Make containers fully transparent
            --     pet_container_bg = Color3.fromRGB(50, 50, 50),  -- Custom bg color (overrides rarity)
            -- },
            -- ["grass_egg"] = {
            --     pet_container_bg = Color3.fromRGB(120, 200, 120), -- Custom bg for this egg
            --     pet_container_transparency = 0.3,                -- More opaque
            --     min_chance_to_show = 0.00001,                   -- Show even rarer pets (0.001%)
            -- },
            -- ["legendary_egg"] = {
            --     min_chance_to_show = 0.000001,                  -- Ultra rare threshold (0.0001%)
            -- },
        },

        -- Asset loading
        load_pet_icons = true, -- Whether to load actual pet model icons (3D models)
        fallback_to_emoji = true, -- Use emoji if asset loading fails
        icon_cache_time = 300, -- Time to cache loaded icons (seconds)

        -- 3D Model display options
        enable_model_spinning = true, -- Whether 3D models should rotate/spin
        model_rotation_speed = 1, -- Rotation speed (degrees per frame)
        static_camera_angle = 45, -- Camera angle if spinning disabled (degrees)
    },

    -- === ERROR MESSAGES ===
    messages = {
        character_not_ready = "Character not ready",
        egg_not_found = "Egg not found",
        too_far_away = "You must be closer to the egg",
        egg_config_error = "Egg configuration error",
        server_not_ready = "Server not ready, please restart game",
        connection_error = "Connection error",
        purchase_failed = "Purchase failed",
        insufficient_currency = "Insufficient funds",
        transaction_failed = "Transaction failed",
        hatching_failed = "Hatching failed",
        cooldown_active = "Please wait before purchasing again",
    },

    -- === DEBUG SETTINGS ===
    debug = {
        log_proximity_changes = true, -- Log when entering/leaving egg range
        log_server_calls = true, -- Log setLastEgg server calls
        log_ui_updates = false, -- Log UI position updates (performance impact)
        log_distance_checks = false, -- Log distance calculations (very verbose)
    },

    -- === SPAWNING SETTINGS ===
    spawning = {
        spawn_point_name = "EggSpawnPoint", -- Name of parts to look for as spawn points
        search_workspace = true, -- Whether to search entire workspace for spawn points
        auto_spawn_on_startup = true, -- Whether to spawn eggs automatically on server start
        respawn_delay = 0, -- Delay before respawning egg after purchase (0 = immediate)
    },

    -- === VALIDATION SETTINGS ===
    validation = {
        -- Server-side validation strictness
        enforce_distance_check = true, -- Always validate distance on server
        enforce_currency_check = true, -- Always validate currency on server
        enforce_cooldown_check = true, -- Always validate cooldowns on server

        -- Client-side pre-validation
        client_distance_precheck = true, -- Check distance on client before server call
        client_currency_preview = true, -- Show currency requirements in UI
    },
}
