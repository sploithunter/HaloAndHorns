--[[
    Shop — Halo & Horns [PROTOTYPE] (Phase 7).

    A shop offer is a Claim whose gate is a *cost* (an inverse reward bundle) plus an
    optional purchase limit. ShopLogic decides affordability/limit; on success the
    cost is spent and the reward bundle is granted via RewardService. The "Shop -25%"
    tag is `discount_percent`; limited offers reuse the claim-count ledger.
]]

return {
    offers = {
        starter_pack = {
            name = "Starter Pack",
            cost = { currencies = { coins = 1000 } },
            reward = { items = { { id = "health_potion", qty = 5 } }, slots = { pet_storage = 1 } },
            limit = 1,
            discount_percent = 25,
        },
        coin_cache = {
            name = "Crystal Cache",
            cost = { currencies = { gems = 5 } },
            reward = { currencies = { coins = 5000 } },
            -- repeatable (no limit)
        },
        speed_boost = {
            name = "Speed Boost (10 min)",
            cost = { currencies = { gems = 3 } },
            reward = {
                effects = {
                    { id = "speed_boost", seconds = 600, modifiers = { speedMultiplier = 0.5 } },
                },
            },
        },
    },
}
