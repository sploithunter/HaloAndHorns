--[[
    Hall of Worlds — guided Level 1-5 entry world.

    FuturePath is baked authored geometry. Runtime systems bind progression,
    currency gates, eggs, encounters, and portals to it; they do not generate
    or replace structural tiles.
]]

return {
    enabled = true,
    version = 2,
    minimum_level = 1,
    map_name = "FuturePath",
    initial_area = "Hall_1",
    crystal_world_area = "Spawn",
    -- Authored moveable pad under Maps.FuturePath. WorldBinding binds it as
    -- Hall_1 PlayerSpawn. The wire pass adopts it in place and never snaps it.
    player_spawn = {
        part_name = "HallSpawn",
        area_id = "Hall_1",
    },
    currency = "hall_coins",
    crystal_world_effectiveness = 0.8,

    -- Ambient jamb-to-jamb bolts on Hall gate arches. Authored lightning*
    -- markers are already grouped under each host; the client can also sample
    -- a host's bounds if a streamed copy arrives without markers.
    arch_lightning = {
        enabled = true,
        part_prefix = "lightning",
        adopt_workspace_parts = true,
        host_names = {
            "TrainingGroundPadGateVisual",
            "RangePadGateVisual",
            "CrystalWorldGateVisual",
            "CrystalWorldReturnGateVisual",
            "HallOfWorldsGateVisual",
            "HellFaceGateTest",
        },
        host_tag = "ArchLightning",
        hide_markers = true,
        sample_rows = 9,
        cluster_radius = 48,
        view_distance = 180,
        interval_min = 0.05,
        interval_max = 0.14,
        bolts_per_pulse = 2,
        prefer_cross = true,
        min_cross_span = 8,
        bolt = {
            enabled = true,
            duration = 0.3,
            thickness = 0.22,
            segments = 16,
            origin_limit = 1,
            strands_per_origin = 2,
            min_radius = 0,
            max_radius = 0.6,
            curve_size0 = 0,
            curve_size1 = 0,
            center_flash = false,
            animation_speed = 9,
            flicker = 0.4,
            fade_out_seconds = 0.12,
            target_offset = { 0, 0, 0 },
            colors = { { 120, 150, 255 }, { 200, 235, 255 } },
            sound_name = "_silent",
        },
        -- The rapid visual cadence stays silent. A separate positional buzz
        -- plays softly and no more than about once per second near the player.
        sound = {
            name = "arch_lightning_buzz",
            -- The source clip is quiet and still passes through the player's
            -- Effects slider. This remains subdued at normal mix settings but
            -- stays audible when Effects is turned down.
            volume = 0.55,
            interval_min = 0.65,
            interval_max = 1.1,
            roll_off_min_distance = 24,
            roll_off_max_distance = 90,
        },
    },

    theme = {
        id = "wayfinder_hall",
        display_name = "Wayfinder Hall",
        description = "A gilded concourse connecting every world.",
    },

    -- Soft horizon so the floating concourse does not read as outer space when
    -- tiles stream out. FogEnd sits inside a typical 1024-stud StreamingTargetRadius;
    -- Atmosphere.Haze is the real hide (classic Fog* is ignored while Atmosphere exists).
    -- Color is pale mint-sky, never the purple aurora void.
    atmosphere = {
        fog_start = 260,
        fog_end = 680,
        fog_color = { 208, 228, 232 },
        density = 0.3,
        offset = 0.35,
        color = { 214, 232, 236 },
        decay = { 188, 214, 222 },
        glare = 0.12,
        haze = 2.8,
    },

    -- Hall pedestals are authored map fixtures, same as Crystal World. The Studio wiring
    -- pass seats them on the real nook/floor; runtime only places the egg on UIanchor.
    -- The egg's bob is client-visual only; the stand anchor remains fixed for interaction.
    egg_stand = {
        model_asset_id = 124799395948890,
        texture_id = "rbxassetid://81791717345802",
        target_max_dimension = 12,
        -- Hall egg meshes import at ~1 stud. The shared Crystal World stand
        -- scale (3.5) leaves them tiny in this 12-stud pedestal cup.
        egg_scale = 8,
        egg_offset_y = 0.5,
        egg_target_max_dimension = 8,
        egg_hover_height = 1.25,
        prompt_height = 4.8,
        float_amplitude = 0.3,
        float_period = 3.4,
    },

    -- Authored gameplay footprints. These records adopt the SpawnZone parts baked into each tile;
    -- they never recreate their geometry from duplicate coordinates. A marker can share an area_id
    -- with another marker (the two corridor turns do), so spawning and the moving dotted marquee
    -- cover the exact union of green fields without accepting the surrounding sidewalks.
    play_areas = {
        Hall_1 = {
            area_id = "Hall_1",
            tile_name = "Tile01_cap",
            marker_name = "SpawnZone",
            spawner_id = "spawn_crystals",
            slot_layout = "random",
            marquee = {
                dash_length = 4.5,
                dash_width = 1.3,
                dash_height = 0.4,
                dash_spacing = 8,
                speed = 14,
            },
        },
        Hall_2_A = {
            area_id = "Hall_2",
            tile_name = "Tile03_playfield",
            marker_name = "SpawnZone",
            spawner_id = "spawn_crystals",
            slot_layout = "random",
        },
        Hall_2_B = {
            area_id = "Hall_2",
            tile_name = "Tile04_corner",
            marker_name = "SpawnZone",
            spawner_id = "spawn_crystals",
            slot_layout = "random",
        },
        Hall_3_A = {
            area_id = "Hall_3",
            tile_name = "Tile06_playfield",
            marker_name = "SpawnZone",
            spawner_id = "spawn_crystals",
            slot_layout = "random",
        },
        Hall_3_B = {
            area_id = "Hall_3",
            tile_name = "Tile07_corner",
            marker_name = "SpawnZone",
            spawner_id = "spawn_crystals",
            slot_layout = "random",
        },
        Hall_4 = {
            area_id = "Hall_4",
            tile_name = "Tile09_cap",
            marker_name = "SpawnZone",
            spawner_id = "spawn_crystals",
            slot_layout = "random",
        },
    },

    -- Authored Hall encounters. The barn and fence live in Tile01_cap; this marker sits just
    -- inside the barn's field-facing doorway so the tutorial trail, proximity wave, and actual
    -- fight all resolve to the same place. BaddieSpawnerService owns the encounter lifecycle.
    encounters = {
        barn = {
            spawner_name = "BaddieSpawnerHallBarn",
            area_id = "Hall_1",
            center = { x = 2165, y = 3, z = -203 },
            size = { x = 12, y = 2, z = 12 },
            faction = "earth",
            use_area_currency_loot = true,
        },
    },

    -- Costs are deliberately isolated here and mirrored by configs/areas.lua.
    -- They are early-beta balance knobs, not baked into the map.
    route = {
        {
            id = "arrival",
            area_id = "Hall_1",
            display_name = "Wayfinder Landing",
            egg = { egg_id = "wayfinder_egg", pet_choice_count = 5 },
            unlock = { kind = "default" },
        },
        {
            id = "level_gate",
            area_id = "Hall_2",
            display_name = "Gilded Gallery",
            egg = { egg_id = "hall_gilded_egg", pet_choice_count = 5, cost = 400 },
            unlock = {
                kind = "level",
                required_level = 2,
                tutorial_required = true,
            },
        },
        {
            id = "coin_gate_1",
            area_id = "Hall_3",
            display_name = "Vanguard Walk",
            -- Bay 3 is the first post-tutorial Hall egg to graduate from an art preview into a
            -- live hatcher. EggStandPlacement resolves this config at runtime, so an older baked
            -- marker cannot silently leave the finished egg noninteractive.
            egg = { egg_id = "vanguard_egg", pet_choice_count = 5, cost = 1000 },
            unlock = { kind = "currency", currency = "hall_coins", cost = 750 },
        },
        {
            id = "coin_gate_2",
            area_id = "Hall_4",
            display_name = "Worlds Plaza",
            egg = { egg_id = "worldheart_egg", pet_choice_count = 5, cost = 2500 },
            unlock = { kind = "currency", currency = "hall_coins", cost = 2500 },
        },
    },

    final_plaza = {
        area_id = "Hall_4",
        crystal_world_gate_target = "Spawn",
        requires_tutorial = true,
    },

    -- Hall 1 nook return door. Open only after entered_crystal_world
    -- (legacy grandfather or Plaza first exit). Not a Hall skip.
    crystal_world_return = {
        tile_name = "Tile01_cap",
        pad_name = "Archpad",
        source_area = "Hall_1",
        target_area = "Spawn",
        title = "CRYSTAL WORLD",
        lock_action = "Finish the Hall",
    },

    -- Reserved spokes from Worlds Plaza. These are design contracts only until
    -- their authored tiles and services are added.
    future_spokes = {
        challenge_field = {
            enabled = false,
            no_pet_revives = true,
            leaderboards = { "daily", "all_time" },
        },
        clone_missions = {
            enabled = false,
            fixed_squad = true,
            no_pet_revives = true,
        },
        luck_egg = { enabled = false, interaction = "timing" },
        event_gate = { enabled = false },
    },

    -- Kept for compatibility with the retired optional combat-route service.
    -- The new Hall route is driven by `route` and authored area bindings.
    stages = {},
}
