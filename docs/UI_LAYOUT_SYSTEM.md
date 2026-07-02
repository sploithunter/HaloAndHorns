# UI Layout System - Configuration as Code

## Overview

The UI Layout System uses a **pane-based architecture** where UI elements are organized into configurable containers called "panes". Think of panes as "cards" in web development - they hold related UI elements and can be positioned anywhere on screen using semantic positioning.

## Screen Layout Reference

```
┌─────────────────────────────────────────────────────────────┐
│ top-left           top-center           top-right           │
│     ┌─────┐           ┌─────┐              ┌─────┐           │
│     │     │           │     │              │     │           │
│     └─────┘           └─────┘              └─────┘           │
│                                                             │
│ center-left         center              center-right        │
│     ┌─────┐           ┌─────┐              ┌─────┐           │
│     │     │           │     │              │     │           │
│     └─────┘           └─────┘              └─────┘           │
│                                                             │
│ bottom-left        bottom-center        bottom-right        │
│     ┌─────┐           ┌─────┐              ┌─────┐           │
│     │     │           │     │              │     │           │
│     └─────┘           └─────┘              └─────┘           │
└─────────────────────────────────────────────────────────────┘
```

## Current Game Layout

```
┌─────────────────────────────────────────────────────────────┐
│                    ┌───────────────────┐                    │
│                    │ 👤 coloradoplays  │ top-center         │
│                    │ Level 15 • XP     │                    │
│                    │ 🎯 Current Quest  │                    │
│                    │ Collect 50 Blocks │                    │
│                    │ ████████░░ 32/50  │                    │
│                    └───────────────────┘                    │
│                                                             │
│ ┌─────────┐                                                 │
│ │ 💰   70 │ center-left (floating cards)                   │
│ └─────────┘                                                 │
│ ┌─────────┐                                                 │
│ │ 💎  200 │                                                 │
│ └─────────┘                                                 │
│ ┌─────────┐                                                 │
│ │ 🔮    0 │                                                 │
│ └─────────┘                                                 │
│                                                             │
│ ┌─────────────┐              ┌───────┐      ┌────────────┐  │
│ │🛒│🎒│⚡│⚙️   │ bottom-left  │ 🐾    │     │ 🎁 Rewards  │  │
│ │──┼──┼──┼──  │              │ Pets  │      │     (3)    │  │
│ │  │  │  │👑  │              └───────┘      └────────────┘  │
│ └─────────────┘             bottom-center   bottom-right    │
└─────────────────────────────────────────────────────────────┘
```

## Positioning System

### Available Positions

| Position | Description | Anchor Point | Use Cases |
|----------|-------------|--------------|-----------|
| `top-left` | Upper left corner | `(0, 0)` | Status indicators, debug info |
| `top-center` | Top middle | `(0.5, 0)` | Player info, important notifications |
| `top-right` | Upper right corner | `(1, 0)` | Currency, settings menu |
| `center-left` | Middle left edge | `(0, 0.5)` | Secondary currency, tools |
| `center` | Screen center | `(0.5, 0.5)` | Alerts, main content |
| `center-right` | Middle right edge | `(1, 0.5)` | Navigation, quick access |
| `bottom-left` | Lower left corner | `(0, 1)` | Main menu buttons |
| `bottom-center` | Bottom middle | `(0.5, 1)` | Primary actions (Pets button) |
| `bottom-right` | Lower right corner | `(1, 1)` | Secondary actions, rewards |

### Sane Defaults

The system automatically applies logical anchor points and alignments:

- **`top-left`** → Anchor: `(0, 0)` - Element aligns to top-left of container
- **`top-center`** → Anchor: `(0.5, 0)` - Element centers horizontally at top
- **`bottom-right`** → Anchor: `(1, 1)` - Element aligns to bottom-right
- **`center`** → Anchor: `(0.5, 0.5)` - Element centers perfectly on screen

