return {
    version = "2.0.0",

    -- Never enumerate player profiles. Each player replaces only their own ordered key when
    -- joining, changing a relevant score, and leaving. Servers read one cached top-100 page and
    -- render the first ten entries.
    publication = {
        cache_entries = 100,
        display_entries = 10,
        status_rank_limit = 100,
        refresh_seconds = 90,
        debounce_seconds = 20,
        derive_debounce_seconds = 1,
        -- Studio Play can GetSortedAsync the live OrderedDataStores. Writes stay
        -- gated by each board's studio_enabled so testers never publish —
        -- except this TEMP so Macros can land on the Range/TG signs.
        studio_read_global = true,
        studio_write_global = true,
        -- Internal IDs are always written. hide=true omits them from the
        -- public top 10. TEMP false so Macros can be seen while we test.
        hide_internal_accounts = false,
    },

    -- Display-only hide list. Scores still publish. IDs live in
    -- configs/internal_accounts.lua (not Colorado* names). Optional extras
    -- can be appended here.

    boards = {
        {
            id = "most_dragons",
            status_title = "Dragonlord",
            display_name = "Most Dragons",
            subtitle = "Dragons currently owned",
            origin = "grass",
            icon = "dragon",
            style = { accent = { 83, 214, 105 }, header = { 21, 86, 42 } },
            -- Playing for dragons: world/Hall egg hatches, not boss exclusives.
            -- Wyrmling is exclusive from the Obsidian Egg — leave it off.
            score = {
                kind = "inventory_taxonomy",
                pet_ids = {
                    "dragon",
                    "empyrean_dragon",
                    "abyssal_wyrm",
                    "aurora_dragon",
                    "rimewraith_dragon",
                    "portal_drake",
                },
            },
            sort = "desc",
            max_entries = 10,
            global = {
                enabled = true,
                studio_enabled = false,
                ordered_store = "LB_MostDragons_v1",
            },
        },
        {
            id = "crystal_crusher",
            status_title = "Farmer",
            display_name = "Crystal Crusher",
            subtitle = "Lifetime crystals destroyed",
            origin = "desert",
            icon = "crystal",
            style = { accent = { 255, 191, 57 }, header = { 112, 68, 15 } },
            score = { kind = "counter", counter = "breakables_broken" },
            sort = "desc",
            max_entries = 10,
            global = {
                enabled = true,
                studio_enabled = false,
                ordered_store = "LB_CrystalCrusher_v1",
            },
        },
        {
            id = "enemies_defeated",
            status_title = "Slayer",
            display_name = "Enemies Defeated",
            subtitle = "Lifetime meaningful defeats",
            origin = "lava",
            icon = "combat",
            style = { accent = { 255, 77, 55 }, header = { 112, 24, 18 } },
            score = { kind = "counter", counter = "enemies_defeated" },
            sort = "desc",
            max_entries = 10,
            global = {
                enabled = true,
                studio_enabled = false,
                ordered_store = "LB_EnemiesDefeated_v1",
            },
        },
        {
            id = "team_power",
            status_title = "Commander",
            display_name = "Team Power",
            subtitle = "Strongest legal squad",
            origin = "ice",
            icon = "team_power",
            style = { accent = { 78, 190, 255 }, header = { 22, 67, 115 } },
            score = { kind = "strongest_squad" },
            sort = "desc",
            max_entries = 10,
            global = {
                enabled = true,
                studio_enabled = false,
                ordered_store = "LB_TeamPower_v1",
            },
        },
        -- This ranking powers the social People-list title without adding a fifth physical board.
        -- It uses the same bounded, event-driven OrderedDataStore pipeline as the four origin boards.
        {
            id = "eggs_hatched",
            display_name = "Eggs Hatched",
            subtitle = "Lifetime eggs hatched",
            status_only = true,
            status_title = "Hatcher",
            score = { kind = "counter", counter = "eggs_hatched" },
            sort = "desc",
            max_entries = 10,
            global = {
                enabled = true,
                studio_enabled = false,
                ordered_store = "LB_EggsHatched_v1",
            },
        },
        -- Current Range / Training Ground: best cleared room in the sliding
        -- window from configs/challenge_runs.lua leaderboard.window_seconds.
        -- No People-list title and no podium yet (backend first).
        {
            id = "range_current",
            display_name = "The Range",
            subtitle = "Best room in the last 2 hours",
            style = { accent = { 232, 176, 72 }, header = { 72, 48, 18 } },
            score = { kind = "challenge_window", mode = "range" },
            sort = "desc",
            max_entries = 10,
            global = {
                enabled = true,
                studio_enabled = false,
                ordered_store = "LB_RangeCurrent_v1",
            },
        },
        {
            id = "training_ground_current",
            display_name = "Training Ground",
            subtitle = "Best room in the last 2 hours",
            style = { accent = { 120, 196, 96 }, header = { 28, 56, 32 } },
            score = { kind = "challenge_window", mode = "training_ground" },
            sort = "desc",
            max_entries = 10,
            global = {
                enabled = true,
                studio_enabled = false,
                ordered_store = "LB_TrainingGroundCurrent_v1",
            },
        },
    },

    -- World award stands. Client visualization parents to tagged AwardPodium
    -- hooks in the map (same contract as egg stands). Move the hook, not config.
    podiums = {
        {
            id = "hall_most_dragons",
            board_id = "most_dragons",
            title = { "DRAGONS" },
            title_cell = 0.45,
            title_height = 14,
            title_back = 3.4,
            title_color = { 83, 214, 105 },
            figure_yaw_degrees = 0,
            dances = {
                "rbxassetid://507771019",
                "rbxassetid://507776043",
                "rbxassetid://507776720",
            },
            plate = {
                width = 4.15,
                height = 1.85,
                thickness = 0.14,
                from_top = 1.05,
            },
            step = {
                width = 4.4,
                depth = 4.4,
                gap = 0.4,
                heights = { 6.2, 4.1, 2.7 },
            },
        },
        {
            id = "hall_crystal_crusher",
            board_id = "crystal_crusher",
            title = { "FARMER" },
            title_cell = 0.45,
            title_height = 14,
            title_back = 3.4,
            title_color = { 255, 191, 57 },
            figure_yaw_degrees = 0,
            dances = {
                "rbxassetid://507771019",
                "rbxassetid://507776043",
                "rbxassetid://507776720",
            },
            plate = {
                width = 4.15,
                height = 1.85,
                thickness = 0.14,
                from_top = 1.05,
            },
            step = {
                width = 4.4,
                depth = 4.4,
                gap = 0.4,
                heights = { 6.2, 4.1, 2.7 },
            },
        },
        {
            id = "hall_enemies_defeated",
            board_id = "enemies_defeated",
            title = { "SLAYERS" },
            title_cell = 0.45,
            title_height = 14,
            title_back = 3.4,
            title_color = { 255, 77, 55 },
            figure_yaw_degrees = 0,
            dances = {
                "rbxassetid://507771019",
                "rbxassetid://507776043",
                "rbxassetid://507776720",
            },
            plate = {
                width = 4.15,
                height = 1.85,
                thickness = 0.14,
                from_top = 1.05,
            },
            step = {
                width = 4.4,
                depth = 4.4,
                gap = 0.4,
                heights = { 6.2, 4.1, 2.7 },
            },
        },
        {
            id = "hall_team_power",
            board_id = "team_power",
            title = { "TEAM" },
            title_cell = 0.45,
            title_height = 14,
            title_back = 3.4,
            title_color = { 78, 190, 255 },
            figure_yaw_degrees = 0,
            dances = {
                "rbxassetid://507771019",
                "rbxassetid://507776043",
                "rbxassetid://507776720",
            },
            plate = {
                width = 4.15,
                height = 1.85,
                thickness = 0.14,
                from_top = 1.05,
            },
            step = {
                width = 4.4,
                depth = 4.4,
                gap = 0.4,
                heights = { 6.2, 4.1, 2.7 },
            },
        },
    },
}
