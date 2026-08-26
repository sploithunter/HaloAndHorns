--[[
    Studio-only Merge an Egg Phase 6.

    This is deliberately one authored strip under Workspace.Maps. It does not use the tile kit,
    mission layout generation, or any streaming/chunk lifecycle. Four stationary NPC principals
    own independently targeted temporary defense squads; every principal, unit, and enemy remains
    session-only.
]]

return {
    version = 6,
    enabled = true,
    stream_timeout = 8,

    gate = {
        hook_name = "HallOfWorldsPortal",
        prompt_name = "MergeEggPrototypeEnterPrompt",
        action_text = "Enter Prototype",
        object_text = "Merge an Egg — Phase 6",
        title = "MERGE AN EGG\nPROTOTYPE",
    },

    world = {
        maps_root = "Maps",
        model_name = "MergeEggPrototype",
        player_spawn = "PlayerSpawn",
        hatcher_control = "HatcherControl",
        hatcher_spawn = "HatcherSpawn",
        reset_control = "ResetControl",
        exit_control = "ExitControl",
        enemy_spawn_area = "EnemySpawnArea",
        enemy_finish_line = "EnemyFinishLine",
        bulwark_line = "BulwarkLine",
        breach_line = "BreachLine",
        enemy_portal_visual = "EnemyPortalVisual",
        bounds = {
            center_x = -16000,
            center_z = -150,
            half_x = 46,
            half_z = 149,
            inset = 1,
        },
    },

    -- The existing Future Self / Colorado NPC-principal lifecycle consumes this base definition.
    -- The owner avatar is a temporary visual stand-in for four purpose-built hatcher NPC assets.
    principal = {
        avatar_owner = true,
        level = 1,
        squad = {},
        alliance = { enabled = false },
        powers = {},
        auto_farm = { enabled = false },
    },

    -- Required by the config schema for compatibility; Phase 5 never reads a fixed roster.
    squad = {},

    team = {
        return_ready_distance = 20,
        starts_with_egg = false,
        -- Capacity now belongs to the world stage. Home fields three pets per hatcher and Heaven
        -- Layer 1 fields four; egg tier changes draft quality, not formation size.
        positions_by_egg_tier = { 3, 3, 3, 3 },
        -- Studio balance variants keep the actual pet definitions immutable. The runner can select
        -- one with { automation = "coin_runner", experiment = <id> } for matched A/B/C runs.
        balance_experiments = {
            default = "world_draft",
            modes = {
                world_draft = {
                    stage_positions = true,
                    draft_quality = true,
                    origin_power_per_tier = 0,
                },
                positions = {
                    positions_by_egg_tier = { 3, 4, 5, 6 },
                    origin_power_per_tier = 0,
                },
                origin_10 = {
                    positions_by_egg_tier = { 4, 4, 4, 4 },
                    origin_power_per_tier = 0.10,
                },
                origin_20 = {
                    positions_by_egg_tier = { 4, 4, 4, 4 },
                    origin_power_per_tier = 0.20,
                },
            },
        },
        earth_egg_pricing = {
            currency = "hall_coins",
            base_amount = 100,
            -- Reserved for paid upgrades within each position: Earth 100, Ice 200, Lava 400.
            -- Installing the first Earth Egg in any other empty position still costs 100.
            growth = 2,
        },
        -- The existing camera-facing button is only a presentation surface. The server accepts an
        -- egg action when the avatar is both safely behind the actual BulwarkLine and physically
        -- beneath the selected captain's button.
        build_access = {
            minimum_bulwark_depth = 4,
            maximum_hatcher_distance = 18,
        },
        -- Each captain begins empty. Creating its first egg fills the world's fixed formation;
        -- each later egg becomes the source and increases best-of-N quality for future FIFO rolls.
        egg_progression = {
            "grass_egg",
            "ice_egg",
            "lava_egg",
            "desert_egg",
        },
    },

    -- A stage owns capacity, egg families, pricing, and balance scaling. Home completion carries
    -- the actual collected Waycoin balance into Heaven 1. Heaven 1 can also be launched directly
    -- with its minimum four-Egg opening reserve, so later tuning does not depend on replaying Home.
    progression_loop = {
        default_stage = "home",
        order = { "home", "heaven_1" },
        stages = {
            home = {
                display_name = "Home",
                team_positions = 3,
                egg_progression = {
                    "grass_egg",
                    "ice_egg",
                    "lava_egg",
                    "desert_egg",
                },
                draft_rolls_by_tier = { 1, 2, 3, 4 },
                egg_pricing = {
                    currency = "hall_coins",
                    base_amount = 100,
                    growth = 2,
                },
                starting_coins = 100,
                enemy = {
                    hp_multiplier = 1,
                    damage_multiplier = 1,
                    reward_multiplier = 1,
                },
                next_stage = "heaven_1",
            },
            heaven_1 = {
                display_name = "Heaven • Layer 1",
                team_positions = 4,
                -- Preserve the Home origin order: Earth, Ice, Lava, Desert.
                egg_progression = {
                    "bloom_egg",
                    "aurora_egg",
                    "solar_egg",
                    "gilded_egg",
                },
                draft_rolls_by_tier = { 1, 2, 3, 4 },
                egg_pricing = {
                    currency = "hall_coins",
                    base_amount = 1600,
                    growth = 2,
                },
                -- Four first-tier Heaven eggs. Sequential runs carry their real Home balance;
                -- isolated Heaven runs use this conservative minimum unless explicitly overridden.
                independent_starting_coins = 6400,
                enemy = {
                    hp_multiplier = 2.25,
                    damage_multiplier = 1.5,
                    reward_multiplier = 5,
                },
            },
        },
    },

    -- A Studio-only upper-bound balance runner. It temporarily gives the active prototype session
    -- the real new-player 100-Waycoin bankroll, walks the actual avatar to physical drops, returns
    -- beneath each captain, and uses the same purchase method as the billboard. Reset/exit restores
    -- the tester's pre-run Waycoin balance. A full loop sweeps every remaining drop after a stage,
    -- carries the measured balance forward, and can restart Heaven 1 from its minimum reserve.
    automation = {
        coin_runner = {
            starting_coins = 100,
            random_seed = 260826,
            target_hatchers = 4,
            sequential_stages = true,
            completed_drop_poll_seconds = 0.6,
            navigation_timeout = 18,
            hatcher_arrival_distance = 7,
            drop_arrival_distance = 6,
            idle_poll_seconds = 0.15,
            maximum_navigation_failures = 8,
        },
    },

    -- The shipping egg roll is now the source of every prototype pet. This queue experiment
    -- preserves each NPC team's world-scaled stable slots: a defeated slot enters its captain's
    -- FIFO, then the current egg supplies one to four candidates before the composition-aware draft
    -- picks the replacement. Species, variant, and the rare Huge roll can change; only the slot
    -- itself remains stable.
    -- Four real seconds at 4× combat approximates a 16-second production cadence for comparison.
    reinforcement = {
        enabled = true,
        hatch_seconds = 4,
        queue_policy = "per_team_fifo_random_egg_roll",
    },

    -- Five protected reserve eggs are the prototype's base health. A marcher that reaches the rear
    -- line destroys one; losing the fifth ends the run. Replacement hatches are intentionally
    -- abstract/unlimited in this pass so objective pressure and queue throughput remain separable.
    objective = {
        starting_eggs = 5,
        damage_per_escape = 1,
        -- First destructible-hatcher experiment: a rear-line arrival destroys the installed egg
        -- on its assigned lane immediately. Existing pets remain, but replacements stop until the
        -- player rebuilds that lane from its first egg. Attack windup/durability comes later.
        hatcher_egg_health = 1,
        hatcher_egg_damage_per_arrival = 1,
    },

    -- Defeats pay only the prototype's board currency. The physical pickup and HUD art reuse the
    -- Hall Waycoin identity, while collection uses a prototype-owned radius attribute so later
    -- board upgrades can scale it without inheriting the player's regular Magnet build.
    -- Baseline 8/30 rewards could not fund the 100-Waycoin second position before a Wave 3
    -- objective loss (the perfect runner earned only 62). The first balance correction targets the
    -- authored cadence directly: three Wave 1 Whelps gross 120 for position two, while Wave 2's
    -- Brute plus four Whelps gross 280 toward positions three/four and future upgrades.
    rewards = {
        currency = "hall_coins",
        trash_amount = 40,
        tank_amount = 120,
        magnet = {
            base_radius = 10,
            use_player_modifiers = false,
        },
    },

    -- Early-balance accelerator: both sides attack four times as often. Movement, regeneration,
    -- aggro decay, and wave timing remain at real speed so the lane still reads clearly.
    combat = {
        attack_cadence_multiplier = 4,
    },

    debug = {
        trace_bulwark_aggro = true,
        bulwark_trace_seconds = 2,
    },

    -- Keep enemy stats fixed so this isolates concurrency and cumulative squad endurance. With
    -- replacement queues enabled, an empty field may recover; the protected egg reserve is defeat.
    endurance = {
        stop_when_all_teams_defeated = false,
    },

    teams = {
        {
            id = 1,
            principal_name = "Merge Hatcher Team 1",
            principal_display_name = "Hatcher Captain 1",
            display_name = "NPC Team 1",
            spawn_offset = { x = -24, z = 0 },
        },
        {
            id = 2,
            principal_name = "Merge Hatcher Team 2",
            principal_display_name = "Hatcher Captain 2",
            display_name = "NPC Team 2",
            spawn_offset = { x = -8, z = 0 },
        },
        {
            id = 3,
            principal_name = "Merge Hatcher Team 3",
            principal_display_name = "Hatcher Captain 3",
            display_name = "NPC Team 3",
            spawn_offset = { x = 8, z = 0 },
        },
        {
            id = 4,
            principal_name = "Merge Hatcher Team 4",
            principal_display_name = "Hatcher Captain 4",
            display_name = "NPC Team 4",
            spawn_offset = { x = 24, z = 0 },
        },
    },

    enemy = {
        id = "lava_imp",
        hp = 320,
        armor = 0,
        level = 1,
        damage = 4,
        cadence = 2,
        march_speed = 22,
        finish_distance = 2,
        engagement_distance = 260,
        engagement_threat = 250,
        reengage_seconds = 1,
        -- Past the authored BulwarkLine, strict team ownership ends. A breached enemy becomes an
        -- open emergency target and every surviving hatcher folder receives a sustained ordinary
        -- threat floor. The breach plane uses authoritative MoveTarget plus the enemy's forward
        -- visual extent, never its stale server pivot (client interpolation owns visible movement).
        -- Refreshing the floor lets a team finish its current target, then respond.
        bulwark_threat = 250,
        bulwark_reengage_seconds = 0.5,
        bulwark_contact_padding = 1,
        -- BulwarkLine still means all teams engage. The separate red BreachLine sits before the
        -- hatchers; crossing it is the authoritative breach. "Overrun" is a warning state, not the
        -- final egg-loss condition: it begins when breached enemies equal the remaining defenders.
        breach_overrun_enemy_per_active_pet = 1,
        breach_overrun_minimum = 4,
        spawn_inset = 5,
        finish_inset = 5,
        portal_spawn_interval = 0.15,
        -- A tank-led attack group uses one Brute as its lead unit. Trash groups use only Whelps.
        -- Later waves without authored groups retain one tank lead per assigned hatcher front.
        tank = {
            id = "ember_brute",
            hp = 1600,
            armor = 80,
            level = 1,
            damage = 10,
            cadence = 2,
        },
    },

    wave_gap = 2,
    waves = {
        -- Opening cadence teaches one readable pressure change at a time. Attack groups select
        -- initialized hatchers first, then empty positions, so failing to install a second egg
        -- before Wave 2 deliberately leaves its second front undefended.
        {
            count = 3,
            gap_after = 8,
            groups = {
                { kind = "trash", count = 3 },
            },
        },
        {
            count = 5,
            gap_after = 8,
            groups = {
                { kind = "tank", count = 1 },
                { kind = "trash", count = 4 },
            },
        },
        {
            count = 8,
            gap_after = 6,
            groups = {
                { kind = "tank", count = 4 },
                { kind = "trash", count = 4 },
            },
        },
        { count = 12 },
        { count = 16 },
        { count = 24 },
        { count = 32 },
        { count = 48 },
        { count = 56 },
        { count = 64 },
        { count = 72 },
        { count = 80 },
        { count = 96 },
        { count = 112 },
        { count = 128 },
        { count = 144 },
        { count = 160 },
        { count = 176 },
        { count = 192 },
        { count = 208 },
    },
}