## Pane Configuration Structure

```lua
panes = {
    pane_name = {
        position = "top-left",              -- Semantic position
        offset = {x = 0, y = 0},           -- Fine-tune positioning
        size = {width = 200, height = 100}, -- Pane dimensions
        background = {                      -- Visual styling
            enabled = true,
            color = Color3.fromRGB(0, 0, 0),
            transparency = 0.3,
            corner_radius = 12,
            border = {
                enabled = true,
                color = Color3.fromRGB(255, 255, 255),
                thickness = 2,
                transparency = 0.5
            }
        },
        layout = {                         -- How contents are arranged
            type = "list",                 -- "list", "grid", "single", "custom"
            direction = "vertical",        -- "horizontal", "vertical"
            spacing = 5,
            padding = {top = 10, bottom = 10, left = 10, right = 10}
        },
        contents = {                       -- What goes inside
            {type = "currency_display", config = {currency = "coins", icon = "💰"}},
            {type = "menu_button", config = {name = "Shop", icon = "🛒"}}
        }
    }
}
```

## Layout Types

### 1. List Layout (`type = "list"`)

Arranges elements in a single row or column.

```lua
layout = {
    type = "list",
    direction = "vertical",    -- or "horizontal"
    spacing = 5,              -- Gap between elements
    padding = {top = 8, bottom = 8, left = 12, right = 12}
}
```

**Use for:** Currency displays, navigation menus, simple lists

### 2. Grid Layout (`type = "grid"`)

Arranges elements in a rectangular grid.

```lua
layout = {
    type = "grid",
    columns = 4,              -- Number of columns
    rows = 2,                 -- Number of rows (optional)
    cell_size = {width = 75, height = 75},
    spacing = 5,              -- Gap between cells
    padding = {top = 5, bottom = 5, left = 5, right = 5}
}
```

**Use for:** Menu button grids, inventory items, skill trees

### 3. Single Layout (`type = "single"`)

Contains exactly one element that fills the pane.

```lua
layout = {
    type = "single"
}
```

**Use for:** Action buttons, large displays, single widgets

### 4. Custom Layout (`type = "custom"`)

Manual positioning within the pane.

```lua
layout = {
    type = "custom"
}
```

**Use for:** Complex arrangements, overlapping elements, special cases

## Element Types

### Currency Display

```lua
{
    type = "currency_display",
    config = {
        currency = "coins",    -- "coins", "gems", "crystals"
        icon = "💰",
        color = Color3.fromRGB(255, 215, 0)
    }
}
```

### Menu Button

```lua
{
    type = "menu_button",
    config = {
        name = "Shop",
        icon = "🛒",
        text = "Shop",
        color = Color3.fromRGB(46, 204, 113),
        admin_only = false    -- Optional: restrict to admin users
    }
}
```

### Player Info

```lua
{
    type = "player_info",
    config = {}    -- Uses default player data
}
```

### Quest Tracker

```lua
{
    type = "quest_tracker",
    config = {}    -- Uses current quest data
}
```

### Action Buttons

```lua
{
    type = "pets_button",    -- or "rewards_button"
    config = {
        icon = "🐾",
        text = "Pets",
        color = Color3.fromRGB(52, 152, 219),
        badge_count = 3    -- Optional notification badge
    }
}
```

## Quick Configuration Examples

### Individual Floating Currency Cards (Center-Left)

Each currency type gets its own floating card for a clean, professional look:

