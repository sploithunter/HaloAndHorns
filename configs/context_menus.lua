--[[
    Context Menu Configuration - Define right-click actions for different item types
    
    This configuration controls what options appear when right-clicking items
    in the inventory, based on the item's folder_source and specific properties.
    
    Action Types:
    - "info": Show item details
    - "delete": Delete with quantity options
    - "consume": Use/consume the item with quantity options  
    - "equip": Equip/unequip the item
    - "upgrade": Upgrade the item (if applicable)
    - "rename": Rename the item (pets, tools)
    - "sell": Sell the item to shop
    
    Color Guide:
    - Blue: Info/utility actions
    - Yellow/Orange: Quantity-based actions (consume, delete low amounts)
    - Red: Destructive actions (delete high amounts)
    - Green: Positive actions (equip, upgrade)
    - Purple: Special actions (rename, sell)
]]

return {
    -- === GLOBAL SETTINGS ===
    global = {
        always_show_info = true, -- Always show "Info" as first option
        max_quantity_options = 4, -- Maximum delete/consume quantity options
        auto_close_delay = 5, -- Seconds before auto-close
        show_separators = true, -- Show visual separators between action groups
    },

    -- === ITEM TYPE CONFIGURATIONS ===
    item_types = {
        -- === CONSUMABLES (Potions, Food, etc.) ===
        consumables = {
            actions = {
                {
                    action = "info",
                    text = "ℹ️ Info",
                    color = { 100, 150, 255 }, -- Blue
                    order = 1,
                },
                {
                    action = "consume",
                    text = "🍎 Consume %d",
                    color = { 100, 255, 100 }, -- Green
                    order = 2,
                    quantities = { 1, 5, 10, "all" }, -- Dynamic based on item count
                    min_count = 1, -- Only show if item count >= 1
                },
                {
                    action = "delete",
                    text = "🗑️ Delete %d",
                    color = { 255, 200, 100 }, -- Orange for small amounts
                    order = 3,
                    quantities = { 1, 10, 100, "all" },
                    quantity_colors = {
                        [1] = { 255, 200, 100 }, -- Orange for delete 1
                        [10] = { 255, 150, 100 }, -- Darker orange for delete 10
                        [100] = { 255, 100, 100 }, -- Red for delete 100
                        ["all"] = { 230, 76, 60 }, -- Dark red for delete all
                    },
                },
            },
            -- Item-specific overrides
            item_overrides = {
                speed_potion = {
                    additional_actions = {
                        {
                            action = "consume",
                            text = "⚡ Drink 5 (Speed Boost)",
                            quantities = { 5 },
                            color = { 255, 255, 100 }, -- Yellow
                            order = 2.5,
                        },
                    },
                },
                health_potion = {
                    additional_actions = {
                        {
                            action = "consume",
                            text = "❤️ Drink 3 (Full Heal)",
                            quantities = { 3 },
                            color = { 255, 100, 100 }, -- Red
                            order = 2.5,
                        },
                    },
                },
            },
        },

        -- === PETS ===
        pets = {
            actions = {
                {
                    action = "info",
                    text = "ℹ️ Info",
                    color = { 100, 150, 255 }, -- Blue
                    order = 1,
                },
                {
                    action = "equip",
                    text = "🐾 Toggle Equipped",
                    color = { 100, 255, 100 }, -- Green
                    order = 2,
                },
                {
                    action = "rename",
                    text = "✏️ Rename",
                    color = { 200, 100, 255 }, -- Purple
                    order = 3,
                    enabled = true, -- Could be based on player permissions
                },
                {
                    action = "delete",
                    text = "🗑️ Release Pet",
                    color = { 230, 76, 60 }, -- Dark red (destructive)
                    order = 4,
                    confirmation = "Are you sure you want to release this pet? This cannot be undone!",
                },
            },
        },

        -- === TOOLS ===
        tools = {
            actions = {
                {
                    action = "info",
                    text = "ℹ️ Info",
                    color = { 100, 150, 255 }, -- Blue
                    order = 1,
                },
                {
                    action = "equip",
                    text = "🔧 Toggle Equipped",
                    color = { 100, 255, 100 }, -- Green
                    order = 2,
                },
                {
                    action = "upgrade",
                    text = "⬆️ Upgrade",
                    color = { 255, 215, 0 }, -- Gold
                    order = 3,
                    enabled_check = "can_upgrade", -- Check item properties
                },
                {
                    action = "sell",
                    text = "💰 Sell",
                    color = { 255, 165, 0 }, -- Orange
                    order = 4,
                    enabled_check = "can_sell",
                },
                {
                    action = "delete",
                    text = "🗑️ Delete",
                    color = { 230, 76, 60 }, -- Dark red
                    order = 5,
                },
            },
        },

        -- === EGGS ===
        eggs = {
            actions = {
                {
                    action = "info",
                    text = "ℹ️ Info",
                    color = { 100, 150, 255 }, -- Blue
                    order = 1,
                },
                {
                    action = "hatch",
                    text = "🥚 Hatch",
                    color = { 255, 215, 0 }, -- Gold
                    order = 2,
                },
                {
                    action = "hatch_multiple",
                    text = "🥚 Hatch %d",
                    color = { 255, 165, 0 }, -- Orange
                    order = 3,
                    quantities = { 5, 10, "all" },
                    min_count = 5,
                },
                {
                    action = "delete",
                    text = "🗑️ Delete %d",
                    color = { 255, 100, 100 }, -- Red
                    order = 4,
                    quantities = { 1, 10, "all" },
                },
            },
        },
    },

    -- === FALLBACK CONFIGURATION ===
    -- Used for items that don't match any specific type
    fallback = {
        actions = {
            {
                action = "info",
                text = "ℹ️ Info",
                color = { 100, 150, 255 }, -- Blue
                order = 1,
            },
            {
                action = "delete",
                text = "🗑️ Delete",
                color = { 230, 76, 60 }, -- Red
                order = 2,
            },
        },
    },
}
