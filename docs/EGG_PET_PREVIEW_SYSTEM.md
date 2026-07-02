# Egg Pet Preview System

🎯 **Real-time pet hatch chances display when approaching eggs**

## Overview

The Egg Pet Preview System displays pets and their calculated hatch percentages when players approach eggs. The system integrates with the existing egg proximity system and includes all player modifiers for accurate chance calculations.

## Features

✅ **Real-time Chance Calculation**: Includes all player luck modifiers  
✅ **Aggregate Integration**: Uses Player/Aggregates/ folder values  
✅ **Professional UI**: Clean grid layout with pet icons and percentages  
✅ **Smart Display**: Shows "??" for very rare pets (<0.1% chance)  
✅ **Performance Optimized**: Updates only when needed  
✅ **Configurable**: All settings in egg_system.lua config  

## How It Works

### 1. Integration with Proximity System

The pet preview integrates seamlessly with `EggCurrentTargetService`:

```lua
-- When player approaches egg
eggPetPreviewService:ShowPetPreview(eggType, anchor.Position)

-- When moving around egg  
eggPetPreviewService:UpdatePreviewPosition(anchor.Position)

-- When leaving egg range
eggPetPreviewService:HidePetPreview()
```

### 2. Display Logic (Simplified)

```lua
-- Basic Eggs: Show only basic variants with pet type weights
if eggType == "basic_egg" then
    for petType, weight in pairs(eggData.pet_weights) do
        local petTypeChance = weight / totalWeight  -- e.g., Bear = 25%
        -- Show basic variant only
        addToDisplay(petType, "basic", petTypeChance)
    end
end

-- Golden Eggs: Show golden and rainbow variants  
if eggType == "golden_egg" then
    for petType, weight in pairs(eggData.pet_weights) do
        local petTypeChance = weight / totalWeight
        -- Show golden and rainbow variants
        addToDisplay(petType, "golden", petTypeChance)
        addToDisplay(petType, "rainbow", petTypeChance)
    end
end
```

### 3. UI Display

**Basic Egg Preview:**
```
┌─────────────────────────────────────┐
│               Pet Chances           │
├─────────────────────────────────────┤
│  [🐻]   [🐰]   [🐶]   [🐱]        │
│  Bear   Bunny  Doggy  Kitty        │
│  25%    25%    25%    20%          │
│                                    │
│          [🐲]                      │
│         Dragon                     │
│          5%                        │
└─────────────────────────────────────┘
```

**Golden Egg Preview:**
```
┌─────────────────────────────────────┐
│               Pet Chances           │
├─────────────────────────────────────┤
│ [✨🐻] [🌈🐻] [✨🐰] [🌈🐰]       │
│Golden  Rainbow Golden  Rainbow      │
│ Bear   Bear   Bunny   Bunny        │
│ 25%    25%    25%    25%           │
└─────────────────────────────────────┘
```

*Note: [🐻] represents actual 3D pet models displayed in ViewportFrames with optional spinning animation*

## Configuration

All settings in `configs/egg_system.lua`:

```lua
pet_preview = {
    enabled = true,                     -- Toggle preview system
    min_chance_to_show = 0.001,        -- 0.1% minimum to show actual %
    max_pets_to_display = 8,           -- Limit display count
    grid_columns = 4,                  -- Grid layout
    pet_icon_size = 60,                -- Icon size in pixels
    chance_precision = 2,              -- Decimal places (e.g., "5.25%")
    
    -- Display options
    show_variant_names = true,         -- Show "Golden Bear" vs "Bear"
    group_by_rarity = true,            -- Group by rarity
    sort_by_chance = true,             -- Sort highest first
    
    -- Performance
    load_pet_icons = true,             -- Load actual pet models
    fallback_to_emoji = true,          -- Use emoji if loading fails
    icon_cache_time = 300,             -- Cache time in seconds
}
```

## Player Data Sources

The system aggregates data from multiple sources:

### ProfileStore Data
- `Level` - Player level (affects base luck)
- `PetsHatched` - Total pets hatched (experience luck)

