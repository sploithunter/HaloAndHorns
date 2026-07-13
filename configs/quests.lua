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
        -- Door missions: the trials + Jason's random-mission ladder ("scale it
        -- up to something ridiculous... always be on a random quest").
        trials = { title = "The Trials", order = 7, unlock_level = 7 },
        -- THE MATRIX (2 realms x 4 elements): every quest in a track BINDS
        -- the auto gates to its trial (def.mission); 100-clear = Platinum egg
        hell_lava = { title = "Hell Lava Trials", order = 8, unlock_level = 7 },
        heaven_lava = { title = "Heaven Lava Trials", order = 9, unlock_level = 7 },
        hell_ice = { title = "Hell Ice Trials", order = 10, unlock_level = 7 },
        heaven_ice = { title = "Heaven Ice Trials", order = 11, unlock_level = 7 },
        hell_grass = { title = "Hell Grass Trials", order = 12, unlock_level = 7 },
        heaven_grass = { title = "Heaven Grass Trials", order = 13, unlock_level = 7 },
        hell_desert = { title = "Hell Desert Trials", order = 14, unlock_level = 7 },
        heaven_desert = { title = "Heaven Desert Trials", order = 15, unlock_level = 7 },
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
            description = "Smash 20 crystals — coins fund everything you'll do here.",
            condition = {
                type = "counter_at_least",
                counter = "breakables_broken",
                value = 20, -- was 30 (Jason 2026-07-13: tighten the onramp pacing)
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
        -- id CHANGED fs_welcome -> fs_cave with the combat retune: since_start
        -- baselines persist BY QUEST ID, so the old id carried a breakables
        -- baseline that froze the new enemies counter at 0/5 (Jason hit it live)
        fs_cave = {
            track = "first_steps",
            order = 5,
            -- WAS "smash 50 more crystals" — Work the Vein again with a bigger
            -- number (Jason: "if that's the case, get rid of it"). The capstone
            -- now graduates through COMBAT — the thing this game does that pet
            -- sims don't, taught at the cave the tutorial just introduced.
            name = "Answer the Cave",
            description = "The Earth cave keeps stirring — defeat 5 creatures there. Your pets fight for you!",
            condition = {
                type = "counter_at_least",
                counter = "enemies_defeated",
                value = 5,
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

        -- ===================== THE TRIALS (door missions + the random ladder) =====================
        -- Chain: first trial UNLOCKS the random-mission doors (def.unlock →
        -- GameData.Unlocks.random_missions, checked by MissionInstanceService),
        -- then the ladder counts LIFETIME random completions — career totals,
        -- deliberately absurd at the top (10 → 100 → 1,000 → 10,000).
        tr_first_trial = {
            track = "trials",
            order = 1,
            name = "Answer the Call",
            description = "Complete any Trial behind a mission door.",
            condition = {
                type = "counter_at_least",
                counter = "missions_completed",
                value = 1,
            },
            reward = { currencies = { gems = 25 } },
        },
        tr_random_10 = {
            track = "trials",
            order = 2,
            name = "Roll the Dice",
            description = "Complete 10 trials.",
            condition = {
                type = "counter_at_least",
                counter = "missions_completed",
                value = 10,
            },
            reward = { currencies = { gems = 50 } },
        },
        tr_treasure_25 = {
            track = "trials",
            order = 3,
            name = "Treasure Hunter",
            description = "Crack open 25 mission treasure chests.",
            condition = {
                type = "counter_at_least",
                counter = "mission_chests_opened",
                value = 25,
            },
            reward = { currencies = { gems = 75 } },
        },
        tr_random_100 = {
            track = "trials",
            order = 4,
            name = "Veteran of a Hundred Doors",
            description = "Complete 100 trials.",
            condition = {
                type = "counter_at_least",
                counter = "missions_completed",
                value = 100,
            },
            reward = { currencies = { gems = 150 } },
        },
        tr_random_1000 = {
            track = "trials",
            order = 5,
            name = "The Thousand-Door March",
            description = "Complete 1,000 trials.",
            condition = {
                type = "counter_at_least",
                counter = "missions_completed",
                value = 1000,
            },
            reward = { currencies = { gems = 500 } },
        },
        tr_random_10000 = {
            track = "trials",
            order = 6,
            name = "Legend of the Infinite Halls",
            description = "Complete 10,000 trials. Yes, really.",
            condition = {
                type = "counter_at_least",
                counter = "missions_completed",
                value = 10000,
            },
            reward = { currencies = { gems = 2500 } },
        },
        -- ===================== THE MATRIX TRIALS (8 tracks, Platinum centuries) =====================
        hell_lava_10 = {
            track = "hell_lava",
            order = 1,
            name = "Hell Lava: 10 Trials",
            description = "Complete 10 Hell Lava Trials.",
            mission = "hell_lava_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_lava_trials_completed",
                value = 10,
            },
            reward = { currencies = { gems = 30 } },
        },
        hell_lava_25 = {
            track = "hell_lava",
            order = 2,
            name = "Hell Lava: 25 Trials",
            description = "Complete 25 Hell Lava Trials.",
            mission = "hell_lava_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_lava_trials_completed",
                value = 25,
            },
            reward = { currencies = { gems = 60 } },
        },
        hell_lava_50 = {
            track = "hell_lava",
            order = 3,
            name = "Hell Lava: 50 Trials",
            description = "Complete 50 Hell Lava Trials.",
            mission = "hell_lava_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_lava_trials_completed",
                value = 50,
            },
            reward = { currencies = { gems = 120 } },
        },
        hell_lava_90 = {
            track = "hell_lava",
            order = 4,
            name = "Hell Lava: 90 Trials",
            description = "Complete 90 Hell Lava Trials.",
            mission = "hell_lava_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_lava_trials_completed",
                value = 90,
            },
            reward = { currencies = { gems = 250 } },
        },
        hell_lava_100 = {
            track = "hell_lava",
            order = 5,
            name = "Hell Lava: The Century",
            description = "Complete 100 Hell Lava Trials. Requires Level 50. The Platinum egg awaits.",
            mission = "hell_lava_trial",
            -- ANTI-ALT (Jason): the century itself demands a leveled account —
            -- alts can grind 90 but can't CLAIM without hitting 50
            condition = {
                type = "all_of",
                of = {
                    {
                        type = "counter_at_least",
                        counter = "hell_lava_trials_completed",
                        value = 100,
                    },
                    { type = "level_at_least", value = 50 },
                },
            },
            reward = {
                currencies = { gems = 500 },
                items = { { id = "platinum_obsidian_egg", bucket = "eggs", qty = 1 } },
            },
        },
        heaven_lava_10 = {
            track = "heaven_lava",
            order = 1,
            name = "Heaven Lava: 10 Trials",
            description = "Complete 10 Heaven Lava Trials.",
            mission = "heaven_lava_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_lava_trials_completed",
                value = 10,
            },
            reward = { currencies = { gems = 30 } },
        },
        heaven_lava_25 = {
            track = "heaven_lava",
            order = 2,
            name = "Heaven Lava: 25 Trials",
            description = "Complete 25 Heaven Lava Trials.",
            mission = "heaven_lava_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_lava_trials_completed",
                value = 25,
            },
            reward = { currencies = { gems = 60 } },
        },
        heaven_lava_50 = {
            track = "heaven_lava",
            order = 3,
            name = "Heaven Lava: 50 Trials",
            description = "Complete 50 Heaven Lava Trials.",
            mission = "heaven_lava_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_lava_trials_completed",
                value = 50,
            },
            reward = { currencies = { gems = 120 } },
        },
        heaven_lava_90 = {
            track = "heaven_lava",
            order = 4,
            name = "Heaven Lava: 90 Trials",
            description = "Complete 90 Heaven Lava Trials.",
            mission = "heaven_lava_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_lava_trials_completed",
                value = 90,
            },
            reward = { currencies = { gems = 250 } },
        },
        heaven_lava_100 = {
            track = "heaven_lava",
            order = 5,
            name = "Heaven Lava: The Century",
            description = "Complete 100 Heaven Lava Trials. Requires Level 50. The Platinum egg awaits.",
            mission = "heaven_lava_trial",
            -- ANTI-ALT (Jason): the century itself demands a leveled account —
            -- alts can grind 90 but can't CLAIM without hitting 50
            condition = {
                type = "all_of",
                of = {
                    {
                        type = "counter_at_least",
                        counter = "heaven_lava_trials_completed",
                        value = 100,
                    },
                    { type = "level_at_least", value = 50 },
                },
            },
            reward = {
                currencies = { gems = 500 },
                items = { { id = "platinum_celestial_egg", bucket = "eggs", qty = 1 } },
            },
        },
        hell_ice_10 = {
            track = "hell_ice",
            order = 1,
            name = "Hell Ice: 10 Trials",
            description = "Complete 10 Hell Ice Trials.",
            mission = "hell_ice_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_ice_trials_completed",
                value = 10,
            },
            reward = { currencies = { gems = 30 } },
        },
        hell_ice_25 = {
            track = "hell_ice",
            order = 2,
            name = "Hell Ice: 25 Trials",
            description = "Complete 25 Hell Ice Trials.",
            mission = "hell_ice_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_ice_trials_completed",
                value = 25,
            },
            reward = { currencies = { gems = 60 } },
        },
        hell_ice_50 = {
            track = "hell_ice",
            order = 3,
            name = "Hell Ice: 50 Trials",
            description = "Complete 50 Hell Ice Trials.",
            mission = "hell_ice_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_ice_trials_completed",
                value = 50,
            },
            reward = { currencies = { gems = 120 } },
        },
        hell_ice_90 = {
            track = "hell_ice",
            order = 4,
            name = "Hell Ice: 90 Trials",
            description = "Complete 90 Hell Ice Trials.",
            mission = "hell_ice_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_ice_trials_completed",
                value = 90,
            },
            reward = { currencies = { gems = 250 } },
        },
        hell_ice_100 = {
            track = "hell_ice",
            order = 5,
            name = "Hell Ice: The Century",
            description = "Complete 100 Hell Ice Trials. Requires Level 50. The Platinum egg awaits.",
            mission = "hell_ice_trial",
            -- ANTI-ALT (Jason): the century itself demands a leveled account —
            -- alts can grind 90 but can't CLAIM without hitting 50
            condition = {
                type = "all_of",
                of = {
                    {
                        type = "counter_at_least",
                        counter = "hell_ice_trials_completed",
                        value = 100,
                    },
                    { type = "level_at_least", value = 50 },
                },
            },
            reward = {
                currencies = { gems = 500 },
                items = { { id = "platinum_obsidian_egg", bucket = "eggs", qty = 1 } },
            },
        },
        heaven_ice_10 = {
            track = "heaven_ice",
            order = 1,
            name = "Heaven Ice: 10 Trials",
            description = "Complete 10 Heaven Ice Trials.",
            mission = "heaven_ice_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_ice_trials_completed",
                value = 10,
            },
            reward = { currencies = { gems = 30 } },
        },
        heaven_ice_25 = {
            track = "heaven_ice",
            order = 2,
            name = "Heaven Ice: 25 Trials",
            description = "Complete 25 Heaven Ice Trials.",
            mission = "heaven_ice_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_ice_trials_completed",
                value = 25,
            },
            reward = { currencies = { gems = 60 } },
        },
        heaven_ice_50 = {
            track = "heaven_ice",
            order = 3,
            name = "Heaven Ice: 50 Trials",
            description = "Complete 50 Heaven Ice Trials.",
            mission = "heaven_ice_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_ice_trials_completed",
                value = 50,
            },
            reward = { currencies = { gems = 120 } },
        },
        heaven_ice_90 = {
            track = "heaven_ice",
            order = 4,
            name = "Heaven Ice: 90 Trials",
            description = "Complete 90 Heaven Ice Trials.",
            mission = "heaven_ice_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_ice_trials_completed",
                value = 90,
            },
            reward = { currencies = { gems = 250 } },
        },
        heaven_ice_100 = {
            track = "heaven_ice",
            order = 5,
            name = "Heaven Ice: The Century",
            description = "Complete 100 Heaven Ice Trials. Requires Level 50. The Platinum egg awaits.",
            mission = "heaven_ice_trial",
            -- ANTI-ALT (Jason): the century itself demands a leveled account —
            -- alts can grind 90 but can't CLAIM without hitting 50
            condition = {
                type = "all_of",
                of = {
                    {
                        type = "counter_at_least",
                        counter = "heaven_ice_trials_completed",
                        value = 100,
                    },
                    { type = "level_at_least", value = 50 },
                },
            },
            reward = {
                currencies = { gems = 500 },
                items = { { id = "platinum_celestial_egg", bucket = "eggs", qty = 1 } },
            },
        },
        hell_grass_10 = {
            track = "hell_grass",
            order = 1,
            name = "Hell Grass: 10 Trials",
            description = "Complete 10 Hell Grass Trials.",
            mission = "hell_grass_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_grass_trials_completed",
                value = 10,
            },
            reward = { currencies = { gems = 30 } },
        },
        hell_grass_25 = {
            track = "hell_grass",
            order = 2,
            name = "Hell Grass: 25 Trials",
            description = "Complete 25 Hell Grass Trials.",
            mission = "hell_grass_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_grass_trials_completed",
                value = 25,
            },
            reward = { currencies = { gems = 60 } },
        },
        hell_grass_50 = {
            track = "hell_grass",
            order = 3,
            name = "Hell Grass: 50 Trials",
            description = "Complete 50 Hell Grass Trials.",
            mission = "hell_grass_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_grass_trials_completed",
                value = 50,
            },
            reward = { currencies = { gems = 120 } },
        },
        hell_grass_90 = {
            track = "hell_grass",
            order = 4,
            name = "Hell Grass: 90 Trials",
            description = "Complete 90 Hell Grass Trials.",
            mission = "hell_grass_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_grass_trials_completed",
                value = 90,
            },
            reward = { currencies = { gems = 250 } },
        },
        hell_grass_100 = {
            track = "hell_grass",
            order = 5,
            name = "Hell Grass: The Century",
            description = "Complete 100 Hell Grass Trials. Requires Level 50. The Platinum egg awaits.",
            mission = "hell_grass_trial",
            -- ANTI-ALT (Jason): the century itself demands a leveled account —
            -- alts can grind 90 but can't CLAIM without hitting 50
            condition = {
                type = "all_of",
                of = {
                    {
                        type = "counter_at_least",
                        counter = "hell_grass_trials_completed",
                        value = 100,
                    },
                    { type = "level_at_least", value = 50 },
                },
            },
            reward = {
                currencies = { gems = 500 },
                items = { { id = "platinum_obsidian_egg", bucket = "eggs", qty = 1 } },
            },
        },
        heaven_grass_10 = {
            track = "heaven_grass",
            order = 1,
            name = "Heaven Grass: 10 Trials",
            description = "Complete 10 Heaven Grass Trials.",
            mission = "heaven_grass_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_grass_trials_completed",
                value = 10,
            },
            reward = { currencies = { gems = 30 } },
        },
        heaven_grass_25 = {
            track = "heaven_grass",
            order = 2,
            name = "Heaven Grass: 25 Trials",
            description = "Complete 25 Heaven Grass Trials.",
            mission = "heaven_grass_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_grass_trials_completed",
                value = 25,
            },
            reward = { currencies = { gems = 60 } },
        },
        heaven_grass_50 = {
            track = "heaven_grass",
            order = 3,
            name = "Heaven Grass: 50 Trials",
            description = "Complete 50 Heaven Grass Trials.",
            mission = "heaven_grass_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_grass_trials_completed",
                value = 50,
            },
            reward = { currencies = { gems = 120 } },
        },
        heaven_grass_90 = {
            track = "heaven_grass",
            order = 4,
            name = "Heaven Grass: 90 Trials",
            description = "Complete 90 Heaven Grass Trials.",
            mission = "heaven_grass_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_grass_trials_completed",
                value = 90,
            },
            reward = { currencies = { gems = 250 } },
        },
        heaven_grass_100 = {
            track = "heaven_grass",
            order = 5,
            name = "Heaven Grass: The Century",
            description = "Complete 100 Heaven Grass Trials. Requires Level 50. The Platinum egg awaits.",
            mission = "heaven_grass_trial",
            -- ANTI-ALT (Jason): the century itself demands a leveled account —
            -- alts can grind 90 but can't CLAIM without hitting 50
            condition = {
                type = "all_of",
                of = {
                    {
                        type = "counter_at_least",
                        counter = "heaven_grass_trials_completed",
                        value = 100,
                    },
                    { type = "level_at_least", value = 50 },
                },
            },
            reward = {
                currencies = { gems = 500 },
                items = { { id = "platinum_celestial_egg", bucket = "eggs", qty = 1 } },
            },
        },
        hell_desert_10 = {
            track = "hell_desert",
            order = 1,
            name = "Hell Desert: 10 Trials",
            description = "Complete 10 Hell Desert Trials.",
            mission = "hell_desert_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_desert_trials_completed",
                value = 10,
            },
            reward = { currencies = { gems = 30 } },
        },
        hell_desert_25 = {
            track = "hell_desert",
            order = 2,
            name = "Hell Desert: 25 Trials",
            description = "Complete 25 Hell Desert Trials.",
            mission = "hell_desert_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_desert_trials_completed",
                value = 25,
            },
            reward = { currencies = { gems = 60 } },
        },
        hell_desert_50 = {
            track = "hell_desert",
            order = 3,
            name = "Hell Desert: 50 Trials",
            description = "Complete 50 Hell Desert Trials.",
            mission = "hell_desert_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_desert_trials_completed",
                value = 50,
            },
            reward = { currencies = { gems = 120 } },
        },
        hell_desert_90 = {
            track = "hell_desert",
            order = 4,
            name = "Hell Desert: 90 Trials",
            description = "Complete 90 Hell Desert Trials.",
            mission = "hell_desert_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "hell_desert_trials_completed",
                value = 90,
            },
            reward = { currencies = { gems = 250 } },
        },
        hell_desert_100 = {
            track = "hell_desert",
            order = 5,
            name = "Hell Desert: The Century",
            description = "Complete 100 Hell Desert Trials. Requires Level 50. The Platinum egg awaits.",
            mission = "hell_desert_trial",
            -- ANTI-ALT (Jason): the century itself demands a leveled account —
            -- alts can grind 90 but can't CLAIM without hitting 50
            condition = {
                type = "all_of",
                of = {
                    {
                        type = "counter_at_least",
                        counter = "hell_desert_trials_completed",
                        value = 100,
                    },
                    { type = "level_at_least", value = 50 },
                },
            },
            reward = {
                currencies = { gems = 500 },
                items = { { id = "platinum_obsidian_egg", bucket = "eggs", qty = 1 } },
            },
        },
        heaven_desert_10 = {
            track = "heaven_desert",
            order = 1,
            name = "Heaven Desert: 10 Trials",
            description = "Complete 10 Heaven Desert Trials.",
            mission = "heaven_desert_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_desert_trials_completed",
                value = 10,
            },
            reward = { currencies = { gems = 30 } },
        },
        heaven_desert_25 = {
            track = "heaven_desert",
            order = 2,
            name = "Heaven Desert: 25 Trials",
            description = "Complete 25 Heaven Desert Trials.",
            mission = "heaven_desert_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_desert_trials_completed",
                value = 25,
            },
            reward = { currencies = { gems = 60 } },
        },
        heaven_desert_50 = {
            track = "heaven_desert",
            order = 3,
            name = "Heaven Desert: 50 Trials",
            description = "Complete 50 Heaven Desert Trials.",
            mission = "heaven_desert_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_desert_trials_completed",
                value = 50,
            },
            reward = { currencies = { gems = 120 } },
        },
        heaven_desert_90 = {
            track = "heaven_desert",
            order = 4,
            name = "Heaven Desert: 90 Trials",
            description = "Complete 90 Heaven Desert Trials.",
            mission = "heaven_desert_trial", -- binds the auto gates while this track is active
            condition = {
                type = "counter_at_least",
                counter = "heaven_desert_trials_completed",
                value = 90,
            },
            reward = { currencies = { gems = 250 } },
        },
        heaven_desert_100 = {
            track = "heaven_desert",
            order = 5,
            name = "Heaven Desert: The Century",
            description = "Complete 100 Heaven Desert Trials. Requires Level 50. The Platinum egg awaits.",
            mission = "heaven_desert_trial",
            -- ANTI-ALT (Jason): the century itself demands a leveled account —
            -- alts can grind 90 but can't CLAIM without hitting 50
            condition = {
                type = "all_of",
                of = {
                    {
                        type = "counter_at_least",
                        counter = "heaven_desert_trials_completed",
                        value = 100,
                    },
                    { type = "level_at_least", value = 50 },
                },
            },
            reward = {
                currencies = { gems = 500 },
                items = { { id = "platinum_celestial_egg", bucket = "eggs", qty = 1 } },
            },
        },
    },
}
