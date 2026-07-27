--[[
    Future Call — the Level-5 progression consumable.

    The token manifests an authored future version of the player for two minutes.
    Its combat level is the caller's current earned level plus five, capped by the
    game's progression level cap.
    It is deliberately a consumable rather than a power: Level 5 already asks the
    player to choose an Origin and place two enhancement slots, while the first
    Origin power remains the Level-6 reward.
]]

return {
    enabled = true,

    entitlement = {
        grants = {
            {
                claimed_level = 5,
                grant_count = 5,
                marker = "level5_v2",
                -- Profiles that received the original three-token Level-5 grant get
                -- only the two-token difference when this schedule reconciles.
                legacy = { marker = "level5_v1", granted_count = 3 },
            },
            { claimed_level = 6, grant_count = 4, marker = "level6_v1" },
            { claimed_level = 7, grant_count = 3, marker = "level7_v1" },
            { claimed_level = 8, grant_count = 2, marker = "level8_v1" },
            { claimed_level = 9, grant_count = 1, marker = "level9_v1" },
        },
    },

    token = {
        id = "future_call_token",
        display_name = "Future Call",
        type = "Summon token",
        description = "Call your future self 5 levels ahead with four powered-up pets for 2 minutes.",
        duration = 120,
        icon_power = "world_travel",
    },

    principal = {
        name_format = "%s's Future Self",
        display_name_format = "%s's Future Self",
        avatar_owner = true,
        level_offset = 5,
        duration = 120,
        walk_speed = 24,
        follow_offset = { x = -8, y = 0, z = 6 },
        teleport_leash = 60,
        alliance = {
            enabled = false,
        },
        auto_farm = {
            enabled = true,
            mode = "nearest",
            retarget_seconds = 0.5,
        },
        powers = {},
        squad = {
            { pet = "polarbear", variant = "rainbow", role = "tank" },
            { pet = "dragon", variant = "golden", role = "ranged" },
            { pet = "penguin", variant = "rainbow", role = "support" },
            { pet = "snowleopard", variant = "rainbow", role = "melee" },
        },
    },
}
