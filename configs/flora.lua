--[[
    Flora theming (Jason 2026-07-16) — restyle a realm's trees/cacti/rocks
    with CONFIG, not map edits.

    Authored flora models in Maps.<Layer> are tagged `FloraAnchor` with
    attributes Kind + Variant (see docs/MAP_MARKER_REFERENCE.md). At boot,
    FloraService replaces each tagged model whose context resolves to a
    replacement here (Shared/Game/FloraTheme precedence: layer kind/variant
    -> layer kind -> realm kind/variant -> realm kind -> keep original).

    Replacement value = a model name under ReplicatedStorage.Assets.Models.Flora
    (prebaked via the Models.rbxm flow). An entry left out = the authored
    original stays. The PLACE keeps the authored layout forever — the swap
    is runtime-only, so restyles are pure config changes.

    Variants (from the 2026-07-16 tagging sweep): baobab_tree, cactus,
    desert_tree, pine_tree, pinetree1, tree1, tree2, world_tree_10k,
    joshua_tree_7500tris, magenta_ti_plant, cloudtiplant, rock, rocks2,
    rockstone, small_rock_path.

    Example (once the dawnbloom model is prebaked):
        realms = {
            heaven = {
                ["tree/desert_tree"] = "dawnbloom_tree",
                ["tree/pine_tree"] = "dawnbloom_tree",
            },
        },
]]

