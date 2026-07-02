# General Guidelines & Best Practices

## 🎯 Philosophy

### Core Principles
- **Configuration-Driven**: Use configs over hardcoded values
- **Modular Architecture**: Each system should be independent and testable
- **Defensive Programming**: No silent failures, comprehensive error handling
- **Performance-First**: Profile early and often, optimize bottlenecks
- **Security-Minded**: Never trust client input, validate everything

### Four Core Tenants Compliance
1. **Code/Asset Separation**: All code in filesystem, assets exported from Studio
2. **Configuration as Code**: Game logic driven by `/configs/` files
3. **Aggregate Properties**: Individual contributors, calculated totals
4. **ProfileStore Authority**: Single source of truth for persistent data

---

## 📂 Code Organization

### Services (Server-side)
**Location**: `src/Server/Services/`
**Pattern**: One service per feature domain
**Lifecycle**: Init → Start pattern with dependency injection

```lua
local MyService = {}
MyService.__index = MyService

function MyService:Init()
    -- Get dependencies from self._modules
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    -- Setup but don't start operations
end

function MyService:Start()
    -- Begin operations after all services initialized
end

return MyService
```

### Components (Matter ECS)
**Location**: `src/Shared/Matter/Components/`
**Pattern**: Data-only structures, no methods

```lua
local Matter = require(game.ReplicatedStorage.Shared.Libraries.Matter)

local Health = Matter.component("Health", {
    current = 100,
    max = 100,
    regeneration = 0
})

return Health
```

### Systems (Matter ECS)
**Location**: `src/Shared/Matter/Systems/` or `src/Server/Systems/`
**Pattern**: Pure functions that operate on components

```lua
local function healthRegenerationSystem(world, deltaTime)
    for id, health in world:query(Components.Health) do
        if health.regeneration > 0 and health.current < health.max then
            health.current = math.min(
                health.max,
                health.current + health.regeneration * deltaTime
            )
        end
    end
end

return healthRegenerationSystem
```

### Configuration Files
**Location**: `/configs/`
**Pattern**: Lua tables with structured data

```lua
-- configs/items.lua
return {
    {
        id = "speed_potion",
        name = "⚡ Speed Potion",
        type = "consumable",
        price = {currency = "gems", amount = 5},
        effects = {"speed_boost"},
        description = "Increases movement speed by 50% for 5 minutes"
    }
}
```

---

## 🏗️ Architectural Patterns

### 1. Service Pattern (Server)
**Use For**: Core game functionality, business logic
**Dependencies**: Injected via ModuleLoader
**Lifecycle**: Init() for setup, Start() for operations

```lua
-- Registration in init.server.lua
loader:RegisterModule("EconomyService", path, {"DataService", "NetworkBridge"})
```

### 2. Controller Pattern (Client)
**Use For**: Input handling, UI management, client-side logic
**Dependencies**: Similar to services but client-focused

### 3. Configuration Pattern
**Use For**: All game data that might change
**Benefits**: No code changes needed for game tuning

```lua
-- Add new currency without touching code
local currencies = ConfigLoader:LoadConfig("currencies")
local newCurrency = {
    id = "crystals",
    name = "Crystals", 
    icon = "💎",
    maxAmount = 50000
}
```

### 4. Effect Aggregation Pattern
**Use For**: Player bonuses, multipliers, temporary effects
**Storage**: Individual effects in ProfileStore, aggregates calculated

```lua
-- Individual effects stored
data.ActiveEffects = {
    speed_boost = {timeRemaining = 180},
    luck_potion = {timeRemaining = 240}
}

-- Aggregates calculated and cached
Player/Aggregates/speedMultiplier.Value = 1.5  -- +50%
Player/Aggregates/luckBoost.Value = 0.25       -- +25%
```

### 5. Folder-Based Replication Pattern
**Use For**: Real-time data that needs client visibility
**Benefits**: No network calls, automatic replication

```lua
-- Server creates structure
Player/TimedBoosts/speed_boost/timeRemaining.Value = 180
-- Client automatically receives updates via replication
```

