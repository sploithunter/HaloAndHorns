# Menu Modifications System: Configuration-as-Code for Visual Customization

## Overview

The Menu Modifications System allows you to customize colors, displays, fonts, and visual appearance across the entire UI system through configuration files, without touching any Lua code. This system provides global defaults with per-component overrides for ultimate flexibility.

## Core Concept: Global Defaults + Overrides

The system uses a **hierarchical configuration approach**:

1. **Global Defaults** - Base settings that apply everywhere
2. **Component Defaults** - Settings for specific UI component types (eggs, pets, etc.)
3. **Per-Item Overrides** - Settings for individual items (specific eggs, specific pets)

## File Structure

- `configs/egg_system.lua` - Global UI defaults and egg-specific settings
- `configs/pets.lua` - Pet viewport defaults and per-pet overrides
- `src/Shared/Services/EggPetPreviewService.lua` - Applies the configuration hierarchy

## Color System Configuration

### Global Color Defaults (configs/egg_system.lua)

```lua
-- === UI CONFIGURATION ===
ui = {
    -- Colors and Styling
    colors = {
        -- Main UI colors
        background = Color3.fromRGB(255, 255, 255),  -- White background
        border = Color3.fromRGB(0, 0, 0),  -- Black border for contrast
        text_primary = Color3.fromRGB(0, 0, 0),  -- Black primary text
        text_secondary = Color3.fromRGB(100, 100, 100),  -- Dark gray secondary text
        success_bg = Color3.fromRGB(34, 139, 34),
        error_bg = Color3.fromRGB(220, 53, 69),
        
        -- Pet preview UI colors
        pet_preview_bg = Color3.fromRGB(255, 255, 255),  -- White background
        pet_preview_border = Color3.fromRGB(0, 100, 200),  -- Blue border
        very_rare_text = Color3.fromRGB(150, 0, 0), -- Dark red for very low chances
        
        -- Pet container colors (individual pet frames)
        pet_container_bg = "rarity",  -- "rarity" = use rarity color, or set Color3 for uniform
        pet_container_transparency = 0.7,  -- More opaque for better visibility
        pet_container_border = Color3.fromRGB(200, 200, 200),  -- Light gray border
        
        -- Pet icon/viewport colors
        pet_icon_bg = Color3.fromRGB(240, 240, 240),  -- Light gray viewport background
        pet_icon_transparency = 0.2,  -- Semi-transparent to show background
    },
    
    -- Font Configuration
    fonts = {
        title = Enum.Font.GothamBold,
        prompt = Enum.Font.Gotham,
        notification = Enum.Font.Gotham,
        pet_name = Enum.Font.GothamBold,
        pet_chance = Enum.Font.Bangers,
        
        -- Pet container fonts (for individual pet displays)
        pet_icon_fallback = Enum.Font.GothamBold,      -- Font for emoji fallback icons
        pet_name_secondary = Enum.Font.Gotham,         -- Alternative pet name font
        pet_stats = Enum.Font.RobotoMono,              -- For detailed pet stats
        rarity_label = Enum.Font.GothamBold,           -- For rarity indicators
    },
}
```

### Component-Specific Defaults (configs/pets.lua)

```lua
-- === VIEWPORT DISPLAY SETTINGS ===
viewport = {
    default_zoom = 1.5,  -- Default camera zoom for all pets
    
    -- Default display settings (can be overridden per pet variant)
    default_show_name = true,          -- Show pet names by default
    default_container_transparency = 0.8,  -- Default container transparency
    default_container_bg = "rarity",   -- Default background ("rarity" or Color3)
    default_name_color = Color3.fromRGB(0, 0, 139),  -- Dark blue name text
    default_chance_color = Color3.fromRGB(139, 0, 0), -- Dark red chance text
},
```

## Per-Item Override System

### Per-Egg Display Overrides

Customize individual eggs in `configs/egg_system.lua`:

```lua
-- Per-egg display overrides (optional - overrides global settings)
egg_display_overrides = {
    ["basic_egg"] = {
        show_variant_names = false,        -- Hide pet names for this egg
        pet_container_transparency = 1.0,  -- Make containers fully transparent
        pet_container_bg = Color3.fromRGB(50, 50, 50),  -- Custom background color
    },
    ["golden_egg"] = {
        pet_container_bg = Color3.fromRGB(255, 215, 0),  -- Golden background
        pet_container_transparency = 0.3,                -- More opaque for premium egg
        min_chance_to_show = 0.00001,                   -- Show even rarer pets (0.001%)
    },
    ["legendary_egg"] = {
        min_chance_to_show = 0.000001,                  -- Ultra rare threshold (0.0001%)
    },
},
```

### Per-Pet Display Overrides

Customize individual pet variants in `configs/pets.lua`:

