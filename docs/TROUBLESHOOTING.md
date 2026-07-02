# Troubleshooting Guide

## 🔧 Common Issues

### Rojo Sync Problems

**Issue**: Changes not appearing in Studio
**Symptoms**: Code edits in VS Code/Cursor don't reflect in Studio
**Solutions**:
1. Check `rojo serve` is running without errors
2. Verify Rojo plugin is connected in Studio (green indicator)
3. Try disconnecting and reconnecting in Studio
4. Restart Rojo server: `Ctrl+C` then `rojo serve`
5. Check file paths in `default.project.json`

**Issue**: "Failed to read project file"
**Symptoms**: Rojo server won't start
**Solutions**:
1. Validate JSON syntax in `default.project.json`
2. Check file permissions on project directory
3. Ensure no special characters in file paths

**Issue**: Packages not syncing
**Symptoms**: `Packages` folder empty in Studio
**Solutions**:
1. Run `wally install` to download packages
2. Check `wally.toml` syntax
3. Verify internet connection for package downloads
4. Try `wally install --clean` to force refresh

---

### Configuration System Issues

**Issue**: Config changes not taking effect
**Symptoms**: Modified configs don't change game behavior
**Solutions**:
1. **Restart the game** - configs are loaded on server start
2. Check for syntax errors in Lua config files
3. Verify config file names match `ConfigLoader:LoadConfig("name")`
4. Check Studio output for config loading errors

**Issue**: "Config 'name' not found" error
**Symptoms**: ConfigLoader can't find specified config
**Solutions**:
1. Verify file exists in `/configs/` folder
2. Check file is a `.lua` file with proper return statement
3. Ensure Rojo is syncing `/configs/` to `ReplicatedStorage/Configs`
4. Confirm config name matches file name (without .lua extension)

**Issue**: Configuration validation errors
**Symptoms**: Configs load but cause runtime errors
**Solutions**:
```lua
-- Check config structure matches expected format
local items = ConfigLoader:LoadConfig("items")
print("Items config:", items)  -- Debug output

-- Ensure required fields are present
for _, item in ipairs(items) do
    assert(item.id, "Item missing id field")
    assert(item.price, "Item missing price field")
end
```

---

### Player Effects System Issues

**Issue**: Effects not applying to players
**Symptoms**: PlayerEffectsService:ApplyEffect returns false
**Solutions**:
1. Check effect is defined in `configs/ratelimits.lua`
2. Verify effect ID matches exactly (case-sensitive)
3. Ensure player has TimedBoosts folder structure
4. Check Studio output for effect application errors

**Issue**: Effects not persisting after rejoin
**Symptoms**: Player loses effects when leaving/rejoining
**Solutions**:
1. Verify ProfileStore is saving `ActiveEffects` data
2. Check `PlayerEffectsService:LoadPlayerEffects` is called
3. Ensure DataService loads profile before effects
4. Debug ProfileStore data structure:
```lua
-- Check what's actually saved
local data = DataService:GetData(player)
print("ActiveEffects in profile:", data.ActiveEffects)
```

**Issue**: Aggregate values not updating
**Symptoms**: Player/Aggregates/ values don't change with effects
**Solutions**:
1. Verify effect has `statModifiers` in config
2. Check aggregate recalculation is running
3. Ensure Player/Aggregates folder exists
4. Debug aggregate calculation:
```lua
-- Check aggregate totals
local aggregates = player:FindFirstChild("Aggregates")
if aggregates then
    for _, stat in ipairs(aggregates:GetChildren()) do
        print(stat.Name, stat.Value)
    end
end
```

**Issue**: Effect stacking not working correctly
**Symptoms**: Multiple effects don't combine properly
**Solutions**:
1. Check `stacking` configuration in effect definition
2. Verify stacking mode: `"extend_duration"`, `"reset"`, or `"stack"`
3. Ensure aggregate recalculation handles multiple effects
4. Debug active effects:
```lua
local activeEffects = PlayerEffectsService:GetActiveEffects(player)
for effectId, data in pairs(activeEffects) do
    print(effectId, data.multiplier, data.timeRemaining)
end
```

---

### Economy System Issues

