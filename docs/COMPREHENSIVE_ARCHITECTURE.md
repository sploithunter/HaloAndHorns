# Universal Roblox Game Template - Comprehensive Architecture Guide

## 🎯 Purpose
This document serves as the **single source of truth** for understanding the entire architecture of this Roblox game template. Point new developers (including AI assistants) to this document to understand the core principles, structure, and patterns used throughout the codebase.

---

## 🏗️ Four Core Tenets

This architecture is built on four fundamental principles that guide every design decision:

### 1. **Clear Separation of Code vs Models/Assets (Rojo Requirement)**
- **All code lives in the file system** and is synced via Rojo
- **Assets (.rbxmx files) are exported from Studio** to `/assets/` folder
- **No scripts embedded in models** - all logic is in dedicated ModuleScripts
- **Studio is used only for asset placement and export**

### 2. **Configuration as Code**
- **All game logic driven by Lua configuration files** in `/configs/`
- **Adding currencies, items, effects requires only config changes**
- **Network packets, bridges, and handlers auto-generated from config**
- **Specialty code injected at runtime based on configuration**

### 3. **Aggregate Properties Pattern**
- **Individual contributors stored separately** (e.g., luck potion, super luck gamepass)
- **Aggregates calculated and cached** in Player/Aggregates/ structure
- **Never store aggregates in ProfileStore** - only individual components
- **Real-time updates via NumberValue replication**

### 4. **ProfileStore Single Source of Truth**
- **All persistent game data stored in ProfileStore**
- **Handles session locking and data integrity**
- **Effects persist with exact time remaining across restarts**
- **Currency, inventory, and progression all ProfileStore-backed**

---

## 🛠️ Technology Stack

- **Rojo 7.5+**: File synchronization between VS Code/Cursor and Studio
- **Matter ECS**: Entity Component System for game logic (**via Wally**)
- **Reflex**: Redux-like state management (**via Wally**)  
- **ProfileStore**: Enterprise-grade data persistence with session locking (**via Wally**)
- **Wally**: Package manager for Roblox dependencies (**primary package manager**)
- **Custom Libraries**: ModuleLoader, Signals (sleittnick/Net), ConfigLoader, Locations

---

## 📁 Complete File Structure & Rojo Mapping

### File System Structure
```
GameTemplate1/
├── src/                          # All source code
│   ├── Client/                   # Client-side code only
│   │   ├── UI/                   # User interface components
│   │   │   ├── Components/       # Reusable UI elements (Button, Panel, etc.)
│   │   │   ├── Menus/            # Menu screens (AdminPanel, InventoryPanel)
│   │   │   └── Screens/          # Full screen UIs
│   │   ├── Controllers/          # Input, camera, UI controllers
│   │   ├── Systems/              # Client-side ECS systems
│   │   ├── Effects/              # Sound and visual effects
│   │   └── init.client.lua       # Client bootstrap
│   ├── Server/                   # Server-side code only
│   │   ├── Services/             # Core game services
│   │   │   ├── DataService.lua           # ProfileStore management
│   │   │   ├── EconomyService.lua        # Currency and purchases
│   │   │   ├── PlayerEffectsService.lua  # Folder-based effects
│   │   │   ├── EggService.lua            # Egg spawning and management
│   │   │   └── MonetizationService.lua   # Robux purchases
│   │   ├── Systems/              # Server-side ECS systems
│   │   ├── Middleware/           # Rate limiting, validation
│   │   └── init.server.lua       # Server bootstrap
│   └── Shared/                   # Code that runs on both sides
│       ├── Libraries/            # Manual utilities (Signal, Maid, Sift - minor packages)
│       ├── Matter/               # ECS components and systems
│       │   ├── Components/       # Data-only component definitions
│       │   └── Systems/          # Shared ECS systems
│       ├── State/                # Reflex producers and selectors
│       ├── Network/              # Networking bridge and packets
│       ├── Constants/            # Game constants and enums
│       ├── Services/             # Shared services (EggSpawner, etc.)
│       ├── Utils/                # Utilities and helpers
│       ├── ConfigLoader.lua      # Configuration management
│       └── Locations.lua         # Service locator (CRITICAL for portability)
├── configs/                      # Configuration as Code
│   ├── game.lua                  # Game mode and settings
│   ├── currencies.lua            # Currency definitions
│   ├── items.lua                 # Item catalog with effects
│   ├── pets.lua                  # Pet definitions and egg systems
│   ├── monetization.lua          # Robux products and pricing
│   ├── network.lua               # Auto-generated networking config
│   └── ui.lua                    # UI component configurations
├── assets/                       # Studio-exported assets
│   ├── Models/                   # .rbxmx model files (static assets)
│   ├── UI/                       # UI layouts and images
│   └── Audio/                    # Sound files
├── tests/                        # TestEZ test suites
├── docs/                         # Documentation
└── default.project.json          # Rojo configuration (maps filesystem to Roblox)
```

