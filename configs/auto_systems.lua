-- Phase 5 auto-system configuration.
-- Player profiles store choices; this file is the source of truth for valid
-- target modes, default settings, and which hatch filters designers allow.

return {
    version = "1.0.0",
    enabled = true,

    auto_target = {
        enabled = true,
        -- ON by default (Jason): pets auto-mine the moment a new player walks up to a
        -- crystal — the tutorial's farm step depends on it. Players who toggle Farm off
        -- keep their choice (persisted per player in data.Settings.AutoSystems).
        default_enabled = true,
        default_mode = "nearest",
        default_selected_currency = "crystals",
        current_world_only = true,
        request_interval_seconds = 0.3,
        -- Max distance (studs) a breakable can be auto-targeted from. Pets TRAVEL to
        -- any target within this; nothing farther is picked. INVARIANT: keep this
        -- BELOW pet_follow.lua movement.catchup_distance so the pet's teleport-snap
        -- only fires for a real player teleport (zone change), never to reach a normal
        -- target — otherwise pets appear to teleport to distant ore.
        max_target_distance = 120,
        modes = {
            nearest = {
                display_name = "Nearest",
                sort = "distance_asc",
            },
            highest_value = {
                display_name = "Highest Value",
                sort = "value_desc",
            },
            weakest = {
                display_name = "Weakest",
                sort = "hp_asc",
            },
            strongest = {
                display_name = "Strongest",
                sort = "hp_desc",
            },
            selected_currency = {
                display_name = "Selected Currency",
                sort = "value_desc",
                requires_currency = true,
            },
        },
        compatibility_toggles = {
            -- Free farming = NEAREST (minimize travel). With flat ~26 studs/s pets, the old free
            -- mode (weakest) sent pets chasing the smallest crystals scattered across the zone, so
            -- travel time dominated and effective DPS cratered to ~half of paid. Nearest keeps pets
            -- on whatever's closest -> max uptime -> the best DPS the slow-pet baseline allows. The
            -- paid pass adds value-targeting (camp the biggest payouts / AFK-friendly), not raw speed.
            free_mode = "nearest",
            paid_mode = "highest_value",
        },
    },

    auto_delete = {
        enabled = true,
        default_enabled = false,
        allow_rarity_filters = true,
        allow_pet_type_filters = true,
        allow_variant_filters = true,
        protect_unique = true,
        protected_rarities = {
            secret = true,
            exclusive = true,
            huge = true,
        },
        defaults = {
            rarities = {},
            pet_types = {},
            variants = {},
        },
    },
}
