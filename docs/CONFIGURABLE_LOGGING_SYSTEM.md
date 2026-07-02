# Configurable Logging System

## Overview

The Configurable Logging System allows fine-grained control over debug output to keep the console clean while debugging specific systems. You can control logging at both global and per-service levels.

## Configuration File

**Location**: `configs/logging.lua`

### Global Settings

```lua
global = {
    default_level = "info",           -- Default level for unconfigured services
    console_output = true,            -- Show logs in console
    enable_performance_logs = false,  -- Show performance timing logs
    max_log_history = 100,           -- Number of logs to keep in memory
    enable_remote_logging = false,   -- Send logs to external services
}
```

### Service-Specific Log Levels

```lua
services = {
    AssetPreloadService = "info",     -- Set to "debug" to see detailed asset loading
    EggPetPreviewService = "info",    -- Set to "debug" to see detailed pet preview
    BaseUI = "warn",                  -- UI can be very verbose
    EggCurrentTargetService = "info",
    -- ... more services
}
```

### Log Levels

- **`"disabled"`** = No logging (silent)
- **`"error"`** = Only errors
- **`"warn"`** = Warnings and above  
- **`"info"`** = Info and above (normal operation)
- **`"debug"`** = Everything (detailed debugging)

## Admin Panel Controls

Access via the **Admin Panel → 📊 Logging Controls** section:

### Quick Actions
- **Show Current Log Config** - Display current settings
- **Set All to INFO/DEBUG/WARN** - Change global level
- **Enable/Disable Console Output** - Turn console logging on/off
- **Enable/Disable Performance Logs** - Control timing measurements

### Custom Service Control
Use the text input to set individual service levels:
- Format: `ServiceName:level` or `ServiceName level`
- Examples:
  - `EggPetPreviewService:debug`
  - `BaseUI warn`  
  - `AssetPreloadService:info`

## Runtime API

The Logger provides methods for runtime control:

```lua
local Logger = require(ReplicatedStorage.Shared.Utils.Logger)

-- Set individual service log levels
Logger:SetServiceLogLevel("EggPetPreviewService", "debug")

-- Get current level for a service
local level = Logger:GetServiceLogLevel("BaseUI")

-- Control global settings
Logger:SetConsoleOutput(false)
Logger:SetPerformanceLogging(true)

-- Get current configuration
local config = Logger:GetConfig()
```

## Common Use Cases

### Debugging Pet Preview Issues
```lua
-- In configs/logging.lua
services = {
    EggPetPreviewService = "debug",
    AssetPreloadService = "debug", 
    EggCurrentTargetService = "debug",
    default_level = "warn"  -- Keep everything else quiet
}
```

### Production Mode (Minimal Logging)
```lua
global = {
    default_level = "warn",
    console_output = false,  -- Disable console in production
}
```

### Performance Analysis
```lua
global = {
    enable_performance_logs = true,
}
```

## Benefits

1. **Cleaner Console**: Filter out noise to focus on relevant logs
2. **Focused Debugging**: Enable detailed logging only for systems being debugged
3. **Production Ready**: Easily disable verbose logging for live environments
4. **Runtime Control**: Change logging levels without restarting via Admin Panel
5. **Performance Monitoring**: Optional timing logs for performance analysis

## Integration with Services

All services use the LoggerWrapper pattern from the memory to ensure consistent context:

```lua
-- Services automatically get per-service filtering
local LoggerWrapper = {
    new = function(name)
        return {
            info = function(self, ...) 
                loggerResult:Info("[" .. name .. "] " .. tostring((...)), {context = name}) 
            end,
            -- ... other levels
        }
    end
}

local logger = LoggerWrapper.new("MyService")
logger:debug("This respects MyService's configured log level")
```

The `{context = name}` ensures that the Logger knows which service is logging and applies the correct filtering level.

## Example Output

With `EggPetPreviewService = "debug"` and `BaseUI = "warn"`:

```
[4.803] [INFO] [EggPetPreviewService] Loading 3D pet model {"petType":"bear","variant":"basic"}
[4.804] [DEBUG] [EggPetPreviewService] Got model from ReplicatedStorage.Assets {"path":"..."}
# BaseUI debug/info logs are filtered out, only warnings+ shown
[5.102] [WARN] [BaseUI] Failed to update currency display {"error":"..."}
```

This system provides powerful debugging capabilities while maintaining clean console output during normal operation.