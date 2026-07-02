# BasicEgg Testing Guide

You now have your BasicEgg set up! Here's how to test it in your game.

## Current Setup

✅ **BasicEgg Model**: `rbxassetid://77451518796778`  
✅ **Golden BasicEgg Model**: `rbxassetid://83992435784076`  
✅ **Pet Assets**: All 15 variants (Basic, Golden, Rainbow × 5 animals)

## Quick Test Setup

### 1. Create a Spawn Point

In Roblox Studio:
1. Insert a `Part` into Workspace
2. Name it `"EggSpawnPoint"`
3. Set attribute: `EggType = "basic_egg"`
4. Position it where you want the egg to appear

### 2. Test the EggSpawner

Run this in the Command Bar:

```lua
-- Load the EggSpawner service
local EggSpawner = require(game.ReplicatedStorage.Shared.Services.EggSpawner)

-- Initialize the system (spawns eggs at all spawn points)
EggSpawner:Initialize()

-- Or manually spawn a BasicEgg at a specific position
local egg = EggSpawner:SpawnEgg("basic_egg", Vector3.new(0, 10, 0))
print("Spawned egg:", egg)
```

### 3. Test Pet Configuration

```lua
-- Test pet data loading
local petConfig = require(game.ReplicatedStorage.Configs.pets)

-- Get a specific pet
local goldenBear = petConfig.getPet("bear", "golden")
print("Golden Bear Power:", goldenBear.power) -- Should show 50
print("Asset ID:", goldenBear.asset_id) -- Should show your bear asset ID

-- Test egg configuration
local basicEgg = petConfig.egg_sources.basic_egg
print("BasicEgg Asset ID:", basicEgg.egg_model_asset_id) -- Should show 77451518796778
```

## Expected Behavior

When you run `EggSpawner:Initialize()`:

1. **Finds** all `EggSpawnPoint` parts in workspace
2. **Loads** the BasicEgg model from your asset ID
3. **Spawns** the egg at the spawn point location
4. **Adds** hover effects and click detection
5. **Plays** spawn animation

## Drop Rates in BasicEgg

Your BasicEgg now contains all pet variants:

| Variant | Drop Rate | Examples |
|---------|-----------|----------|
| **Basic** | 95% | Bear (20%), Bunny (20%), Dog (20%), Cat (20%), Dragon (15%) |
| **Golden** | 4.5% | All golden variants (1% each, 0.5% for dragon) |
| **Rainbow** | 0.5% | All rainbow variants (0.1% each) |

## Troubleshooting

### "Failed to load egg asset"
- Double-check the asset ID: `77451518796778`
- Make sure the asset is public or owned by your account
- Verify the asset contains a Model (not just MeshParts)

### "No spawn points found"
- Make sure you have a Part named exactly `"EggSpawnPoint"`
- Check that it has attribute `EggType = "basic_egg"`
- Verify it's in workspace (not in a folder that might be ignored)

### Egg doesn't appear
- Check that the spawn point is positioned correctly
- Make sure there isn't already an egg at that location
- Verify the EggSpawner service initialized successfully

## Next Steps

Once BasicEgg is working:

1. **Add more spawn points** for multiple egg locations
2. **Test Golden Egg** (requires unlocking after 10 pets hatched)
3. **Upload more egg models** from your other game
4. **Connect to purchase system** for actual gameplay

## Testing Commands

Quick commands for testing:

```lua
-- List all active eggs
local EggSpawner = require(game.ReplicatedStorage.Shared.Services.EggSpawner)
for egg, info in pairs(EggSpawner.activeEggs or {}) do
    print("Active egg:", egg.Name, "Type:", info.eggType)
end

-- Force spawn at cursor position
local mouse = game.Players.LocalPlayer:GetMouse()
EggSpawner:SpawnEgg("basic_egg", mouse.Hit.Position)

-- Test pet spawning
local petConfig = require(game.ReplicatedStorage.Configs.pets)
local randomPet = petConfig.getPet("dragon", "rainbow")
print("Rainbow Dragon:", randomPet.name, randomPet.power)
```

Your BasicEgg system is ready to go! 🥚✨