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

    layers = {
        -- heaven_2 = { ["tree/desert_tree"] = "dawnbloom_tree" },
    },
    realms = {
        -- heaven = { ... }, hell = { ... }
    },
}
