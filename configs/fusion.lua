--[[
    Chaotic Fusion — Halo & Horns [PROTOTYPE] (Feature 20).

    Sacrifice 1 Light + 1 Shadow pet at the fusion altar to produce 1 Chaotic pet.
    Both inputs are consumed permanently; the output is Chaotic of the recipe's
    theme family (default: inherit input A's theme). Pure rules:
    `src/Shared/Game/FusionLogic.lua`. The altar UI + confirm modal are [studio].
]]

return {
    output_element = "chaotic",
    -- A valid fusion needs exactly one of each of these (order-independent).
    required_elements = { "light", "shadow" },
    -- Optional explicit recipes keyed "themeA+themeB" (sorted) -> output theme.
    recipes = {},
    -- When no recipe matches, the output theme inherits from this input.
    default_output_theme_from = "input_a",
    -- Cap the in-memory fusion-history audit log per server.
    fusion_log_limit = 100,
}
