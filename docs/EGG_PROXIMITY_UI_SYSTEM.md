# Egg Proximity & UI System

Complete proximity detection and purchase UI system for eggs, with full integration to the two-stage hatching system.

## Features

✅ **Proximity Detection**: Automatic prompts when players approach eggs  
✅ **Professional UI**: Purchase confirmation with pet chances display  
✅ **Two-Stage Integration**: Uses your custom hatching algorithm  
✅ **Responsive Design**: Modern UI with animations and effects  
✅ **Error Handling**: Graceful fallbacks and debugging info  

## How It Works

### 1. Proximity System

When eggs are spawned by `EggSpawner`, they automatically get:
- **ProximityPrompt** attached to the egg model
- **Custom styling** with egg name and cost
- **"E" key interaction** (or controller X button)
- **15 stud activation distance**

### 2. Purchase UI

When players interact with an egg:

```lua
-- Shows professional UI with:
- Egg name and description
- Live pet chances calculation
- Cost display with currency
- Purchase/Close buttons
- Smooth animations
```

### 3. Pet Chances Display

The UI dynamically calculates and displays:
- **Base pet types** (Bear 25%, Bunny 25%, etc.)
- **Rarity breakdown** (Basic 94.5%, Golden 5%, Rainbow 0.5%)
- **Color-coded rarities** matching your rarity system
- **Exact percentage chances** for each pet variant

### 4. Hatching Simulation

When purchase is confirmed:
- **Currency validation** (TODO: integrate with economy)
- **Two-stage hatching** using `petConfig.simulateHatch()`
- **Results display** showing the hatched pet
- **Animation system** (TODO: expand)

## Configuration

Everything is driven by your existing pet configuration:

```lua
-- configs/pets.lua
basic_egg = {
    name = "Basic Egg",
    description = "Contains all your favorite pets!",
    cost = 100,
    currency = "coins",
    
    -- Stage 1: Pet selection weights
    pet_weights = {
        bear = 25,    -- 25% chance
        bunny = 25,   -- 25% chance
        doggy = 25,   -- 25% chance
        kitty = 20,   -- 20% chance
        dragon = 5,   -- 5% chance
    },
    
    -- Stage 2: Rarity calculation
    rarity_rates = {
        golden_chance = 0.05,   -- 5%
        rainbow_chance = 0.005, -- 0.5%
    }
}
```

## UI Screenshots

The purchase UI includes:

1. **Header**: Egg name and description
2. **Pet Chances**: Scrollable list of all possible pets with percentages
3. **Cost Display**: Clear pricing with currency type
4. **Action Buttons**: Purchase (green) and Close (red) with hover animations

## Integration Points

### EggSpawner Integration
```lua
-- Automatically called when eggs spawn
EggInteractionService:AddPromptToEgg(egg)
```

### Client Initialization
```lua
-- Added to client startup
EggInteractionService:Initialize()
```

### Economy Integration (TODO)
```lua
-- Will integrate with your economy system
function EggInteractionService:HandlePurchase(eggType, eggData, egg)
    -- 1. Check player currency
    -- 2. Deduct cost
    -- 3. Run two-stage hatching
    -- 4. Give pet to player
    -- 5. Show results
end
```

## Current Status

### ✅ Working Now
- Proximity detection on eggs
- Professional purchase UI
- Pet chances calculation and display
- Two-stage hatching simulation
- UI animations and styling

### 🚧 TODO (Next Steps)
- Economy integration (check/deduct currency)
- Hatching animation sequence
- Pet creation and inventory system
- Results UI with 3D pet preview
- Sound effects and particles

## Testing

To test the system:

1. **Create spawn point** with `EggType = "basic_egg"`
2. **Restart game** (auto-spawns eggs)
3. **Walk near egg** - proximity prompt appears
4. **Press E** - purchase UI opens
5. **Click Purchase** - see hatching simulation in console

## Example Usage

```lua
-- Test the two-stage hatching
local playerData = {
    level = 15,
    petsHatched = 25,
    hasLuckGamepass = true,
    isVIP = true
}

local result = petConfig.simulateHatch("basic_egg", playerData)
print("Result:", result.variant, result.pet, result.petData.power)
```

The system is fully functional and ready for economy integration! 🚀

## UI Architecture

The system uses modern Roblox UI best practices:
- **ScreenGui** with proper layering
- **Corner radius** and shadows for depth
- **Smooth animations** with TweenService
- **Responsive layouts** with UIListLayout
- **Color coding** based on rarity system
- **Professional styling** with proper contrast

This creates a polished, professional experience that matches modern pet game standards!