### Rojo Mapping (`default.project.json`)
```json
{
  "tree": {
    "ServerScriptService": {
      "Server": { "$path": "src/Server" }           # Server code → ServerScriptService
    },
    "ReplicatedStorage": {
      "Shared": { "$path": "src/Shared" },          # Shared code → ReplicatedStorage
      "Packages": { "$path": "Packages" },          # Wally packages (Matter, Reflex, ProfileStore, etc.)
      "Assets": { "$path": "assets" },              # Static assets
      "Configs": { "$path": "configs" }             # Configuration files
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "Client": { "$path": "src/Client" }         # Client code → StarterPlayerScripts
      }
    }
  }
}
```

**How Rojo Works:**
1. Developer writes code in VS Code/Cursor in filesystem
2. Rojo syncs files to Roblox Studio in real-time
3. Studio only used for asset placement, testing, and export
4. All code changes happen in filesystem, never in Studio

---

## 📦 Package Management Strategy

### Wally-First Approach ✅
This project **uses Wally as the primary package manager**:

**Wally-Managed Packages** (`Packages/_Index/`):
- `TestEZ` - Testing framework  
- `Promise` - Promise implementation
- `Matter` - ECS framework (**migrated!**)
- `Reflex` - State management (**migrated!**)
- `ProfileStore` - Data persistence (**migrated!**)

**Still Manually-Managed** (`src/Shared/Libraries/`):
- `Signal` - Event system
- `Maid` - Memory management  
- `Sift` - Utility library

### Package Access Pattern
**ALL package access goes through Locations.lua:**

```lua
local Locations = require(ReplicatedStorage.Shared.Locations)

-- Wally packages via Locations
local Matter = Locations.getPackage("Matter")
local Reflex = Locations.getPackage("Reflex")
local ProfileStore = Locations.getPackage("ProfileStore")
local TestEZ = Locations.getPackage("TestEZ")

-- Manual libraries via Locations
local Signal = Locations.getLibrary("Signal")
local Maid = Locations.getLibrary("Maid")

-- Core utilities via Locations
local Logger = require(Locations.Logger)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local ConfigLoader = require(Locations.ConfigLoader)
```

### Wally Success Story (With Workarounds)
Originally, Wally had reliability issues during initial setup, so the project moved to manual package management. We've successfully migrated back to Wally, but **some packages need workarounds** due to Wally generation issues:

**✅ Working Packages:**
- `TestEZ`, `Promise`, `Reflex`, `ProfileStore` - Use standard Wally generation

**⚠️ Packages with Workarounds:**
- `Matter` - Uses nested structure requiring direct path: `_Index["matter-ecs_matter@0.8.5"]["matter"]["lib"]`

The Locations.lua `getPackage()` function handles these workarounds transparently, so the API remains consistent while dealing with Wally's quirks under the hood.

---

## 🎯 Locations.lua: Service Locator for Portability

**File**: `src/Shared/Locations.lua`

### Purpose
The Locations module is the **backbone of the entire architecture**. It provides:
- **Single source of truth** for all service and asset locations
- **Consistent access patterns** across client/server
- **Refactoring safety** - change paths in one place
- **Dependency management** - clear visibility of service dependencies

### Core Pattern
```lua
local Locations = require(ReplicatedStorage.Shared.Locations)

-- Get services through Locations (uses ModuleLoader internally)
local economyService = Locations.getService("EconomyService")

-- Get configurations through Locations (uses ConfigLoader internally)
local petConfig = Locations.getConfig("pets")

-- Access Roblox services through Locations
local players = Locations.Players
local workspace = Locations.Workspace
```