```lua
rainbow = {
    asset_id = "rbxassetid://120821607721730",
    display_name = "Rainbow Dragon",
    power = 1250,
    health = 10000, 
    abilities = {"prismatic_breath", "reality_burn", "cosmic_flight"},
    viewport_zoom = 1.2,  -- Custom zoom for this pet
    
    -- Display overrides (optional - overrides viewport defaults)
    display_container_bg = Color3.fromRGB(255, 0, 255),  -- Magenta bg for Rainbow Dragon
    display_container_transparency = 0.3,  -- More opaque for mythic pet
    display_show_name = true,  -- Always show name for rainbow variants
}
```

## Smart Percentage Formatting

The system includes intelligent percentage formatting that shows meaningful digits:

```lua
smart_percentage_formatting = true, -- Use intelligent digit formatting
fallback_precision = 2,            -- Fallback decimal places if smart formatting disabled
```

### Formatting Examples

- **10%+**: Show as whole numbers (25%, 67%)
- **1-9.9%**: Show one decimal if needed (5%, 2.5%, 1.2%)
- **0.1-0.99%**: Show two decimals (0.25%, 0.50%)
- **0.01-0.099%**: Show three decimals (0.025%, 0.050%)
- **Below threshold**: Show as "??" (configurable via `min_chance_to_show`)

## Configuration Hierarchy Examples

### Example 1: Theme Switching

**Dark Theme Configuration:**
```lua
-- In egg_system.lua
colors = {
    background = Color3.fromRGB(30, 30, 30),  -- Dark background
    text_primary = Color3.fromRGB(255, 255, 255),  -- White text
    text_secondary = Color3.fromRGB(200, 200, 200),  -- Light gray
    pet_preview_bg = Color3.fromRGB(45, 45, 45),  -- Dark pet preview
    pet_preview_border = Color3.fromRGB(100, 150, 255),  -- Bright blue border
}
```

**Light Theme Configuration:**
```lua
-- In egg_system.lua  
colors = {
    background = Color3.fromRGB(255, 255, 255),  -- White background
    text_primary = Color3.fromRGB(0, 0, 0),  -- Black text
    text_secondary = Color3.fromRGB(100, 100, 100),  -- Dark gray
    pet_preview_bg = Color3.fromRGB(255, 255, 255),  -- White pet preview
    pet_preview_border = Color3.fromRGB(0, 100, 200),  -- Blue border
}
```

### Example 2: Seasonal Color Schemes

**Halloween Theme:**
```lua
egg_display_overrides = {
    ["spooky_egg"] = {
        pet_container_bg = Color3.fromRGB(255, 140, 0),  -- Orange containers
        pet_container_transparency = 0.3,  -- More opaque
        pet_icon_bg = Color3.fromRGB(139, 69, 19),  -- Brown icon background
    },
}
```

**Christmas Theme:**
```lua
egg_display_overrides = {
    ["festive_egg"] = {
        pet_container_bg = Color3.fromRGB(220, 20, 60),  -- Crimson containers
        pet_preview_border = Color3.fromRGB(34, 139, 34),  -- Green border
        pet_icon_bg = Color3.fromRGB(255, 255, 255),  -- White icon background
    },
}
```

### Example 3: Rarity-Based Customization

**High-End Egg Styling:**
```lua
egg_display_overrides = {
    ["mythic_egg"] = {
        pet_container_bg = "rarity",  -- Use rarity colors (maintains identity)
        pet_container_transparency = 0.2,  -- Very opaque for premium feel
        min_chance_to_show = 0.000001,  -- Show ultra-rare pets
        show_variant_names = true,  -- Always show names for premium pets
    },
}
```

## Override Priority System

The configuration system follows a strict priority order:

1. **Pet-specific overrides** (highest priority)
   - `display_container_bg`, `display_container_transparency`, etc. in pet definitions
2. **Egg-specific overrides** 
   - Settings in `egg_display_overrides[eggType]`
3. **Component defaults**
   - Settings in `viewport` defaults (pets.lua)
4. **Global defaults** (lowest priority)
   - Settings in `ui.colors` (egg_system.lua)

### Priority Example

For pet container background color:
```lua
-- 1. Pet override (highest priority)
rainbow_dragon = {
    display_container_bg = Color3.fromRGB(255, 0, 255),  -- Magenta
}

-- 2. Egg override
egg_display_overrides = {
    ["legendary_egg"] = {
        pet_container_bg = Color3.fromRGB(255, 215, 0),  -- Gold
    }
}

-- 3. Component default
viewport = {
    default_container_bg = "rarity",  -- Use rarity color
}

-- 4. Global default (fallback)
ui = {
    colors = {
        pet_container_bg = Color3.fromRGB(128, 128, 128),  -- Gray
    }
}
```

## Font Customization

### Available Font Options

The system includes comprehensive font options with fallbacks:

