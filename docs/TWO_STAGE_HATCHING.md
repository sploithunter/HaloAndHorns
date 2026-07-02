# Two-Stage Hatching System

This document explains the flexible two-stage hatching mechanic that supports gamepass and luck modifiers.

## Overview

The hatching system works in two distinct stages:

1. **Stage 1**: Select the pet type (bear, bunny, etc.) based on egg weights
2. **Stage 2**: Calculate rarity (basic/golden/rainbow) with modifiers applied

This separation allows for much cleaner configuration and easier balancing.

## Stage 1: Pet Selection

Each egg defines which pets are available and their relative weights:

```lua
pet_weights = {
    bear = 25,    -- 25% chance for bear
    bunny = 25,   -- 25% chance for bunny
    doggy = 25,   -- 25% chance for doggy
    kitty = 20,   -- 20% chance for kitty
    dragon = 5,   -- 5% chance for dragon (rarest)
}
```

**Algorithm:**
1. Sum all weights (100 in this example)
2. Generate random number 0-100
3. Find which pet range the number falls into

## Stage 2: Rarity Calculation

Base rarity rates are defined per egg:

```lua
rarity_rates = {
    golden_chance = 0.05,   -- 5% base golden chance
    rainbow_chance = 0.005, -- 0.5% base rainbow chance
    -- Remaining 94.5% is basic
}
```

### Modifier System

Multiple modifiers can be applied:

```lua
-- Gamepass multipliers
golden_chance *= golden_gamepass_multiplier  -- 2x if owned
rainbow_chance *= rainbow_gamepass_multiplier -- 3x if owned

-- Luck system
luck_multiplier = base_luck + (level * luck_per_level) + (pets_hatched * luck_from_pets_hatched)

-- Apply luck to both chances
golden_chance *= luck_multiplier
rainbow_chance *= luck_multiplier

-- VIP bonuses
if isVIP then
    golden_chance *= vip_golden_bonus
    rainbow_chance *= vip_rainbow_bonus
end
```

## Configuration Examples

### Basic Egg (All Rarities)
```lua
basic_egg = {
    pet_weights = { bear = 25, bunny = 25, doggy = 25, kitty = 20, dragon = 5 },
    rarity_rates = {
        golden_chance = 0.05,   -- 5%
        rainbow_chance = 0.005, -- 0.5%
    },
    modifier_support = {
        supports_luck_gamepass = true,
        supports_golden_gamepass = true,
        supports_rainbow_gamepass = true,
        max_luck_multiplier = 10.0,
    }
}
```

### Golden Egg (Premium Only)
```lua
golden_egg = {
    pet_weights = { bear = 25, bunny = 25, doggy = 25, kitty = 20, dragon = 5 },
    rarity_rates = {
        golden_chance = 0.95,   -- 95%
        rainbow_chance = 0.05,  -- 5%
        no_basic_variants = true, -- Special flag
    },
    modifier_support = {
        supports_luck_gamepass = true,
        supports_golden_gamepass = false, -- Already guaranteed
        supports_rainbow_gamepass = true,
        max_luck_multiplier = 5.0, -- Lower cap
    }
}
```

## Implementation Example

```lua
function HatchingService:HatchEgg(player, eggType)
    -- Get player data
    local playerData = {
        level = PlayerDataService:GetLevel(player),
        petsHatched = PlayerDataService:GetPetsHatched(player),
        hasLuckGamepass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, LUCK_GAMEPASS_ID),
        hasGoldenGamepass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, GOLDEN_GAMEPASS_ID),
        hasRainbowGamepass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, RAINBOW_GAMEPASS_ID),
        isVIP = PlayerDataService:IsVIP(player),
    }
    
    -- Use the simulation function
    local result = petConfig.simulateHatch(eggType, playerData)
    
    if result then
        -- Create the pet instance
        local newPet = PetService:CreatePet(result.pet, result.variant, player)
        
        -- Show hatching results
        HatchingUI:ShowResults(player, result)
        
        return newPet
    end
    
    return nil
end
```

## Benefits

✅ **Flexible**: Easy to add new modifiers or change rates  
✅ **Balanced**: Separate luck caps per egg type  
✅ **Monetizable**: Gamepass bonuses clearly defined  
✅ **Configurable**: All values in config files  
✅ **Testable**: Simulation function for testing  

## Testing

Use the built-in test function:

```lua
local petConfig = require(ReplicatedStorage.Configs.pets)
petConfig.testHatching() -- Simulates 10 hatches
```

Example output:
```
=== Hatching Simulation ===
Hatch 1: golden bear (Power: 50)
Hatch 2: basic bunny (Power: 8)
Hatch 3: rainbow dragon (Power: 1250)
Hatch 4: golden kitty (Power: 45)
...
```

## Gamepass Configuration

Update gamepass IDs in the config:

```lua
gamepass_modifiers = {
    luck_gamepass_id = 12345678,
    golden_gamepass_id = 12345679,
    rainbow_gamepass_id = 12345680,
    
    luck_gamepass_multiplier = 2.0,
    golden_gamepass_multiplier = 2.0,
    rainbow_gamepass_multiplier = 3.0,
}
```

This system scales perfectly from simple free-to-play mechanics to complex premium monetization!