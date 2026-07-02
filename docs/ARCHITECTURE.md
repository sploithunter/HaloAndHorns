# Universal Roblox Game Template – Architecture

## Overview

This template provides a production-ready, configuration-driven foundation for building scalable Roblox games. The architecture follows four core tenants and uses modern frameworks for reliable, maintainable game development.

## 🏗️ Core Tenants

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

## 🛠️ Tech Stack

- **Rojo 7.5+**: File synchronization between VS Code/Cursor and Studio
- **Matter ECS**: Entity Component System (prepared for game-specific systems)
- **Reflex**: Redux-like state management (prepared for advanced state)
- **ProfileStore**: Enterprise-grade data persistence with session locking
- **Wally**: Package manager for Roblox dependencies
- **Custom Libraries**: ModuleLoader, Signals (sleittnick/Net), ConfigLoader

---

## 📁 Project Structure

```
GameTemplate1/
├── src/
│   ├── Client/                 # Client-side code only
│   │   ├── UI/                # User interface components
│   │   │   ├── Components/    # Reusable UI elements
│   │   │   └── Screens/       # Full screen UIs
│   │   ├── Controllers/       # Input, camera, UI controllers
│   │   ├── Systems/           # Client-side ECS systems
│   │   ├── Effects/           # Sound and visual effects
│   │   └── init.client.lua    # Client bootstrap
│   ├── Server/                # Server-side code only
│   │   ├── Services/          # Core game services
│   │   │   ├── DataService.lua         # ProfileStore management
│   │   │   ├── EconomyService.lua      # Currency and purchases
│   │   │   ├── PlayerEffectsService.lua # Folder-based effects
│   │   │   └── GlobalEffectsService.lua # Server-wide effects
│   │   ├── Systems/           # Server-side ECS systems
│   │   ├── Middleware/        # Rate limiting, validation
│   │   └── init.server.lua    # Server bootstrap
│   └── Shared/                # Code that runs on both sides
│       ├── Libraries/         # External packages (Wally)
│       ├── Matter/            # ECS components and systems
│       ├── State/             # Reflex producers and selectors
│       ├── Network/           # Networking bridge and packets
│       ├── Constants/         # Game constants and enums
│       ├── Utils/             # Utilities and helpers
│       └── ConfigLoader.lua   # Configuration management
├── configs/                   # Configuration as Code
│   ├── game.lua              # Game mode and settings
│   ├── currencies.lua        # Currency definitions
│   ├── items.lua             # Item catalog with effects
│   ├── ratelimits.lua        # Effects and rate limit config
│   └── network.lua           # Auto-generated networking
├── assets/                   # Studio-exported assets
│   ├── Models/               # .rbxmx model files
│   ├── UI/                   # UI layouts and images
│   └── Audio/                # Sound files
├── tests/                    # TestEZ test suites
└── docs/                     # Documentation
```

---

## 🔄 Core Systems Architecture

### 1. Module Loading System
**File**: `src/Shared/Utils/ModuleLoader.lua`

- **Dependency injection** with topological sorting
- **Prevents circular dependencies**
- **Lazy loading** for heavy services
- **Init/Start lifecycle** for proper initialization order

```lua
-- Registration with dependencies
loader:RegisterModule("DataService", path, {"Logger", "ConfigLoader"})
loader:RegisterModule("EconomyService", path, {"DataService", "NetworkConfig"})

-- Automatic dependency resolution
local loadOrder = loader:LoadAll()
```

### 2. Configuration-Driven Architecture
**File**: `src/Shared/ConfigLoader.lua`

- **Lua configuration files** for all game data
- **Hot-reloading** capability (prepared)
- **Environment-specific configs** (dev/prod)
- **Validation and fallbacks**

```lua
-- Adding new currency (configs/currencies.lua)
{
    id = "crystals",
    name = "Crystals", 
    icon = "💎",
    maxAmount = 50000,
    canPurchase = true
}

-- Automatic integration - no code changes needed
local currencies = ConfigLoader:LoadConfig("currencies")
```

