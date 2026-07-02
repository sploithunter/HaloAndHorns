# Configuration-as-Code Examples

## Adding New Buttons Without Code Changes

This guide shows how to add new UI buttons and functionality purely through configuration changes, without modifying any Lua code.

## Example 1: Adding a "Leaderboard" Button

### Step 1: Define the Action (in `configs/ui.lua`)

```lua
-- Add to the actions section
leaderboard_action = {
    type = "menu_panel",
    panel = "Leaderboard",
    transition = "slide_in",
    sound = "button_click",
    description = "Opens the player leaderboard"
},
```

### Step 2: Add the Button (in `configs/ui.lua`)

```lua
-- Add to menu_buttons_pane contents
{type = "menu_button", config = {
    name = "Leaderboard", 
    icon = "🏆", 
    text = "Ranks", 
    color = Color3.fromRGB(255, 215, 0),
    action = "leaderboard_action"
}},
```

**Result**: A new leaderboard button appears automatically with professional styling and functionality!

## Example 2: Adding a "Spin Wheel" Mini-Game

### Step 1: Define the Action

```lua
spin_wheel_action = {
    type = "script_execute",
    script = "SpinWheelGame", 
    method = "StartSpin",
    parameters = {
        wheel_type = "daily_rewards",
        cost = 100,
        currency = "coins"
    },
    sound = "success",
    description = "Starts the daily spin wheel game"
},
```

### Step 2: Add Conditional Requirements

```lua
spin_wheel_action = {
    type = "conditional_action",
    conditions = {
        has_daily_spin = true,
        sufficient_coins = true
    },
    success_action = {
        type = "script_execute",
        script = "SpinWheelGame",
        method = "StartSpin",
        parameters = {cost = 100}
    },
    failure_action = {
        type = "notification",
        message = "Not enough coins or already spun today!",
        notification_type = "warning",
        duration = 3
    }
}
```

### Step 3: Add the Button

```lua
{type = "menu_button", config = {
    name = "Spin", 
    icon = "🎲", 
    text = "Spin", 
    color = Color3.fromRGB(255, 20, 147),
    action = "spin_wheel_action"
}},
```

## Example 3: Multi-Step "Collect All" Button

```lua
collect_all_action = {
    type = "action_sequence",
    sequence = {
        {
            type = "script_execute",
            script = "CollectionManager",
            method = "CalculateCollectable"
        },
        {
            type = "conditional_action", 
            conditions = {has_collectables = true},
            success_action = {
                type = "script_execute",
                script = "CollectionManager", 
                method = "CollectAll"
            },
            failure_action = {
                type = "notification",
                message = "Nothing to collect!",
                notification_type = "info"
            }
        },
        {
            type = "notification",
            message = "All rewards collected!",
            notification_type = "success",
            sound = "achievement"
        }
    },
    description = "Collects all available rewards in sequence"
}
```

## Example 4: Purchase Confirmation Flow

```lua
buy_vip_action = {
    type = "network_call",
    service = "PurchaseService",
    method = "ProcessVIPPurchase", 
    parameters = {
        product_id = "vip_monthly",
        robux_cost = 499
    },
    confirmation = {
        enabled = true,
        title = "VIP Purchase",
        message = "Buy VIP membership for 499 Robux?\n\n✨ 2x XP and Coins\n🎁 Daily Rewards\n🚀 Exclusive Areas",
        confirm_text = "Buy Now",
        cancel_text = "Cancel"
    },
    sound = "purchase",
    description = "VIP membership purchase with confirmation"
}
```

## Example 5: Debug Testing Tools

```lua
-- Debug action (only shows for admins in debug mode)
debug_test_action = {
    type = "action_sequence",
    conditions = {
        admin_only = true,
        debug_mode = true
    },
    sequence = {
        {
            type = "script_execute",
            script = "DebugConsole",
            method = "AddTestCurrency"
        },
        {
            type = "script_execute", 
            script = "DebugConsole",
            method = "UnlockAllAreas"
        },
        {
            type = "notification",
            message = "Debug features activated!",
            notification_type = "info"
        }
    },
    description = "Activates debug features for testing"
}
```

