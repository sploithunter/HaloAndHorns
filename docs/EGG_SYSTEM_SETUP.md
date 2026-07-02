# Egg System Setup Guide

This guide explains how to set up the dynamic egg spawning system in your Roblox game.

## Overview

The egg system uses **asset IDs** for models and **spawn points** in the workspace. This gives you maximum flexibility:

- 🎯 **Dynamic**: Eggs spawn/despawn based on player actions
- 🔧 **Configurable**: All settings in `configs/pets.lua` 
- 🎨 **Visual**: Each egg type can have unique models
- 💰 **Monetizable**: Easy to add premium eggs

## Setup Steps

### 1. Upload Egg Models as Assets

From your other game:
1. Select each egg model (e.g., `BasicEgg`, `Golden_BasicEgg`)
2. Right-click → "Save to Roblox" or use Asset Manager
3. Get the asset ID from the upload
4. Add to `configs/pets.lua`:

```lua
basic_egg = {
    egg_model_asset_id = "rbxassetid://YOUR_BASIC_EGG_ID",
    -- ... other config
}
```

### 2. Create Spawn Points in Workspace

#### Option A: Simple Spawn Points
1. Create a `Part` in Workspace
2. Name it `"EggSpawnPoint"`
3. Set attribute `EggType` to the egg type (e.g., `"basic_egg"`)
4. Position where you want the egg to appear

#### Option B: Decorated Spawn Points
```
Workspace/
  EggShop/
    BasicEggStand/        -- Folder or Model
      EggSpawnPoint       -- Part (the actual spawn point)
      Stand               -- Decorative base
      Sign                -- Shop sign
      Particles           -- Visual effects
```

### 3. Initialize the System

In your server initialization:

```lua
local EggSpawner = require(ReplicatedStorage.Shared.Services.EggSpawner)

-- Initialize when server starts
EggSpawner:Initialize()
```

## Configuration Examples

### Basic Shop Setup
```lua
-- configs/pets.lua
egg_sources = {
    basic_egg = {
        name = "Basic Egg",
        cost = 100,
        currency = "coins",
        egg_model_asset_id = "rbxassetid://123456789",
        icon_asset_id = "rbxassetid://123456790",
        
        possible_pets = {
            {pet = "bear", variant = "basic", weight = 25},
            {pet = "bunny", variant = "basic", weight = 25},
            -- ...
        }
    }
}
```

### Premium Egg Setup
```lua
golden_egg = {
    name = "Golden Egg",
    cost = 1000,
    currency = "gems", 
    egg_model_asset_id = "rbxassetid://987654321",
    unlock_requirement = {type = "pets_hatched", amount = 10},
    
    hatching_time = 30, -- 30 second anticipation
    special_hatch_animation = true,
}
```

## Advanced Features

### Multiple Spawn Points
- Create multiple `EggSpawnPoint` parts for the same egg type
- System will populate all available spawn points
- Perfect for busy areas or multiple shop locations

### Event/Seasonal Eggs
```lua
halloween_egg = {
    name = "Spooky Egg",
    available_until = "2024-11-01", 
    unlock_requirement = {type = "event_active", event_name = "halloween"},
    event_exclusive = true,
}
```

### Spawn Point Attributes
Set these attributes on `EggSpawnPoint` parts:

- `EggType` (string): Which egg to spawn ("basic_egg", "golden_egg", etc.)
- `Cooldown` (number): Seconds before respawning after purchase
- `MaxEggs` (number): Max eggs at this spawn point (default: 1)

## Interaction System

The system automatically adds:
- ✨ **Hover Effects**: Glow when mouse hovers over egg
- 🖱️ **Click Detection**: Opens purchase UI when clicked
- 🎬 **Animations**: Spawn/despawn animations
- 📊 **Tracking**: Monitors all active eggs

## Benefits Over Static Eggs

| Static Eggs (Old) | Dynamic System (New) |
|------------------|---------------------|
| ❌ Hard to update | ✅ Config-driven updates |
| ❌ Version control issues | ✅ Clean asset management |  
| ❌ Fixed in workspace | ✅ Spawn/despawn dynamically |
| ❌ Difficult monetization | ✅ Easy premium features |
| ❌ No progression | ✅ Unlock requirements |

## Workflow Summary

1. **Upload** egg models → Get asset IDs
2. **Configure** eggs in `pets.lua` with asset IDs  
3. **Place** spawn points in workspace
4. **Initialize** EggSpawner service
5. **Players** see eggs spawn dynamically based on config!

This system scales perfectly from a few eggs to hundreds of different types, all managed through configuration.