**Issue**: Purchases failing silently
**Symptoms**: Purchase buttons don't work, no error messages
**Solutions**:
1. Check item exists in `configs/items.lua`
2. Verify player has sufficient currency
3. Check rate limiting isn't blocking purchases
4. Enable DEBUG logging to see purchase flow:
```lua
-- In EconomyService, add debug logging
self._logger:Debug("Purchase attempt", {
    player = player.Name,
    itemId = itemId,
    playerCurrency = self:GetCurrency(player, currency)
})
```

**Issue**: Currency not saving
**Symptoms**: Player currency resets after rejoin
**Solutions**:
1. Verify ProfileStore template includes currency fields
2. Check DataService is saving currency changes
3. Ensure atomic currency operations
4. Debug ProfileStore data:
```lua
local profile = DataService:GetProfile(player)
print("Currency in profile:", profile.Data.Currencies)
```

**Issue**: Invalid purchase transactions
**Symptoms**: Players can buy items they can't afford
**Solutions**:
1. Add server-side currency validation
2. Check for race conditions in purchase flow
3. Implement atomic transactions
4. Add transaction logging for audit trail

---

### Network System Issues

**Issue**: Packets not being received
**Symptoms**: Client-server communication fails
**Solutions**:
1. Check packet is defined in `configs/network.lua`
2. Verify bridge creation and connection
3. Check rate limiting isn't blocking packets
4. Debug network flow:
```lua
-- On server, log packet reception
bridge:Connect(function(player, packetType, data)
    Logger:Debug("Packet received", {
        player = player.Name,
        packet = packetType,
        data = data
    })
end)
```

**Issue**: Rate limiting triggering unexpectedly
**Symptoms**: Valid actions get blocked by rate limits
**Solutions**:
1. Check rate limit configuration in `configs/ratelimits.lua`
2. Adjust limits for development/testing
3. Verify rate limit reset timing
4. Debug rate limit state:
```lua
local limit = RateLimitService:GetCurrentLimit(player, "PurchaseItem")
print("Current rate limit:", limit)
```

**Issue**: Network bridge creation fails
**Symptoms**: "Bridge not found" errors
**Solutions**:
1. Verify network configuration is loaded
2. Check bridge names match exactly
3. Ensure NetworkConfig processes bridge definitions
4. Debug bridge creation:
```lua
local bridges = NetworkConfig:GetBridges()
for name, config in pairs(bridges) do
    print("Bridge available:", name)
end
```

---

### Data Persistence Issues

**Issue**: ProfileStore session locking
**Symptoms**: Players can't join, "Profile locked" errors
**Solutions**:
1. Wait for session lock timeout (usually 5 minutes)
2. Check for infinite loops holding locks
3. Ensure proper profile release on PlayerRemoving
4. Debug profile state:
```lua
-- Check profile loading
local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)
if not profile then
    print("Profile failed to load for", player.Name)
end
```

**Issue**: Data corruption or rollbacks
**Symptoms**: Player data randomly resets
**Solutions**:
1. Check for concurrent profile modifications
2. Ensure atomic data operations
3. Add data validation before saves
4. Implement backup/recovery system

**Issue**: Memory leaks in data handling
**Symptoms**: Server memory usage continuously increases
**Solutions**:
1. Check profile cleanup on player leave
2. Verify all event connections are cleaned up
3. Use Maid pattern for resource management
4. Profile memory usage with Studio tools

---

### Performance Issues

**Issue**: High server lag/frame drops
**Symptoms**: Poor game performance, timeout warnings
**Solutions**:
1. Use MicroProfiler (Ctrl+F6 in Studio) to identify bottlenecks
2. Check for expensive operations in heartbeat events
3. Optimize database operations and caching
4. Review effect expiration loop performance:
```lua
-- Profile effect processing
local startTime = tick()
-- ... effect processing code ...
local duration = tick() - startTime
if duration > 0.01 then  -- More than 10ms
    Logger:Warn("Slow effect processing", {duration = duration})
end
```

**Issue**: High memory usage
**Symptoms**: Studio warns about memory usage
**Solutions**:
1. Check for memory leaks in services
2. Verify proper cleanup of player data
3. Use object pooling for frequently created objects
4. Monitor aggregate cache size

**Issue**: Network bandwidth problems
**Symptoms**: Poor replication, lag spikes
**Solutions**:
1. Reduce frequency of effect updates
2. Batch similar network operations
3. Use native replication instead of RemoteEvents where possible
4. Optimize data structures sent over network