## Dynamic Grid Layout

The beauty of this system is that buttons automatically arrange themselves. The 4x2 grid in `menu_buttons_pane` will automatically accommodate new buttons:

```lua
contents = {
    -- Row 1
    {type = "menu_button", config = {name = "Shop", action = "shop_action"}},
    {type = "menu_button", config = {name = "Inventory", action = "inventory_action"}},
    {type = "menu_button", config = {name = "Effects", action = "effects_action"}},
    {type = "menu_button", config = {name = "Settings", action = "settings_action"}},
    
    -- Row 2 (automatically flows to next row)
    {type = "menu_button", config = {name = "Leaderboard", action = "leaderboard_action"}},
    {type = "menu_button", config = {name = "Spin", action = "spin_wheel_action"}},
    {type = "menu_button", config = {name = "Collect", action = "collect_all_action"}},
    {type = "menu_button", config = {name = "VIP", action = "buy_vip_action"}},
}
```

## Creating New Panes

You can also create entirely new UI areas:

```lua
-- Add to panes section
special_offers_pane = {
    position = "top-right",
    offset = {x = -20, y = 20},
    size = {width = 200, height = 100},
    background = {
        enabled = true,
        color = Color3.fromRGB(255, 20, 147),
        transparency = 0.1,
        corner_radius = 15,
        border = {
            enabled = true,
            color = Color3.fromRGB(255, 255, 255),
            thickness = 2
        }
    },
    layout = {type = "single"},
    contents = {
        {type = "menu_button", config = {
            name = "SpecialOffer",
            icon = "💎",
            text = "50% OFF!",
            color = Color3.fromRGB(255, 20, 147),
            action = "special_offer_action"
        }}
    }
}
```

## Configuration Hot-Reloading

For development, you can implement hot-reloading:

```lua
-- Add this helper function
reload_ui_config = function()
    local newConfig = require(script.Parent.configs.ui)
    -- Update BaseUI with new configuration
    if _G.BaseUI then
        _G.BaseUI:ReloadConfiguration(newConfig)
    end
end
```

## Benefits Demonstrated

1. **Zero Code Changes**: All examples require only configuration edits
2. **Instant Prototyping**: Test new UI flows immediately  
3. **Complex Logic**: Multi-step actions, conditions, confirmations
4. **Professional Features**: Animations, sounds, notifications
5. **Flexible Layout**: Automatic button arrangement and positioning
6. **Conditional Visibility**: Admin-only, debug-mode, player-state dependent buttons

## Common Patterns

### Menu Button Pattern
```lua
action_name = {type = "menu_panel", panel = "PanelName", transition = "slide_in"}
```

### Script Execution Pattern  
```lua
action_name = {type = "script_execute", script = "HandlerName", method = "MethodName"}
```

### Conditional Pattern
```lua
action_name = {
    type = "conditional_action",
    conditions = {requirement = true},
    success_action = {/* action */},
    failure_action = {/* feedback */}
}
```

### Purchase Pattern
```lua
action_name = {
    type = "network_call", 
    service = "ServiceName",
    confirmation = {enabled = true, title = "Confirm"}
}
```

This configuration-as-code system provides **unlimited flexibility** while maintaining **professional quality** and **ease of use**!

## See Also

- **[Menu Modifications System](MENU_MODIFICATIONS_SYSTEM.md)** - Visual customization (colors, fonts, styling)
- **[UI Layout System](UI_LAYOUT_SYSTEM.md)** - Layout and positioning configuration
- **[EGG System Configuration](EGG_SYSTEM_CONFIGURATION.md)** - Egg interaction and preview settings

This document covers **functional configuration** (buttons, actions, behaviors), while the Menu Modifications System covers **visual configuration** (colors, fonts, appearance). Together, they provide complete control over your UI without code changes!