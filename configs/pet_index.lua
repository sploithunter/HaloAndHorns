return {
    version = "1.0.0",

    index_key_fields = { "id", "variant" },
    default_variant = "basic",

    milestones = {
        {
            id = "first_friend",
            display_name = "First Friend",
            goal = 1,
            reward = {
                type = "currency",
                currency = "gems",
                amount = 5,
            },
        },
        {
            id = "starter_collector",
            display_name = "Starter Collector",
            goal = 3,
            reward = {
                type = "currency",
                currency = "gems",
                amount = 15,
            },
        },
        {
            id = "rainbow_album",
            display_name = "Rainbow Album",
            goal = 6,
            reward = {
                type = "currency",
                currency = "gems",
                amount = 40,
            },
        },
    },
}
