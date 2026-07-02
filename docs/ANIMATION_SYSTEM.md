# UI Animation System

## Overview

The UI Animation System provides a comprehensive, configuration-driven approach to animating menu panels and UI elements. This system supports 15 different animation effects and integrates seamlessly with the Action System.

## Architecture

### Animation Priority System

The animation system uses a three-tier priority system:

1. **Animation Showcase Overrides** (highest priority)
   - Used for testing and development
   - Defined in `configs/ui.lua` under `animation_showcase.test_effects`
   - Only active when `override_animations = true`

2. **Action Configuration Transitions** (medium priority)
   - Production animation settings
   - Defined in action configurations (e.g., `shop_action.transition`)
   - Used when showcase overrides are disabled

3. **Default Fallback** (lowest priority)
   - Ensures animations always work
   - Defaults to `slide_in_right` if no other configuration is found

### Integration Points

- **BaseUI**: Handles button clicks and animation selection
- **MenuManager**: Executes the actual animation effects
- **UI Config**: Stores all animation definitions and settings

## Available Animation Effects

### Slide Animations
- `slide_in_left` - Slides in from the left side
- `slide_in_right` - Slides in from the right side  
- `slide_in_top` - Slides in from the top
- `slide_in_bottom` - Slides in from the bottom

### Scale Animations
- `scale_in_small` - Scales up from tiny to normal size
- `scale_in_large` - Scales down from large to normal size
- `scale_out_in` - Scales out then back in
- `fade_in_scale` - Fades in while scaling

### Rotation Animations
- `spin_in` - Spins while scaling up
- `flip_in` - Flips 180° while scaling
- `spiral_in` - Combines rotation, scaling, and sliding

### Bounce Animations
- `bounce_in` - Bounces into position
- `bounce_scale` - Bounces with scale effect
- `elastic_in` - Elastic bounce effect

### Fade Animations
- `fade_in` - Simple fade in
- `zoom_blur` - Zoom effect with fade

## Configuration

### Animation Showcase System

For testing and development:

```lua
animation_showcase = {
    enabled = true,
    override_animations = true,  -- Use test effects instead of action config
    
    test_effects = {
        shop = "slide_in_left",
        inventory = "flip_in", 
        effects = "spin_in",
        settings = "slide_in_bottom",
        admin = "zoom_blur",
    }
}
```

### Action System Integration

For production use:

```lua
actions = {
    shop_action = {
        type = "menu_panel",
        panel = "Shop", 
        transition = "slide_in_left",  -- Animation defined here
        sound = "button_click"
    }
}
```

### Animation Definitions

All animations are defined in `animations.menu_transitions.effects`:

```lua
animations = {
    duration = { fast = 0.15, normal = 0.25, slow = 0.4 },
    easing = { ease_out = Enum.EasingStyle.Quad },
    direction = { out_dir = Enum.EasingDirection.Out },
    
    menu_transitions = {
        enabled = true,
        default_effect = "slide_in_right",
        
        effects = {
            slide_in_left = {
                duration = "normal",
                easing = "ease_out", 
                direction = "out_dir",
                start_position = UDim2.new(-0.2, 0, 0.5, 0),
                end_position = UDim2.new(0.5, 0, 0.5, 0),
                anchor_point = Vector2.new(0.5, 0.5)
            },
            -- ... more effects
        }
    }
}
```

## Usage Examples

### Testing New Animations

1. Enable animation showcase:
   ```lua
   animation_showcase = { enabled = true, override_animations = true }
   ```

2. Set test effects:
   ```lua
   test_effects = {
       shop = "spiral_in",  -- Try a different effect
       inventory = "bounce_in"
   }
   ```

3. Test in game - each menu will use the specified animation

### Adding New Animation Effects

1. Define the effect in `animations.menu_transitions.effects`:
   ```lua
   my_custom_effect = {
       duration = "normal",
       easing = "ease_out",
       direction = "out_dir", 
       start_position = UDim2.new(0.5, 0, -0.1, 0),
       end_position = UDim2.new(0.5, 0, 0.5, 0),
       start_scale = 0.8,
       end_scale = 1.0,
       anchor_point = Vector2.new(0.5, 0.5)
   }
   ```

2. Use in action configuration:
   ```lua
   my_button_action = {
       type = "menu_panel",
       panel = "MyPanel",
       transition = "my_custom_effect"
   }
   ```

### Production Deployment

1. Disable animation showcase:
   ```lua
   animation_showcase = { enabled = false }
   ```

2. Set production animations in action configs:
   ```lua
   shop_action = { transition = "slide_in_left" }
   inventory_action = { transition = "fade_in_scale" }
   ```

## Technical Details

### Animation Properties

Each animation effect can define:

- **Positioning**: `start_position`, `end_position`, `anchor_point`
- **Scaling**: `start_scale`, `end_scale` 
- **Rotation**: `start_rotation`, `end_rotation`
- **Transparency**: `start_transparency`, `end_transparency`
- **Timing**: `duration`, `easing`, `direction`

### Tween Creation

MenuManager creates multiple tweens per animation:
- **Main Tween**: Handles position, rotation, transparency
- **Scale Tween**: Handles UIScale effects separately
- **Sequential Effects**: Some animations use multiple phases

### Error Handling

- Invalid effect names fall back to default
- Missing animation config disables transitions
- Comprehensive logging for debugging

## Debugging

### Console Output

Enable detailed logging to see animation selection:

```
[BaseUI] Using animation showcase override for Shop: slide_in_left
[MenuManager] Attempting to use transition effect: slide_in_left  
[MenuManager] Applied entrance effect: slide_in_left
```

### Available Effects List

MenuManager can list all configured effects:

```lua
local effects = menuManager:_getAvailableEffects()
print("Available animations:", table.concat(effects, ", "))
```

## Best Practices

1. **Use Animation Showcase** for rapid prototyping
2. **Test on multiple devices** - some effects may perform differently
3. **Consider UX impact** - don't overuse dramatic animations
4. **Consistent timing** - use standard duration values
5. **Fallback strategy** - always ensure default animations work
6. **Performance monitoring** - complex animations can impact frame rate

## Future Enhancements

- **Sequence animations** - Multiple effects in succession
- **Conditional animations** - Different effects based on game state
- **Performance profiles** - Simpler animations on lower-end devices
- **Custom easing curves** - More animation personality options