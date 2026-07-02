# Action System Implementation Guide

## Overview

The enhanced UI configuration system now supports **fully configuration-driven button actions**. This means all button behaviors can be defined in `configs/ui.lua` without requiring code changes.

## Action Types Supported

### 1. Menu Panel Actions
```lua
shop_action = {
    type = "menu_panel",
    panel = "Shop",
    transition = "slide_in",
    sound = "button_click"
}
```

### 2. Script Execution Actions  
```lua
pets_action = {
    type = "script_execute",
    script = "PetsHandler",
    method = "TogglePetsUI", 
    parameters = {
        animation = "slide_up"
    }
}
```

### 3. Network/Service Actions
```lua
purchase_action = {
    type = "network_call",
    service = "EconomyService",
    method = "InitiatePurchase",
    parameters = {
        product_type = "gems"
    },
    confirmation = {
        enabled = true,
        title = "Purchase Confirmation"
    }
}
```

### 4. Action Sequences
```lua
daily_login_action = {
    type = "action_sequence", 
    sequence = {
        {type = "script_execute", script = "DailyRewards", method = "CheckAvailable"},
        {type = "menu_panel", panel = "DailyRewards", transition = "scale_in"}
    }
}
```

### 5. Conditional Actions
```lua
quest_claim_action = {
    type = "conditional_action",
    conditions = {
        quest_completed = true,
        not_claimed = true
    },
    success_action = {
        type = "script_execute",
        script = "QuestManager",
        method = "ClaimReward"
    },
    failure_action = {
        type = "notification", 
        message = "Quest not completed yet!"
    }
}
```

## Implementation Requirements

### 1. Update BaseUI Button Handler

The current `_onMenuButtonClicked` method needs to be replaced with a more flexible action executor:

```lua
-- OLD (hardcoded)
function BaseUI:_onMenuButtonClicked(menuName)
    if self.menuManager then
        self.menuManager:TogglePanel(menuName)
    end
end

-- NEW (configuration-driven)
function BaseUI:_onButtonClicked(buttonConfig)
    local actionName = buttonConfig.action
    if not actionName then
        self.logger:warn("No action defined for button:", buttonConfig.name)
        return
    end
    
    local playerState = self:_getPlayerState()
    local success = self.uiConfig.helpers.execute_action(
        self.uiConfig, 
        actionName, 
        playerState, 
        self.actionHandler
    )
    
    if not success then
        self.logger:warn("Failed to execute action:", actionName)
    end
end
```

### 2. Create ActionHandler Class

```lua
local ActionHandler = {}
ActionHandler.__index = ActionHandler

function ActionHandler.new(baseUI)
    local self = setmetatable({}, ActionHandler)
    self.baseUI = baseUI
    self.logger = baseUI.logger
    return self
end

function ActionHandler:executeAction(actionConfig)
    local actionType = actionConfig.type
    
    if actionType == "menu_panel" then
        return self:_executeMenuPanel(actionConfig)
    elseif actionType == "script_execute" then
        return self:_executeScript(actionConfig)
    elseif actionType == "network_call" then
        return self:_executeNetworkCall(actionConfig)
    elseif actionType == "action_sequence" then
        return self:_executeSequence(actionConfig)
    elseif actionType == "conditional_action" then
        return self:_executeConditional(actionConfig)
    elseif actionType == "notification" then
        return self:_showNotification(actionConfig)
    else
        self.logger:error("Unknown action type:", actionType)
        return false
    end
end

function ActionHandler:_executeMenuPanel(actionConfig)
    if self.baseUI.menuManager then
        return self.baseUI.menuManager:OpenPanel(
            actionConfig.panel, 
            actionConfig.transition
        )
    end
    return false
end

function ActionHandler:_executeScript(actionConfig)
    -- Dynamic script execution
    local scriptPath = "src.Client.Scripts." .. actionConfig.script
    local success, scriptModule = pcall(require, scriptPath)
    
    if success and scriptModule[actionConfig.method] then
        return scriptModule[actionConfig.method](actionConfig.parameters)
    end
    
    self.logger:error("Script execution failed:", actionConfig.script)
    return false
end

function ActionHandler:_executeNetworkCall(actionConfig)
    -- Handle network/service calls through NetworkBridge
    if actionConfig.confirmation and actionConfig.confirmation.enabled then
        -- Show confirmation dialog first
        self:_showConfirmation(actionConfig)
    else
        self:_makeNetworkCall(actionConfig)
    end
    return true
end

function ActionHandler:_executeSequence(actionConfig)
    -- Execute actions in sequence
    for _, action in ipairs(actionConfig.sequence) do
        local success = self:executeAction(action)
        if not success then
            self.logger:warn("Sequence failed at action:", action.type)
            return false
        end
    end
    return true
end

function ActionHandler:_executeConditional(actionConfig)
    local playerState = self.baseUI:_getPlayerState()
    local conditionsMet = self.baseUI.uiConfig.helpers.check_action_conditions(
        self.baseUI.uiConfig, 
        actionConfig, 
        playerState
    )
    
    if conditionsMet then
        return self:executeAction(actionConfig.success_action)
    else
        return self:executeAction(actionConfig.failure_action)
    end
end

function ActionHandler:_showNotification(actionConfig)
    -- Show notification through notification system
    local NotificationManager = self.baseUI.notificationManager
    if NotificationManager then
        NotificationManager:Show(
            actionConfig.message,
            actionConfig.notification_type,
            actionConfig.duration
        )
        return true
    end
    return false
end
```