### Complete Registry System

**Services:**
```lua
Locations.Services = {
    DataService = "DataService",
    EconomyService = "EconomyService", 
    PlayerEffectsService = "PlayerEffectsService"
}
// Access: Locations.getService("EconomyService")
```

**Wally Packages:**
```lua
Locations.PackageFiles = {
    Matter = "Matter",
    Reflex = "Reflex",
    ProfileStore = "ProfileStore",
    TestEZ = "TestEZ",
    Promise = "Promise"
}
// Access: Locations.getPackage("Matter")
```

**Manual Libraries:**
```lua
Locations.Libraries = {
    Maid = "Maid",
    Signal = "Signal", 
    Sift = "Sift"
}
// Access: Locations.getLibrary("Maid")
```

**Configurations:**
```lua
Locations.ConfigFiles = {
    Game = "game",
    Currencies = "currencies", 
    Items = "items",
    Pets = "pets"
}
// Access: Locations.getConfig("Pets")
```

### Why This Matters
- **Portability**: Services can be moved without breaking dependencies
- **Consistency**: Same access pattern everywhere
- **Testing**: Easy to mock services in tests
- **Refactoring**: Change once, works everywhere

---

## 🔧 Configuration as Code Deep Dive

### Philosophy
**Everything that might change should be configuration, not code.**

### Configuration Structure
```lua
-- configs/items.lua example
return {
    speed_potion = {
        id = "speed_potion",
        displayName = "⚡ Speed Potion",
        description = "Increases movement speed by 50% for 5 minutes",
        type = "consumable",
        rarity = "common",
        price = {currency = "gems", amount = 5},
        effects = {"speed_boost"},
        icon = "rbxassetid://123456789",
        stackable = true,
        maxStack = 10
    }
}
```

### Auto-Generated Systems
The configuration drives:
- **Network packet creation** (configs/network.lua)
- **UI button generation** (configs/ui.lua) 
- **Economy item validation**
- **Effect application logic**

### Adding New Features
```lua
-- Add new currency in configs/currencies.lua - NO CODE CHANGES
{
    id = "crystals",
    name = "Crystals",
    icon = "💎", 
    maxAmount = 50000,
    canPurchase = true,
    exchangeRate = {from = "coins", rate = 100}
}
```

The system automatically:
- Creates UI displays
- Handles transactions
- Validates purchases
- Persists in ProfileStore

---

## 🎮 Model Management: Static vs Dynamic

### Static Models (Fixed Assets)
**Purpose**: Environmental assets, UI layouts, fixed game objects
**Workflow**:
1. Create/import model in Roblox Studio
2. Position and configure in workspace
3. Export via Studio → "Save to Roblox" → Download as .rbxmx
4. Place .rbxmx file in `/assets/Models/`
5. Reference in code: `Locations.ReplicatedStorage.Assets.Models.MyModel`

**Example Usage**:
```lua
-- Loading a static model
local shopModel = Locations.ReplicatedStorage.Assets.Models.ShopBuilding
local shopClone = shopModel:Clone()
shopClone.Parent = workspace
```

### Dynamic Models (Asset ID System)
**Purpose**: Player items, pets, eggs, vehicles - things spawned at runtime
**Workflow**:
1. Create model in Studio or import from catalog
2. Upload to Roblox as asset (Right-click → "Save to Roblox")
3. Get asset ID from upload
4. Add asset ID to configuration file
5. Spawn via service at runtime

**Example - Pet System**:
```lua
-- configs/pets.lua
bear = {
    variants = {
        basic = {
            asset_id = "rbxassetid://102676279378350",
            display_name = "Bear",
            power = 10
        },
        golden = {
            asset_id = "rbxassetid://107758879638540", 
            display_name = "Golden Bear",
            power = 50
        }
    }
}
```

