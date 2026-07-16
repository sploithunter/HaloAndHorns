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

    -- fraction of a spawn's height sunk BELOW the anchor floor, per kind
    -- (Jason 2026-07-16: "sink the rocks into the ground a bit — they look
    -- like they're kind of floating there on points"). Irregular meshes
    -- only touch at their lowest vertex, so burying a slice reads seated.
    sink_fraction = { rock = 0.18 },

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
