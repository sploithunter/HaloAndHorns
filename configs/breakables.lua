--[[
    Breakables — crystals + Pet Realm zone ORE families.

    Zone economy (design §32): each elemental zone has one ore family that pays that
    zone's soulbound coin. One ore family per element, three size tiers (Small/Medium/
    Large) for the payoff; the size is driven by `scale` (bounds-based floor alignment
    re-sits any scale, with per-tier `sink_depth` to fine-tune the elevation).

    MESHES (in progress): each element will get THREE cosmetic mesh variants for variety,
    resized to S/M/L. Drop the asset IDs into `ORE_FAMILIES[*].variants` below — when a
    family has >1 variant the preloader/spawner can pick one at random (follow-up). Until
    real meshes land, every ore uses the existing blue-crystal meshes (sized S/M/L) as a
    PLACEHOLDER so the economy loop is fully testable now. Random yaw + elevation offset
    are already handled by BreakableSpawner (same as crystals).
]]

-- Placeholder meshes = the three existing blue crystals (already S/M/L sized).
local ORE_PLACEHOLDER = {
    Small = "rbxassetid://112188519963572",
    Medium = "rbxassetid://113452230594676",
    Large = "rbxassetid://109710590640681",
}

-- One entry per elemental zone. `variants` holds this element's cosmetic mesh IDs
-- (fill when meshes are ready, e.g. { "rbxassetid://A", "rbxassetid://B", "rbxassetid://C" });
-- empty = use the size placeholders above.
-- Per-family: `variants` = cosmetic mesh IDs (for now mapped one-per-size-tier so all 3
-- show; true random-variety-within-size is a follow-up). `scale` multiplies every tier's
-- scale (use it to size a new mesh family up/down vs the placeholders). `orientation` lets
-- a family override the import-orientation fix (different meshes import differently).
local ORE_FAMILIES = {
    {
        el = "grass",
        display = "Bloomstone",
        currency = "grass_coins",
        -- Cosmetic variants (random-pick per spawn). `norm` normalizes each mesh's wildly
        -- different import size to a common ~6-stud base (measured native max: 7.7 / 1.9 / 1.9),
        -- so the size tier alone decides how big it reads.
        variants = {
            { asset = "rbxassetid://100630669468901", norm = 0.78 }, -- Emerald_Crystal_1 (native 7.7)
            { asset = "rbxassetid://72360244393742", norm = 3.16 }, -- Emerald_Crystal_2 (native 1.9)
            { asset = "rbxassetid://121055776582247", norm = 3.16 }, -- Emerald_Crystal_3 (native 1.9)
        },
        scale = 1, -- family-wide multiplier on top of normalization
        orientation = { x = 0, y = 0, z = 0 }, -- emerald meshes import upright (unlike the blue crystals)
        -- Self-glow: a soft PointLight in the node, themed per element (shadows off, cheap).
        -- brightness 0.75 = the tuned "gentle gem shimmer" sweet spot; range keeps it local.
        glow = { color = { 80, 255, 120 }, brightness = 0.75, range = 16 },
    },
    {
        el = "desert",
        display = "Sunglass",
        currency = "desert_coins",
        variants = {
            { asset = "rbxassetid://94786603011124", norm = 3.15 }, -- Citrine_Crystal_Cluster_1 (native 1.91)
            { asset = "rbxassetid://90886294637792", norm = 3.15 }, -- Citrine_Crystal_Cluster_2 (native 1.91)
            { asset = "rbxassetid://106635944648380", norm = 3.14 }, -- Citrine_Crystal_Cluster_3 (native 1.91)
        },
        scale = 1,
        orientation = { x = 0, y = 0, z = 0 }, -- assume upright; verify live
        glow = { color = { 255, 205, 130 }, brightness = 0.75, range = 16 },
    },
    {
        el = "lava",
        display = "Emberstone",
        currency = "lava_coins",
        -- Cosmetic variants (random-pick). `norm` placeholders = 1 until measured live, then
        -- set to 6/<native max studs> like the emeralds so all read ~6 studs at Medium.
        variants = {
            { asset = "rbxassetid://81424041024347", norm = 3.14 }, -- EmberCrystal1 (native 1.91)
            { asset = "rbxassetid://91219330332155", norm = 3.14 }, -- EmberCrystal2 (native 1.91)
            { asset = "rbxassetid://84600281598015", norm = 3.25 }, -- EmberCrystal3 (native 1.84)
        },
        scale = 1,
        orientation = { x = 0, y = 0, z = 0 }, -- assume upright like emeralds; verify live
        glow = { color = { 255, 120, 40 }, brightness = 0.75, range = 16 },
    },
    {
        el = "ice",
        display = "Frostshard",
        currency = "ice_coins",
        -- Cosmetic variants (random-pick). `norm` placeholders = 1 until measured live, then
        -- set to 6/<native max studs> so all read ~6 studs at Medium.
        variants = {
            { asset = "rbxassetid://139713750428794", norm = 3.16 }, -- Azure_Crystal_Cluster_1 (native 1.90)
            { asset = "rbxassetid://116652270757215", norm = 3.15 }, -- Azure_Crystal_Cluster_2 (native 1.91)
            { asset = "rbxassetid://74298032032655", norm = 3.15 }, -- Azure_Crystal_Cluster_3 (native 1.91)
        },
        scale = 1,
        orientation = { x = 0, y = 0, z = 0 }, -- assume upright; verify live
        glow = { color = { 120, 220, 255 }, brightness = 0.75, range = 16 },
    },
}