**Runtime Spawning**:
```lua
-- src/Shared/Services/EggSpawner.lua
function EggSpawner:SpawnEgg(eggType, position, spawnPoint)
    local eggData = petConfig.egg_sources[eggType]
    local assetId = eggData.egg_model_asset_id
    
    -- Load model from asset ID
    local eggModel = InsertService:LoadAsset(tonumber(assetId:match("%d+")))
    local egg = eggModel:FindFirstChildOfClass("Model")
    
    -- Position and setup
    egg.Parent = workspace
    egg:SetPrimaryPartCFrame(CFrame.new(position))
    
    -- Add metadata
    local eggInfo = Instance.new("StringValue")
    eggInfo.Name = "EggType"
    eggInfo.Value = eggType
    eggInfo.Parent = egg
end
```

### When to Use Which
- **Static Models**: Lobby areas, spawn points, decorative items, UI layouts
- **Dynamic Models**: Player inventory items, pets, collectibles, purchasable items

---

## 📊 Data Architecture: ProfileStore + Effects System

### ProfileStore Pattern
```lua
-- Profile template structure
{
    Currencies = {
        coins = 100,
        gems = 0,
        crystals = 0
    },
    Inventory = {
        -- Items with quantities
        speed_potion = {quantity = 3, lastUsed = 0}
    },
    ActiveEffects = {
        -- Individual effect instances (NOT aggregates)
        speed_boost = {
            timeRemaining = 180,  -- Exact seconds left
            appliedAt = 1234567890,
            multiplier = 1.5
        }
    },
    Statistics = {
        PlayTime = 0,
        JoinDate = 1234567890,
        Level = 1
    }
}
```

### Effects System Architecture
**Folder-Based Real-Time Updates**:
```
Player/
├── TimedBoosts/              # Individual effect instances
│   ├── speed_boost/          # Effect folder
│   │   ├── timeRemaining     # IntValue (auto-replicates to client)
│   │   ├── multiplier        # NumberValue
│   │   ├── description       # StringValue
│   │   └── icon              # StringValue
│   └── luck_potion/          # Another effect
└── Aggregates/               # Calculated totals (NEVER stored in ProfileStore)
    ├── speedMultiplier       # NumberValue: 1.5 (+50%)
    ├── luckBoost             # NumberValue: 0.25 (+25%)
    └── damageBoost           # NumberValue: 1.1 (+10%)
```

**Key Benefits**:
- ✅ **Real-time client updates** via native replication (no RemoteEvents)
- ✅ **Perfect persistence** - exact time remaining saved/restored
- ✅ **Aggregate calculation** from individual components
- ✅ **Configurable stacking** (extend, reset, or stack)

---

## 🌐 Network Architecture

### Configuration-Driven Networking
```lua
-- configs/network.lua (auto-generates bridges)
return {
    Economy = {
        PurchaseItem = {
            rateLimit = 30,  -- Per minute
            validator = "itemPurchaseValidator"
        },
        SellItem = {
            rateLimit = 60,
            validator = "itemSellValidator"  
        }
    },
    Social = {
        SendFriendRequest = {
            rateLimit = 10,
            validator = "friendRequestValidator"
        }
    }
}
```

### Auto-Generated Bridge Usage
```lua
-- Server-side handler
local economyBridge = Locations.getBridge("Economy")
economyBridge:Connect(function(player, packetType, data)
    if packetType == "PurchaseItem" then
        EconomyService:PurchaseItem(player, data.itemId)
    elseif packetType == "SellItem" then
        EconomyService:SellItem(player, data.itemId, data.quantity)
    end
end)
```

---

## 🎯 Core Systems Integration

### Module Loading with Dependency Injection
```lua
-- Server initialization (src/Server/init.server.lua)
local loader = ModuleLoader.new()

-- Register services with dependencies
loader:RegisterModule("Logger", path, {})
loader:RegisterModule("DataService", path, {"Logger", "ConfigLoader"})
loader:RegisterModule("EconomyService", path, {"DataService", "Logger"})

-- Automatic dependency resolution and loading
local loadOrder = loader:LoadAll()
```

### Service Pattern
```lua
local MyService = {}
MyService.__index = MyService

function MyService:Init()
    -- Get injected dependencies
    self._logger = self._modules.Logger
    self._dataService = self._modules.DataService
    -- Setup but don't start operations
end

function MyService:Start()
    -- Begin operations after all services initialized
    self._logger:Info("MyService started")
end

return MyService
```