```lua
-- Individual Floating Cards (like professional games)
coins_pane = {
    position = "center-left",
    offset = {x = 15, y = -40},
    size = {width = 120, height = 35},
    background = {
        enabled = true,
        color = Color3.fromRGB(0, 0, 0),
        transparency = 0.15,
        corner_radius = 18,
        border = {
            enabled = true,
            color = Color3.fromRGB(255, 215, 0),  -- Gold border
            thickness = 2,
            transparency = 0.3
        }
    },
    layout = {type = "single"},
    contents = {
        {type = "currency_display", config = {currency = "coins", icon = "💰"}}
    }
},

gems_pane = {
    position = "center-left",
    offset = {x = 15, y = 0},
    size = {width = 120, height = 35},
    background = {
        enabled = true,
        color = Color3.fromRGB(0, 0, 0),
        transparency = 0.15,
        corner_radius = 18,
        border = {
            enabled = true,
            color = Color3.fromRGB(138, 43, 226),  -- Purple border
            thickness = 2,
            transparency = 0.3
        }
    },
    layout = {type = "single"},
    contents = {
        {type = "currency_display", config = {currency = "gems", icon = "💎"}}
    }
}
```

### Menu Grid (Bottom-Left)

```lua
menu_buttons_pane = {
    position = "bottom-left",
    size = {width = 320, height = 160},
    layout = {
        type = "grid",
        columns = 4,
        rows = 2,
        cell_size = {width = 75, height = 75},
        spacing = 5
    },
    contents = {
        {type = "menu_button", config = {name = "Shop", icon = "🛒"}},
        {type = "menu_button", config = {name = "Inventory", icon = "🎒"}},
        {type = "menu_button", config = {name = "Effects", icon = "⚡"}},
        {type = "menu_button", config = {name = "Settings", icon = "⚙️"}}
    }
}
```

### Combined Info Panel (Top-Center)

```lua
player_info_pane = {
    position = "top-center",
    size = {width = 400, height = 160},
    layout = {type = "custom"},
    contents = {
        {type = "player_info", config = {}},
        {type = "quest_tracker", config = {}}
    }
}
```

### Action Button (Bottom-Center)

```lua
pets_button_pane = {
    position = "bottom-center",
    size = {width = 100, height = 50},
    layout = {type = "single"},
    contents = {
        {type = "pets_button", config = {icon = "🐾", text = "Pets"}}
    }
}
```

## Advanced Features

### Responsive Offsets

Fine-tune positioning with pixel-perfect offsets:

```lua
position = "top-center",
offset = {x = 0, y = 35}    -- Move 35 pixels down from top
```

### Conditional Elements

Elements can be conditionally shown:

```lua
{
    type = "menu_button", 
    config = {
        name = "Admin", 
        admin_only = true    -- Only shows for admin users
    }
}
```

### Background Styling

Full control over pane appearance:

```lua
background = {
    enabled = true,
    color = Color3.fromRGB(0, 0, 0),
    transparency = 0.3,
    corner_radius = 15,
    border = {
        enabled = true,
        color = Color3.fromRGB(52, 152, 219),
        thickness = 2,
        transparency = 0.5
    }
}
```

## Multi-View Panes (Advanced)

For complex menus that switch between different content:

```lua
menu_views = {
    shop_panel = {
        default_view = "featured",
        views = {
            featured = {
                name = "Featured",
                icon = "⭐",
                layout = {type = "grid", columns = 3, rows = 4}
            },
            pets = {
                name = "Pets",
                icon = "🐾", 
                layout = {type = "grid", columns = 4, rows = 5}
            }
        }
    }
}
```

## Number Formatting System

The UI system includes an intelligent number formatting system similar to popular games:

### Automatic Formatting
- **1,000** → **1K**
- **1,000,000** → **1M** 
- **1,230,000** → **1.23M**
- **123,000,000** → **123M**
- **1,000,000,000** → **1B**
- **1,000,000,000,000** → **1T**
- **1,000,000,000,000,000** → **1Qa**

### Smart Decimal Precision
- Numbers 1-9.99: Show 2 decimals (e.g., 1.23M)
- Numbers 10-99.9: Show 1 decimal (e.g., 12.3M) 
- Numbers 100+: Show whole numbers (e.g., 123M)

This ensures currency displays always remain readable and appropriately sized, just like professional games.

