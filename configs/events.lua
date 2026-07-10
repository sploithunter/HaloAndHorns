return {
    tick_seconds = 1,

    workspace = {
        active_folder = "GlobalEvents",
        modifier_folder = "EventModifiers",
        clock_folder = "EventClock",
    },

    modifiers = {
        egg_luck = {
            display_name = "Egg Luck",
            base = 0,
        },
        breakable_reward_multiplier = {
            display_name = "Breakable Reward Multiplier",
            base = 1,
        },
        coin_reward_multiplier = {
            display_name = "Crystal Reward Multiplier",
            base = 1,
        },
        crystal_reward_multiplier = {
            display_name = "Crystal Reward Multiplier",
            base = 1,
        },
        secret_luck = {
            display_name = "Secret Luck",
            base = 0,
        },
        -- additive fractions (base 0): consumers apply (1 + value). 1 = 2x.
        xp_multiplier = {
            display_name = "XP Boost",
            base = 0,
        },
        drop_rate = {
            display_name = "Drop Rate",
            base = 0,
        },
        -- COMBAT CALENDAR axes (Jason 2026-07-09: the weekday rewards predate
        -- combat — "none of them have anything to do with combat content").
        -- All additive fractions (base 0): consumers apply (1 + value).
        exclusive_egg_chance = {
            display_name = "Boss Egg Chance",
            base = 0,
        },
        enemy_drop_rate = {
            display_name = "Enemy Drop Rate",
            base = 0,
        },
        team_mining_bonus = {
            display_name = "Team Mining Bonus",
            base = 0,
        },
        kill_credit_radius_bonus = {
            display_name = "Kill Credit Radius Bonus",
            base = 0,
        },
    },

    global_events = {
        hatch_luck_hour = {
            display_name = "Hatch Luck Hour",
            description = "Improves golden and rainbow hatch odds for everyone.",
            duration_seconds = 3600,
            stacking = "extend_duration",
            icon = "LUCK",
            modifiers = {
                egg_luck = 0.35,
            },
        },

        double_rewards_hour = {
            display_name = "Double Rewards Hour",
            description = "Doubles breakable rewards for everyone.",
            duration_seconds = 3600,
            stacking = "extend_duration",
            icon = "2X",
            modifiers = {
                breakable_reward_multiplier = 1,
            },
        },

        crystal_rush = {
            display_name = "Crystal Rush",
            description = "Boosts crystal rewards from breakables.",
            duration_seconds = 1800,
            stacking = "extend_duration",
            icon = "CRYS",
            modifiers = {
                crystal_reward_multiplier = 0.5,
            },
        },

        coin_shower = {
            display_name = "Crystal Shower",
            description = "Boosts crystal rewards from breakables.",
            duration_seconds = 1800,
            stacking = "extend_duration",
            icon = "COIN",
            modifiers = {
                coin_reward_multiplier = 0.5,
            },
        },

        lucky_day = {
            display_name = "Lucky Day",
            description = "Scheduled daily hatch luck boost.",
            duration_seconds = -1,
            stacking = "reset",
            icon = "DAY",
            modifiers = {
                egg_luck = 0.1,
            },
        },

        -- ── Weekday calendar (all MOUNTAIN time — see scheduled_global_events) ────────────
        -- One all-day event per weekday, each boosting a DISTINCT axis so every day feels
        -- different. duration -1 = all day; "reset" so it just stays on while scheduled.
        mineral_monday = {
            display_name = "Mineral Monday",
            description = "Double crystals from everything you break, all day.",
            duration_seconds = -1,
            stacking = "reset",
            icon = "CRYS",
            modifiers = {
                crystal_reward_multiplier = 1, -- base 1 + 1 = 2x
            },
        },

        tycoon_tuesday = {
            display_name = "Tycoon Tuesday",
            description = "Double crystals from everything you break, all day.",
            duration_seconds = -1,
            stacking = "reset",
            icon = "COIN",
            modifiers = {
                coin_reward_multiplier = 1, -- 2x
            },
        },

        wishful_wednesday = {
            display_name = "Wishful Wednesday",
            description = "Golden and rainbow hatch odds get a big lift, all day.",
            duration_seconds = -1,
            stacking = "reset",
            icon = "LUCK",
            modifiers = {
                egg_luck = 0.5,
            },
        },

        thriving_thursday = {
            -- WARPATH THURSDAY (Jason): Thursday is the day you FIGHT — the XP
            -- day gains double enhancement drops from ENEMIES specifically
            -- (distinct from Saturday's everything-drops day).
            display_name = "Warpath Thursday",
            description = "Double XP everywhere — and enemies drop enhancements twice as often.",
            duration_seconds = -1,
            stacking = "reset",
            icon = "XP",
            modifiers = {
                xp_multiplier = 1, -- 2x
                enemy_drop_rate = 1, -- 2x enhancement/potion odds from enemy kills
            },
        },

        frenzy_friday = {
            display_name = "Frenzy Friday",
            description = "Double rewards from every breakable — the big payoff day.",
            duration_seconds = -1,
            stacking = "reset",
            icon = "2X",
            modifiers = {
                breakable_reward_multiplier = 1, -- 2x everything
            },
        },

        showering_saturday = {
            display_name = "Showering Saturday",
            description = "Enhancement and rare drops fall twice as often, all day.",
            duration_seconds = -1,
            stacking = "reset",
            icon = "DROP",
            modifiers = {
                drop_rate = 1, -- 2x drop chance
            },
        },

        -- WYRM WEEKEND (layered on Sat+Sun): the boss-egg chase weekend — trial
        -- bosses and first-clears roll their exclusive eggs at DOUBLE chance
        -- (0.5% -> 1%). Drop-rate lever, NOT stated egg odds: fixed_odds
        -- inventory eggs keep their exact stated hatch odds.
        wyrm_weekend = {
            display_name = "Wyrm Weekend",
            description = "Trial bosses and first-clears drop their exclusive eggs at double chance!",
            duration_seconds = -1,
            stacking = "reset",
            icon = "EGG",
            modifiers = {
                exclusive_egg_chance = 1, -- 2x boss/first-clear egg rolls
            },
        },

        -- TEAM TUESDAY (layered on Tycoon Tuesday): bring-a-friend day — the
        -- farming-pass team bonus fattens (1.2x -> 1.4x shared-node shares)
        -- and kill credit reaches further.
        team_tuesday = {
            display_name = "Team Tuesday",
            description = "Team up! Bigger shared-mining bonus and wider kill credit, all day.",
            duration_seconds = -1,
            stacking = "reset",
            icon = "TEAM",
            modifiers = {
                team_mining_bonus = 0.2, -- mining team_payout_mult 1.2 -> 1.4
                kill_credit_radius_bonus = 50, -- studs added to teaming kill_credit.radius
            },
        },

        secret_luck_day = {
            display_name = "Secret Sunday",
            description = "Sunday secret-pet luck boost — secret hatch odds get a lift all day.",
            duration_seconds = -1,
            stacking = "reset",
            icon = "SECRET",
            modifiers = {
                secret_luck = 0.5, -- +0.5 secret-tier reweight (was 0.05; Jason wants it more felt)
            },
        },
    },

    -- All schedules are MOUNTAIN time (America/Denver, DST-aware) — EventService converts the
    -- UTC server clock via Shared/Game/MountainTime. weekdays: 1=Sun .. 7=Sat.
    scheduled_global_events = {
        mineral_monday = {
            event_id = "mineral_monday",
            weekdays = { 2 },
            reason = "Mineral Monday",
        },
        tycoon_tuesday = {
            event_id = "tycoon_tuesday",
            weekdays = { 3 },
            reason = "Tycoon Tuesday",
        },
        wishful_wednesday = {
            event_id = "wishful_wednesday",
            weekdays = { 4 },
            reason = "Wishful Wednesday",
        },
        thriving_thursday = {
            event_id = "thriving_thursday",
            weekdays = { 5 },
            reason = "Thriving Thursday",
        },
        frenzy_friday = { event_id = "frenzy_friday", weekdays = { 6 }, reason = "Frenzy Friday" },
        showering_saturday = {
            event_id = "showering_saturday",
            weekdays = { 7 },
            reason = "Showering Saturday",
        },
        secret_luck_sunday = {
            event_id = "secret_luck_day",
            weekdays = { 1 },
            reason = "Secret Sunday",
        },
        -- LAYERED combat calendar (fold = base + Σ over active events, so
        -- these stack with the day's economy event by design)
        wyrm_weekend = {
            event_id = "wyrm_weekend",
            weekdays = { 7, 1 }, -- Saturday + Sunday
            reason = "Wyrm Weekend",
        },
        team_tuesday = {
            event_id = "team_tuesday",
            weekdays = { 3 },
            reason = "Team Tuesday",
        },
    },
}