### 3. Update Button Creation

Update the button creation methods to use the new action system:

```lua
function BaseUI:_createMenuButtonElement(config, parent, layoutOrder)
    local button = Instance.new("TextButton")
    -- ... existing button setup code ...
    
    -- NEW: Configuration-driven click handling
    button.Activated:Connect(function()
        self:_onButtonClicked(config)  -- Pass full config instead of just name
        self:_animateButtonPress(button)
    end)
    
    return button
end
```

## Configuration Examples

### Basic Menu Button
```lua
{
    type = "menu_button", 
    config = {
        name = "Shop", 
        icon = "🛒", 
        text = "Shop",
        action = "shop_action"  -- References action defined in actions section
    }
}
```

### Custom Script Button
```lua
{
    type = "menu_button",
    config = {
        name = "Pets",
        icon = "🐾", 
        text = "Pets",
        action = "pets_action"  -- Executes custom pets logic
    }
}
```

### Multi-Action Button
```lua
{
    type = "menu_button",
    config = {
        name = "Daily",
        icon = "📅",
        text = "Daily", 
        action = "daily_login_action"  -- Executes sequence of actions
    }
}
```

## Benefits

### 1. **No Code Changes Required**
- All button behaviors defined in configuration
- Add new buttons by editing `configs/ui.lua`
- No need to modify BaseUI or other UI code

### 2. **Flexible Action Types**
- Menu panels with custom transitions
- Script execution with parameters
- Network calls with confirmations
- Action sequences and conditions
- Notifications and feedback

### 3. **Conditional Logic**
- Admin-only buttons
- Debug-mode actions
- Quest/achievement requirements
- Player state validation

### 4. **Easy Testing & Iteration**
- Rapidly prototype new UI flows
- A/B test different button layouts
- Enable/disable features via configuration
- Hot-reload configuration changes

## Migration Path

1. **Phase 1**: Update BaseUI to support action system
2. **Phase 2**: Create ActionHandler with basic action types
3. **Phase 3**: Migrate existing buttons to use configuration actions
4. **Phase 4**: Add advanced action types (sequences, conditions)
5. **Phase 5**: Create script handlers for custom game logic

## Security Considerations

- Validate all action configurations on load
- Sanitize script execution parameters
- Implement proper permission checks for admin actions
- Rate-limit network calls to prevent spam
- Log all action executions for debugging

## Animation System Integration

The Action System fully integrates with the **UI Animation System** to provide seamless, configuration-driven animations. For complete animation documentation, see [ANIMATION_SYSTEM.md](ANIMATION_SYSTEM.md).

### Animation Priority System

The system uses a three-tier priority for selecting animations:

1. **Animation Showcase Overrides** (testing/development)
   - Defined in `animation_showcase.test_effects`
   - Only active when `override_animations = true`

2. **Action Configuration Transitions** (production)
   - Defined in action `transition` property
   - Used when showcase overrides are disabled

3. **Default Fallback** (always works)
   - Ensures animations never break

### Example Integration

```lua
-- Action definition with animation
shop_action = {
    type = "menu_panel",
    panel = "Shop",
    transition = "slide_in_left",  -- Animation effect name
    sound = "button_click"
}

-- Animation showcase for testing
animation_showcase = {
    enabled = true,
    override_animations = true,
    test_effects = {
        shop = "spiral_in",  -- Overrides action transition during testing
    }
}
```

### Available Animation Effects

- **Slides**: `slide_in_left`, `slide_in_right`, `slide_in_top`, `slide_in_bottom`
- **Scales**: `scale_in_small`, `scale_in_large`, `fade_in_scale`
- **Rotations**: `spin_in`, `flip_in`, `spiral_in`
- **Bounces**: `bounce_in`, `elastic_in`
- **Fades**: `fade_in`, `zoom_blur`

All effects are defined in `animations.menu_transitions.effects` and can be referenced by name in action configurations.

---

This system provides **complete configuration-as-code** capabilities while maintaining security and performance. The UI can now be entirely reconfigured without touching any Lua code!