## Performance Notes

- Position calculations are **cached** for better performance
- Theme lookups are **cached** to reduce redundant calls
- Pane creation is **logged** with millisecond timing
- **Error handling** ensures graceful fallbacks for invalid configurations

## File Locations

- **Main Config:** `configs/ui.lua`
- **Fallback Config:** `src/Client/UI/BaseUI.lua` (lines 125-200)
- **Implementation:** `src/Client/UI/BaseUI.lua` (pane system methods)

## Quick Tips

1. **Start simple:** Use semantic positions without offsets initially
2. **Group related elements:** Currency, buttons, info panels work well together
3. **Test different screen sizes:** Semantic positioning adapts automatically
4. **Use appropriate layouts:** Lists for linear content, grids for equal elements
5. **Leverage backgrounds:** Visual grouping improves user experience
6. **Consider z-index:** Higher values appear on top (default: 12)

## Common Patterns

### Status Bar (Top)
```lua
position = "top-center", layout = {type = "custom"}
```

### Currency Panel (Side)
```lua
position = "center-left", layout = {type = "list", direction = "vertical"}
```

### Action Menu (Bottom)
```lua
position = "bottom-left", layout = {type = "grid"}
```

## Universal Icon System

**ALL ICONS** in the UI system support both emoji and Roblox asset IDs. This includes:
- **Currency displays** (coins, gems, crystals)
- **Menu buttons** (Shop, Items, Effects, Settings, Admin)
- **Pets button**
- **Rewards button**
- **Any future icon elements**

### Icon Format Support

**Emoji Icons (Simple):**
```lua
icon = "🛒"    -- Shopping cart emoji
icon = "💰"    -- Money bag emoji
icon = "🐾"    -- Paw prints emoji
```

**Roblox Asset Icons (Professional):**
```lua
icon = "rbxassetid://7733920644"  -- Full rbxassetid format
icon = "13262136289"              -- Asset ID only (auto-converted)
icon = "7733686592"               -- Any valid asset ID
```

### Automatic Detection
The system automatically detects the icon type and uses the appropriate UI element:
- **Asset IDs** → `ImageLabel` with proper scaling and color tinting
- **Emoji/Text** → `TextLabel` with font rendering

### Mix and Match
You can freely mix emoji and asset IDs in the same UI:
```lua
contents = {
    {type = "currency_display", config = {currency = "coins", icon = "7733686592"}},     -- Asset
    {type = "currency_display", config = {currency = "gems", icon = "💎"}},              -- Emoji
    {type = "menu_button", config = {name = "Shop", icon = "rbxassetid://7733920644"}}, -- Asset
    {type = "pets_button", config = {icon = "13262136255", text = "Pets"}},             -- Working asset
    {type = "menu_button", config = {name = "Items", icon = "🎒"}}                      -- Emoji
}
```

### Button Architecture
The system automatically uses the most efficient Roblox button type:
- **Asset IDs** → `ImageButton` (image configured directly on button)
- **Emoji/Text** → `TextButton` (text configured directly on button)

This matches professional game architecture and provides optimal performance.

### Primary Action (Prominent)
```lua
position = "bottom-center", layout = {type = "single"}
```

## Version History

### v2.0 - Enhanced Asset Support & Performance
- **ImageButton architecture**: Asset IDs now use `ImageButton` directly instead of `TextButton` + `ImageLabel`
- **Universal asset support**: ALL icon types support both emoji and Roblox asset IDs
- **Robust error handling**: Automatic fallback to emoji when assets fail to load
- **Smart number formatting**: Professional currency display with K/M/B/T/Qa suffixes
- **Floating currency cards**: Individual panes for each currency type
- **Enhanced debugging**: Comprehensive error logging and diagnostics

---

This system provides **complete flexibility** while maintaining **ease of use**. Simply modify the configuration files to completely reorganize your UI without touching any code!