-- Size tiers: payoff scales with size. `scale` multiplies the mesh (when real single-mesh
-- art lands); placement offsets mirror the crystals so each tier sits right on the floor.
-- `scale` is used for PLACEHOLDER families (the blue-crystal meshes are already sized per
-- tier, so scale stays 1). `size_scale` is used for real VARIANT families (normalized to a
-- common base, so the tier supplies the size): Small/Medium/Large ≈ 3.6 / 6 / 10.8 studs.
-- value = coins per break. value/HP is the income RATIO (coins/sec = DPS x value/HP). Live grass
-- homeworld: a 3-dog starter (~45 DPS) earned ~5 coins/sec, a 3-bear (~25 DPS) ~2.5 — too slow.
-- Raised the ratio 0.1 -> 0.2 (was 5/25/100, then 10/50/200, now 20/100/400) so dogs ~9 coins/sec
-- (100-coin grass egg in ~11s), bears ~5. DPS felt right; this lifts INCOME only. Pure dev knob.
local ORE_TIERS = {
    {
        suffix = "Small",
        scale = 1,
        size_scale = 0.6,
        health = 100,
        value = 20,
        level_offset = 0, -- minion tier (Jason: S/M/L = minion/lieutenant/boss, like enemy rank_offset)
        placement = { height_offset = 1, sink_depth = 0.75 },
    },
    {
        suffix = "Medium",
        scale = 1,
        size_scale = 1.0,
        health = 500,
        value = 100,
        level_offset = 1, -- lieutenant tier
        placement = { height_offset = 2, sink_depth = 1.05 },
    },
    {
        suffix = "Large",
        scale = 1,
        size_scale = 1.8,
        health = 2000,
        value = 400,
        level_offset = 2, -- boss tier
        placement = { height_offset = 7, sink_depth = 1.45 },
    },
}

