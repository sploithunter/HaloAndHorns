--[[
    Studio-only Merge an Egg Phase 5.

    This is deliberately one authored strip under Workspace.Maps. It does not use the tile kit,
    mission layout generation, or any streaming/chunk lifecycle. Four stationary NPC principals
    own independently targeted temporary defense squads; every principal, unit, and enemy remains
    session-only.
]]

return {
    version = 5,
    enabled = true,
    stream_timeout = 8,

    gate = {
        hook_name = "HallOfWorldsPortal",
        prompt_name = "MergeEggPrototypeEnterPrompt",
        action_text = "Enter Prototype",
        object_text = "Merge an Egg — Phase 5",
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
        egg_id = "grass_egg",
        initial_hatch_count = 5,
    },

    -- The shipping egg roll is now the source of every prototype pet. This queue experiment
    -- preserves each NPC team's five stable slots: a defeated slot enters that captain's FIFO, and
    -- a fresh Home Grass Egg outcome hatches into that slot at the stationary captain before
    -- traveling back to battle. Species, variant, and the rare Huge roll can change; only the slot
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
        spawn_inset = 5,
        finish_inset = 5,
        portal_spawn_interval = 0.15,
        -- The first assignment in every non-empty team group is a real tank role. Keeping one
        -- tank per group (rather than a global tank count) makes the 3/5/8/... ladder comparable
        -- even when round-robin assignment leaves one team idle.
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
        { count = 3 },
        { count = 5 },
        { count = 8 },
        { count = 12 },
        { count = 16 },
        { count = 24 },
        { count = 32 },
        { count = 48 },
    },
}
