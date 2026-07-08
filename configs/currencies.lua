-- Currency Configuration
-- Define all available currencies in the game

return {
    {
        id = "coins",
        name = "Crystals",
        description = "Primary currency earned through gameplay",
        maxAmount = 999999999,
        defaultAmount = 100,
        icon = "💰",
    },

    {
        id = "gems",
        name = "Gems",
        description = "Premium currency purchased or earned through special rewards",
        -- 10B (Jason live-hit the old 999,999 wall 2026-07-08 — gems are now the shop+trade
        -- economy's main currency and enhancement-selling alone outruns a 1M cap fast)
        maxAmount = 10000000000,
        defaultAmount = 0,
        icon = "💎",
    },

    {
        -- NOTE: id stays "crystals" (frozen save key), but the MINED biome currencies are now the
        -- player-facing "Crystals" — so this rare/unused currency is displayed as "Relics" to avoid
        -- a name clash. (Jason: confirm/rename.)
        id = "crystals",
        name = "Relics",
        description = "Rare currency found in dungeons and special events",
        maxAmount = 50000,
        defaultAmount = 0,
        icon = "🔮",
    },

    -- Halo & Horns themed currencies (Feature 4). Per-biome coins + Heaven/Hell
    -- tokens. All non-tradeable (see configs/biomes.lua + configs/layers.lua).
    {
        id = "grass_coins",
        name = "Grass Crystals",
        description = "Grass (earth) biome currency",
        maxAmount = 999999999,
        defaultAmount = 100,
        icon = "🌿",
        tradeable = false,
    }, -- 100 starter grant: funds the first EarthEgg hatch before mining
    {
        id = "ice_coins",
        name = "Ice Crystals",
        description = "Ice biome currency",
        maxAmount = 999999999,
        defaultAmount = 0,
        icon = "🧊",
        tradeable = false,
    },
    {
        id = "lava_coins",
        name = "Lava Crystals",
        description = "Lava biome currency",
        maxAmount = 999999999,
        defaultAmount = 0,
        icon = "🌋",
        tradeable = false,
    },
    {
        id = "desert_coins",
        name = "Desert Crystals",
        description = "Desert biome currency",
        maxAmount = 999999999,
        defaultAmount = 0,
        icon = "🏜️",
        tradeable = false,
    },
    {
        id = "beach_coins",
        name = "Beach Crystals",
        description = "Beach biome currency",
        maxAmount = 999999999,
        defaultAmount = 0,
        icon = "🏖️",
        tradeable = false,
    },
    {
        id = "light_tokens",
        name = "Light Tokens",
        description = "Heaven layer token (Halo)",
        maxAmount = 999999,
        defaultAmount = 0,
        icon = "😇",
        tradeable = false,
    },
    {
        id = "shadow_tokens",
        name = "Shadow Tokens",
        description = "Hell layer token (Horns)",
        maxAmount = 999999,
        defaultAmount = 0,
        icon = "😈",
        tradeable = false,
    },
}
