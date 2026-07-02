-- Pet progression tuning for unique pets.
-- Stack pets stay compact and do not carry XP/level state until promoted to unique.

return {
    version = "1.0.0",
    enabled = true,

    unique_only = true,
    default_max_level = 1,

    max_level_by_rarity = {
        mythic = 25,
        secret = 50,
        exclusive = 75,
        huge = 100,
    },

    xp_curve = {
        type = "exponential",
        base = 100,
        growth = 1.18,
    },

    -- FLOOR power level scaling — NORMALIZED CAP (Jason: same mechanic as the
    -- eternal level bonus, "we only have to set a cap... it's just scaled"):
    --   bonus = max_bonus_percent x (level-1)/(maxLevel-1)
    -- The per-level step derives from the rarity's max level (100-level huge
    -- ~1%/level, 50-level secret ~2%/level), all landing at +100% at the capstone.
    -- The eternal-output twin lives in pets.lua eternal.level_bonus_max (0.25).
    power_scaling = {
        type = "normalized_cap",
        max_bonus_percent = 1.0,
    },

    enchant_slots = {
        default_unlocked_slots = 1,
        -- CAPSTONE rule (Jason): the FINAL enchant slot unlocks at the rarity's MAX
        -- level — the last awakening is the max-level celebration. Intermediates
        -- spread evenly. (Permanent classes auto-roll + lock at each unlock —
        -- enchants.lua `permanent`; secrets/exclusives unlock an empty slot for
        -- the Enchanter station.)
        unlocks_by_rarity = {
            mythic = {
                { level = 1, slots = 1 },
            },
            secret = { -- max 50
                { level = 1, slots = 1 },
                { level = 50, slots = 2 },
            },
            exclusive = { -- max 75
                { level = 1, slots = 1 },
                { level = 75, slots = 2 },
            },
            huge = { -- max 100: hatch / midpoint / capstone
                { level = 1, slots = 1 },
                { level = 50, slots = 2 },
                { level = 100, slots = 3 },
            },
        },
    },

    xp_sources = {
        breakable_damage = {
            enabled = false,
            xp_per_damage = 0,
        },
        breakable_destroy = {
            enabled = true,
            xp_by_world = {
                Spawn = 8,
                Meadow = 20,
            },
            xp_by_breakable = {
                BigBlueCrystal = 25,
            },
            default_xp = 5,
        },
    },
}