---

### Matter ECS Issues

**Issue**: Components not appearing on entities
**Symptoms**: Systems can't find expected components
**Solutions**:
1. Verify component is properly spawned on entity
2. Check component definition syntax
3. Ensure component names match exactly
4. Debug entity components:
```lua
for id, transform in world:query(Components.Transform) do
    print("Entity", id, "has Transform:", transform)
end
```

**Issue**: Systems not running
**Symptoms**: Game logic not executing
**Solutions**:
1. Check system is added to Matter loop
2. Verify system function returns properly
3. Ensure no errors in system code
4. Enable Matter debugger for visualization

**Issue**: Performance problems with ECS
**Symptoms**: Frame rate drops with many entities
**Solutions**:
1. Optimize system queries
2. Use change detection to avoid unnecessary work
3. Consider system execution order
4. Profile individual systems

---

## 🔍 Debugging Tools

### 1. Logging Configuration
Add to any service for detailed debugging:
```lua
-- Enable debug logging in development
if RunService:IsStudio() then
    Logger:SetLevel("DEBUG")
else
    Logger:SetLevel("INFO")
end
```

### 2. Player Data Inspector
```lua
-- Add to ServerScriptService for debugging
local Players = game:GetService("Players")

local function inspectPlayer(player)
    local data = DataService:GetData(player)
    local effects = PlayerEffectsService:GetActiveEffects(player)
    
    print("=== Player Inspection:", player.Name, "===")
    print("Currency:", data.Currencies)
    print("Inventory:", data.Inventory)
    print("Active Effects:", effects)
    
    local aggregates = player:FindFirstChild("Aggregates")
    if aggregates then
        for _, stat in ipairs(aggregates:GetChildren()) do
            print("Aggregate", stat.Name .. ":", stat.Value)
        end
    end
end

-- Usage: inspectPlayer(game.Players.YourUsername)
```

### 3. Configuration Validator
```lua
-- Validate configurations on server start
local function validateConfigs()
    local configs = {"items", "currencies", "ratelimits", "network"}
    
    for _, configName in ipairs(configs) do
        local success, result = pcall(function()
            return ConfigLoader:LoadConfig(configName)
        end)
        
        if success then
            print("✅ Config valid:", configName)
        else
            warn("❌ Config invalid:", configName, result)
        end
    end
end

validateConfigs()
```

### 4. Network Packet Monitor
```lua
-- Monitor all network traffic
local function monitorNetworking()
    local NetworkBridge = require(game.ReplicatedStorage.Shared.Network.NetworkBridge)
    
    -- Override packet handling to log all traffic
    local originalFire = NetworkBridge.Fire
    NetworkBridge.Fire = function(self, ...)
        Logger:Debug("Network packet sent", {...})
        return originalFire(self, ...)
    end
end
```

---

## 🚨 Emergency Procedures

### Server Crash Recovery
1. Check Studio output for error messages
2. Identify last successful operation before crash
3. Verify ProfileStore data integrity
4. Restart server and monitor for recurring issues

### Data Loss Prevention
1. Always test data operations in Studio first
2. Implement data backup strategies
3. Use atomic operations for critical data
4. Add data validation before writes

### Performance Emergency
1. Use MicroProfiler to identify immediate bottlenecks
2. Temporarily disable non-critical systems
3. Increase rate limiting to reduce load
4. Monitor server resources and player count

---

## 📞 Getting Help

### Information to Gather
When seeking help, provide:
1. **Error messages** from Studio output
2. **Steps to reproduce** the issue
3. **Expected vs actual behavior**
4. **Configuration files** involved
5. **Code snippets** related to the problem

### Community Resources
1. **Roblox DevForum** - For platform-specific issues
2. **Matter Discord/GitHub** - For ECS-related problems
3. **Rojo Documentation** - For sync and project issues
4. **ProfileStore GitHub** - For data persistence issues

### Creating Minimal Reproduction
1. Create smallest possible test case
2. Remove unrelated systems/code
3. Document exact steps to trigger issue
4. Share configuration and code snippets
5. Include Studio output and error messages

Remember: Most issues are configuration-related or missing dependencies. Always check the basics first before diving into complex debugging. 