---

## 🔧 Naming Conventions

### Files and Modules
- **Services**: `<Feature>Service.lua` (e.g., `DataService.lua`)
- **Controllers**: `<Feature>Controller.lua` (e.g., `InputController.lua`)
- **Components**: `<Type>.lua` (e.g., `Health.lua`, `Transform.lua`)
- **Systems**: `<Action>System.lua` (e.g., `MovementSystem.lua`)
- **UI Screens**: `<Screen>Screen.lua` (e.g., `InventoryScreen.lua`)

### Variables and Functions
- **Functions**: `PascalCase` for public, `_camelCase` for private
- **Variables**: `camelCase` for local, `PascalCase` for config keys
- **Constants**: `UPPER_SNAKE_CASE`
- **Events**: `On<Event>` (e.g., `OnPlayerJoined`)

### Configuration Keys
- **Config Files**: `snake_case.lua`
- **Config Keys**: `PascalCase` for sections, `camelCase` for values
- **IDs**: `snake_case` (e.g., `speed_boost`, `health_potion`)

---

## ⚡ Performance Guidelines

### 1. Memory Management
```lua
-- Use object pooling for frequently created objects
local bulletPool = ObjectPool.new(function()
    return Instance.new("Part")
end)

-- Always clean up connections
local maid = Maid.new()
maid:GiveTask(event:Connect(handler))
-- maid:DoCleaning() when done
```

### 2. Network Optimization
```lua
-- Batch similar operations
local updates = {}
for player in pairs(players) do
    table.insert(updates, {player = player, currency = getCurrency(player)})
end
networkBridge:FireAll("CurrencyBatch", updates)

-- Use rate limiting
bridge:DefinePacket("PurchaseItem", {
    rateLimit = 30,  -- 30 per minute
    validator = validatePurchase
})
```

### 3. ECS Performance
```lua
-- Query optimization - store queries
local healthQuery = world:query(Components.Health, Components.Alive)

function healthSystem(world, deltaTime)
    for id, health, alive in healthQuery do
        -- Process health regeneration
    end
end
```

### 4. Configuration Performance
```lua
-- Cache frequently accessed configs
local itemsCache = nil
function getItemConfig(itemId)
    if not itemsCache then
        itemsCache = ConfigLoader:LoadConfig("items")
    end
    return itemsCache[itemId]
end
```

---

## 🛡️ Security Best Practices

### 1. Server Authority
```lua
-- ❌ WRONG - Trust client position
function teleportPlayer(player, position)
    player.Character.HumanoidRootPart.CFrame = CFrame.new(position)
end

-- ✅ CORRECT - Validate and sanitize
function teleportPlayer(player, position)
    if not isValidPosition(position) then
        logger:Warn("Invalid teleport position", {player = player.Name, position = position})
        return false
    end
    
    if not canPlayerTeleport(player) then
        logger:Info("Player cannot teleport", {player = player.Name, reason = "cooldown"})
        return false
    end
    
    player.Character.HumanoidRootPart.CFrame = CFrame.new(position)
    return true
end
```

### 2. Input Validation
```lua
-- Network packet validation
bridge:DefinePacket("PurchaseItem", {
    rateLimit = 30,
    validator = function(data)
        return type(data.itemId) == "string" and
               data.itemId:match("^[a-z_]+$") and  -- Only lowercase and underscores
               #data.itemId <= 50                  -- Reasonable length limit
    end
})
```

### 3. Rate Limiting
```lua
-- Service-level rate limiting
function EconomyService:PurchaseItem(player, itemId)
    if not self._rateLimitService:CheckLimit(player, "PurchaseItem") then
        self._logger:Warn("Purchase rate limit exceeded", {player = player.Name})
        return false
    end
    
    -- Process purchase
end
```

### 4. Data Sanitization
```lua
-- Always sanitize user input
function processPlayerName(input)
    local sanitized = input:gsub("[^%w%s]", "")  -- Remove special characters
    sanitized = sanitized:sub(1, 20)            -- Limit length
    return sanitized
end
```