### 3. Player Effects System
**File**: `src/Server/Services/PlayerEffectsService.lua`

**Folder-Based Architecture** for real-time updates:
```
Player/
├── TimedBoosts/           # Individual effect instances
│   ├── speed_boost/       # Effect folder
│   │   ├── timeRemaining  # IntValue
│   │   ├── multiplier     # NumberValue
│   │   ├── description    # StringValue
│   │   └── icon           # StringValue
│   └── luck_potion/       # Another effect
└── Aggregates/            # Calculated totals
    ├── speedMultiplier    # NumberValue: 1.5 (+50%)
    ├── luckBoost          # NumberValue: 0.25 (+25%)
    └── damageBoost        # NumberValue: 1.1 (+10%)
```

**Key Features**:
- ✅ **Real-time client updates** via native replication
- ✅ **Perfect persistence** - exact time remaining saved/restored
- ✅ **Configurable stacking** (extend, reset, or stack)
- ✅ **Aggregate calculation** from individual components
- ✅ **No network calls** - uses Roblox's built-in replication

### 4. Economy System
**File**: `src/Server/Services/EconomyService.lua`

- **Multi-currency support** (coins, gems, crystals)
- **Transaction logging** with rollback capability
- **Rate limiting** integration
- **ProfileStore persistence**

```lua
-- Purchase with automatic validation
EconomyService:PurchaseItem(player, "speed_potion")
-- Applies effect, deducts currency, logs transaction
```

### 5. Data Persistence
**File**: `src/Server/Services/DataService.lua`

**ProfileStore Integration**:
- **Session locking** prevents data corruption
- **Data reconciliation** handles template updates
- **Atomic operations** for currency transactions
- **Effect persistence** with time-accurate restoration

```lua
-- Profile template
{
    Currencies = {coins = 100, gems = 0},
    Inventory = {},
    ActiveEffects = {
        speed_boost = {
            timeRemaining = 180,  -- Exact seconds left
            appliedAt = 1234567890
        }
    },
    Statistics = {PlayTime = 0, JoinDate = 1234567890}
}
```

### 6. Networking System
**Network Layer**: Signals registry (`src/Shared/Network/Signals.lua`)

**Configuration-Driven Networking**:
- **Packet definitions in config** auto-generate bridges
- **Rate limiting per packet type**
- **Automatic validation** from config schemas
- **Bridge creation** from network.lua configuration

```lua
-- configs/network.lua defines everything
Economy = {
    PurchaseItem = {rateLimit = 30, validator = "itemPurchaseValidator"},
    SellItem = {rateLimit = 60, validator = "itemSellValidator"}
}

-- Auto-generated bridge and handlers
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
economyBridge:Connect(function(player, packetType, data)
    -- Handles PurchaseItem, SellItem automatically
end)
```

---

## 🎯 Data Flow Architecture

### Purchase Flow Example
```
1. Client clicks "Buy Speed Potion"
2. Signals layer validates packet + rate limit
3. EconomyService validates currency + item exists
4. DataService performs atomic currency deduction
5. PlayerEffectsService applies effect with aggregates
6. ProfileStore saves new currency + active effects
7. Client receives real-time effect via folder replication
8. UI updates automatically from Player/Aggregates values
```

### Effect Aggregation Flow
```
1. Multiple effects applied: luck_potion (+10%), vip_pass (+25%), event_boost (+15%)
2. Individual effects stored in Player/TimedBoosts/
3. Aggregates calculated: luckBoost = 0.1 + 0.25 + 0.15 = 0.5
4. Player/Aggregates/luckBoost.Value = 0.5
5. Client reads NumberValue for real-time luck display
6. Only individual effects saved to ProfileStore (not aggregates)
```

---

## 🚀 Game Mode Support

The architecture supports multiple game genres via configuration:

### Current Implementation
```lua
-- configs/game.lua
{
    GameMode = "Simulator",  -- "Simulator", "FPS", "TowerDefense"
    MaxPlayers = 20,
    EnableTrading = true,
    EnablePvP = false
}
```

