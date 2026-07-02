--[[
    Achievements — PASSIVE lifetime milestones (Jason 2026-06-29; SSOT docs/QUESTS_VS_ACHIEVEMENTS.md).

    The counterpart to quests: a quest is an ACTIVE task you do now; an achievement just HAPPENS in the
    background as your lifetime totals climb. Everything passive lives here — lifetime totals,
    reach-level, rebirths.

    CLAIMABLE (not auto-granted): when a tier's goal is reached the reward is CLAIMABLE, not given.
    The Achievements panel shows a Claim button on reached tiers and a progress bar on the rest.
    AchievementsService owns the reached/claimed/progress state; `category` groups them in the panel.

    Each achievement tracks ONE stat counter (configs/stats.lua) across ascending `tiers`
    (goal strictly increases). Rewards are currency-only (the schema's shape). Capstone PET rewards
    are a follow-up (needs a reward-schema extension).
]]

return {
    version = "2.0.0",

    -- Panel grouping (Jason: "group the achievements by category"). order = display order.
    categories = {
        hatching = { title = "Hatching", order = 1, icon = "🥚" },
        mining = { title = "Mining", order = 2, icon = "⛏️" },
        combat = { title = "Combat", order = 3, icon = "⚔️" },
        collection = { title = "Collection", order = 4, icon = "🐾" },
        progression = { title = "Progression", order = 5, icon = "⭐" },
        exploration = { title = "Exploration", order = 6, icon = "🧭" },
    },

    achievements = {
        -- ===================== HATCHING =====================
        eggs_hatched = {
            id = "eggs_hatched",
            category = "hatching",
            display_name = "Egg Hatchery",
            stat = "eggs_hatched",
            tiers = {
                {
                    id = "eggs_10",
                    goal = 10,
                    reward = { type = "currency", currency = "gems", amount = 10 },
                },
                {
                    id = "eggs_100",
                    goal = 100,
                    reward = { type = "currency", currency = "gems", amount = 25 },
                },
                {
                    id = "eggs_1k",
                    goal = 1000,
                    reward = { type = "currency", currency = "gems", amount = 75 },
                },
                {
                    id = "eggs_10k",
                    goal = 10000,
                    reward = { type = "currency", currency = "gems", amount = 250 },
                },
                {
                    id = "eggs_25k",
                    goal = 25000,
                    reward = {
                        bundle = {
                            currencies = { gems = 500 },
                            pets = { { id = "bear", variant = "rainbow" } },
                        },
                    },
                },
            },
        },

        -- ===================== MINING =====================
        breakables_broken = {
            id = "breakables_broken",
            category = "mining",
            display_name = "Crystal Crusher",
            stat = "breakables_broken",
            tiers = {
                {
                    id = "breakables_50",
                    goal = 50,
                    reward = { type = "currency", currency = "gems", amount = 8 },
                },
                {
                    id = "breakables_500",
                    goal = 500,
                    reward = { type = "currency", currency = "gems", amount = 20 },
                },
                {
                    id = "breakables_2500",
                    goal = 2500,
                    reward = { type = "currency", currency = "gems", amount = 60 },
                },
                {
                    id = "breakables_25k",
                    goal = 25000,
                    reward = { type = "currency", currency = "gems", amount = 200 },
                },
            },
        },
        coins_earned = {
            id = "coins_earned",
            category = "mining",
            display_name = "Crystal Fortune",
            stat = "coins_earned_lifetime",
            tiers = {
                {
                    id = "coins_8k",
                    goal = 8000,
                    reward = { type = "currency", currency = "gems", amount = 15 },
                },
                {
                    id = "coins_50k",
                    goal = 50000,
                    reward = { type = "currency", currency = "gems", amount = 40 },
                },
                {
                    id = "coins_500k",
                    goal = 500000,
                    reward = { type = "currency", currency = "gems", amount = 150 },
                },
                {
                    id = "coins_1m",
                    goal = 1000000,
                    reward = {
                        bundle = {
                            currencies = { gems = 300 },
                            pets = { { id = "bear", variant = "rainbow" } },
                        },
                    },
                },
            },
        },

        -- ===================== COMBAT =====================
        enemies_defeated = {
            id = "enemies_defeated",
            category = "combat",
            display_name = "Invader Slayer",
            stat = "enemies_defeated",
            tiers = {
                {
                    id = "enemies_10",
                    goal = 10,
                    reward = { type = "currency", currency = "gems", amount = 10 },
                },
                {
                    id = "enemies_100",
                    goal = 100,
                    reward = { type = "currency", currency = "gems", amount = 25 },
                },
                {
                    id = "enemies_1k",
                    goal = 1000,
                    reward = { type = "currency", currency = "gems", amount = 80 },
                },
                {
                    id = "enemies_10k",
                    goal = 10000,
                    reward = {
                        bundle = {
                            currencies = { gems = 300 },
                            pets = { { id = "bear", variant = "rainbow" } },
                        },
                    },
                },
            },
        },
        powers_cast = {
            id = "powers_cast",
            category = "combat",
            display_name = "Power Adept",
            stat = "powers_cast",
            tiers = {
                {
                    id = "powers_100",
                    goal = 100,
                    reward = { type = "currency", currency = "gems", amount = 20 },
                },
                {
                    id = "powers_1k",
                    goal = 1000,
                    reward = { type = "currency", currency = "gems", amount = 80 },
                },
            },
        },

        -- ===================== COLLECTION =====================
        distinct_pets = {
            id = "distinct_pets",
            category = "collection",
            display_name = "Pet Collector",
            stat = "distinct_pets",
            tiers = {
                {
                    id = "distinct_25",
                    goal = 25,
                    reward = { type = "currency", currency = "gems", amount = 30 },
                },
                {
                    id = "distinct_75",
                    goal = 75,
                    reward = {
                        bundle = {
                            currencies = { gems = 200 },
                            pets = { { id = "bear", variant = "rainbow" } },
                        },
                    },
                },
            },
        },
        enhancements_found = {
            id = "enhancements_found",
            category = "collection",
            display_name = "Gear Hunter",
            stat = "enhancements_found",
            tiers = {
                {
                    id = "enh_10",
                    goal = 10,
                    reward = { type = "currency", currency = "gems", amount = 15 },
                },
                {
                    id = "enh_50",
                    goal = 50,
                    reward = { type = "currency", currency = "gems", amount = 80 },
                },
            },
        },

        -- ===================== PROGRESSION (passive — reach-level / rebirth) =====================
        levels_gained = {
            id = "levels_gained",
            category = "progression",
            display_name = "Ascendant",
            stat = "levels_gained",
            -- levels_gained = levels claimed; "Reach Level N" ~= N-1 gained from Level 1.
            tiers = {
                {
                    id = "level_5",
                    goal = 4,
                    reward = { type = "currency", currency = "gems", amount = 20 },
                },
                {
                    id = "level_10",
                    goal = 9,
                    reward = { type = "currency", currency = "gems", amount = 30 },
                },
                {
                    id = "level_15",
                    goal = 14,
                    reward = { type = "currency", currency = "gems", amount = 50 },
                },
                {
                    id = "level_20",
                    goal = 19,
                    reward = { type = "currency", currency = "gems", amount = 75 },
                },
                {
                    id = "level_30",
                    goal = 29,
                    reward = { type = "currency", currency = "gems", amount = 150 },
                },
                {
                    id = "level_50",
                    goal = 49,
                    reward = {
                        bundle = {
                            currencies = { gems = 500 },
                            pets = { { id = "bear", variant = "rainbow" } },
                        },
                    },
                },
            },
        },
        rebirths = {
            id = "rebirths",
            category = "progression",
            display_name = "Reborn",
            stat = "rebirths",
            tiers = {
                {
                    id = "rebirth_1",
                    goal = 1,
                    reward = { type = "currency", currency = "gems", amount = 100 },
                },
                {
                    id = "rebirth_3",
                    goal = 3,
                    reward = { type = "currency", currency = "gems", amount = 350 },
                },
            },
        },

        -- ===================== EXPLORATION =====================
        areas_unlocked = {
            id = "areas_unlocked",
            category = "exploration",
            display_name = "Trailblazer",
            stat = "areas_unlocked",
            tiers = {
                {
                    id = "areas_3",
                    goal = 3,
                    reward = { type = "currency", currency = "gems", amount = 15 },
                },
                {
                    id = "areas_6",
                    goal = 6,
                    reward = {
                        bundle = {
                            currencies = { gems = 40 },
                            pets = { { id = "bear", variant = "rainbow" } },
                        },
                    },
                },
            },
        },
        creators_met = {
            id = "creators_met",
            category = "exploration",
            display_name = "Socialite",
            stat = "creators_met",
            tiers = {
                {
                    id = "creators_5",
                    goal = 5,
                    reward = { type = "currency", currency = "gems", amount = 25 },
                },
            },
        },
        secrets_found = {
            id = "secrets_found",
            category = "exploration",
            display_name = "Secret Seeker",
            stat = "secrets_found",
            tiers = {
                {
                    id = "secrets_5",
                    goal = 5,
                    reward = { type = "currency", currency = "gems", amount = 25 },
                },
            },
        },
        heaven_visits = {
            id = "heaven_visits",
            category = "exploration",
            display_name = "Heaven Bound",
            stat = "heaven_visits",
            tiers = {
                {
                    id = "heaven_1",
                    goal = 1,
                    reward = { type = "currency", currency = "gems", amount = 20 },
                },
            },
        },
        hell_visits = {
            id = "hell_visits",
            category = "exploration",
            display_name = "Hell Bound",
            stat = "hell_visits",
            tiers = {
                {
                    id = "hell_1",
                    goal = 1,
                    reward = { type = "currency", currency = "gems", amount = 20 },
                },
            },
        },
    },
}
