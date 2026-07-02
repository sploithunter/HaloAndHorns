return {
    version = "1.0.0",

    boards = {
        {
            id = "eggs_hatched",
            display_name = "Eggs Hatched",
            stat = "eggs_hatched",
            sort = "desc",
            max_entries = 10,
            global = {
                enabled = false,
                ordered_store = "LB_EggsHatched_v1",
                refresh_seconds = 120,
            },
        },
        {
            id = "breakables_broken",
            display_name = "Breakables Broken",
            stat = "breakables_broken",
            sort = "desc",
            max_entries = 10,
            global = {
                enabled = false,
                ordered_store = "LB_BreakablesBroken_v1",
                refresh_seconds = 120,
            },
        },
        {
            id = "distinct_pets",
            display_name = "Pet Index",
            stat = "distinct_pets",
            sort = "desc",
            max_entries = 10,
            global = {
                enabled = false,
                ordered_store = "LB_DistinctPets_v1",
                refresh_seconds = 120,
            },
        },
    },
}
