-- Pet enchant configuration.
--
-- This is the single source of truth for both:
-- 1. how enchants roll: rarity profiles, roll counts, weights, strength ranges;
-- 2. what enchants do: modifier stage/kind/currency/combine/amount mappings.
--
-- Saved pets should store only rolled state such as `{ id = "scholar",
-- strength = 2 }`. Do not put enchant behavior on pet configs or individual pet
-- records. To rebalance or redefine an enchant, edit `effects` below.
--
-- For an effect to be live, some gameplay system must resolve the matching
-- modifier context through ModifierService. Current live contexts include
-- `breakable_reward`, `pet_xp`, `hatch_luck`, `secret_hatch_luck`,
-- `pet_damage`, `team_power`, and `pet_efficiency`.

return {
    version = "1.0.0",
    enabled = true,

    -- FOREGROUND DISPLAY (Jason, 2026-06-12: enchants were the only buff system with
    -- zero visible presence — "we need a foreground use of it"). Enchant badges use
    -- the SAME visual alphabet as auras/powers (disc symbol = what it does) on the
    -- NEUTRAL (white) disc, with the RING METAL carrying strength 1-5. Cards place
    -- enchants lower-LEFT (per-copy identity) vs auras lower-RIGHT (species role).
    display = {
        -- effect id -> disc symbol (power_icons neutral disc set)
        symbols = {
            coin_finder = "coins_up",
            crystal_finder = "magnet",
            scholar = "xp_up",
            luck = "clover_lucky",
            secret_luck = "clover_huge",
            efficiency = "chevrons_up",
            tactics = "target",
            leadership = "star_sparkle",
            home_world = "portal",
        },
        -- METAL RING per strength (copper -> bronze -> silver -> gold -> onyx).
        -- `asset` = Jason's ring art (drop the rbxassetid in when it lands); until
        -- then the grayscale enhancement ring is tinted with `tint`. Copper/bronze
        -- are deliberately separated by VALUE (light warm vs dark warm) so they
        -- read apart at badge size; onyx carries a faint purple cast so a black
        -- ring never vanishes against dark card chrome.
        -- Jason's metal ring art (assets/ui/enchant_rings, uploaded 2026-06-12);
        -- tint remains as the fallback if an asset ever fails to load.
        ring_tiers = {
            { name = "Copper", tint = { 196, 120, 70 }, asset = "rbxassetid://98395799121019" },
            { name = "Bronze", tint = { 110, 74, 42 }, asset = "rbxassetid://100659029330565" },
            { name = "Silver", tint = { 201, 209, 220 }, asset = "rbxassetid://127566698062573" },
            { name = "Gold", tint = { 240, 196, 60 }, asset = "rbxassetid://94783967669881" },
            { name = "Onyx", tint = { 38, 32, 56 }, asset = "rbxassetid://119998247389513" },
        },
    },

    hatch_rolls = {
        enabled = true,
        require_unlocked_slot = true,
    },

    -- PERMANENT ENCHANTS (Jason, 2026-06-12): huge-and-above are FATED, not crafted —
    -- "once a huge is hatched its first enchant is permanent", and each slot a pet
    -- level-up unlocks auto-rolls on the spot (the level-up IS the reveal, with a
    -- celebration) and locks forever. No Enchanter station access. Secrets and
    -- exclusives stay re-enchantable — that's what makes them the craftable,
    -- highly-tradeable tier. Future top classes (titan/colossal) add their flag here.
    permanent = {
        huge = true, -- the huge TRAIT on the record, not a rarity
        categories = { creator = true }, -- species categories that also lock
    },

    -- STACKABLE ENCHANTS (Storage v2 D2-D4, Jason): rarities here roll ONE effect at
    -- hatch that becomes part of the pet's STACK KEY (id:variant:enchant) — the pet
    -- stays stackable and the enchant is the STACK's identity ("Mythic Scorpion ·
    -- Coin Finder" is its own pile). Strength is FLAT — "Mythic Strength" — resolved
    -- at READ time from `strength` below (never stored on the stack), so tweaking it
    -- retunes every mythic enchant in the world instantly. No rerolls on stacks:
    -- hatching IS the mythic enchant gamble (want a Luck mythic? hatch more mythics);
    -- rerolling stays the privilege of secrets+. Rolls use the same per-rarity pool
    -- as unique hatch rolls (the `mythical` profile: 35% chance, weighted effects).
    stack_enchants = {
        -- legendary is the top STACKABLE tier in today's catalog (no mythic species
        -- exist yet — mythic is pre-wired for when that tier ships). Roll odds come
        -- from each rarity's pool profile (legendary 100%, mythical 35%).
        rarities = { legendary = true, mythic = true },
        strength = 2, -- "Mythic Strength" — THE knob (mid of the old 1-3 ranges)
    },

    -- TYPE (rarity/size) MULTIPLIER on enchant magnitude (Jason: "base * type multiplier — no
    -- shift"). The rolled `strength` is the same +N for every pet; the pet's TIER multiplies the
    -- per-strength base at READ time (never stored on the pet record, so a traded pet re-resolves on
    -- the new owner — same principle as stack "Mythic Strength"). Tier = the huge/titanic/colossal
    -- size trait if present, else the pet's rarity. Resolved in EnchantService:_typeMultiplier.
    -- Coin Finder example (base 0.06 = 6%/strength): exclusive (x2.0) +5 = 60%, colossal (x4.0)
    -- +5 = 120%. No cap on strength (Onyx ring = +5 and up); rarer just scales bigger + adds slots.
    type_multipliers = {
        legendary = 1.0,
        mythic = 1.5,
        secret = 2.0,
        exclusive = 2.0,
        huge = 2.5,
        titanic = 3.0,
        colossal = 4.0,
    },

    reroll = {
        enabled = true,
        requires_station = true,
        station_grace_seconds = 12,
        default_slot = 1,
        cost = {
            currency = "gems",
            amount = 5,
        },
    },

    stations = {
        basic_enchanter = {
            display_name = "Enchanter",
            touch_part_name = "EnchantTouchPart",
            prompt = {
                enabled = true,
                action_text = "Enchant Pets",
                object_text = "Enchanter",
                key = "E",
                max_distance = 14,
                hold_duration = 0,
            },
            animation = {
                enabled = true,
                script_name = "FloatingCoinScript",
                active_when_near = false,
                lightning = {
                    enabled = true,
                    center_part_name = "EnchantTouchPart",
                    center_offset = Vector3.new(0, 1.5, 0),
                    origin_part_name = "Rune",
                    origin_part_paths = {
                        "RuneStone1.Rune",
                        "RuneStone2.Rune",
                        "RuneStone3.Rune",
                        "RuneStone4.Rune",
                    },
                    origin_limit = 4,
                    strands_per_origin = 5,
                    segments = 40,
                    jitter = 1.0,
                    min_radius = 0,
                    max_radius = 1,
                    thickness = 0.42,
                    min_thickness_multiplier = 0.2,
                    max_thickness_multiplier = 1,
                    frequency = 1,
                    animation_speed = 7,
                    curve_size0 = 10,
                    curve_size1 = 15,
                    flicker = 0.35,
                    neon_lift = 0.2,
                    core_enabled = true,
                    core_thickness_multiplier = 0.32,
                    core_opacity_multiplier = 1,
                    fade_out_seconds = 0.35,
                    duration = 2.8,
                    result_delay_seconds = 2.95,
                    sound_name = "enchant_thunder",
                    sound_id = "rbxassetid://71266985896124",
                    volume = 0.9,
                    playback_speed = 0.85,
                    sound_lifetime_seconds = 16,
                    display_pet = {
                        enabled = true,
                        offset = Vector3.new(0, -2.4, 0),
                        yaw_degrees = 180,
                        scale = 1.15,
                        huge_scale = 1.65,
                        lifetime_seconds = 3.2,
                    },
                    colors = {
                        Color3.fromRGB(80, 255, 255),
                        Color3.fromRGB(120, 145, 255),
                        Color3.fromRGB(255, 95, 240),
                        Color3.fromRGB(255, 245, 120),
                    },
                },
            },
        },
    },

    -- Maps a real pets.rarities entry -> a roll_profile. Keys MUST be defined rarities (ConfigLoader
    -- validates). titanic/colossal are NOT rarities yet (size traits), so they're not mapped here —
    -- their roll_profiles + type_multipliers are pre-wired below; add the mapping when those tiers ship.
    rarity_profiles = {
        legendary = "legendary",
        mythic = "mythical",
        secret = "secret",
        exclusive = "exclusive",
        huge = "huge",
    },

    -- Each effect owns its STRENGTH ROLL: `roll = { low, high, scale }`. Strength is +1..+5 (hard
    -- cap, high = 5 for all — no 6+), rarity-INDEPENDENT, so "+5 odds" is one transparent number for
    -- an effect on ANY pet that can roll it. `scale` is the climb steepness: each step toward +5 has
    -- a 1/scale chance, so P(+5) = (1/scale)^4. Rarity's edge is the type_multiplier (value) + slots,
    -- NOT the odds. The rarity profiles below only pick WHICH effects roll and their WEIGHTS.
    --   scale 2 -> +5 = 6.25%  | 3 -> 1.2%  | 4 -> 0.39%  | 5 -> 0.16%  | 6 -> 0.08%
    effects = {
        home_world = {
            display_name = "Home World",
            description = "Increases breakable rewards while the pet is useful in the current world.",
            roll = { low = 1, high = 5, scale = 2 },
            modifier = {
                stage = "enchants",
                kind = "breakable_reward",
                combine = "multiply",
                amount_per_strength = 0.02,
            },
        },
        efficiency = {
            display_name = "Efficiency",
            description = "Faster pet attack cadence (team-wide; pet_efficiency pipeline).",
            roll = { low = 1, high = 5, scale = 4 },
            modifier = {
                stage = "enchants",
                kind = "pet_efficiency",
                combine = "add",
                amount_per_strength = 0.01,
            },
        },
        tactics = {
            display_name = "Tactics",
            description = "More pet damage (team-wide; pet_damage pipeline).",
            roll = { low = 1, high = 5, scale = 3 },
            modifier = {
                stage = "enchants",
                kind = "pet_damage",
                combine = "multiply",
                amount_per_strength = 0.015,
            },
        },
        leadership = {
            display_name = "Leadership",
            description = "Template effect for team-wide pet power bonuses.",
            roll = { low = 1, high = 5, scale = 3 },
            modifier = {
                stage = "enchants",
                kind = "team_power",
                combine = "multiply",
                amount_per_strength = 0.015,
            },
        },
        luck = {
            display_name = "Luck",
            description = "Template effect for general hatch luck.",
            roll = { low = 1, high = 5, scale = 5 },
            modifier = {
                stage = "enchants",
                kind = "hatch_luck",
                combine = "add",
                amount_per_strength = 0.01,
            },
        },
        secret_luck = {
            display_name = "Secret Luck",
            description = "Template effect for secret-pet hatch luck.",
            roll = { low = 1, high = 5, scale = 6 },
            modifier = {
                stage = "enchants",
                kind = "secret_hatch_luck",
                combine = "add",
                amount_per_strength = 0.005,
            },
        },
        crystal_finder = {
            display_name = "Crystal Finder",
            description = "Increases crystal rewards from breakables.",
            roll = { low = 1, high = 5, scale = 2 },
            modifier = {
                stage = "enchants",
                kind = "breakable_reward",
                currency = "crystals",
                combine = "multiply",
                amount_per_strength = 0.015,
            },
        },
        coin_finder = {
            display_name = "Crystal Finder",
            description = "Increases crystal rewards from breakables.",
            roll = { low = 1, high = 5, scale = 2 },
            modifier = {
                stage = "enchants",
                kind = "breakable_reward",
                currency = "coins",
                combine = "multiply",
                -- BASE per strength (legendary tier). Scaled by type_multipliers at read time:
                -- legendary 6%/str, exclusive 12%/str (+5 = 60%), colossal 24%/str (+5 = 120%).
                amount_per_strength = 0.06,
            },
        },
        scholar = {
            display_name = "Scholar",
            description = "Increases pet XP earned from breakables.",
            roll = { low = 1, high = 5, scale = 3 },
            modifier = {
                stage = "enchants",
                kind = "pet_xp",
                combine = "multiply",
                amount_per_strength = 0.02,
            },
        },
    },

    -- Profiles pick WHICH effects can roll + their WEIGHTS only. Strength now lives on each effect
    -- (effects[id].roll, +1..+5, rarity-independent) — so a profile no longer carries strength.
    -- min/max_rolls = how many SLOTS roll at hatch; initial_roll_chance = per-slot gate.
    roll_profiles = {
        legendary = {
            min_rolls = 1,
            max_rolls = 1,
            initial_roll_chance = 1.0,
            prevent_duplicate_effects = true,
            chances = {
                { effect = "home_world", weight = 10 },
                { effect = "efficiency", weight = 5 },
                { effect = "tactics", weight = 2 },
                { effect = "luck", weight = 1 },
                { effect = "leadership", weight = 1 },
                { effect = "secret_luck", weight = 0.1 },
            },
        },
        mythical = {
            min_rolls = 1,
            max_rolls = 1,
            initial_roll_chance = 0.35,
            prevent_duplicate_effects = true,
            chances = {
                { effect = "crystal_finder", weight = 12 },
                { effect = "coin_finder", weight = 8 },
                { effect = "home_world", weight = 10 },
                { effect = "efficiency", weight = 5 },
                { effect = "tactics", weight = 2 },
                { effect = "scholar", weight = 2 },
                { effect = "luck", weight = 1 },
                { effect = "secret_luck", weight = 0.1 },
            },
        },
        secret = {
            min_rolls = 1,
            max_rolls = 2,
            initial_roll_chance = 0.65,
            prevent_duplicate_effects = true,
            chances = {
                { effect = "crystal_finder", weight = 12 },
                { effect = "coin_finder", weight = 8 },
                { effect = "home_world", weight = 10 },
                { effect = "efficiency", weight = 5 },
                { effect = "tactics", weight = 2 },
                { effect = "scholar", weight = 2 },
                { effect = "luck", weight = 1 },
                { effect = "leadership", weight = 1 },
                { effect = "secret_luck", weight = 0.1 },
            },
        },
        exclusive = {
            min_rolls = 1,
            max_rolls = 2,
            initial_roll_chance = 1.0,
            prevent_duplicate_effects = true,
            chances = {
                { effect = "crystal_finder", weight = 12 },
                { effect = "coin_finder", weight = 8 },
                { effect = "home_world", weight = 10 },
                { effect = "efficiency", weight = 5 },
                { effect = "tactics", weight = 2 },
                { effect = "scholar", weight = 2 },
                { effect = "luck", weight = 1 },
                { effect = "leadership", weight = 1 },
                { effect = "secret_luck", weight = 0.1 },
            },
        },
        huge = {
            min_rolls = 1,
            max_rolls = 3,
            initial_roll_chance = 1.0,
            prevent_duplicate_effects = true,
            chances = {
                { effect = "crystal_finder", weight = 12 },
                { effect = "coin_finder", weight = 8 },
                { effect = "home_world", weight = 10 },
                { effect = "efficiency", weight = 5 },
                { effect = "tactics", weight = 2 },
                { effect = "scholar", weight = 2 },
                { effect = "luck", weight = 1 },
                { effect = "leadership", weight = 1 },
                { effect = "secret_luck", weight = 0.1 },
            },
        },
        titanic = {
            min_rolls = 2,
            max_rolls = 4,
            initial_roll_chance = 1.0,
            prevent_duplicate_effects = true,
            chances = {
                { effect = "crystal_finder", weight = 12 },
                { effect = "coin_finder", weight = 8 },
                { effect = "home_world", weight = 10 },
                { effect = "efficiency", weight = 5 },
                { effect = "tactics", weight = 2 },
                { effect = "scholar", weight = 2 },
                { effect = "luck", weight = 1 },
                { effect = "leadership", weight = 1 },
                { effect = "secret_luck", weight = 0.1 },
            },
        },
        colossal = {
            min_rolls = 2,
            max_rolls = 5,
            initial_roll_chance = 1.0,
            prevent_duplicate_effects = true,
            chances = {
                { effect = "crystal_finder", weight = 12 },
                { effect = "coin_finder", weight = 8 },
                { effect = "home_world", weight = 10 },
                { effect = "efficiency", weight = 5 },
                { effect = "tactics", weight = 2 },
                { effect = "scholar", weight = 2 },
                { effect = "luck", weight = 1 },
                { effect = "leadership", weight = 1 },
                { effect = "secret_luck", weight = 0.1 },
            },
        },
    },
}
