# Locations.lua Documentation

## Overview

The `Locations.lua` module serves as a **Service Locator** pattern implementation that provides centralized access to all game services, folders, configurations, and assets. This architectural pattern ensures consistent access patterns across the codebase and makes refactoring easier by having all locations defined in one place.

## File Location
```
src/Shared/Locations.lua
```

## Core Purpose

1. **Single Source of Truth**: All service and asset locations are defined in one module
2. **Consistent Access Patterns**: Standardized way to access services and configs across client/server
3. **Refactoring Safety**: Changing paths only requires updating one file
4. **Dependency Management**: Clear visibility of what services depend on what

## Architecture Overview

```lua
local Locations = require(ReplicatedStorage.Shared.Locations)
```

### Main Categories

1. **Core Roblox Services** - Game engine services
2. **Project Structure** - Folder references 
3. **Configuration Files** - Game config access
4. **Game Services** - Custom service location mapping
5. **Asset Bridges** - UI/Asset management systems
6. **Player Functions** - Player-specific utilities

## Configuration System

### ConfigFiles Registry
```lua
Locations.ConfigFiles = {
    Game = "game",
    Currencies = "currencies", 
    Items = "items",
    Monetization = "monetization",
    Network = "network",
    Effects = "effects",
    UI = "ui",
    Pets = "pets",
    EggSystem = "egg_system"
}
```

### Configuration Access Pattern
```lua
-- Standard way to load configs
local petConfig = Locations.getConfig("Pets")
local eggSystemConfig = Locations.getConfig("EggSystem")
```

### How Configuration Loading Works

1. **ConfigLoader Integration**: `Locations.getConfig()` calls `ConfigLoader:LoadConfig()`
2. **File Mapping**: Config names map to ModuleScript objects in `ReplicatedStorage.Configs`
3. **Validation**: All configs are validated before being returned
4. **Caching**: Configs are cached for performance

## Service Registry System

### Service Location Mapping
```lua
Locations.Services = {
    -- Economy & Data
    EconomyService = "EconomyService",
    DataService = "DataService", 
    
    -- Egg System
    EggService = "EggService",
    EggSpawner = "EggSpawner",
    
    -- Effects & Global
    GlobalEffectsService = "GlobalEffectsService",
    // ... more services
}
```

### Service Access Pattern
```lua
-- Get a service instance
local economyService = Locations.getService("EconomyService")
local eggService = Locations.getService("EggService")
```

## Bridge System (UI/Asset Management)

### Bridge Registry
```lua
Locations.Bridges = {
    Monetization = "MonetizationBridge",
    Economy = "EconomyBridge",
    Social = "SocialBridge"
}
```

### Bridge Access
```lua
local monetizationBridge = Locations.getBridge("Monetization")
```

## Player Utilities

### Player-Specific Functions
```lua
-- Get player's GUI
local playerGui = Locations.getPlayerGui(player)

-- Get player's character
local character = Locations.getPlayerCharacter(player)
```

## Usage Patterns in Practice

### In Service Modules
```lua
-- Example: EggService.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locations = require(ReplicatedStorage.Shared.Locations)

local EggService = {}

function EggService:Initialize()
    -- Load configurations
    self.petsConfig = Locations.getConfig("Pets")
    self.eggSystemConfig = Locations.getConfig("EggSystem")
    
    -- Access other services if needed
    self.dataService = Locations.getService("DataService")
end
```

### In Client UI
```lua
-- Example: UI Component
local Locations = require(ReplicatedStorage.Shared.Locations)

local function createPetUI()
    local petsConfig = Locations.getConfig("Pets")
    local uiConfig = Locations.getConfig("UI")
    
    -- Build UI using config data
end
```

## Directory Structure Reference

### Server-Side (Only available on server)
```
Locations.Server
├── Locations.ServerServices
├── Locations.ServerSystems  
└── Locations.ServerMiddleware
```

### Client-Side (Only available on client)
```
Locations.ClientUI
├── Locations.ClientUIComponents
├── Locations.ClientUIScreens
└── Locations.ClientUIMenus
Locations.ClientControllers
Locations.ClientSystems
Locations.ClientEffects
```

### Shared (Available on both)
```
Locations.Shared
├── Locations.SharedLibraries
├── Locations.SharedUtils
├── Locations.SharedConstants
├── Locations.SharedNetwork
├── Locations.SharedState
├── Locations.SharedMatter
└── Locations.SharedServices
```

## Adding New Configurations

When adding a new configuration file:

1. **Create the config file** in `configs/new_config.lua`
2. **Register in Locations.lua**:
   ```lua
   Locations.ConfigFiles = {
       -- ... existing configs
       NewConfig = "new_config"
   }
   ```
3. **Use the standard access pattern**:
   ```lua
   local newConfig = Locations.getConfig("NewConfig")
   ```

## Adding New Services

When creating a new service:

1. **Create the service** in appropriate folder
2. **Register in Locations.lua**:
   ```lua
   Locations.Services = {
       -- ... existing services
       NewService = "NewService"
   }
   ```
3. **Access via standard pattern**:
   ```lua
   local newService = Locations.getService("NewService")
   ```

## Best Practices

### ✅ **DO:**
- Always use `Locations.getConfig()` for configuration access
- Register new services and configs in the appropriate registry
- Use `Locations.getService()` for service dependencies
- Follow the established naming conventions

### ❌ **DON'T:**
- Direct require of config modules (`require(ReplicatedStorage.Configs.pets)`)
- Hard-coded service paths
- Bypassing the Locations system for consistency

## Error Handling

### Common Issues and Solutions

**"Config 'X' not found"**
- Ensure config is registered in `Locations.ConfigFiles`
- Verify config file exists in `configs/` folder
- Check Rojo sync to ensure file is in `ReplicatedStorage.Configs`

**"Service 'X' not found"**
- Ensure service is registered in `Locations.Services`
- Verify service file exists and exports properly
- Check service initialization order

## Integration with ConfigLoader

The Locations system works closely with ConfigLoader:

1. **Locations** provides the registry and access methods
2. **ConfigLoader** handles file loading, validation, and caching
3. **Services** use Locations to access configs in a standardized way

This separation of concerns makes the system maintainable and testable.

## Migration Guide

If migrating from direct config access:

### Before:
```lua
local petsConfig = require(ReplicatedStorage.Configs.pets)
```

### After:
```lua
local Locations = require(ReplicatedStorage.Shared.Locations)
local petsConfig = Locations.getConfig("Pets")
```

This change provides validation, caching, and consistency with the rest of the codebase.