return {
    -- kinds that spawn with a DETERMINISTIC random yaw (seeded by anchor
    -- position, so the world is stable across boots) instead of the
    -- authored rotation. Trees keep their authored facing (Jason: "large
    -- items we might want to rotate a particular way") — rotate the anchor
    -- part in Studio to change one.
    random_yaw_kinds = { rock = true, cactus = true, plant = true },

    -- Client-only rustle for nearby soft flora. Rocks and structural wall decor
    -- stay still. Fabric banners must opt in with Kind="banner"; a model name
    -- alone never makes an authored wall fixture move.
    sway = {
        enabled = true,
        radius = 80,
        tree_degrees = 1.3,
        plant_degrees = 2.6,
        cactus_degrees = 1.8,
        banner_degrees = 4.5,
        speed = 1.15,
    },

    -- fraction of a spawn's height sunk BELOW the anchor floor, per kind
    -- (Jason 2026-07-16: "sink the rocks into the ground a bit — they look
    -- like they're kind of floating there on points"). Irregular meshes
    -- only touch at their lowest vertex, so burying a slice reads seated.
    sink_fraction = { rock = 0.18 },

    -- Dark Hell 3 textures carry narrow red/purple accent lines. Neon lifts those authored texels
    -- without washing out the near-black body; selected signature models also get a restrained
    -- no-shadow PointLight through Shared.Game.EnvironmentGlow. Values are intentionally below
    -- combat-FX brightness and comparable to the persistent crystal glow.
    glow_models = {
        dreadthorn_tree = {
            neon = true,
            color = { 255, 45, 20 },
            brightness = 1.8,
            range = 24,
        },
        dreadspire_thorn_cactus = {
            neon = true,
            color = { 255, 55, 20 },
            brightness = 1,
            range = 12,
        },
        dreadspire_ribbon_grass = {
            neon = true,
            color = { 255, 45, 20 },
            brightness = 0.65,
            range = 8,
        },
        ironroot_crawler = {
            neon = true,
            color = { 255, 40, 15 },
            brightness = 0.65,
            range = 8,
        },
        blood_reed = {
            neon = true,
            color = { 255, 35, 20 },
            brightness = 0.8,
            range = 9,
        },
        ember_thorn_cluster = {
            neon = true,
            color = { 255, 65, 20 },
            brightness = 0.8,
            range = 9,
        },
        crimson_watcher_bloom = {
            neon = true,
            color = { 255, 35, 25 },
            brightness = 1,
            range = 10,
        },
        abyss_orchid = {
            neon = true,
            color = { 185, 45, 255 },
            brightness = 0.75,
            range = 9,
        },
        obsidian_spike_plant = {
            neon = true,
            color = { 255, 35, 20 },
            brightness = 0.8,
            range = 10,
        },
        -- These silhouettes benefit from emissive texture accents but do not need another dynamic
        -- light in the garden cluster.
        violet_hook_bloom = { neon = true },
        gloom_pitcher = { neon = true },
        razorleaf_fan = { neon = true },
        violet_bramble = { neon = true },

        -- Moving Hell 3 fauna carry their glow with them. Their ranges remain smaller than their
        -- authored routes so they read as living sparks rather than roaming area lights.
        dreadwing_beetle = {
            neon = true,
            color = { 255, 45, 20 },
            brightness = 0.6,
            range = 7,
        },
        obsidian_hornback_lizard = {
            neon = true,
            color = { 255, 50, 20 },
            brightness = 0.7,
            range = 8,
        },
    },

    layers = {
        -- Home ("base") is not a realm, so it needs its own row for
        -- realm-agnostic swaps like the baobab purge.
        base = {
            ["tree/baobab_tree"] = "oak_tree",
            -- ice-zone boulders carry Variant=ice_rock (retagged 2026-07-16
            -- so hell ice can run cold-fire); Home keeps granite
            ["rock/ice_rock"] = "rock",
        },
        -- Layer tier beats realm tier — per-layer IDENTITY on top of the
        -- realm theme (Jason 2026-07-16: "not a lot of differentiation...
        -- we should have assets that are in theme"). Heaven_1 = cloud/
        -- pearl, Heaven_2 = crystal/cherry; Hell_1 = ash/bone, Hell_2 =
        -- rot/sulfur. Deeper splits (crystal_* plants for heaven_2,
        -- toxic/swamp/rotten for hell_2) land when those meshes exist.
        heaven_1 = {
            ["tree/tree1"] = "cloud_sapling",
            ["rock/rock"] = { "marble_pebble", "pearl_quartz" },
        },
        heaven_2 = {
            ["tree/tree1"] = { "cherry_heaven_tree_1", "cherry_heaven_tree_2" },
            ["rock/rock"] = { "pearl_quartz", "amethyst_geode", "rosegold_geode" },
            ["tree/oak_tree"] = "rainbow_fern", -- garden center = Jason's fern
            ["rock/mossy_pebble"] = { "rosegold_geode", "amethyst_geode" },
            -- crystalline garden plants (crystal_* meshes, 2026-07-16)
            ["plant/grass_tuft"] = "crystal_tuft",
            ["plant/field_flower_bush"] = "crystal_bloom",
            ["plant/meadow_bush"] = "crystal_bush",
        },
        hell_1 = {
            ["rock/rock"] = { "bone_rock", "sulfur_rock", "cinder_rock" },
        },
        hell_2 = {
            ["rock/rock"] = { "putrid_rock", "sulfur_rock", "bone_rock" },
            ["tree/oak_tree"] = "scorched_tree",
            ["rock/mossy_pebble"] = { "putrid_rock", "sulfur_rock" },
            -- ROT garden (swamp meshes, 2026-07-16)
            ["plant/grass_tuft"] = "swamp_reed",
            ["plant/field_flower_bush"] = "rotten_mushroom",
            ["plant/meadow_bush"] = { "putrid_bush", "toxic_vine" },
        },
        -- Layer 3 owns a complete flora palette. Signature trees are mixed
        -- with a small number of compatible realm trees so the copied anchor
        -- layout does not read as a single repeated silhouette; rocks and
        -- cacti use only the new Layer 3 models.
        heaven_3 = {
            ["tree/baobab_tree"] = { "luminous_canopy_tree", "cherry_heaven_tree_1" },
            ["tree/joshua_tree_7500tris"] = { "luminous_canopy_tree", "cloud_sapling" },
            ["tree/oak_tree"] = "luminous_canopy_tree",
            ["tree/pine_tree"] = { "luminous_canopy_tree", "frosted_pine_1" },
            ["tree/pinetree1"] = { "luminous_canopy_tree", "frosted_pine_2" },
            ["tree/scorched_tree"] = { "luminous_canopy_tree", "cherry_heaven_tree_1" },
            ["tree/tree1"] = {
                "luminous_canopy_tree",
                "cloud_sapling",
                "cherry_heaven_tree_2",
            },
            ["tree/tree2"] = { "luminous_canopy_tree", "cloud_sapling" },
            ["tree/world_tree_10k"] = { "luminous_canopy_tree", "cherry_heaven_tree_1" },
            rock = { "pearlroot_boulder", "bloomstone_shelf" },
            cactus = "empyrean_bloom_cactus",
            ["plant/cloudtiplant"] = {
                "halo_fern",
                "wingleaf_reed",
                "celestial_bellgrass",
                "rootlight_vine",
            },
            ["plant/grass_tuft"] = {
                "wingleaf_reed",
                "lumen_moss_cushion",
                "celestial_bellgrass",
                "petal_spire",
            },
            ["plant/field_flower_bush"] = {
                "celestial_bellgrass",
                "moonpetal_bush",
                "pearlroot_anemone",
                "empyrean_hibiscus",
                "jade_lantern_bloom",
            },
            ["plant/meadow_bush"] = {
                "emerald_ribbon_shrub",
                "moonpetal_bush",
                "halo_fern",
                "rootlight_vine",
                "jade_lantern_bloom",
            },
        },
        hell_3 = {
            ["tree/baobab_tree"] = { "dreadthorn_tree", "withered_sapling" },
            ["tree/desert_tree"] = { "dreadthorn_tree", "withered_sapling" },
            ["tree/oak_tree"] = "dreadthorn_tree",
            ["tree/pine_tree"] = { "dreadthorn_tree", "coldfire_pine" },
            ["tree/scorched_tree"] = { "dreadthorn_tree", "lava_eye_tree" },
            ["tree/tree1"] = { "dreadthorn_tree", "withered_sapling", "scorched_tree" },
            rock = { "dreadspire_faultstone", "dreadspire_razorstone" },
            cactus = "dreadspire_thorn_cactus",
            ["plant/grass_tuft"] = {
                "dreadspire_ribbon_grass",
                "ironroot_crawler",
                "blood_reed",
                "ember_thorn_cluster",
            },
            ["plant/field_flower_bush"] = {
                "crimson_watcher_bloom",
                "violet_hook_bloom",
                "abyss_orchid",
                "blood_reed",
            },
            ["plant/meadow_bush"] = {
                "gloom_pitcher",
                "razorleaf_fan",
                "obsidian_spike_plant",
                "violet_bramble",
                "ember_thorn_cluster",
            },
        },
    },
    realms = {
        -- Baobab purge (Jason 2026-07-16): base renders oaks (layers.base);
        -- heaven/hell render their themed trees below.
        heaven = {
            -- REALM THEME (Jason: "we have heaven and hell themes — assets
            -- should be in theme"): every generic green/grey exemplar gets
            -- a celestial skin. Home keeps the naturals.
            ["tree/baobab_tree"] = "cherry_heaven_tree_1",
            ["tree/tree1"] = { "cloud_sapling", "cherry_heaven_tree_2" },
            ["tree/tree2"] = "cloud_sapling",
            ["tree/world_tree_10k"] = "cherry_heaven_tree_1",
            ["rock/rock"] = { "marble_pebble", "pearl_quartz" },
            ["rock/rocks2"] = "marble_pebble",
            ["rock/rockstone"] = "pearl_quartz",
            -- heaven ice reads distinct from base (Jason 2026-07-16):
            -- frosted pines replace the default pines
            ["tree/pine_tree"] = "frosted_pine_1",
            ["tree/pinetree1"] = "frosted_pine_2",
            -- lava-zone tree anchors carry Variant=scorched_tree (retagged
            -- 2026-07-16 — "not sure why we have lava trees inside of
            -- sand"); heaven's lava banks bloom pink instead
            ["tree/scorched_tree"] = "cherry_heaven_tree_1",
            -- heaven ice boulders stay holy-frost pale
            ["rock/ice_rock"] = { "marble_pebble", "pearl_quartz" },
            -- garden palette (2026-07-16 19-item set): heavenly skins for
            -- the base garden plants; center tree = the realm sapling
            ["tree/oak_tree"] = "cloud_sapling",
            ["plant/grass_tuft"] = "pearl_tuft",
            ["plant/field_flower_bush"] = "softglow_bloom",
            ["plant/meadow_bush"] = "cloud_bush",
            ["rock/mossy_pebble"] = "marble_pebble",
            -- heaven deserts grow cloud/crystal cacti (array = deterministic
            -- position-seeded mix, FloraTheme.pick)
            cactus = { "cloud_cactus", "crystal_cactus" },
        },
        hell = {
            -- REALM THEME: dead and scorched everywhere a generic green
            -- exemplar would have spawned. Canon sub-themes (design doc
            -- "surprise contrast" + Jason 2026-07-16): Hell Ice = FREEZING
            -- COLD FIRE (the blues), Hell Lava = corrupted volcanic
            -- (lava_eye_tree), rot carries Hell_2.
            ["tree/pine_tree"] = "coldfire_pine",
            ["tree/pinetree1"] = "coldfire_pine",
            ["rock/ice_rock"] = { "coldfire_rock", "dark_ice_shard" },
            ["tree/scorched_tree"] = "lava_eye_tree",
            ["tree/baobab_tree"] = "withered_sapling",
            ["tree/tree1"] = { "withered_sapling", "scorched_tree" },
            ["tree/tree2"] = "withered_sapling",
            ["rock/rock"] = { "putrid_rock", "sulfur_rock", "bone_rock" },
            ["rock/rocks2"] = "bone_rock",
            ["rock/rockstone"] = "sulfur_rock",
            -- hell DESERT keeps real desert trees (savanna default) —
            -- lava-zone anchors carry Variant=scorched_tree and default to
            -- the scorched model, so no desert_tree rule here
            -- garden palette: hellish skins for the base garden plants;
            -- center tree = the realm sapling
            ["tree/oak_tree"] = "withered_sapling",
            ["plant/grass_tuft"] = "ash_tuft",
            ["plant/field_flower_bush"] = "thorn_tuft",
            ["plant/meadow_bush"] = "dead_brush",
            ["rock/mossy_pebble"] = "cinder_rock",
            -- hell deserts grow fire/rot cacti
            cactus = { "lava_cactus", "rotted_cactus" },
        },
    },
}
