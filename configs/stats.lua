return {
    counters = {
        taps = {
            display_name = "Taps",
            scope = "lifetime",
            default = 0,
        },
        eggs_hatched = {
            display_name = "Eggs Hatched",
            scope = "lifetime",
            default = 0,
        },
        breakables_broken = {
            display_name = "Breakables Broken",
            scope = "lifetime",
            default = 0,
        },
        pets_equipped = {
            display_name = "Pets Equipped",
            scope = "lifetime",
            default = 0,
        },
        powers_cast = {
            display_name = "Powers Cast",
            scope = "lifetime",
            default = 0,
        },
        enhancements_slotted = {
            display_name = "Enhancements Slotted",
            scope = "lifetime",
            default = 0,
        },
        levels_gained = {
            display_name = "Levels Gained",
            scope = "lifetime",
            default = 0,
        },
        enemies_defeated = {
            display_name = "Enemies Defeated",
            scope = "lifetime",
            default = 0,
        },
        enhancements_found = {
            display_name = "Enhancements Found",
            scope = "lifetime",
            default = 0,
        },
        secrets_found = {
            display_name = "Secrets Found",
            scope = "lifetime",
            default = 0,
        },
        rebirths = {
            display_name = "Rebirths",
            scope = "lifetime",
            default = 0,
        },
        coins_earned_lifetime = {
            display_name = "Crystals Earned",
            scope = "lifetime",
            default = 0,
        },
        crystals_earned_lifetime = {
            display_name = "Crystals Earned",
            scope = "lifetime",
            default = 0,
        },
        gems_earned_lifetime = {
            display_name = "Gems Earned",
            scope = "lifetime",
            default = 0,
        },
        distinct_pets = {
            display_name = "Distinct Pets",
            scope = "lifetime",
            default = 0,
        },
        creators_met = {
            display_name = "Creators Met",
            scope = "lifetime",
            default = 0,
        },
        levels_earned = {
            display_name = "Levels Earned",
            scope = "lifetime",
            default = 0,
        },
        areas_unlocked = {
            display_name = "Areas Unlocked",
            scope = "lifetime",
            default = 0,
        },
        -- REALM TRACK (the heaven/hell journey): visits fire on realm ENTRY (ZoneTrackerService),
        -- unlocks fire when a Heaven_*/Hell_* zone is purchased (ZoneService). Back the Crossing
        -- quests. Fed via event_counters below — no service edits beyond the event fires.
        heaven_visits = {
            display_name = "Heaven Visits",
            scope = "lifetime",
            default = 0,
        },
        hell_visits = {
            display_name = "Hell Visits",
            scope = "lifetime",
            default = 0,
        },
        heaven_areas_unlocked = {
            display_name = "Heaven Areas Unlocked",
            scope = "lifetime",
            default = 0,
        },
        hell_areas_unlocked = {
            display_name = "Hell Areas Unlocked",
            scope = "lifetime",
            default = 0,
        },
        -- TRADER TRACK (Jason: "a leaderboard for prolific traders... not the
        -- billboard now, but let's start capturing the data"). Kept fully separate
        -- from the *_earned_lifetime environment counters.
        trades_completed = {
            display_name = "Trades Completed",
            scope = "lifetime",
            default = 0,
        },
        pets_traded_away = {
            display_name = "Pets Traded Away",
            scope = "lifetime",
            default = 0,
        },
        pets_traded_received = {
            display_name = "Pets Received in Trade",
            scope = "lifetime",
            default = 0,
        },
        gems_traded_lifetime = {
            display_name = "Gems Received in Trade",
            scope = "lifetime",
            default = 0,
        },
        coins_traded_lifetime = {
            display_name = "Crystals Received in Trade",
            scope = "lifetime",
            default = 0,
        },
        crystals_traded_lifetime = {
            display_name = "Crystals Received in Trade",
            scope = "lifetime",
            default = 0,
        },
    },

    -- EVENT-FED COUNTERS (Jason: "it's free data — if there's an event, we can just
    -- subscribe to it, keep a counter, stored in their profile"). StatEventCounters
    -- taps the GameEvents bus and increments these on every matching fire — a new
    -- achievement/alignment stat is ONE LINE here, no service edits. Lifetime
    -- counters stay the substrate; quests window them via QuestBaselines.
    event_counters = {
        trade_complete = "trades_completed",
        met_creator = "creators_met",
        level_earned = "levels_earned",
        area_unlocked = "areas_unlocked",
        -- Realm journey (the Crossing quests): entry + per-realm unlocks.
        entered_heaven = "heaven_visits",
        entered_hell = "hell_visits",
        heaven_area_unlocked = "heaven_areas_unlocked",
        hell_area_unlocked = "hell_areas_unlocked",
    },
}
