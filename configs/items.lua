-- Items Configuration
-- Define all purchasable and obtainable items in the game

return {
    -- Test Items
    {
        id = "test_item",
        name = "Test Item",
        type = "consumable",
        rarity = "common",
        description = "A simple test item for debugging purchases",
        price = {
            currency = "coins",
            amount = 50,
        },
        level_requirement = 1,
        stackable = true,
        max_stack = 99,
    },

    -- Weapons
    {
        id = "wooden_sword",
        name = "Wooden Sword",
        type = "weapon",
        rarity = "common",
        description = "A basic wooden sword for beginners",
        stats = {
            damage = 10,
            speed = 1.5,
            range = 5,
        },
        price = {
            currency = "coins",
            amount = 100,
        },
        level_requirement = 1,
        stackable = false,
    },

    {
        id = "iron_sword",
        name = "Iron Sword",
        type = "weapon",
        rarity = "uncommon",
        description = "A sturdy iron sword with improved damage",
        stats = {
            damage = 20,
            speed = 1.3,
            range = 5,
        },
        price = {
            currency = "coins",
            amount = 500,
        },
        level_requirement = 5,
        stackable = false,
    },

    -- Consumables
    {
        id = "health_potion",
        name = "Health Potion",
        type = "consumable",
        rarity = "common",
        description = "Restores 50 health points",
        effects = {
            health_restore = 50,
        },
        price = {
            currency = "coins",
            amount = 25,
        },
        stackable = true,
        max_stack = 10,
    },

    -- Tools (for simulators)
    {
        id = "basic_pickaxe",
        name = "Basic Pickaxe",
        type = "tool",
        rarity = "common",
        description = "A simple pickaxe for mining",
        stats = {
            mining_power = 1,
            durability = 100,
        },
        price = {
            currency = "coins",
            amount = 200,
        },
        level_requirement = 1,
        stackable = false,
    },

    -- Premium Items (Gem Currency)
    {
        id = "premium_boost",
        name = "Premium XP Boost",
        type = "consumable",
        rarity = "epic",
        description = "Doubles XP gain for 30 minutes",
        effects = {
            xp_multiplier = 2.0,
            duration = 1800,
        },
        price = {
            currency = "gems",
            amount = 10,
        },
        stackable = true,
        max_stack = 5,
    },

    {
        id = "diamond_sword",
        name = "Diamond Sword",
        type = "weapon",
        rarity = "legendary",
        description = "A magnificent diamond sword with incredible power",
        stats = {
            damage = 75,
            speed = 1.8,
            range = 6,
            critical_chance = 0.15,
        },
        price = {
            currency = "gems",
            amount = 25,
        },
        level_requirement = 3,
        stackable = false,
    },

    {
        id = "crystal_staff",
        name = "Crystal Staff",
        type = "weapon",
        rarity = "epic",
        description = "A magical staff infused with crystal power",
        stats = {
            magic_damage = 100,
            mana_cost = 20,
            range = 15,
            spell_power = 2.5,
        },
        price = {
            currency = "crystals",
            amount = 5,
        },
        level_requirement = 10,
        stackable = false,
    },

    -- Rate Limit Effect Items
    {
        id = "speed_potion",
        name = "Speed Potion",
        type = "consumable",
        rarity = "rare",
        description = "Increases action speed by 50% for 5 minutes",
        effects = {
            rate_effect = "speed_boost",
            duration = 300,
        },
        price = {
            currency = "gems",
            amount = 5,
        },
        stackable = true,
        max_stack = 10,
        consumable = true,
    },

    {
        id = "trader_scroll",
        name = "Trader's Blessing Scroll",
        type = "consumable",
        rarity = "uncommon",
        description = "Grants 25% faster trading for 10 minutes",
        effects = {
            rate_effect = "trader_blessing",
            duration = 600,
        },
        price = {
            currency = "coins",
            amount = 150,
        },
        stackable = true,
        max_stack = 5,
        consumable = true,
    },

    {
        id = "vip_pass",
        name = "VIP Pass",
        type = "pass",
        rarity = "legendary",
        description = "Permanent 50% faster economy actions",
        effects = {
            rate_effect = "vip_pass",
            duration = -1, -- Permanent
        },
        price = {
            currency = "gems",
            amount = 100,
        },
        stackable = false,
        permanent = true,
    },

    -- Testing and utility items
    {
        id = "alamantic_aluminum",
        name = "Alamantic Aluminum",
        type = "consumable",
        rarity = "special",
        description = "Clears all active effects. Perfect for testing!",
        effects = {
            special_effect = "clear_all_effects",
        },
        price = {
            currency = "coins",
            amount = 1, -- Cheap for testing
        },
        stackable = true,
        max_stack = 10,
        consumable = true,
    },

    -- Global Effect Admin Items
    {
        id = "admin_xp_weekend",
        name = "🎉 XP Weekend Activator",
        type = "consumable",
        rarity = "admin",
        description = "Triggers a 48-hour Double XP Weekend event for all players",
        effects = {
            global_effect = "global_xp_weekend",
            duration = 172800, -- 48 hours
            reason = "Admin Weekend Event",
        },
        price = {
            currency = "gems",
            amount = 1, -- Cheap for admin testing
        },
        stackable = true,
        max_stack = 10,
        consumable = true,
    },

    {
        id = "admin_speed_hour",
        name = "⚡ Speed Hour Activator",
        type = "consumable",
        rarity = "admin",
        description = "Triggers a 1-hour Speed Boost event for all players",
        effects = {
            global_effect = "global_speed_hour",
            duration = 3600, -- 1 hour
            reason = "Admin Speed Boost",
        },
        price = {
            currency = "gems",
            amount = 1, -- Cheap for admin testing
        },
        stackable = true,
        max_stack = 10,
        consumable = true,
    },

    {
        id = "admin_luck_boost",
        name = "🍀 Luck Boost Activator",
        type = "consumable",
        rarity = "admin",
        description = "Triggers a 2-hour Global Luck Boost for all players",
        effects = {
            global_effect = "global_luck_boost",
            duration = 7200, -- 2 hours
            reason = "Admin Luck Event",
        },
        price = {
            currency = "gems",
            amount = 1, -- Cheap for admin testing
        },
        stackable = true,
        max_stack = 10,
        consumable = true,
    },

    {
        id = "admin_clear_global",
        name = "🧹 Global Effects Clearer",
        type = "consumable",
        rarity = "admin",
        description = "Clears all active global effects from the server",
        effects = {
            special_effect = "clear_all_global_effects",
        },
        price = {
            currency = "coins",
            amount = 1, -- Cheap for admin testing
        },
        stackable = true,
        max_stack = 10,
        consumable = true,
    },
}
