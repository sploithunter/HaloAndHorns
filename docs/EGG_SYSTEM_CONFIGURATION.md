# Egg System Configuration-as-Code

## **🎯 Overview**

All hardcoded values in the egg system have been moved to `configs/egg_system.lua` for centralized management, easier tuning, and better maintainability.

## **📁 Configuration File Structure**

### **`configs/egg_system.lua`**

```lua
return {
    -- Proximity & interaction settings
    proximity = {
        max_distance = 10,              -- Interaction range
        interaction_key = Enum.KeyCode.E,
    },
    
    -- Performance settings
    performance = {
        update_interval = 0.1,          -- 10fps for proximity checks
        server_update_threshold = 30,   -- Frames before setLastEgg call
    },
    
    -- Cooldown settings
    cooldowns = {
        purchase_cooldown = 3,          -- Seconds between purchases
        ui_error_display_time = 3,      -- Error message duration
        success_notification_time = 5,  -- Success message duration
    },
    
    -- UI configuration
    ui = {
        preview_size = { width = 200, height = 100 },
        position_offset = { x = -100, y = -50 },
        colors = { /* styling */ },
        fonts = { /* typography */ },
        animations = { /* motion */ },
    },
    
    -- Error messages
    messages = {
        too_far_away = "You must be closer to the egg",
        /* ... all error messages ... */
    },
    
    -- Debug settings
    debug = {
        log_proximity_changes = true,   -- Control console spam
        log_server_calls = true,
        /* ... other debug flags ... */
    },
    
    -- Spawning settings
    spawning = {
        spawn_point_name = "EggSpawnPoint",
        auto_spawn_on_startup = true,
        /* ... spawning behavior ... */
    },
    
    -- Validation settings
    validation = {
        enforce_distance_check = true,
        /* ... security settings ... */
    },
}
```

## **🔧 What Was Moved to Configuration**

### **Performance Settings:**
- ✅ **Proximity update interval**: `0.1 seconds` (was hardcoded in multiple places)
- ✅ **Server call threshold**: `30 frames` before setLastEgg
- ✅ **Max interaction distance**: `10 studs` (was duplicated across services)

### **UI Settings:**
- ✅ **Preview window size**: `200x100` pixels
- ✅ **Position offsets**: `-100, -50` from egg center
- ✅ **Colors and styling**: Background, borders, text colors
- ✅ **Fonts**: Title, prompt, notification fonts
- ✅ **Animation settings**: Slide-in timing and easing

### **Cooldowns & Timers:**
- ✅ **Purchase cooldown**: `3 seconds` between egg purchases
- ✅ **Error display time**: `3 seconds` for error messages
- ✅ **Success display time**: `5 seconds` for success notifications

### **Interaction Settings:**
- ✅ **Interaction key**: `Enum.KeyCode.E` (easily changeable)
- ✅ **Spawn point name**: `"EggSpawnPoint"` (configurable for different setups)

### **Error Messages:**
- ✅ **Centralized messages**: All user-facing error text in one place
- ✅ **Localization ready**: Easy to translate or customize

### **Debug Settings:**
- ✅ **Log control**: Toggle console spam on/off
- ✅ **Performance monitoring**: Control verbose logging

## **🎮 Benefits of Configuration-as-Code**

### **🛠️ For Developers:**
- **Single source of truth** for all egg system settings
- **No code changes** needed for tuning
- **Easy A/B testing** of different values
- **Consistent behavior** across all services

### **⚡ For Performance:**
- **Centralized performance settings** (update rates, thresholds)
- **Debug logging control** (reduce console spam in production)
- **Configurable validation** (can disable expensive checks if needed)

### **🎨 For Design:**
- **UI tweaking without code changes** (colors, sizes, positioning)
- **Message customization** (error messages, prompts)
- **Animation tuning** (timing, easing styles)

### **🏗️ For Deployment:**
- **Environment-specific configs** (dev vs production)
- **Feature flags** (enable/disable validation, logging)
- **Easy rollbacks** (revert config changes without code deploy)

## **📊 Usage Examples**

### **Tuning Performance:**
```lua
-- Make proximity checks faster but less smooth
performance = {
    update_interval = 0.2,  -- 5fps instead of 10fps
}

-- Reduce server calls
performance = {
    server_update_threshold = 60,  -- Call server less frequently
}
```

### **Customizing UI:**
```lua
-- Larger, more prominent UI
ui = {
    preview_size = { width = 300, height = 150 },
    colors = {
        background = Color3.fromRGB(0, 0, 0),  -- Black background
        border = Color3.fromRGB(255, 215, 0),  -- Gold border
    },
}
```

### **Debug Control:**
```lua
-- Production: Quiet logging
debug = {
    log_proximity_changes = false,
    log_server_calls = false,
    log_ui_updates = false,
}

-- Development: Verbose logging
debug = {
    log_proximity_changes = true,
    log_server_calls = true,
    log_distance_checks = true,  -- Very verbose!
}
```

## **🚀 Next Steps**

The egg system is now fully configurable! You can:

1. **Tune performance** by adjusting update intervals
2. **Customize appearance** by changing UI settings
3. **Control logging** for production vs development
4. **Experiment with mechanics** by changing distances/cooldowns
5. **Localize messages** for different languages

All without touching any service code! 🎯