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
    },

    -- Test/creator accounts never enter public competition. LeaderboardService also removes any
    -- historical ordered keys for these immutable user IDs.
    excluded_user_ids = {
        3200870803, -- ColoradoPlays
        873359641, -- MacrosGodOfMagic
        864785140, -- SploitHunter
        913292269, -- SploitGiver
    },

    boards = {
        {
            id = "most_dragons",
            status_title = "Dragonlord",
            display_name = "Most Dragons",
            subtitle = "Dragons currently owned",
            origin = "grass",
            icon = "dragon",
            style = { accent = { 83, 214, 105 }, header = { 21, 86, 42 } },
            score = {
                kind = "inventory_taxonomy",
                pet_ids = {
                    "wyrmling",
                    "dragon",
                    "empyrean_dragon",
                    "abyssal_wyrm",
                    "aurora_dragon",
                    "rimewraith_dragon",
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
    },
}