---

## 🚀 Development Workflow

### 1. Configuration First
- Define new features in configs before coding
- Use ConfigLoader for all game data
- Validate configs on server start

### 2. Rojo Development Cycle
```bash
# Start Rojo server
rojo serve --port 34872

# In Studio: Connect to localhost:34872
# Make code changes in VS Code/Cursor
# Changes sync automatically to Studio
# Test in Studio, iterate in code editor
```

### 3. Asset Management
- **Static assets**: Place in Studio → Export to `/assets/`
- **Dynamic assets**: Upload to Roblox → Get asset ID → Add to config

### 4. Adding New Systems
1. Create configuration in `/configs/`
2. Register service in `Locations.Services`
3. Implement service with Init/Start pattern
4. Register in ModuleLoader with dependencies
5. Test and document

---

## 🔒 Security Architecture

### Server Authority Principle
- **All game state lives on server**
- **Client predictions validated server-side**
- **Never trust client-reported values**

### Rate Limiting
```lua
-- Per-action limits from configuration
bridge:DefinePacket("PurchaseItem", {
    rateLimit = 30,  -- 30 per minute
    validator = function(data)
        return type(data.itemId) == "string" and
               data.itemId:match("^[a-z_]+$")
    end
})
```

### Data Validation
- All network packets validated against schemas
- Currency transactions use atomic operations
- Effect configurations validated on startup

---

## 📈 Game Mode Support

The architecture supports multiple game genres via configuration:

### Current Focus: Simulator Mode
```lua
-- configs/game.lua
{
    GameMode = "Simulator",  -- "Simulator", "FPS", "TowerDefense"
    MaxPlayers = 20,
    EnableTrading = true,
    EnablePvP = false
}
```

### Extensible Systems
- **Matter ECS**: Add game-mode specific systems
- **Configuration**: Drive game mode logic via configs
- **Networking**: Auto-adapt based on game mode requirements

---

## 🛡️ Best Practices

### Code Organization
- **One service per feature domain**
- **Shared utilities in `/src/Shared/Utils/`**
- **Game-specific logic in configurations**
- **Use Locations.lua for all service access**

### Error Handling
```lua
-- Always use structured logging
self._logger:Info("Purchase completed", {
    player = player.Name,
    itemId = itemId,
    price = price,
    newBalance = newBalance
})

-- Wrap external calls
local success, result = pcall(function()
    return DataService:SaveProfile(player)
end)
if not success then
    self._logger:Error("Profile save failed", {error = result})
end
```

### Memory Management
- Use Maid pattern for cleanup
- Object pooling for frequently created entities
- Aggregate caching for fast lookups

---

## 🔮 Quick Reference

### Essential Files to Understand
1. **`src/Shared/Locations.lua`** - Service locator, access patterns
2. **`src/Shared/ConfigLoader.lua`** - Configuration management
3. **`src/Server/Services/DataService.lua`** - ProfileStore integration
4. **`src/Server/Services/PlayerEffectsService.lua`** - Effects system
5. **`default.project.json`** - Rojo mapping

### Key Commands
```bash
# Start development
rojo serve --port 34872

# Install Wally dependencies (Matter, Reflex, ProfileStore, etc.)
wally install

# Run tests (in Studio)
# Execute tests/TestBootstrap.lua
```

### Configuration Files Priority
1. **`configs/game.lua`** - Core game settings
2. **`configs/currencies.lua`** - Economy foundation
3. **`configs/items.lua`** - Item catalog
4. **`configs/pets.lua`** - Pet/egg systems
5. **`configs/network.lua`** - Auto-generated networking

---

## 📋 Session Onboarding Checklist

When starting a new session, ensure understanding of:
- [ ] Four core tenets (separation, config-driven, aggregates, ProfileStore)
- [ ] Locations.lua service locator pattern
- [ ] Static vs dynamic model management
- [ ] Configuration-driven development approach
- [ ] Rojo workflow and file structure mapping
- [ ] Effects system architecture (individual + aggregates)
- [ ] Service pattern with dependency injection
- [ ] ProfileStore data structure and persistence

**This document is the single source of truth for the architecture. All development should align with these principles.**