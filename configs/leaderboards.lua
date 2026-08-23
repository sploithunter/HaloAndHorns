local function championAwardTiers()
    local function egg(quantity)
        return {
            id = "gauntlet_champion_egg",
            qty = quantity,
            bucket = "eggs",
        }
    end
    local function enhancement(grade, quantity)
        return {
            id = "origin_" .. grade .. "_enhancement",
            qty = quantity,
            bucket = "enhancements",
            roll = "origin_" .. grade,
        }
    end
    local function token(id)
        return { id = id, qty = 1, bucket = "consumables" }
    end

    return {
        {
            max_rank = 1,
            label = "1,500 Gems + Crowned Chimera + 3 Champion Eggs + champion supplies",
            reward = {
                currencies = { gems = 1500 },
                pets = { { id = "crowned_chimera", variant = "basic" } },
                items = {
                    egg(3),
                    enhancement("single", 2),
                    token("double_xp_token"),
                    token("double_coins_token"),
                },
            },
        },
        {
            max_rank = 2,
            label = "1,200 Gems + 3 Champion Eggs + Single Enhancement + Double Coins",
            reward = {
                currencies = { gems = 1200 },
                items = {
                    egg(3),
                    enhancement("single", 1),
                    token("double_coins_token"),
                },
            },
        },
        {
            max_rank = 3,
            label = "1,000 Gems + 2 Champion Eggs + Single Enhancement + Double XP",
            reward = {
                currencies = { gems = 1000 },
                items = {
                    egg(2),
                    enhancement("single", 1),
                    token("double_xp_token"),
                },
            },
        },
        {
            max_rank = 4,
            label = "800 Gems + 2 Champion Eggs + Dual Enhancement + Future Call",
            reward = {
                currencies = { gems = 800 },
                items = {
                    egg(2),
                    enhancement("dual", 1),
                    token("future_call_token"),
                },
            },
        },
        {
            max_rank = 5,
            label = "700 Gems + Champion Egg + Dual Enhancement + Future Call",
            reward = {
                currencies = { gems = 700 },
                items = {
                    egg(1),
                    enhancement("dual", 1),
                    token("future_call_token"),
                },
            },
        },
        {
            max_rank = 6,
            label = "600 Gems + Champion Egg + Dual Enhancement",
            reward = {
                currencies = { gems = 600 },
                items = { egg(1), enhancement("dual", 1) },
            },
        },
        {
            max_rank = 7,
            label = "500 Gems + Champion Egg + Future Call",
            reward = {
                currencies = { gems = 500 },
                items = { egg(1), token("future_call_token") },
            },
        },
        {
            max_rank = 8,
            label = "450 Gems + Champion Egg",
            reward = { currencies = { gems = 450 }, items = { egg(1) } },
        },
        {
            max_rank = 9,
            label = "400 Gems + Champion Egg",
            reward = { currencies = { gems = 400 }, items = { egg(1) } },
        },
        {
            max_rank = 10,
            label = "350 Gems + Champion Egg",
            reward = { currencies = { gems = 350 }, items = { egg(1) } },
        },
    }
end

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
        -- Release safety: Studio neither reads nor writes live production boards.
        studio_read_global = false,
        studio_write_global = false,
        -- Internal IDs are still stored for deterministic publisher behavior, but the
        -- canonical configs/internal_accounts.lua set is omitted from public ranks and awards.
        hide_internal_accounts = true,
    },

    -- Optional extra hide list for public ranks and awards. Scores still publish. IDs live in
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
        -- Gift-giver podiums are three independent top-three rankings. They are
        -- publication-backed now; an authored combined physical host can bind
        -- these board ids later without changing counters or saved player data.
        {
            id = "gift_exclusives",
            display_name = "Most Exclusives Gifted",
            subtitle = "Exclusive and Huge pets given",
            status_only = true,
            score = { kind = "counter", counter = "exclusive_pets_gifted" },
            sort = "desc",
            max_entries = 3,
            global = {
                enabled = true,
                studio_enabled = false,
                ordered_store = "LB_GiftExclusives_v1",
            },
        },
        {
            id = "gift_secrets",
            display_name = "Most Secrets Gifted",
            subtitle = "Secret pets given",
            status_only = true,
            score = { kind = "counter", counter = "secret_pets_gifted" },
            sort = "desc",
            max_entries = 3,
            global = {
                enabled = true,
                studio_enabled = false,
                ordered_store = "LB_GiftSecrets_v1",
            },
        },
        {
            id = "gift_mythicals",
            display_name = "Most Mythicals Gifted",
            subtitle = "Mythical pets given",
            status_only = true,
            score = { kind = "counter", counter = "mythical_pets_gifted" },
            sort = "desc",
            max_entries = 3,
            global = {
                enabled = true,
                studio_enabled = false,
                ordered_store = "LB_GiftMythicals_v1",
            },
        },
        -- Current Range / Training Ground: best cleared room in the fixed,
        -- clock-aligned round from configs/challenge_runs.lua.
        -- No People-list title and no podium yet (backend first).
        {
            id = "range_current",
            display_name = "The Range",
            subtitle = "Current award round",
            style = { accent = { 232, 176, 72 }, header = { 72, 48, 18 } },
            score = { kind = "challenge_window", mode = "range" },
            sort = "desc",
            max_entries = 10,
            global = {
                enabled = true,
                studio_enabled = false,
                ordered_store = "LB_RangeCurrent_v1",
            },
            awards = {
                enabled = true,
                studio_enabled = false,
                state_store = "LB_RangeAwardWindows_v1",
                observation_debounce_seconds = 5 * 60,
                -- Daily Mountain-midnight cadence comes from challenge_runs.leaderboard.
                -- Every rank has an exact bundle, delivered through the durable award queue.
                tiers = championAwardTiers(),
            },
        },
        {
            id = "training_ground_current",
            display_name = "Training Ground",
            subtitle = "Current award round",
            style = { accent = { 120, 196, 96 }, header = { 28, 56, 32 } },
            score = { kind = "challenge_window", mode = "training_ground" },
            sort = "desc",
            max_entries = 10,
            global = {
                enabled = true,
                studio_enabled = false,
                ordered_store = "LB_TrainingGroundCurrent_v1",
            },
            awards = {
                enabled = true,
                studio_enabled = false,
                state_store = "LB_TrainingAwardWindows_v1",
                observation_debounce_seconds = 5 * 60,
                tiers = championAwardTiers(),
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
