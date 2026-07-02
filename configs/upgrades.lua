return {
    version = "1.0.0",

    upgrades = {
        pet_equip_slots = {
            id = "pet_equip_slots",
            display_name = "Pet Equip Slots",
            description = "Equip more pets at once.",
            max_level = 3,
            cost = {
                currency = "coins",
                type = "exponential",
                base = 250,
                growth = 2,
            },
            effects = {
                {
                    type = "equip_slots",
                    category = "pets",
                    amount_per_level = 1,
                },
            },
        },

        pet_storage = {
            id = "pet_storage",
            display_name = "Pet Storage",
            description = "Store more pet stacks and special pets.",
            max_level = 5,
            cost = {
                currency = "coins",
                type = "exponential",
                base = 150,
                growth = 1.75,
            },
            effects = {
                {
                    type = "storage_slots",
                    bucket = "pets",
                    amount_per_level = 25,
                },
            },
        },

        crystal_value = {
            id = "crystal_value",
            display_name = "Crystal Value",
            description = "Increase crystal rewards from breakables.",
            max_level = 5,
            cost = {
                currency = "crystals",
                type = "linear",
                base = 50,
                increment = 50,
            },
            effects = {
                {
                    type = "modifier",
                    stage = "permanent_upgrades",
                    kind = "breakable_reward",
                    currency = "crystals",
                    combine = "multiply",
                    amount_per_level = 0.1,
                },
            },
        },
    },
}