---

## 🧪 Testing Patterns

### 1. Unit Testing
```lua
-- tests/unit/EconomyService.spec.lua
return function()
    describe("EconomyService", function()
        it("should deduct currency on purchase", function()
            local mockData = {Currencies = {coins = 100}}
            local result = EconomyService:_processPurchase(mockData, "test_item", 50)
            
            expect(result).to.equal(true)
            expect(mockData.Currencies.coins).to.equal(50)
        end)
    end)
end
```

### 2. Integration Testing
```lua
-- Test with real services
function testPurchaseFlow()
    local player = createMockPlayer()
    DataService:LoadProfile(player)
    
    local success = EconomyService:PurchaseItem(player, "test_item")
    expect(success).to.equal(true)
    
    local profile = DataService:GetProfile(player)
    expect(profile.Data.Currencies.coins).to.equal(50)
end
```

### 3. Performance Testing
```lua
-- Profile system performance
local startTime = tick()
for i = 1, 1000 do
    EconomyService:CalculateItemPrice("test_item")
end
local duration = tick() - startTime
expect(duration).to.be.below(0.1)  -- Should complete in under 100ms
```

---

## 🔍 Debugging Guidelines

### 1. Structured Logging
```lua
-- Use structured logging with context
self._logger:Info("Purchase completed", {
    player = player.Name,
    itemId = itemId,
    price = price,
    newBalance = newBalance,
    transactionId = transactionId
})

-- Log levels
-- ERROR: System failures, exceptions
-- WARN: Unexpected conditions
-- INFO: Business logic events
-- DEBUG: Detailed tracing (dev only)
```

### 2. Error Context
```lua
-- Provide helpful error context
local success, error = pcall(function()
    return DataService:SaveProfile(player)
end)

if not success then
    self._logger:Error("Failed to save profile", {
        player = player.Name,
        error = error,
        profileData = profileSummary(player),
        serverTime = os.time()
    })
end
```

### 3. Debug Visualization
```lua
-- Add debug displays for development
if RunService:IsStudio() then
    local gui = player.PlayerGui:FindFirstChild("DebugInfo")
    if gui then
        gui.EffectCount.Text = "Active Effects: " .. #getActiveEffects(player)
        gui.Currency.Text = "Coins: " .. getCurrency(player, "coins")
    end
end
```

---

## 📋 Code Review Checklist

### Before Submitting Code:
- [ ] Follows architectural patterns
- [ ] Uses proper error handling with logging
- [ ] No hardcoded values (uses configuration)
- [ ] Proper input validation and sanitization
- [ ] Performance impact considered
- [ ] Security implications reviewed
- [ ] Tests written and passing
- [ ] Documentation updated

### Code Quality Indicators:
- ✅ **Good**: Clear separation of concerns
- ✅ **Good**: Configuration-driven logic
- ✅ **Good**: Comprehensive error handling
- ✅ **Good**: Structured logging with context
- ❌ **Bad**: Silent failures or missing error handling
- ❌ **Bad**: Hardcoded values instead of configuration
- ❌ **Bad**: Client-authoritative logic for critical systems

---

## 🚀 Extension Guidelines

### Adding New Features:
1. **Start with configuration** - Define data structures
2. **Design services** - Plan dependencies and interfaces
3. **Implement with tests** - Write tests alongside code
4. **Document patterns** - Update guidelines if new patterns emerge

### Modifying Existing Systems:
1. **Understand dependencies** - Check what depends on the system
2. **Maintain backwards compatibility** - Don't break existing configs
3. **Test thoroughly** - Verify existing functionality still works
4. **Update documentation** - Keep guides current

### Performance Considerations:
- Profile before optimizing
- Use caching for expensive operations
- Consider memory usage and cleanup
- Monitor network bandwidth usage
- Test with maximum player counts

This ensures consistent, maintainable, and scalable code across the entire game template. 