-- Monetization Configuration
-- Define all Robux purchases, game passes, and premium benefits

return {
    -- Product ID Mapping (ConfigID -> Roblox Product ID)
    -- IMPORTANT: Users MUST update these with actual Roblox IDs
    product_id_mapping = {
        -- Developer Products
        small_gems = 1234567890, -- REPLACE: Create "100 Gems" product in Roblox
        medium_gems = 1234567891, -- REPLACE: Create "500 Gems" product in Roblox
        starter_pack = 1234567892, -- REPLACE: Create "Starter Pack" product in Roblox

        -- Game Passes
        vip_pass = 123456789, -- REPLACE: Create "VIP Pass" game pass in Roblox
        auto_collect = 123456790, -- REPLACE: Create "Auto Collect" game pass in Roblox
        speed_boost = 123456791, -- REPLACE: Create "Speed Boost" game pass in Roblox
    },

    -- Developer Products (consumable Robux purchases)
    products = {
        {
            id = "small_gems",
            name = "💎 100 Gems",
            description = "Get 100 Gems instantly!",
            price_robux = 99,
            rewards = {
                gems = 100,
            },
            category = "currency",
            popular = false,
            analytics_category = "currency_small",
            test_mode_enabled = true, -- Allow free purchase in Studio
        },
        {
            id = "medium_gems",
            name = "💎 500 Gems (+50 Bonus)",
            description = "Best value! Get 550 Gems total!",
            price_robux = 399,
            rewards = {
                gems = 550, -- 500 + 50 bonus
            },
            category = "currency",
            popular = true,
            badge = "best_value",
            bonus_percent = 10,
            analytics_category = "currency_medium",
            test_mode_enabled = true,
        },
        {
            id = "starter_pack",
            name = "🎁 Starter Pack",
            description = "Perfect for new players! Gems, Crystals, and exclusive items!",
            price_robux = 199,
            rewards = {
                gems = 150,
                coins = 25000,
                items = { "wooden_sword", "health_potion" },
            },
            category = "bundle",
            popular = true,
            one_time_only = true,
            level_requirement = { max = 10 },
            analytics_category = "bundle",
            test_mode_enabled = true,
            first_time_buyer_only = true,
        },
    },

    -- Game Passes (permanent benefits)
    passes = {
        {
            id = "vip_pass",
            name = "👑 VIP Pass",
            description = "Daily rewards, 2x XP, exclusive areas!",
            price_robux = 499,
            benefits = {
                daily_rewards = {
                    gems = 50,
                    coins = 10000,
                },
                multipliers = {
                    xp = 2.0,
                    coins = 1.5,
                },
                effects = {
                    id = "vip_effect",
                    permanent = true,
                    stats = {
                        speedMultiplier = 0.25, -- +25% speed
                        luckBoost = 0.1, -- +10% luck
                    },
                },
                perks = {
                    exclusive_chat_tag = "[VIP]",
                    exclusive_area_access = true,
                    extra_inventory_slots = 50,
                },
            },
            icon = "rbxassetid://0", -- Replace with actual asset ID
            test_mode_enabled = true,
        },
        {
            id = "auto_collect",
            name = "🤖 Auto Collector",
            description = "Automatically collect resources near you!",
            price_robux = 299,
            benefits = {
                features = {
                    auto_collect_enabled = true,
                    auto_collect_range = 20,
                    auto_collect_rate = 1.0,
                },
            },
            icon = "rbxassetid://0", -- Replace with actual asset ID
            test_mode_enabled = true,
        },
        {
            id = "speed_boost",
            name = "⚡ Speed Boost",
            description = "Move 50% faster forever!",
            price_robux = 199,
            benefits = {
                effects = {
                    id = "speed_pass",
                    permanent = true,
                    stats = {
                        speedMultiplier = 0.5, -- +50% speed
                    },
                },
            },
            icon = "rbxassetid://0", -- Replace with actual asset ID
            test_mode_enabled = true,
        },
    },

    -- Premium (Roblox Premium) Benefits
    premium_benefits = {
        enabled = true,
        daily_rewards = {
            gems = 25,
            coins = 5000,
        },
        multipliers = {
            xp = 1.5,
            coins = 1.25,
        },
        perks = {
            exclusive_chat_tag = "[Premium]",
            extra_inventory_slots = 25,
            premium_discount = 0.1, -- 10% off purchases
        },
        effects = {
            id = "premium_effect",
            permanent = true,
            stats = {
                speedMultiplier = 0.1, -- +10% speed
                luckBoost = 0.05, -- +5% luck
            },
        },
    },

    -- First Purchase Bonus
    first_purchase_bonus = {
        enabled = true,
        rewards = {
            gems = 100,
            coins = 50000,
            items = { "wooden_sword" }, -- Starter item
            title = "Supporter",
        },
    },

    -- Purchase Validation Rules
    validation_rules = {
        -- Prevent duplicate one-time purchases
        check_one_time_purchases = true,

        -- Level requirements
        enforce_level_requirements = true,

        -- First time buyer restrictions
        enforce_first_time_buyer = true,

        -- Test mode settings
        test_mode = {
            enabled = true, -- Allow free purchases in Studio
            bypass_robux = true,
            log_transactions = true,
        },
    },

    -- Analytics Configuration
    analytics = {
        track_purchases = true,
        track_failures = true,
        events = {
            purchase_initiated = "monetization_purchase_start",
            purchase_completed = "monetization_purchase_success",
            purchase_failed = "monetization_purchase_fail",
            pass_checked = "monetization_pass_check",
        },
    },

    -- Error Messages
    error_messages = {
        product_not_found = "Product not found. Please try again.",
        already_owned = "You already own this item!",
        level_too_high = "This item is only for new players!",
        level_too_low = "You need to be level {level} to purchase this!",
        one_time_only = "This is a one-time purchase and you already own it!",
        purchase_failed = "Purchase failed. Please try again.",
        not_enough_robux = "Not enough Robux to complete this purchase.",
    },

    -- Purchase UI Configuration
    shop_config = {
        featured_products = { "starter_pack", "medium_gems", "vip_pass" },
        categories = {
            { id = "featured", name = "🌟 Featured", icon = "⭐" },
            { id = "currency", name = "💰 Currency", icon = "💎" },
            { id = "bundles", name = "🎁 Bundles", icon = "🎁" },
            { id = "passes", name = "🎫 Game Passes", icon = "🎫" },
        },

        -- Visual indicators
        badges = {
            popular = { text = "POPULAR", color = Color3.fromRGB(255, 170, 0) },
            best_value = { text = "BEST VALUE", color = Color3.fromRGB(0, 255, 127) },
            one_time = { text = "ONE TIME", color = Color3.fromRGB(255, 0, 127) },
            new = { text = "NEW", color = Color3.fromRGB(0, 162, 255) },
        },
    },
}