```lua
fonts = {
    -- Standard fonts that work reliably:
    -- Enum.Font.Gotham                         - Clean, readable (being replaced by Montserrat)
    -- Enum.Font.GothamBold                     - Bold version of Gotham
    -- Enum.Font.GothamBlack                    - Extra bold Gotham
    -- Enum.Font.Montserrat                     - Replacement for Gotham
    -- Enum.Font.MontserratBold                 - Bold Montserrat
    -- Enum.Font.Arimo                          - Replacement for Arial
    -- Enum.Font.ArimoBold                      - Bold Arimo
    -- Enum.Font.SourceSans                     - Clean, readable
    -- Enum.Font.SourceSansBold                 - Bold Source Sans
    -- Enum.Font.RobotoMono                     - Monospace alternative
    -- Enum.Font.SpecialElite                   - Typewriter style
    -- Enum.Font.Creepster                      - Horror/spooky theme
    -- Enum.Font.Bangers                        - Comic book style
    -- Enum.Font.Kalam                          - Handwritten style
    -- Enum.Font.PatrickHand                    - Casual handwritten
}
```

### Font Theme Examples

**Professional Theme:**
```lua
fonts = {
    title = Enum.Font.MontserratBold,
    pet_name = Enum.Font.Montserrat,
    pet_chance = Enum.Font.RobotoMono,
}
```

**Playful Theme:**
```lua
fonts = {
    title = Enum.Font.Bangers,
    pet_name = Enum.Font.PatrickHand,
    pet_chance = Enum.Font.Kalam,
}
```

**Horror Theme:**
```lua
fonts = {
    title = Enum.Font.Creepster,
    pet_name = Enum.Font.SpecialElite,
    pet_chance = Enum.Font.Creepster,
}
```

## Common Use Cases

### 1. Changing All UI to Dark Mode

Edit `configs/egg_system.lua`:
```lua
colors = {
    background = Color3.fromRGB(30, 30, 30),
    border = Color3.fromRGB(100, 100, 100),
    text_primary = Color3.fromRGB(255, 255, 255),
    text_secondary = Color3.fromRGB(200, 200, 200),
    pet_preview_bg = Color3.fromRGB(45, 45, 45),
    pet_preview_border = Color3.fromRGB(100, 150, 255),
}
```

### 2. Making Rare Pets More Visible

Edit `configs/egg_system.lua`:
```lua
egg_display_overrides = {
    ["basic_egg"] = {
        pet_container_transparency = 0.3,  -- More opaque for visibility
        min_chance_to_show = 0.00001,     -- Show rarer pets
    },
}
```

### 3. Customizing Premium Egg Experience

Edit `configs/egg_system.lua`:
```lua
egg_display_overrides = {
    ["golden_egg"] = {
        pet_container_bg = Color3.fromRGB(255, 215, 0),  -- Golden theme
        pet_container_transparency = 0.2,  -- Very opaque
        pet_icon_bg = Color3.fromRGB(255, 255, 255),  -- White icon backgrounds
        show_variant_names = true,  -- Always show names
    },
}
```

### 4. Per-Pet Special Effects

Edit individual pet definitions in `configs/pets.lua`:
```lua
rainbow_dragon = {
    -- ... existing properties ...
    display_container_bg = Color3.fromRGB(255, 0, 255),  -- Magenta
    display_container_transparency = 0.1,  -- Nearly opaque
    display_show_name = true,  -- Force show name
    display_name_color = Color3.fromRGB(255, 255, 255),  -- White text
}
```

## Benefits of This System

1. **No Code Changes Required** - All visual customization through configuration
2. **Hot-Swappable Themes** - Change entire UI appearance instantly
3. **Granular Control** - Customize individual components or global defaults
4. **Seasonal Updates** - Easy holiday themes and special events
5. **A/B Testing** - Test different visual approaches
6. **Maintainability** - Centralized visual configuration
7. **Designer-Friendly** - Non-programmers can customize appearance

## Testing Configuration Changes

1. **Edit the configuration files** (`configs/egg_system.lua`, `configs/pets.lua`)
2. **Restart the game** (or implement hot-reloading for development)
3. **Approach an egg** to see pet preview changes
4. **Check different egg types** to verify per-egg overrides

## Advanced: Dynamic Configuration

For advanced use cases, you can implement runtime configuration changes:

```lua
-- Example: Seasonal theme switcher
local function ApplySeasonalTheme(season)
    local eggConfig = require(Locations.getConfig("egg_system"))
    
    if season == "halloween" then
        eggConfig.ui.colors.pet_container_bg = Color3.fromRGB(255, 140, 0)
        eggConfig.ui.colors.pet_preview_border = Color3.fromRGB(139, 69, 19)
    elseif season == "christmas" then
        eggConfig.ui.colors.pet_container_bg = Color3.fromRGB(220, 20, 60)
        eggConfig.ui.colors.pet_preview_border = Color3.fromRGB(34, 139, 34)
    end
    
    -- Refresh UI components to apply changes
end
```

This Menu Modifications System provides **unlimited visual customization** while maintaining **professional quality** and **ease of maintenance**!