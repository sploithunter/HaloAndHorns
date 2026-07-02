return {
    modifier_pipeline = {
        stage_order = {
            "base",
            "pet_stats",
            "enchants",
            "permanent_upgrades",
            "rebirth",
            "boosts",
            "active_events",
            "pet_of_the_day",
            "gamepass",
        },

        stages = {
            base = { combine = "override" },
            pet_stats = { combine = "add" },
            enchants = { combine = "add" },
            permanent_upgrades = { combine = "multiply" },
            rebirth = { combine = "multiply" },
            boosts = { combine = "multiply" },
            active_events = { combine = "multiply" },
            pet_of_the_day = { combine = "multiply" },
            gamepass = { combine = "multiply" },
        },
    },

    currency_exchange = {
        enabled = true,
        default_conversion = "crystals_to_gems",
        conversions = {
            crystals_to_gems = {
                from = "crystals",
                to = "gems",
                from_amount = 100,
                to_amount = 10,
                max_batches_per_request = 10,
                display_name = "Crystal Exchange",
            },
        },
    },
}
