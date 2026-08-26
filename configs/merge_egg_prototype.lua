--[[
    Studio-only Merge an Egg Phase 1.

    This is deliberately one authored strip under Workspace.Maps. It does not use the tile kit,
    mission layout generation, or any streaming/chunk lifecycle. The prototype service is only
    registered in Studio and every unit/enemy it creates is session-only.
]]

return {
    version = 1,
    enabled = true,
    stream_timeout = 8,

    gate = {
        hook_name = "HallOfWorldsPortal",
        prompt_name = "MergeEggPrototypeEnterPrompt",
        action_text = "Enter Prototype",
        object_text = "Merge an Egg — Phase 1",
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
        bounds = {
            center_x = -16000,
            center_z = 0,
            half_x = 46,
            half_z = 296,
            inset = 3,
        },
    },

    squad = {
        { pet = "trail_pup", variant = "basic" },
        { pet = "trail_pup", variant = "basic" },
        { pet = "trail_pup", variant = "basic" },
        { pet = "pack_tortoise", variant = "basic" },
        { pet = "compass_fox", variant = "basic" },
    },

    enemy = {
        id = "lava_imp",
        hp = 320,
        level = 1,
        damage = 4,
        cadence = 2,
        march_speed = 22,
        finish_distance = 2,
        spawn_inset = 5,
        finish_inset = 5,
    },

    wave_gap = 2,
    waves = {
        { count = 3 },
        { count = 5 },
        { count = 8 },
    },
}
