--[[
    Biome ring topology — Halo & Horns [PROTOTYPE] content.

    The map is a ring of biomes with deterministic adjacency. This config owns the
    clockwise order, each biome's theme, its dichotomy (mirror-opposite) partner,
    and its themed reward currency. The generic ring/adjacency logic lives in
    `src/Shared/Game/RingTopology.lua` and reads this table — it must never
    hardcode biome names (Feature 1: "theme is config-driven, not inferred";
    "adding a biome requires no service code changes").

    Prototype ring (clockwise): earth → ice → lava → desert → beach → (wrap).
    Dichotomies: earth↔desert, ice↔lava. beach has none.
]]

return {
    -- Clockwise order around the ring. Adjacency wraps (last → first).
    order = { "earth", "ice", "lava", "desert", "beach" },

    -- Per-biome data. `dichotomy` is the mirror-opposite biome (nil if none).
    -- `currency` is the themed reward currency for that biome.
    biomes = {
        earth = { id = "earth", theme = "earth", dichotomy = "desert", currency = "grass_coins" },
        ice = { id = "ice", theme = "ice", dichotomy = "lava", currency = "ice_coins" },
        lava = { id = "lava", theme = "lava", dichotomy = "ice", currency = "lava_coins" },
        desert = { id = "desert", theme = "desert", dichotomy = "earth", currency = "desert_coins" },
        -- beach has no dichotomy partner; beach_coins extends the design's 4 named
        -- themed currencies so every biome has a reward currency.
        beach = { id = "beach", theme = "beach", dichotomy = nil, currency = "beach_coins" },
    },
}