### Player Aggregates (Real-time)
- `Player/Aggregates/luckBoost` - From luck potions
- `Player/Aggregates/rareLuckBoost` - From rare luck effects  
- `Player/Aggregates/ultraLuckBoost` - From ultra luck bonuses

### Gamepass & Premium
- Golden gamepass ownership (2x golden chance)
- Rainbow gamepass ownership (3x rainbow chance)  
- Luck gamepass ownership (2x all luck)
- Premium membership (1.5x bonuses)

## File Structure

```
src/Shared/Services/
├── EggPetPreviewService.lua       # Main preview logic
└── EggCurrentTargetService.lua    # Integration point

configs/
└── egg_system.lua                 # Configuration

tests/unit/
└── EggPetPreviewService.spec.lua  # Unit tests
```

## API Reference

### EggPetPreviewService

```lua
-- Show pet preview for egg at position
:ShowPetPreview(eggType, eggPosition)

-- Hide pet preview
:HidePetPreview()

-- Update preview position (for moving around egg)
:UpdatePreviewPosition(eggPosition)

-- Calculate chances with all modifiers
:CalculatePetChances(eggType) -> petChances[]

-- Get player data including aggregates
:GetPlayerData() -> playerData
```

### Pet Chance Object

```lua
{
    petType = "bear",               -- Base pet type
    variant = "golden",             -- Variant (basic/golden/rainbow)
    chance = 0.038,                 -- Final calculated chance (0-1)
    petData = {                     -- Full pet configuration
        name = "Golden Bear",
        asset_id = "rbxassetid://...",
        power = 50,
        rarity = { color = Color3, glow = true },
        -- ... other pet data
    }
}
```

## Testing

The system includes comprehensive unit tests:

```bash
# Run tests in Studio
-- Execute tests/TestBootstrap.lua
-- or run specific test:
require(tests.unit["EggPetPreviewService.spec"])()
```

## Performance Considerations

### Optimizations
- **Lazy UI Creation**: UI created only when needed
- **Position Updates**: Only when player moves around egg
- **Icon Caching**: Pet icons cached to reduce loading
- **Smart Updates**: Only recalculate when egg type changes

### Memory Management
- UI properly destroyed when service cleanup
- Icon cache limited by time and size
- No memory leaks from event connections

## Integration Notes

### With Existing Systems
- **EggCurrentTargetService**: Handles proximity detection
- **PlayerEffectsService**: Provides aggregate luck values
- **DataService**: Provides player level and stats
- **MonetizationService**: Provides gamepass ownership

### Architecture Compliance
- ✅ Uses LoggerWrapper pattern from memory  
- ✅ Follows aggregate properties pattern
- ✅ Configuration-driven display
- ✅ No ProfileStore aggregate storage
- ✅ Real-time updates via NumberValue replication

## Future Enhancements

### Planned Features
- **Asset Icon Loading**: Load actual pet model thumbnails
- **Animation Effects**: Smooth show/hide animations  
- **Sound Effects**: Audio feedback for rare pets
- **Detailed Tooltips**: Pet stats and abilities on hover

### Possible Improvements
- **Multi-language Support**: Configurable text strings
- **Theme Variants**: Different UI styles
- **Advanced Filtering**: Show only specific rarities
- **Comparison Mode**: Compare multiple egg types

## Troubleshooting

### Common Issues

**Pet preview not showing:**
- Check `eggSystemConfig.pet_preview.enabled = true`
- Verify EggCurrentTargetService is initialized
- Check console for service loading errors

**Incorrect chances:**
- Verify Player/Aggregates/ folder exists
- Check gamepass ownership detection
- Validate pet configuration data

**UI positioning issues:**
- Check egg anchor points (SpawnPoint ObjectValue)
- Verify camera viewport calculations
- Adjust position_offset in config

### Debug Options

```lua
-- In egg_system.lua config
debug = {
    log_proximity_changes = true,   -- Log egg targeting
    log_server_calls = true,        -- Log server communication
    log_ui_updates = false,         -- Log UI position updates
}
```

The Egg Pet Preview System provides players with transparent, real-time information about their hatch chances while maintaining the excitement of the hatching process through smart display thresholds and beautiful UI presentation.