### Planned Extensions

**FPS Mode**:
- Weapon components and damage systems
- Client prediction for shooting
- Respawn and team management

**Tower Defense Mode**:
- Wave spawning systems
- Path finding for enemies
- Tower placement validation

**Simulator Mode** (Current Focus):
- Resource collection with rate limiting
- Pet systems with stat bonuses
- Prestige and progression systems

---

## 🛡️ Security Architecture

### 1. Server Authority
- **All game state lives on server**
- **Client predictions validated server-side**
- **Never trust client-reported values**

### 2. Rate Limiting
**File**: `src/Server/Services/RateLimitService.lua`
- **Per-action limits** configurable
- **Effect-based multipliers** (VIP gets faster rates)
- **Burst protection** and exponential backoff

### 3. Data Validation
- **All network packets validated** against schemas
- **Currency transaction atomic operations**
- **Effect configuration validation**

### 4. Anti-Exploit Measures
- **ProfileStore session locking**
- **Server-side effect calculations**
- **Audit logging** for suspicious behavior

---

## ⚡ Performance Architecture

### 1. Memory Management
- **Object pooling** for frequently created entities
- **Maid pattern** for cleanup
- **Aggregate caching** for fast lookups

### 2. Network Optimization
- **Batch effect updates** every 30 seconds
- **Native replication** instead of RemoteEvents
- **Compressed packet formats**

### 3. ECS Performance
- **Matter optimizations** for large entity counts
- **System ordering** for frame time distribution
- **Query caching** for hot code paths

---

## 🔧 Extension Points

### Adding New Currency
1. Add to `configs/currencies.lua`
2. Update ProfileStore template
3. No code changes required

### Adding New Effect
1. Define in `configs/ratelimits.lua`
2. Configure stat modifiers and stacking
3. Auto-integrated with all systems

### Adding New Item
1. Add to `configs/items.lua` with effects list
2. Specify price, rarity, requirements
3. EconomyService handles automatically

### Adding New Game Mode
1. Update `configs/game.lua`
2. Add mode-specific Matter systems
3. Bootstrap logic in `init.server.lua`

---

## 🧪 Testing Strategy

### 1. Unit Tests
- **TestEZ framework** for service testing
- **Mock data providers** for isolated testing
- **Configuration validation** tests

### 2. Integration Tests
- **Multi-player simulation** in Studio
- **Effect persistence** across server restarts
- **Economy transaction** atomicity

### 3. Performance Tests
- **Frame time monitoring** with MicroProfiler
- **Memory leak detection**
- **Network bandwidth** measurement

---

## 📋 Development Workflow

### 1. Configuration First
- **Define new features in configs** before coding
- **Use ConfigLoader** for all game data
- **Validate configs** on server start

### 2. Service Pattern
```lua
local MyService = {}
MyService.__index = MyService

function MyService:Init()
    -- Get dependencies, setup but don't start
end

function MyService:Start() 
    -- Begin operations after all services initialized
end
```

### 3. Effect Integration
- **Use PlayerEffectsService** for temporary bonuses
- **Define in ratelimits.lua** with stat modifiers
- **Aggregate calculation** automatic

### 4. Network Protocol
- **Define packets in network.lua**
- **Auto-generated bridges** and validation
- **Rate limiting** built-in

---

## 🔮 Future Roadmap

### Phase 1: Core Completion
- [ ] Matter ECS system implementations
- [ ] Advanced UI component system
- [ ] Trading system with escrow

### Phase 2: Genre Expansion  
- [ ] FPS game mode with weapons
- [ ] Tower Defense with pathfinding
- [ ] Advanced progression systems

### Phase 3: Platform Features
- [ ] Cross-server messaging
- [ ] Analytics integration
- [ ] Monetization optimization

---

This architecture provides a solid foundation that scales from simple simulators to complex multiplayer games while maintaining the four core tenants of clear separation, configuration-driven development, aggregate properties, and ProfileStore authority. 