local M = {
    -- Breakable objects configuration (crystals, ores, etc.)
    crystals = {
        SmallBlueCrystal = {
            display_name = "Small Blue Crystal",
            asset_id = "rbxassetid://112188519963572",
            scale = 1,
            health = 100,
            value = 5,
            currency = "crystals",
            -- Some uploaded models import sideways; fix with default orientation at preload time
            default_orientation = { x = -90, y = 0, z = 0 },
            placement = {
                height_offset = 1,
                sink_depth = 0.75,
            },
        },
        MediumBlueCrystal = {
            display_name = "Medium Blue Crystal",
            asset_id = "rbxassetid://113452230594676",
            scale = 1,
            health = 500,
            value = 25,
            currency = "crystals",
            default_orientation = { x = -90, y = 0, z = 0 },
            placement = {
                height_offset = 2,
                sink_depth = 1.05,
            },
        },
        BigBlueCrystal = {
            display_name = "Big Blue Crystal",
            asset_id = "rbxassetid://109710590640681",
            scale = 1,
            health = 2000,
            value = 100,
            currency = "crystals",
            default_orientation = { x = -90, y = 0, z = 0 },
            placement = {
                height_offset = 7,
                sink_depth = 1.45,
            },
        },
        CoinStack = {
            display_name = "Crystal Stack",
            procedural_asset = "coin_stack",
            scale = 1,
            health = 25,
            value = 25,
            currency = "coins",
            placement = {
                height_offset = 0,
                sink_depth = 0,
                drop_from_height = 16,
                drop_duration = 0.75,
            },
            physics = {
                anchored = true,
                can_collide = false,
                can_touch = false,
                can_query = true,
            },
        },
    },

    -- World-level settings for breakables
    worlds = {
        -- Spawn uses an invisible SpawnArea part under:
        -- Workspace.Game.Breakables.Crystals.Spawn
        Spawn = {
            max = 14, -- Starter area should feel curated, not crowded
            interval = 8, -- seconds between spawn attempts per spawner
            spawn_area = {
                name = "SpawnArea",
                size = { x = 140, y = 1, z = 140 },
                position = { x = 0, y = 0, z = 0 },
            },
            spawn_settings = {
                upright = true, -- keep crystals upright and only randomize yaw
                surface_y = 0, -- SpawnIsland floor surface; SpawnArea provides X/Z
                use_spawner_bounds = true,
                spawn_area_margin = 14,
                spawn_center = { x = 0, z = 0 }, -- fallback if no area-sized part exists
                spawn_radius = 55, -- fallback if no area-sized part exists
                spawn_exclusion_radius = 28, -- keep the player spawn pad readable
                embed_ratio = 0, -- use per-crystal sink_depth for predictable floor placement
                min_distance = 18, -- minimum spacing between spawned crystals
                spawn_attempts = 30,
                respawn_min_seconds = 5, -- delay range after a crystal is removed/destroyed
                respawn_max_seconds = 60,
            },
            -- Optional weighted spawn table. Entries can override scale/health/value/currency/placement per area.
            -- Starter area = the GRASS zone: only emerald (Bloomstone) ore now. All 3 cosmetic
            -- variants across S/M/L, weighted small-common -> large-rare. (Coins + blue crystals
            -- + other-element placeholders removed; desert/lava/ice get their own zones later.)
            spawn_table = {
                { name = "BloomstoneSmallV1", weight = 4 },
                { name = "BloomstoneSmallV2", weight = 4 },
                { name = "BloomstoneSmallV3", weight = 4 },
                { name = "BloomstoneMediumV1", weight = 2 },
                { name = "BloomstoneMediumV2", weight = 2 },
                { name = "BloomstoneMediumV3", weight = 2 },
                { name = "BloomstoneLargeV1", weight = 1 },
                { name = "BloomstoneLargeV2", weight = 1 },
                { name = "BloomstoneLargeV3", weight = 1 },
            },
        },
        -- REALM ORE (Heaven_1 + Hell_1): four per-origin spawns each, reusing the homeworld
        -- ore families as PLACEHOLDERS (Emberstone/Frostshard/Sunglass/Bloomstone). Keyed by the
        -- per-origin zone id (Heaven_1_Lava …) so BreakableSpawner:_isWorldActive gates each on
        -- its own unlock (the bare 'Heaven_%d' realm-always-active case doesn't match the suffix).
        -- Swap to dedicated realm crystal art later. Generated by scripts/gen_realm_zones.py.
        -- Heaven_1 per-origin ore (reuses homeworld families; gated on each origin zone).
        Heaven_1_Lava = {
            health_mult = 2, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 340, y = 1, z = 420 },
                position = { x = -206, y = 2000, z = 67 },
            },
            spawn_settings = {
                upright = true,
                surface_y = 2000,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Lava",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -206, z = 67 },
                spawn_radius = 150,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "EmberstoneSmallV1", weight = 4 },
                { name = "EmberstoneSmallV2", weight = 4 },
                { name = "EmberstoneSmallV3", weight = 4 },
                { name = "EmberstoneMediumV1", weight = 2 },
                { name = "EmberstoneMediumV2", weight = 2 },
                { name = "EmberstoneMediumV3", weight = 2 },
                { name = "EmberstoneLargeV1", weight = 1 },
                { name = "EmberstoneLargeV2", weight = 1 },
                { name = "EmberstoneLargeV3", weight = 1 },
            },
        },
        Heaven_1_Ice = {
            health_mult = 2, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 300, y = 1, z = 300 },
                position = { x = -374, y = 2000, z = 377 },
            },
            spawn_settings = {
                upright = true,
                surface_y = 2000,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Ice",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -374, z = 377 },
                spawn_radius = 130,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "FrostshardSmallV1", weight = 4 },
                { name = "FrostshardSmallV2", weight = 4 },
                { name = "FrostshardSmallV3", weight = 4 },
                { name = "FrostshardMediumV1", weight = 2 },
                { name = "FrostshardMediumV2", weight = 2 },
                { name = "FrostshardMediumV3", weight = 2 },
                { name = "FrostshardLargeV1", weight = 1 },
                { name = "FrostshardLargeV2", weight = 1 },
                { name = "FrostshardLargeV3", weight = 1 },
            },
        },
        Heaven_1_Desert = {
            health_mult = 2, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 310, y = 1, z = 280 },
                position = { x = -126, y = 2000, z = 474 },
            },
            spawn_settings = {
                upright = true,
                surface_y = 2000,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Desert",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -126, z = 474 },
                spawn_radius = 120,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "SunglassSmallV1", weight = 4 },
                { name = "SunglassSmallV2", weight = 4 },
                { name = "SunglassSmallV3", weight = 4 },
                { name = "SunglassMediumV1", weight = 2 },
                { name = "SunglassMediumV2", weight = 2 },
                { name = "SunglassMediumV3", weight = 2 },
                { name = "SunglassLargeV1", weight = 1 },
                { name = "SunglassLargeV2", weight = 1 },
                { name = "SunglassLargeV3", weight = 1 },
            },
        },
        Heaven_1_Grass = {
            health_mult = 2, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 330, y = 1, z = 240 },
                position = { x = -150, y = 2000, z = 266 },
            },
            spawn_settings = {
                upright = true,
                surface_y = 2000,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Grass",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -150, z = 266 },
                spawn_radius = 100,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "BloomstoneSmallV1", weight = 4 },
                { name = "BloomstoneSmallV2", weight = 4 },
                { name = "BloomstoneSmallV3", weight = 4 },
                { name = "BloomstoneMediumV1", weight = 2 },
                { name = "BloomstoneMediumV2", weight = 2 },
                { name = "BloomstoneMediumV3", weight = 2 },
                { name = "BloomstoneLargeV1", weight = 1 },
                { name = "BloomstoneLargeV2", weight = 1 },
                { name = "BloomstoneLargeV3", weight = 1 },
            },
        },
        -- Hell_1 per-origin ore (reuses homeworld families; gated on each origin zone).
        Hell_1_Lava = {
            health_mult = 2, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 340, y = 1, z = 420 },
                position = { x = -206, y = -1999, z = 67 },
            },
            spawn_settings = {
                upright = true,
                surface_y = -1999,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Lava",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -206, z = 67 },
                spawn_radius = 150,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "EmberstoneSmallV1", weight = 4 },
                { name = "EmberstoneSmallV2", weight = 4 },
                { name = "EmberstoneSmallV3", weight = 4 },
                { name = "EmberstoneMediumV1", weight = 2 },
                { name = "EmberstoneMediumV2", weight = 2 },
                { name = "EmberstoneMediumV3", weight = 2 },
                { name = "EmberstoneLargeV1", weight = 1 },
                { name = "EmberstoneLargeV2", weight = 1 },
                { name = "EmberstoneLargeV3", weight = 1 },
            },
        },
        Hell_1_Ice = {
            health_mult = 2, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 300, y = 1, z = 300 },
                position = { x = -374, y = -1999, z = 377 },
            },
            spawn_settings = {
                upright = true,
                surface_y = -1999,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Ice",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -374, z = 377 },
                spawn_radius = 130,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "FrostshardSmallV1", weight = 4 },
                { name = "FrostshardSmallV2", weight = 4 },
                { name = "FrostshardSmallV3", weight = 4 },
                { name = "FrostshardMediumV1", weight = 2 },
                { name = "FrostshardMediumV2", weight = 2 },
                { name = "FrostshardMediumV3", weight = 2 },
                { name = "FrostshardLargeV1", weight = 1 },
                { name = "FrostshardLargeV2", weight = 1 },
                { name = "FrostshardLargeV3", weight = 1 },
            },
        },
        Hell_1_Desert = {
            health_mult = 2, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 310, y = 1, z = 280 },
                position = { x = -126, y = -1999, z = 474 },
            },
            spawn_settings = {
                upright = true,
                surface_y = -1999,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Desert",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -126, z = 474 },
                spawn_radius = 120,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "SunglassSmallV1", weight = 4 },
                { name = "SunglassSmallV2", weight = 4 },
                { name = "SunglassSmallV3", weight = 4 },
                { name = "SunglassMediumV1", weight = 2 },
                { name = "SunglassMediumV2", weight = 2 },
                { name = "SunglassMediumV3", weight = 2 },
                { name = "SunglassLargeV1", weight = 1 },
                { name = "SunglassLargeV2", weight = 1 },
                { name = "SunglassLargeV3", weight = 1 },
            },
        },
        Hell_1_Grass = {
            health_mult = 2, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 330, y = 1, z = 240 },
                position = { x = -150, y = -1999, z = 266 },
            },
            spawn_settings = {
                upright = true,
                surface_y = -1999,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Grass",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -150, z = 266 },
                spawn_radius = 100,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "BloomstoneSmallV1", weight = 4 },
                { name = "BloomstoneSmallV2", weight = 4 },
                { name = "BloomstoneSmallV3", weight = 4 },
                { name = "BloomstoneMediumV1", weight = 2 },
                { name = "BloomstoneMediumV2", weight = 2 },
                { name = "BloomstoneMediumV3", weight = 2 },
                { name = "BloomstoneLargeV1", weight = 1 },
                { name = "BloomstoneLargeV2", weight = 1 },
                { name = "BloomstoneLargeV3", weight = 1 },
            },
        },
        -- Layer 2 (Heaven_2 +4000 / Hell_2 -3999) — clones of layer-1 ore, Y-shifted.
        Heaven_2_Lava = {
            health_mult = 3, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 340, y = 1, z = 420 },
                position = { x = -206, y = 4000, z = 67 },
            },
            spawn_settings = {
                upright = true,
                surface_y = 4000,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Lava",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -206, z = 67 },
                spawn_radius = 150,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "EmberstoneSmallV1", weight = 4 },
                { name = "EmberstoneSmallV2", weight = 4 },
                { name = "EmberstoneSmallV3", weight = 4 },
                { name = "EmberstoneMediumV1", weight = 2 },
                { name = "EmberstoneMediumV2", weight = 2 },
                { name = "EmberstoneMediumV3", weight = 2 },
                { name = "EmberstoneLargeV1", weight = 1 },
                { name = "EmberstoneLargeV2", weight = 1 },
                { name = "EmberstoneLargeV3", weight = 1 },
            },
        },
        Heaven_2_Ice = {
            health_mult = 3, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 300, y = 1, z = 300 },
                position = { x = -374, y = 4000, z = 377 },
            },
            spawn_settings = {
                upright = true,
                surface_y = 4000,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Ice",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -374, z = 377 },
                spawn_radius = 130,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "FrostshardSmallV1", weight = 4 },
                { name = "FrostshardSmallV2", weight = 4 },
                { name = "FrostshardSmallV3", weight = 4 },
                { name = "FrostshardMediumV1", weight = 2 },
                { name = "FrostshardMediumV2", weight = 2 },
                { name = "FrostshardMediumV3", weight = 2 },
                { name = "FrostshardLargeV1", weight = 1 },
                { name = "FrostshardLargeV2", weight = 1 },
                { name = "FrostshardLargeV3", weight = 1 },
            },
        },
        Heaven_2_Desert = {
            health_mult = 3, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 310, y = 1, z = 280 },
                position = { x = -126, y = 4000, z = 474 },
            },
            spawn_settings = {
                upright = true,
                surface_y = 4000,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Desert",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -126, z = 474 },
                spawn_radius = 120,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "SunglassSmallV1", weight = 4 },
                { name = "SunglassSmallV2", weight = 4 },
                { name = "SunglassSmallV3", weight = 4 },
                { name = "SunglassMediumV1", weight = 2 },
                { name = "SunglassMediumV2", weight = 2 },
                { name = "SunglassMediumV3", weight = 2 },
                { name = "SunglassLargeV1", weight = 1 },
                { name = "SunglassLargeV2", weight = 1 },
                { name = "SunglassLargeV3", weight = 1 },
            },
        },
        Heaven_2_Grass = {
            health_mult = 3, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 330, y = 1, z = 240 },
                position = { x = -150, y = 4000, z = 266 },
            },
            spawn_settings = {
                upright = true,
                surface_y = 4000,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Grass",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -150, z = 266 },
                spawn_radius = 100,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "BloomstoneSmallV1", weight = 4 },
                { name = "BloomstoneSmallV2", weight = 4 },
                { name = "BloomstoneSmallV3", weight = 4 },
                { name = "BloomstoneMediumV1", weight = 2 },
                { name = "BloomstoneMediumV2", weight = 2 },
                { name = "BloomstoneMediumV3", weight = 2 },
                { name = "BloomstoneLargeV1", weight = 1 },
                { name = "BloomstoneLargeV2", weight = 1 },
                { name = "BloomstoneLargeV3", weight = 1 },
            },
        },
        Hell_2_Lava = {
            health_mult = 3, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 340, y = 1, z = 420 },
                position = { x = -206, y = -3999, z = 67 },
            },
            spawn_settings = {
                upright = true,
                surface_y = -3999,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Lava",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -206, z = 67 },
                spawn_radius = 150,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "EmberstoneSmallV1", weight = 4 },
                { name = "EmberstoneSmallV2", weight = 4 },
                { name = "EmberstoneSmallV3", weight = 4 },
                { name = "EmberstoneMediumV1", weight = 2 },
                { name = "EmberstoneMediumV2", weight = 2 },
                { name = "EmberstoneMediumV3", weight = 2 },
                { name = "EmberstoneLargeV1", weight = 1 },
                { name = "EmberstoneLargeV2", weight = 1 },
                { name = "EmberstoneLargeV3", weight = 1 },
            },
        },
        Hell_2_Ice = {
            health_mult = 3, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 300, y = 1, z = 300 },
                position = { x = -374, y = -3999, z = 377 },
            },
            spawn_settings = {
                upright = true,
                surface_y = -3999,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Ice",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -374, z = 377 },
                spawn_radius = 130,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "FrostshardSmallV1", weight = 4 },
                { name = "FrostshardSmallV2", weight = 4 },
                { name = "FrostshardSmallV3", weight = 4 },
                { name = "FrostshardMediumV1", weight = 2 },
                { name = "FrostshardMediumV2", weight = 2 },
                { name = "FrostshardMediumV3", weight = 2 },
                { name = "FrostshardLargeV1", weight = 1 },
                { name = "FrostshardLargeV2", weight = 1 },
                { name = "FrostshardLargeV3", weight = 1 },
            },
        },
        Hell_2_Desert = {
            health_mult = 3, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 310, y = 1, z = 280 },
                position = { x = -126, y = -3999, z = 474 },
            },
            spawn_settings = {
                upright = true,
                surface_y = -3999,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Desert",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -126, z = 474 },
                spawn_radius = 120,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "SunglassSmallV1", weight = 4 },
                { name = "SunglassSmallV2", weight = 4 },
                { name = "SunglassSmallV3", weight = 4 },
                { name = "SunglassMediumV1", weight = 2 },
                { name = "SunglassMediumV2", weight = 2 },
                { name = "SunglassMediumV3", weight = 2 },
                { name = "SunglassLargeV1", weight = 1 },
                { name = "SunglassLargeV2", weight = 1 },
                { name = "SunglassLargeV3", weight = 1 },
            },
        },
        Hell_2_Grass = {
            health_mult = 3, -- tougher nodes (toughness lever; income lives in layers.lua multipliers)
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 330, y = 1, z = 240 },
                position = { x = -150, y = -3999, z = 266 },
            },
            spawn_settings = {
                upright = true,
                surface_y = -3999,
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Grass",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = { x = -150, z = 266 },
                spawn_radius = 100,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "BloomstoneSmallV1", weight = 4 },
                { name = "BloomstoneSmallV2", weight = 4 },
                { name = "BloomstoneSmallV3", weight = 4 },
                { name = "BloomstoneMediumV1", weight = 2 },
                { name = "BloomstoneMediumV2", weight = 2 },
                { name = "BloomstoneMediumV3", weight = 2 },
                { name = "BloomstoneLargeV1", weight = 1 },
                { name = "BloomstoneLargeV2", weight = 1 },
                { name = "BloomstoneLargeV3", weight = 1 },
            },
        },
        Meadow = {
            max = 8,
            interval = 10,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 130, y = 1, z = 130 },
                position = { x = 220, y = 0, z = 0 },
            },
            spawn_settings = {
                upright = true,
                surface_y = 0,
                use_spawner_bounds = true,
                spawn_area_margin = 16,
                spawn_center = { x = 220, z = 0 },
                spawn_radius = 50,
                spawn_exclusion_radius = 24,
                embed_ratio = 0,
                min_distance = 20,
                spawn_attempts = 30,
                respawn_min_seconds = 10,
                respawn_max_seconds = 70,
            },
            spawn_table = {
                { name = "SmallBlueCrystal", weight = 5 },
                { name = "MediumBlueCrystal", weight = 3 },
                { name = "BigBlueCrystal", weight = 1 },
                { name = "CoinStack", weight = 2 },
            },
        },
        -- LAVA ZONE: spawns on the flat "Lava" baseplate (Home.Lava, center ~-207,0,68, top Y~0.5).
        -- Emberstone ore only, paying lava_coins. Marked always-active in BreakableSpawner
        -- (_isWorldActive) for now; swap to proper enter-the-zone activation via the area system later.
        Lava = {
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 340, y = 1, z = 420 }, -- covers more of the 360x458 Lava pad
                position = { x = -207, y = 0, z = 68 },
            },
            spawn_settings = {
                upright = true,
                surface_y = 0.5, -- fallback; surface raycast (below) sets the real Y per node
                use_spawner_bounds = true,
                -- Raycast down per candidate and only place where it hits the "Lava" baseplate
                -- (the labeled terrain), so ore sits on the lava texture and skips rocks/gaps.
                surface_mode = "surface",
                surface_match_name = "Lava",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 30,
                spawn_center = { x = -207, z = 68 },
                spawn_radius = 150,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12, -- tighter so 100 can fit the cluttered lava pad
                spawn_attempts = 90, -- more tries (material-match rejects rock/gap candidates)
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "EmberstoneSmallV1", weight = 4 },
                { name = "EmberstoneSmallV2", weight = 4 },
                { name = "EmberstoneSmallV3", weight = 4 },
                { name = "EmberstoneMediumV1", weight = 2 },
                { name = "EmberstoneMediumV2", weight = 2 },
                { name = "EmberstoneMediumV3", weight = 2 },
                { name = "EmberstoneLargeV1", weight = 1 },
                { name = "EmberstoneLargeV2", weight = 1 },
                { name = "EmberstoneLargeV3", weight = 1 },
            },
        },
        -- ICE ZONE: spawns on the flat "Ice" baseplate (Home.Ice, center ~-375,0,377).
        -- Frostshard ore only, paying ice_coins. Always-active for now (see _isWorldActive).
        Ice = {
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 300, y = 1, z = 300 }, -- within the 318x326 Ice pad
                position = { x = -375, y = 0, z = 377 },
            },
            spawn_settings = {
                upright = true,
                surface_y = 0.5, -- fallback; surface raycast (below) sets the real Y per node
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Ice",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 20,
                spawn_center = { x = -375, z = 377 },
                spawn_radius = 150,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "FrostshardSmallV1", weight = 4 },
                { name = "FrostshardSmallV2", weight = 4 },
                { name = "FrostshardSmallV3", weight = 4 },
                { name = "FrostshardMediumV1", weight = 2 },
                { name = "FrostshardMediumV2", weight = 2 },
                { name = "FrostshardMediumV3", weight = 2 },
                { name = "FrostshardLargeV1", weight = 1 },
                { name = "FrostshardLargeV2", weight = 1 },
                { name = "FrostshardLargeV3", weight = 1 },
            },
        },
        -- DESERT ZONE: spawns on the flat "Desert" baseplate (Home.Desert, center ~-127,1,475).
        -- Sunglass ore only, paying desert_coins. Always-active for now (see _isWorldActive).
        Desert = {
            max = 100,
            interval = 8,
            spawn_area = {
                name = "SpawnArea",
                size = { x = 310, y = 1, z = 280 }, -- within the 330x301 Desert pad
                position = { x = -127, y = 1, z = 475 },
            },
            spawn_settings = {
                upright = true,
                surface_y = 1.5, -- fallback; surface raycast (below) sets the real Y per node
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "Desert",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 20,
                spawn_center = { x = -127, z = 475 },
                spawn_radius = 140,
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            },
            spawn_table = {
                { name = "SunglassSmallV1", weight = 4 },
                { name = "SunglassSmallV2", weight = 4 },
                { name = "SunglassSmallV3", weight = 4 },
                { name = "SunglassMediumV1", weight = 2 },
                { name = "SunglassMediumV2", weight = 2 },
                { name = "SunglassMediumV3", weight = 2 },
                { name = "SunglassLargeV1", weight = 1 },
                { name = "SunglassLargeV2", weight = 1 },
                { name = "SunglassLargeV3", weight = 1 },
            },
        },
    },

    -- Workspace structure that can be generated from config for local/dev maps.
    -- Designers can still place real area parts in Studio; this is the code-owned fallback.
    structure = {
        spawn_island = {
            name = "SpawnIsland",
            size = { x = 160, y = 4, z = 160 },
            position = { x = 0, y = -2, z = 0 },
            color = { r = 46, g = 158, b = 74 },
            material = "Grass",
        },
        start_spawn = {
            name = "StartSpawn",
            size = { x = 12, y = 1, z = 12 },
            position = { x = 0, y = 2, z = 0 },
            transparency = 0.25,
            color = { r = 38, g = 115, b = 255 },
        },
        egg_spawn_points = {
            {
                spawn_id = "Grass",
                egg_type = "grass_egg",
                name = "EggSpawnPoint",
                size = { x = 3, y = 1, z = 3 },
                position = { x = 0, y = 0.5, z = -22 },
                transparency = 1,
                color = { r = 255, g = 255, b = 255 },
            },
        },
        defaults = {
            max = 0,
            spawner = {
                name = "Spawner",
                size = { x = 1, y = 1, z = 1 },
                random_position = {
                    x = { min = -50, max = 50 },
                    y = 10,
                    z = { min = -50, max = 50 },
                },
            },
        },
        folders = {
            Breakables = {
                Crystals = {
                    spawners = true,
                    worlds = {
                        "Spawn",
                        "World2",
                        "World3",
                        "Desert",
                        "Anime",
                        "Mine",
                        "Artic",
                        "Ancient",
                        "Magic",
                        "Galaxy",
                        "Swamp",
                        "CorruptedCity",
                        "Blackhole",
                        "SpaceLand",
                        "Careers",
                        "Program",
                        "E100KEVENT",
                    },
                },
                Gold = {
                    max = 25,
                    spawners = { name = "GoldSpawner" },
                    worlds = {
                        "World3",
                        "Ancient",
                        "Magic",
                        "Galaxy",
                        "Steampunk",
                        "Carnival",
                        "Swamp",
                        "CorruptedCity",
                        "Blackhole",
                        "SpaceLand",
                        { name = "PowerMaxBunny", spawners = false },
                        { name = "Easter", spawners = false },
                        { name = "CincoDeMayo", spawners = false },
                        { name = "VisitsEvent", spawners = false },
                    },
                },
                Green = {
                    worlds = {
                        { name = "Spawn", spawners = true },
                        { name = "World2", spawners = false },
                        { name = "World3", spawners = false },
                        { name = "StPatrick", spawners = false },
                    },
                },
                Summer = {
                    worlds = {
                        { name = "Spawn", spawners = false },
                        { name = "World2", spawners = false },
                        { name = "World3", spawners = true },
                        { name = "StPatrick", spawners = false },
                    },
                },
                Clicks = {
                    worlds = {
                        { name = "Spawn", spawners = true },
                    },
                },
            },
            Chaseables = {
                Snowman = {
                    worlds = {
                        { name = "Christmas", spawners = false },
                        { name = "Christmas2", spawners = false },
                    },
                },
                Hearts = {
                    worlds = {
                        { name = "Valentine", spawners = false },
                    },
                },
            },
        },
    },

    -- Fallbacks if a world has no explicit settings
    -- Spawn-slot mode (perf): precompute a per-world pool of well-spaced, raycast-validated spawn
    -- points ONCE on world activation, then spawn = claim a free slot (O(free), no raycasts). Kills
    -- the periodic ~0.8s BreakableSpawner hitch. Set false to fall back to the legacy per-spawn
    -- raycast search. `slot_jitter` (per spawn_settings) lightly randomises grid points (0..0.45).
    use_spawn_slots = true,
    -- Oversample: generate ~this many × the crystals a world holds, so only ~1/oversample of slots
    -- are filled at once. A mined crystal respawns in a RANDOM free slot → the field drifts and you
    -- can't idle-farm one spot. 1 = fill every slot (no drift). 3 = ~one-third filled.
    slot_oversample = 3,
    -- Top-up reconciler cadence (s). Respawns are EVENT-DRIVEN (per-crystal random delay on mine);
    -- this slow sweep is only a safety net for missed removals / initial fill, so it no longer
    -- masks the random respawn gap the way the old 5s sweep did.
    topup_interval_seconds = 30,

    defaults = {
        max_per_world = 0,
        spawn_settings = {
            upright = true,
            surface_y = 0,
            use_spawner_bounds = true,
            spawn_area_margin = 0,
            spawn_radius = 0,
            spawn_exclusion_radius = 0,
            -- Authored maps can set surface_mode = "surface" or tag a SpawnZone with
            -- SurfaceOnly=true to raycast onto playable geometry instead of using a flat Y.
            spawn_clearance_radius = 0,
            spawn_clearance_height = 10,
            embed_ratio = 0,
            min_distance = 12,
            spawn_attempts = 12,
            respawn_min_seconds = 5,
            respawn_max_seconds = 60,
        },
    },
}

