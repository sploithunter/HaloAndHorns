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
    layers = {
        -- heaven_2 = { ["tree/desert_tree"] = "dawnbloom_tree" },
    },
    realms = {
        -- heaven = { ... }, hell = { ... }
    },
}
