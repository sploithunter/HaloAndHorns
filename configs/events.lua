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
            display_name = "Thriving Thursday",
            description = "Double XP from mining and combat — level up twice as fast.",
            duration_seconds = -1,
            stacking = "reset",
            icon = "XP",
            modifiers = {
                xp_multiplier = 1, -- 2x
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
    },
}
