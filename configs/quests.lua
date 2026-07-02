--[[
    Quests — Halo & Horns MISSIONS (ACTIVE TASKS ONLY).

    MODEL (Jason 2026-06-29, SSOT docs/QUESTS_VS_ACHIEVEMENTS.md): a quest is an ACTIVE TASK you are
    doing right now. Every quest counts FROM ACTIVATION (since_start) — re-doable, "Hatch 100 eggs"
    means 100 NEW eggs from now, never a lifetime total. NOTHING PASSIVE lives in quests: no
    "reach level N", no lifetime milestones — those are ACHIEVEMENTS (configs/achievements.lua,
    claimable, background). The ONE exception: a level may UNLOCK a track (the gate), never be a goal.

    TRACKS are LEVEL-GATED and HIDDEN until their `unlock_level` (QuestService filters them out of the
    list below that level). Crossing the level fires "New quests available!" — a sound + the Quests
    button pulses (track_unlocked). First Steps `unlock_level = 1` and AUTO-ACTIVATES as the single
    focus right after the tutorial; it carries the player to Level 2.

    Each track is its own ordered chain (QuestChain): one active head, the next unlocks when the head
    is claimed. Tracks run in parallel once unlocked. since_start baselines per-mission at activation.

    Goals are MODEST + re-doable (a session's worth), NOT lifetime grinds — those are achievements.
]]

return {
    -- Track metadata: id -> { title, order, unlock_level }. order = display priority; unlock_level =
    -- the earned Level at which the track appears (hidden below it). first_steps auto-activates.
    tracks = {
        first_steps = { title = "First Steps", order = 0, unlock_level = 1 },
        mining = { title = "Deep Mining", order = 1, unlock_level = 2 },
        hatchery = { title = "The Hatchery", order = 2, unlock_level = 3 },
        collector = { title = "The Collector", order = 3, unlock_level = 4 },
        warpath = { title = "The Warpath", order = 4, unlock_level = 5 },
        trailblazer = { title = "Trailblazer", order = 5, unlock_level = 8 },
        crossing = { title = "The Crossing", order = 6, unlock_level = 12 },
    },

    defs = {
        -- ===================== FIRST STEPS (auto-activated onramp → Level 2) =====================
        -- Picks up where the tutorial ends. since_start so tutorial casts/breaks can't pre-complete it
        -- (Jason hit "Boost the Patch" 5/3 from tutorial casts). Teaches the core loop: power → mine →
        -- hatch → earn, capstone grants the full L2 bar.
        fs_boost = {
            track = "first_steps",
            order = 1,
            name = "Boost the Patch",
            description = "Pulse Resonance near crystals — your pets mine the whole patch harder.",
            condition = {
                type = "counter_at_least",
                counter = "powers_cast",
                value = 3,
                since_start = true,
            },
            reward = { currencies = { gems = 5 } },
        },
        fs_mine = {
            track = "first_steps",
            order = 2,
            name = "Work the Vein",
            description = "Smash 30 crystals — coins fund everything you'll do here.",
            condition = {
                type = "counter_at_least",
                counter = "breakables_broken",
                value = 30,
                since_start = true,
            },
            reward = { currencies = { gems = 10 } },
        },
        fs_grow = {
            track = "first_steps",
            order = 3,
            name = "Grow Your Collection",
            description = "Spend your coins on 10 eggs — a bigger squad mines faster.",
            condition = {
                type = "counter_at_least",
                counter = "eggs_hatched",
                value = 10,
                since_start = true,
            },
            reward = { currencies = { gems = 10 } },
        },
        fs_coffers = {
            track = "first_steps",
            order = 4,
            name = "Fill Your Coffers",
            description = "Earn 1,500 crystals from your hauls — you'll need them for the next area.",
            condition = {
                type = "counter_at_least",
                counter = "coins_earned_lifetime",
                value = 1500,
                since_start = true,
            },
            reward = { currencies = { gems = 10 } },
        },
        fs_welcome = {
            track = "first_steps",
            order = 5,
            name = "Welcome to the Realm",
            description = "Smash 50 more crystals to graduate — then claim your reward.",
            condition = {
                type = "counter_at_least",
                counter = "breakables_broken",
                value = 50,
                since_start = true,
            },
            -- Onramp capstone: a guaranteed jump to Level 2 (700 XP = the full L2 bar) + a head start on
            -- the first area gate (Meadow = 2000 grass_coins) + gems.
            reward = {
                experience = 700,
                currencies = { gems = 15, area_coins = 1500 },
            },
        },

        -- ===================== DEEP MINING (unlocks L2) =====================
        mine_break_100 = {
            track = "mining",
            order = 1,
            name = "Break 100 Crystals",
            description = "Run the mining train — smash 100 crystal nodes.",
            condition = {
                type = "counter_at_least",
                counter = "breakables_broken",
                value = 100,
                since_start = true,
            },
            reward = { currencies = { gems = 10 } },
        },
        mine_earn_3k = {
            track = "mining",
            order = 2,
            name = "Earn 3,000 Crystals",
            description = "Mining pays — bank 3,000 crystals from your hauls.",
            condition = {
                type = "counter_at_least",
                counter = "coins_earned_lifetime",
                value = 3000,
                since_start = true,
            },
            reward = { currencies = { gems = 15 } },
        },
        mine_break_500 = {
            track = "mining",
            order = 3,
            name = "Break 500 Crystals",
            description = "Bigger crystals pay bigger. Yield buffs stack with everything.",
            condition = {
                type = "counter_at_least",
                counter = "breakables_broken",
                value = 500,
                since_start = true,
            },
            reward = { currencies = { area_coins = 5000 } },
        },

        -- ===================== THE HATCHERY (unlocks L3) =====================
        hatch_25 = {
            track = "hatchery",
            order = 1,
            name = "Hatch 25 Eggs",
            description = "Spend your crystals on eggs and grow the collection.",
            condition = {
                type = "counter_at_least",
                counter = "eggs_hatched",
                value = 25,
                since_start = true,
            },
            reward = { currencies = { gems = 10 } },
        },
        hatch_100 = {
            track = "hatchery",
            order = 2,
            name = "Hatch 100 Eggs",
            description = "Keep hatching — duplicates make your team stronger.",
            condition = {
                type = "counter_at_least",
                counter = "eggs_hatched",
                value = 100,
                since_start = true,
            },
            reward = { currencies = { gems = 20 } },
        },
        hatch_250 = {
            track = "hatchery",
            order = 3,
            name = "Hatch 250 Eggs",
            description = "A real hatchery now. Luck powers make every egg count.",
            condition = {
                type = "counter_at_least",
                counter = "eggs_hatched",
                value = 250,
                since_start = true,
            },
            reward = { currencies = { gems = 40 } },
        },

        -- ===================== THE COLLECTOR (unlocks L4) =====================
        gear_hunter = {
            track = "collector",
            order = 1,
            name = "Find an Enhancement",
            description = "Crystals and enemies sometimes drop glowing cogs — grab one!",
            condition = {
                type = "counter_at_least",
                counter = "enhancements_found",
                value = 1,
                since_start = true,
            },
            reward = { currencies = { gems = 5 } },
        },
        gear_smith = {
            track = "collector",
            order = 2,
            name = "Slot an Enhancement",
            description = "Open a power in the Powers menu and slot a cog into it.",
            condition = {
                type = "counter_at_least",
                counter = "enhancements_slotted",
                value = 1,
                since_start = true,
            },
            reward = { currencies = { gems = 8 } },
        },
        gear_collector = {
            track = "collector",
            order = 3,
            name = "Find 10 Enhancements",
            description = "Singles only drop in their home world. Duals are everywhere.",
            condition = {
                type = "counter_at_least",
                counter = "enhancements_found",
                value = 10,
                since_start = true,
            },
            reward = { currencies = { gems = 25 } },
        },

        -- ===================== THE WARPATH (unlocks L5 — combat) =====================
        -- No "Reach Level 5" quest: Level 5 is the track's unlock GATE, not a goal. Enemies invade at 5,
        -- so these become available exactly when they're beatable.
        war_cast_20 = {
            track = "warpath",
            order = 1,
            name = "Cast 20 Powers",
            description = "Powers win fights — keep them on cooldown.",
            condition = {
                type = "counter_at_least",
                counter = "powers_cast",
                value = 20,
                since_start = true,
            },
            reward = { currencies = { gems = 10 } },
        },
        war_defeat_25 = {
            track = "warpath",
            order = 2,
            name = "Defeat 25 Enemies",
            description = "Your squad fights back — let your tank pull and pile on.",
            condition = {
                type = "counter_at_least",
                counter = "enemies_defeated",
                value = 25,
                since_start = true,
            },
            reward = { currencies = { gems = 15 } },
        },
        war_defeat_100 = {
            track = "warpath",
            order = 3,
            name = "Defeat 100 Enemies",
            description = "Hold the line — a hundred invaders sent back.",
            condition = {
                type = "counter_at_least",
                counter = "enemies_defeated",
                value = 100,
                since_start = true,
            },
            reward = { currencies = { gems = 25 }, items = { { id = "health_potion", qty = 3 } } },
        },

        -- ===================== TRAILBLAZER (unlocks L8 — explore) =====================
        path_next_area = {
            track = "trailblazer",
            order = 1,
            name = "Unlock the Next Area",
            description = "Spread out — each area opens new pets and richer ore.",
            condition = {
                type = "counter_at_least",
                counter = "areas_unlocked",
                value = 1,
                since_start = true,
            },
            reward = { currencies = { gems = 15 } },
        },
        path_3_areas = {
            track = "trailblazer",
            order = 2,
            name = "Unlock 3 Areas",
            description = "Open the gates — biome coins compound as you expand.",
            condition = {
                type = "counter_at_least",
                counter = "areas_unlocked",
                value = 3,
                since_start = true,
            },
            reward = { currencies = { gems = 30 } },
        },
        path_creators = {
            track = "trailblazer",
            order = 3,
            name = "Meet 3 Creators",
            description = "Track down the Creators scattered across the realms.",
            condition = {
                type = "counter_at_least",
                counter = "creators_met",
                value = 3,
                since_start = true,
            },
            reward = { currencies = { gems = 25 } },
        },

        -- ===================== THE CROSSING (unlocks L12 — heaven/hell) =====================
        go_heaven = {
            track = "crossing",
            order = 1,
            name = "Journey to Heaven",
            description = "Climb past the Desert gate and set foot in a Heaven realm.",
            condition = {
                type = "counter_at_least",
                counter = "heaven_visits",
                value = 1,
                since_start = true,
            },
            reward = { currencies = { gems = 20 } },
        },
        go_hell = {
            track = "crossing",
            order = 2,
            name = "Descend into Hell",
            description = "Brave the depths below — reach a Hell realm.",
            condition = {
                type = "counter_at_least",
                counter = "hell_visits",
                value = 1,
                since_start = true,
            },
            reward = { currencies = { gems = 20 } },
        },
        realm_settler = {
            track = "crossing",
            order = 3,
            name = "Unlock a Realm Area",
            description = "Stake your claim above or below — unlock any Heaven or Hell zone.",
            condition = {
                type = "counter_at_least",
                counter = "heaven_areas_unlocked",
                value = 1,
                since_start = true,
            },
            reward = { currencies = { gems = 60 } },
        },
    },
}