-- Generate the zone ore breakables: <Display><Tier> (e.g. "BloomstoneSmall"), one per
-- element × size tier, each paying that zone's coin. Mesh = the family's first variant
-- if provided, else the size placeholder (blue crystal). Registered into M.crystals so the
-- existing preloader/spawner handle them with zero engine changes.
for _, fam in ipairs(ORE_FAMILIES) do
    local hasVariants = type(fam.variants) == "table" and #fam.variants > 0
    for _, tier in ipairs(ORE_TIERS) do
        local orientation = fam.orientation or { x = -90, y = 0, z = 0 }
        local function entry(name, asset, scale)
            M.crystals[name] = {
                display_name = fam.display .. " (" .. tier.suffix .. ")",
                asset_id = asset,
                scale = scale,
                health = tier.health,
                value = tier.value,
                level_offset = tier.level_offset, -- spawner: MiningLevel = zone_level + this
                currency = fam.currency,
                glow = fam.glow,
                default_orientation = orientation,
                placement = {
                    height_offset = tier.placement.height_offset,
                    sink_depth = tier.placement.sink_depth,
                },
            }
        end
        if hasVariants then
            -- One entry per cosmetic variant (<Display><Tier>V<n>); the weighted spawn table
            -- random-picks among them. norm * size_scale * family scale -> consistent size.
            for vi, v in ipairs(fam.variants) do
                entry(
                    fam.display .. tier.suffix .. "V" .. vi,
                    v.asset,
                    (v.norm or 1) * tier.size_scale * (fam.scale or 1)
                )
            end
        else
            -- Placeholder family: one entry per tier using the size-matched blue crystal.
            entry(fam.display .. tier.suffix, ORE_PLACEHOLDER[tier.suffix], tier.scale)
        end
    end
end

-- Active-mining BOOST (rewards active players over passive). Clicking the node you're mining
-- builds its Boost (server-side, in BreakableSpawner); higher Boost amplifies YOUR pets' damage
-- on that node (applied in PetFollowService) — firewall-clean: the player amplifies, pets deal.
-- Small nodes die in one hit so boost only matters on big/substantial targets (by design — not
-- a clicker game). Boost decays when you stop, so sustained focus is required.
M.boost = {
    per_click = 1, -- Boost gained per click (capped at max)
    decay_per_sec = 1, -- Boost lost per second when not clicking (must be < clicks/sec to build)
    max = 100, -- MaxBoost
    max_damage_bonus = 1.0, -- at full Boost, pet damage on the node is x(1 + this) = +100%
}

return M
