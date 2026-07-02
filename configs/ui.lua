--[[
    UI Configuration - Pane-Based Architecture (Configuration-as-Code)
    
    Version: 2.0 - Enhanced Asset Support & Performance
    
    This file defines the complete UI layout system using a pane-based architecture.
    All UI positioning, styling, icons, and behavior can be modified here without
    touching any Lua code.
    
    Key Features:
    - Semantic positioning system (top-left, center, bottom-right, etc.)
    - Universal icon support (emoji + Roblox asset IDs)
    - Pane-based layout with configurable backgrounds and layouts
    - Floating currency cards with professional styling
    - Menu button grids with hover effects
    - Combined UI elements (player info + quest tracker)
    - Responsive design with automatic scaling
    
    Architecture:
    - panes: Define UI containers with position, size, background, layout, and contents
    - themes: Visual styling and color schemes
    - layout: Positioning and sizing rules
    - menu_views: Complex multi-view menu definitions
    
    Usage:
    Simply modify the configuration values below to reorganize the entire UI.
    No code changes required - the BaseUI system reads this configuration
    and generates the UI automatically.
--]]

-- 🐛 DEBUG: UI Config loading started
-- 🎉 UNIVERSAL CONSISTENCY SYSTEM ACTIVE!
-- One image rules all buttons: Global defaults working perfectly!

local uiConfig = {
    version = "2.0.0", -- Updated for template system

    -- GLOBAL DEFAULTS for all UI elements
    -- These defaults are applied to any element that doesn't override them
    defaults = {
        menu_button = {
            -- Icon defaults
            icon_config = {
                size = { scale_x = 0.4, scale_y = 0.4 }, -- Default 40% of button size
                position = { scale_x = 0.5, scale_y = 0.5 }, -- Default center position
                offset = { x = 0, y = 0 }, -- Default no offset
            },

            -- Text defaults
            text_config = {
                font = Enum.Font.GothamBold, -- Default font
                size = { height = 20, margin = 10 }, -- Default text area size
                color = Color3.fromRGB(255, 255, 255), -- Default white text
                text_scaled = true, -- Default auto-scale text
                text_size = 14, -- Default font size when not scaled
                position = { bottom_offset = 25, side_margin = 5 }, -- Default text position
                shadow = {
                    enabled = true, -- Default shadow enabled
                    color = Color3.fromRGB(0, 0, 0), -- Default black shadow
                    thickness = 2, -- Default shadow thickness
                    transparency = 0.5, -- Default shadow transparency
                },
            },

            -- Notification defaults
            notification = {
                enabled = false, -- Default no notification
                text = "!", -- Default notification text
                background_color = Color3.fromRGB(255, 0, 0), -- Default red background
                text_color = Color3.fromRGB(255, 255, 255), -- Default white text
                position = "top-right", -- Default position
            },

            -- Button defaults - APPLIES TO ALL BUTTONS GLOBALLY
            color = Color3.fromRGB(100, 100, 100), -- Default button color (fallback mode)
            background_image = "16809347055", -- 🎨 GLOBAL: Teal panel for ALL buttons
        },

        -- Panel defaults (for settings panel, inventory panel, etc.)
        -- 🌟 UNIVERSAL PANEL SYSTEM - ONE IMAGE RULES ALL PANELS! 🌟
        panel = {
            -- Panel background defaults - APPLIES TO ALL PANELS GLOBALLY
            background = {
                image = "6208057940", -- 🎨 GLOBAL: Blue panel for ALL panels
                color = Color3.fromRGB(40, 42, 48), -- Fallback color if image fails
                corner_radius = 16, -- Default corner radius
                padding = { top = 20, bottom = 20, left = 20, right = 20 }, -- Default padding
            },

            -- Panel header defaults - APPLIES TO ALL PANEL HEADERS GLOBALLY
            header = {
                height = 70, -- Default header height
                background_image = "16809347055", -- 🎨 GLOBAL: Teal panel for ALL headers
                background_color = Color3.fromRGB(35, 37, 43), -- Fallback color if image fails
                title_font = Enum.Font.GothamBold, -- Default title font
                title_size = 24, -- Default title size
                title_color = Color3.fromRGB(255, 255, 255), -- Default title color
                icon_size = { width = 32, height = 32 }, -- Default header icon size
                icon_position = "top-left-corner", -- Default icon position

                -- Close button defaults - APPLIES TO ALL POPUP PANELS GLOBALLY
                -- 🎯 AUTO-APPLIED: Every panel gets this close button unless explicitly disabled
                close_button = {
                    icon = "89257673063270", -- 🎨 GLOBAL: New X button icon for ALL panels
                    size = { width = 30, height = 30 }, -- Default close button size
                    position = "top-right-corner", -- Position in top-right corner
                    offset = { x = 10, y = -10 }, -- Offset from corner (extends outside bounds)
                    background_color = Color3.fromRGB(220, 60, 60), -- Default red background
                    hover_color = Color3.fromRGB(180, 40, 40), -- Darker red on hover
                    corner_radius = 8, -- Default corner radius
                },
            },

            -- Panel content defaults
            content = {
                background_image = nil, -- Keep content transparent for layering
                background_color = Color3.fromRGB(45, 47, 53), -- Subtle content color
                corner_radius = 12, -- Default content corner radius
                padding = { top = 15, bottom = 15, left = 15, right = 15 }, -- Default content padding
            },
        },

        -- Setting item defaults (for individual settings like toggles, sliders)
        setting_item = {
            -- Setting background defaults
            background = {
                image = nil, -- Default no setting background
                color = Color3.fromRGB(50, 52, 58), -- Default setting color
                corner_radius = 8, -- Default setting corner radius
                height = 50, -- Default setting height
            },

            -- Setting label defaults
            label = {
                font = Enum.Font.Gotham, -- Default label font
                size = 14, -- Default label size
                color = Color3.fromRGB(255, 255, 255), -- Default label color
                position = "left", -- Default label position
            },

            -- Toggle defaults
            toggle = {
                on_image = "5533192672", -- Default ON toggle image
                off_image = "5533209494", -- Default OFF toggle image
                size = { width = 60, height = 30 }, -- Default toggle size
                position = "right", -- Default toggle position
            },
        },
    },
    -- Template System Configuration
    templates = {
        -- Template storage path
        storage_path = "ReplicatedStorage.UI_Templates",

        -- Asset ID mappings (your owned assets - swappable without code changes)
        assets = {
            currency_icons = {
                coins = "rbxassetid://5088859456", -- Using your gems icon
                gems = "rbxassetid://5088859456", -- Your gems asset
                crystals = "rbxassetid://12155643116", -- Your crystals asset
                robux = "rbxassetid://5088859456", -- Can use gems icon as fallback
                xp = "rbxassetid://5088859456", -- Can use gems icon as fallback
            },

            ui_icons = {
                shop = "rbxassetid://12155643116", -- Using your frame asset for now
                inventory = "rbxassetid://12155643116",
                settings = "rbxassetid://12155643116",
                effects = "rbxassetid://12155643116",
                close = "rbxassetid://12155643116",
                menu = "rbxassetid://12155643116",
            },

            backgrounds = {
                panel = "rbxassetid://12155643116", -- Your frame background
                button = "rbxassetid://12155643116",
                frame = "rbxassetid://12155643116",
            },
        },

        -- Template type mappings
        types = {
            currency_display = "CurrencyLabel",
            menu_button = "MenuButton",
            shop_item = "GenericEntryTemplate",
            inventory_item = "GenericEntryTemplate",
            panel_large = "LargeUIBlank",
            panel_scroll = "LargeUIScroller",
            text_display = "TextLabelStyle",
        },

        -- Optional per-template defaults (safe to be empty)
        defaults = {
            -- Examples (uncomment and customize as needed):
            -- menu_button = { corner_radius = 12 },
            -- panel_large = { corner_radius = 16 },
            -- panel_scroll = { corner_radius = 16 },
        },

        -- Template configurations moved to template_helpers section below
    },

    -- === THEMES ===
    themes = {
        dark = {
            name = "Dark Theme",
            primary = {
                background = Color3.fromRGB(30, 30, 35),
                surface = Color3.fromRGB(40, 40, 45),
                accent = Color3.fromRGB(0, 120, 180),
                success = Color3.fromRGB(34, 139, 34),
                warning = Color3.fromRGB(255, 165, 0),
                error = Color3.fromRGB(220, 53, 69),
                info = Color3.fromRGB(138, 43, 226),
            },
            text = {
                primary = Color3.fromRGB(255, 255, 255),
                secondary = Color3.fromRGB(200, 200, 200),
                muted = Color3.fromRGB(150, 150, 150),
                disabled = Color3.fromRGB(100, 100, 100),
                inverse = Color3.fromRGB(0, 0, 0),
            },
            button = {
                primary = Color3.fromRGB(0, 120, 180),
                secondary = Color3.fromRGB(100, 100, 120),
                success = Color3.fromRGB(34, 139, 34),
                danger = Color3.fromRGB(220, 53, 69),
                disabled = Color3.fromRGB(60, 60, 65),
            },
            input = {
                background = Color3.fromRGB(35, 35, 40),
                border = Color3.fromRGB(80, 80, 85),
                focus = Color3.fromRGB(0, 120, 180),
                error = Color3.fromRGB(220, 53, 69),
            },
            shadow = Color3.fromRGB(0, 0, 0),
            overlay = Color3.fromRGB(0, 0, 0),
        },

        light = {
            name = "Light Theme",
            primary = {
                background = Color3.fromRGB(248, 249, 250),
                surface = Color3.fromRGB(255, 255, 255),
                accent = Color3.fromRGB(0, 123, 255),
                success = Color3.fromRGB(40, 167, 69),
                warning = Color3.fromRGB(255, 193, 7),
                error = Color3.fromRGB(220, 53, 69),
                info = Color3.fromRGB(23, 162, 184),
            },
            text = {
                primary = Color3.fromRGB(33, 37, 41),
                secondary = Color3.fromRGB(108, 117, 125),
                muted = Color3.fromRGB(134, 142, 150),
                disabled = Color3.fromRGB(173, 181, 189),
                inverse = Color3.fromRGB(255, 255, 255),
            },
            button = {
                primary = Color3.fromRGB(0, 123, 255),
                secondary = Color3.fromRGB(108, 117, 125),
                success = Color3.fromRGB(40, 167, 69),
                danger = Color3.fromRGB(220, 53, 69),
                disabled = Color3.fromRGB(173, 181, 189),
            },
            input = {
                background = Color3.fromRGB(255, 255, 255),
                border = Color3.fromRGB(206, 212, 218),
                focus = Color3.fromRGB(0, 123, 255),
                error = Color3.fromRGB(220, 53, 69),
            },
            shadow = Color3.fromRGB(0, 0, 0),
            overlay = Color3.fromRGB(255, 255, 255),
        },
    },

    -- Current active theme
    active_theme = "dark",

    -- === TYPOGRAPHY ===
    fonts = {
        primary = Enum.Font.Gotham,
        secondary = Enum.Font.GothamMedium,
        bold = Enum.Font.GothamBold,
        monospace = Enum.Font.RobotoMono,

        -- Font sizes (scaled automatically based on screen size)
        sizes = {
            xs = 10,
            sm = 12,
            md = 14,
            lg = 16,
            xl = 18,
            xxl = 24,
            xxxl = 32,
        },
    },

    -- === SPACING SYSTEM ===
    spacing = {
        xs = 4,
        sm = 8,
        md = 16,
        lg = 24,
        xl = 32,
        xxl = 48,
        xxxl = 64,
    },

    -- === BORDER RADIUS ===
    radius = {
        none = 0,
        sm = 4,
        md = 8,
        lg = 12,
        xl = 16,
        full = 999, -- For circular elements
    },

    -- === ANIMATIONS ===
    animations = {
        duration = {
            fast = 0.15,
            normal = 0.25,
            slow = 0.4,
        },
        easing = {
            ease_in = Enum.EasingStyle.Quad,
            ease_out = Enum.EasingStyle.Quad,
            ease_in_out = Enum.EasingStyle.Quad,
            bounce = Enum.EasingStyle.Bounce,
            elastic = Enum.EasingStyle.Elastic,
        },
        direction = {
            in_dir = Enum.EasingDirection.In,
            out_dir = Enum.EasingDirection.Out,
            in_out_dir = Enum.EasingDirection.InOut,
        },

        -- Menu transition effects - Professional Animation Showcase
        menu_transitions = {
            enabled = true,
            default_effect = "slide_in_right", -- Default animation

            effects = {
                -- === DIRECTIONAL SLIDES ===
                slide_in_right = {
                    name = "Slide from Right",
                    duration = "normal",
                    easing = "ease_out",
                    direction = "out_dir",
                    start_position = UDim2.new(1.2, 0, 0.5, 0), -- Off-screen right
                    end_position = UDim2.new(0.5, 0, 0.5, 0), -- Center
                    anchor_point = Vector2.new(0.5, 0.5),
                    start_transparency = 0,
                    end_transparency = 0,
                },

                slide_in_left = {
                    name = "Slide from Left",
                    duration = "normal",
                    easing = "ease_out",
                    direction = "out_dir",
                    start_position = UDim2.new(-0.2, 0, 0.5, 0), -- Off-screen left
                    end_position = UDim2.new(0.5, 0, 0.5, 0), -- Center
                    anchor_point = Vector2.new(0.5, 0.5),
                    start_transparency = 0,
                    end_transparency = 0,
                },

                slide_in_top = {
                    name = "Slide from Top",
                    duration = "normal",
                    easing = "ease_out",
                    direction = "out_dir",
                    start_position = UDim2.new(0.5, 0, -0.2, 0), -- Off-screen top
                    end_position = UDim2.new(0.5, 0, 0.5, 0), -- Center
                    anchor_point = Vector2.new(0.5, 0.5),
                    start_transparency = 0,
                    end_transparency = 0,
                },

                slide_in_bottom = {
                    name = "Slide from Bottom",
                    duration = "normal",
                    easing = "ease_out",
                    direction = "out_dir",
                    start_position = UDim2.new(0.5, 0, 1.2, 0), -- Off-screen bottom
                    end_position = UDim2.new(0.5, 0, 0.5, 0), -- Center
                    anchor_point = Vector2.new(0.5, 0.5),
                    start_transparency = 0,
                    end_transparency = 0,
                },

                -- === SCALING EFFECTS ===
                scale_in_small = {
                    name = "Scale In (Small)",
                    duration = "fast",
                    easing = "ease_out",
                    direction = "out_dir",
                    start_position = UDim2.new(0.5, 0, 0.5, 0),
                    end_position = UDim2.new(0.5, 0, 0.5, 0),
                    anchor_point = Vector2.new(0.5, 0.5),
                    start_scale = 0.3,
                    end_scale = 1.0,
                    start_transparency = 0.8,
                    end_transparency = 0,
                },

                scale_in_large = {
                    name = "Scale In (Large)",
                    duration = "normal",
                    easing = "ease_out",
                    direction = "out_dir",
                    start_position = UDim2.new(0.5, 0, 0.5, 0),
                    end_position = UDim2.new(0.5, 0, 0.5, 0),
                    anchor_point = Vector2.new(0.5, 0.5),
                    start_scale = 1.5,
                    end_scale = 1.0,
                    start_transparency = 0.5,
                    end_transparency = 0,
                },

                -- === ROTATION EFFECTS ===
                spin_in = {
                    name = "Spin In",
                    duration = "normal",
                    easing = "ease_out",
                    direction = "out_dir",
                    start_position = UDim2.new(0.5, 0, 0.5, 0),
                    end_position = UDim2.new(0.5, 0, 0.5, 0),
                    anchor_point = Vector2.new(0.5, 0.5),
                    start_scale = 0.1,
                    end_scale = 1.0,
                    start_rotation = 180, -- Half rotation
                    end_rotation = 0,
                    start_transparency = 0.7,
                    end_transparency = 0,
                },

                flip_in = {
                    name = "Flip In",
                    duration = "normal",
                    easing = "bounce",
                    direction = "out_dir",
                    start_position = UDim2.new(0.5, 0, 0.5, 0),
                    end_position = UDim2.new(0.5, 0, 0.5, 0),
                    anchor_point = Vector2.new(0.5, 0.5),
                    start_scale = 0.01, -- Nearly invisible
                    end_scale = 1.0,
                    start_rotation = 90, -- Quarter rotation
                    end_rotation = 0,
                    start_transparency = 0.9,
                    end_transparency = 0,
                },

                -- === BOUNCE & ELASTIC ===
                bounce_in = {
                    name = "Bounce In",
                    duration = "slow",
                    easing = "bounce",
                    direction = "out_dir",
                    start_position = UDim2.new(0.5, 0, -0.3, 0), -- Off-screen top
                    end_position = UDim2.new(0.5, 0, 0.5, 0), -- Center
                    anchor_point = Vector2.new(0.5, 0.5),
                    start_transparency = 0,
                    end_transparency = 0,
                },

                elastic_in = {
                    name = "Elastic In",
                    duration = "slow",
                    easing = "elastic",
                    direction = "out_dir",
                    start_position = UDim2.new(0.5, 0, 0.5, 0),
                    end_position = UDim2.new(0.5, 0, 0.5, 0),
                    anchor_point = Vector2.new(0.5, 0.5),
                    start_scale = 0.2,
                    end_scale = 1.0,
                    start_transparency = 0.3,
                    end_transparency = 0,
                },

                -- === FADE VARIATIONS ===
                fade_in = {
                    name = "Fade In",
                    duration = "fast",
                    easing = "ease_in_out",
                    direction = "out_dir",
                    start_position = UDim2.new(0.5, 0, 0.5, 0),
                    end_position = UDim2.new(0.5, 0, 0.5, 0),
                    anchor_point = Vector2.new(0.5, 0.5),
                    start_transparency = 1,
                    end_transparency = 0,
                },

                fade_in_scale = {
                    name = "Fade + Scale",
                    duration = "normal",
                    easing = "ease_out",
                    direction = "out_dir",
                    start_position = UDim2.new(0.5, 0, 0.5, 0),
                    end_position = UDim2.new(0.5, 0, 0.5, 0),
                    anchor_point = Vector2.new(0.5, 0.5),
                    start_scale = 0.8,
                    end_scale = 1.0,
                    start_transparency = 1,
                    end_transparency = 0,
                },

                -- === SPECIAL EFFECTS ===
                spiral_in = {
                    name = "Spiral In",
                    duration = "slow",
                    easing = "ease_out",
                    direction = "out_dir",
                    start_position = UDim2.new(1.5, 0, -0.5, 0), -- Off-screen top-right
                    end_position = UDim2.new(0.5, 0, 0.5, 0), -- Center
                    anchor_point = Vector2.new(0.5, 0.5),
                    start_scale = 0.3,
                    end_scale = 1.0,
                    start_rotation = 360, -- Full rotation
                    end_rotation = 0,
                    start_transparency = 0.8,
                    end_transparency = 0,
                },

                zoom_blur = {
                    name = "Zoom Blur",
                    duration = "fast",
                    easing = "ease_in",
                    direction = "in_dir",
                    start_position = UDim2.new(0.5, 0, 0.5, 0),
                    end_position = UDim2.new(0.5, 0, 0.5, 0),
                    anchor_point = Vector2.new(0.5, 0.5),
                    start_scale = 3.0, -- Very large
                    end_scale = 1.0,
                    start_transparency = 0.9,
                    end_transparency = 0,
                },
            },
        },
    },

    -- === RESPONSIVE DESIGN ===
    breakpoints = {
        mobile = 600, -- Phone screens
        tablet = 900, -- Tablet screens
        desktop = 1200, -- Desktop screens
        wide = 1600, -- Wide screens
    },

    -- Inventory grid configuration has moved under panel_configs.inventory_panel.grid

    -- Responsive scaling factors
    scale_factors = {
        mobile = 0.6,
        tablet = 0.7,
        desktop = 0.8,
        wide = 0.9,
    },

    -- === COMPONENT DEFAULTS REMOVED ===
    -- These were unused and have been consolidated into the main defaults section above

    -- === SOUND EFFECTS ===
    sounds = {
        button_hover = "rbxasset://sounds/electronicpingshort.wav",
        button_click = "rbxasset://sounds/button-09.mp3",
        error = "rbxasset://sounds/electronicpingshort.wav",
        success = "rbxasset://sounds/bell-sweet.mp3",
        notification = "rbxasset://sounds/notification.mp3",

        -- Sound settings
        volume = 0.5,
        enabled = true,
    },

    -- === Z-INDEX LAYERS ===
    z_index = {
        background = 1,
        content = 10,
        dropdown = 100,
        modal = 1000,
        toast = 2000,
        tooltip = 3000,
    },

    -- === ACCESSIBILITY ===
    accessibility = {
        high_contrast_mode = false,
        reduced_motion = false,
        screen_reader_support = true,
        keyboard_navigation = true,
        focus_indicators = true,
    },

    -- === MOBILE SPECIFIC ===
    mobile = {
        touch_target_min_size = 44, -- Minimum touch target size in pixels
        swipe_threshold = 50,
        long_press_duration = 0.5,
        haptic_feedback = true,
    },

    -- === DEBUG & DEVELOPMENT ===
    debug = {
        show_bounds = false, -- Enable to visualize pane boundaries
        show_anchor_points = false, -- Show anchor point indicators
        show_backgrounds = false, -- Force show pane backgrounds for debugging
        log_interactions = false,
        performance_monitoring = true,
        component_inspector = false,
        position_validation = false, -- Validate positioning calculations
    },

    -- === ANIMATION TESTING SYSTEM ===
    -- Quick way to test different animations - just change the values below!
    -- This system allows developers to easily prototype different animation effects
    -- without modifying the main action configuration.
    animation_showcase = {
        enabled = true,

        -- Override animations for testing (set to false to use default action animations)
        -- When true: Uses test_effects below instead of action configuration
        -- When false: Uses the transition defined in each action (shop_action.transition, etc.)
        override_animations = true, -- ENABLED to showcase animation variety

        -- Test animations (when override_animations = true)
        -- Each menu name (lowercase) maps to an animation effect name
        test_effects = {
            shop = "slide_in_left", -- Try: slide_in_right, scale_in_small, spiral_in
            inventory = "flip_in", -- Try: bounce_in, elastic_in, zoom_blur
            effects = "spin_in", -- Try: slide_in_top, fade_in_scale, scale_in_large
            settings = "slide_in_bottom", -- Try: fade_in, elastic_in, bounce_in
            admin = "zoom_blur", -- Try: spiral_in, spin_in, scale_in_large
        },

        -- Available effects for easy copy/paste:
        -- All effects are defined in animations.menu_transitions.effects below
        -- SLIDES: slide_in_right, slide_in_left, slide_in_top, slide_in_bottom
        -- SCALES: scale_in_small, scale_in_large, fade_in_scale
        -- ROTATION: spin_in, flip_in, spiral_in
        -- BOUNCE: bounce_in, elastic_in
        -- FADE: fade_in, fade_in_scale, zoom_blur
        -- SPECIAL: spiral_in, zoom_blur
    },

    -- === ACTION SYSTEM (Configuration-as-Code) ===
    -- Define all button actions through configuration instead of hardcoded behavior
    actions = {
        -- Menu Panel Actions - Each with unique animation style
        shop_action = {
            type = "menu_panel",
            panel = "Shop",
            transition = "slide_in_right", -- Classic slide from right
            sound = "button_click",
            description = "Opens the shop panel with slide animation",
        },

        -- Auto-Target Actions (server-driven visual state; UI calls script actions to toggle)
        auto_target_low = {
            type = "script_execute",
            script = "AutoTargetActions",
            method = "ToggleLow",
        },
        auto_target_high = {
            type = "script_execute",
            script = "AutoTargetActions",
            method = "ToggleHigh",
        },

        -- Aliases to match BaseUI name->action convention (menuName:lower() .. "_action")
        autolow_action = {
            type = "script_execute",
            script = "AutoTargetActions",
            method = "ToggleLow",
        },
        autohigh_action = {
            type = "script_execute",
            script = "AutoTargetActions",
            method = "ToggleHigh",
        },

        inventory_action = {
            type = "menu_panel",
            panel = "Inventory",
            transition = "scale_in_small", -- Compact scale in
            sound = "button_click",
            description = "Opens inventory with scale animation",
        },

        effects_action = {
            type = "menu_panel",
            panel = "Effects",
            transition = "spiral_in", -- Dramatic spiral effect
            sound = "button_click",
            description = "Opens effects panel with spiral animation",
        },

        settings_action = {
            type = "menu_panel",
            panel = "Settings",
            transition = "fade_in_scale", -- Subtle fade + scale
            sound = "button_click",
            description = "Opens settings panel with fade animation",
        },

        admin_action = {
            type = "menu_panel",
            panel = "Admin",
            transition = "bounce_in", -- Authority bounce
            sound = "button_click",
            conditions = {
                admin_only = true,
            },
            description = "Opens admin panel with bounce animation",
        },

        -- Custom Script Actions
        pets_action = {
            -- Consolidated (Jason): Pets/Items were two buttons for the SAME inventory. One
            -- Pets button opens the Inventory panel (all categories: pets, items, enhancements);
            -- Trade lives inside that panel now (header button), not on the tray.
            type = "menu_panel",
            panel = "Inventory",
            transition = "scale_in_small",
            sound = "button_click",
            description = "Opens the unified inventory (pets/items/enhancements)",
        },

        powers_action = {
            -- The character sheet: PowerChoiceMenu in live mode (with no pending claims it
            -- shows owned powers + the ENHANCE slotting strip; picks only appear when earned).
            type = "menu_panel",
            panel = "PowerChoice",
            transition = "scale_in_small",
            sound = "button_click",
            description = "Manage your powers and slot enhancements",
        },

        rewards_action = {
            -- Rewards = the Quest panel (where met missions are claimed). Was a dead
            -- script_execute; the standalone rewards button used a hardcoded click
            -- handler for the same thing.
            type = "menu_panel",
            panel = "Quest",
            transition = "scale_in_small",
            sound = "button_click",
            description = "Open quests / claim rewards",
        },

        -- Multi-step Action Sequences
        daily_login_action = {
            type = "action_sequence",
            sequence = {
                { type = "script_execute", script = "DailyRewards", method = "CheckAvailable" },
                { type = "menu_panel", panel = "DailyRewards", transition = "elastic_in" }, -- Exciting daily reward
                { type = "script_execute", script = "Analytics", method = "LogDailyLogin" },
            },
            description = "Daily login reward flow with elastic animation",
        },

        -- Network/Remote Actions
        purchase_gems_action = {
            type = "network_call",
            service = "EconomyService",
            method = "InitiatePurchase",
            parameters = {
                product_type = "gems",
                package = "starter_pack",
            },
            confirmation = {
                enabled = true,
                title = "Purchase Confirmation",
                message = "Buy starter gem pack for 99 Robux?",
            },
            description = "Initiates gem purchase flow",
        },

        trade_action = {
            type = "menu_panel",
            panel = "Trade",
            transition = "slide_in_right",
            sound = "button_click",
            description = "Opens the player-to-player trade panel",
        },

        -- Conditional Actions
        quest_claim_action = {
            -- straight panel open (was a dead conditional referencing a QuestManager
            -- script_execute that doesn't exist — the button only worked by fallthrough)
            type = "menu_panel",
            panel = "Quest",
            transition = "scale_in_small",
            sound = "button_click",
            description = "Open quests / claim rewards",
        },

        -- Notification Actions
        achievement_action = {
            type = "notification",
            message = "Achievement unlocked!",
            notification_type = "success",
            duration = 3,
            sound = "achievement",
            description = "Shows achievement notification",
        },

        -- Debug/Development Actions
        debug_currencies_action = {
            type = "script_execute",
            script = "DebugConsole",
            method = "AddCurrencies",
            parameters = {
                coins = 1000,
                gems = 100,
                crystals = 50,
            },
            conditions = {
                debug_mode = true,
            },
            description = "Adds test currencies (debug only)",
        },
    },

    -- === PANE-BASED LAYOUT SYSTEM (Configuration-as-Code) ===
    -- Modern component-based architecture where groups of elements live in configurable "panes"
    -- Think of these as "cards" in web development - containers that hold related UI elements
    panes = {
        -- Individual Floating Currency Cards (like reference game).
        -- Legacy `coins` and `crystals` panes were removed (Pet Realm uses gems + the four
        -- soulbound biome coins). The currency ids still exist in configs/currencies.lua for
        -- back-compat; full economy retirement is a later phase (design §32).
        gems_pane = {
            position = "center-left",
            offset = { x = 15, y = -110 },
            size = { width = 120, height = 35 },
            background = {
                enabled = true,
                color = Color3.fromRGB(0, 0, 0),
                transparency = 0.15,
                corner_radius = 18,
                border = {
                    enabled = true,
                    color = Color3.fromRGB(138, 43, 226),
                    thickness = 2,
                    transparency = 0.3,
                },
            },
            layout = { type = "single" },
            contents = {
                {
                    type = "currency_display",
                    config = {
                        currency = "gems",
                        icon = "136309678310342",
                        color = Color3.fromRGB(138, 43, 226),
                        icon_config = {
                            size = { width = 32, height = 32 },
                            position = "left_outside",
                            offset = { x = -10, y = 0 },
                        },
                    },
                },
            },
        },

        -- Pet Realm biome coins (zone economy, design §32). Soulbound, mined per zone.
        -- The server mirrors every currency to a Player attribute generically, so these
        -- update automatically when mined. Stacked below gems (y 40/76/112/148).
        -- NOTE (future, deferred): when the player ENTERS a zone, that zone's coin could
        -- become prominent (larger/brighter/front) while the other three shrink + dim.
        grass_coins_pane = {
            position = "center-left",
            offset = { x = 15, y = -74 },
            size = { width = 120, height = 32 },
            background = {
                enabled = true,
                color = Color3.fromRGB(0, 0, 0),
                transparency = 0.15,
                corner_radius = 18,
                border = {
                    enabled = true,
                    color = Color3.fromRGB(90, 210, 80),
                    thickness = 2,
                    transparency = 0.3,
                },
            },
            layout = { type = "single" },
            contents = {
                {
                    type = "currency_display",
                    config = {
                        currency = "grass_coins",
                        icon = "🌿",
                        color = Color3.fromRGB(90, 210, 80),
                    },
                },
            },
        },
        desert_coins_pane = {
            position = "center-left",
            offset = { x = 15, y = -38 },
            size = { width = 120, height = 32 },
            background = {
                enabled = true,
                color = Color3.fromRGB(0, 0, 0),
                transparency = 0.15,
                corner_radius = 18,
                border = {
                    enabled = true,
                    color = Color3.fromRGB(214, 184, 130),
                    thickness = 2,
                    transparency = 0.3,
                },
            },
            layout = { type = "single" },
            contents = {
                {
                    type = "currency_display",
                    config = {
                        currency = "desert_coins",
                        icon = "🏜️",
                        color = Color3.fromRGB(214, 184, 130),
                    },
                },
            },
        },
        lava_coins_pane = {
            position = "center-left",
            offset = { x = 15, y = -2 },
            size = { width = 120, height = 32 },
            background = {
                enabled = true,
                color = Color3.fromRGB(0, 0, 0),
                transparency = 0.15,
                corner_radius = 18,
                border = {
                    enabled = true,
                    color = Color3.fromRGB(255, 110, 30),
                    thickness = 2,
                    transparency = 0.3,
                },
            },
            layout = { type = "single" },
            contents = {
                {
                    type = "currency_display",
                    config = {
                        currency = "lava_coins",
                        icon = "🌋",
                        color = Color3.fromRGB(255, 110, 30),
                    },
                },
            },
        },
        ice_coins_pane = {
            position = "center-left",
            offset = { x = 15, y = 34 },
            size = { width = 120, height = 32 },
            background = {
                enabled = true,
                color = Color3.fromRGB(0, 0, 0),
                transparency = 0.15,
                corner_radius = 18,
                border = {
                    enabled = true,
                    color = Color3.fromRGB(150, 220, 255),
                    thickness = 2,
                    transparency = 0.3,
                },
            },
            layout = { type = "single" },
            contents = {
                {
                    type = "currency_display",
                    config = {
                        currency = "ice_coins",
                        icon = "🧊",
                        color = Color3.fromRGB(150, 220, 255),
                    },
                },
            },
        },

        -- Player Info Pane (top-center - Colorado Plays, Level, XP)
        player_info_pane = {
            position = "top-center",
            offset = { x = 0, y = 35 },
            size = { width = 300, height = 80 },
            background = {
                enabled = true,
                color = Color3.fromRGB(0, 0, 0),
                transparency = 0.3,
                corner_radius = 12,
                border = {
                    enabled = true,
                    color = Color3.fromRGB(255, 255, 255),
                    thickness = 1,
                    transparency = 0.7,
                },
            },
            layout = {
                type = "single",
            },
            contents = {
                { type = "player_info", config = {} },
            },
        },

        -- Quest Tracker Pane (top-right, clear background — out of the way of the
        -- center-right squad HUD strip).
        quest_tracker_pane = {
            position = "top-right",
            offset = { x = -15, y = 10 },
            size = { width = 350, height = 120 },
            background = {
                enabled = false, -- Completely disabled background for full transparency
            },
            layout = {
                type = "single",
            },
            contents = {
                { type = "quest_tracker", config = {} },
            },
        },

        -- Menu Buttons Pane (bottom-left) - Auto-sizing grid that adapts to content
        menu_buttons_pane = {
            position = "bottom-left",
            -- zero offset: the semantic bottom-left base is (15, -15), so the tray's left edge
            -- aligns with the coin stack (x=15) and the bottom gap equals the left gap.
            offset = { x = 0, y = 0 },
            size = { width = 200, height = 135 }, -- snug 2x3: cells hug the ~60px buttons (no gaps)
            background = { enabled = false }, -- Debug backgrounds will handle visualization
            layout = {
                type = "grid",
                auto_size = true, -- Enable automatic sizing based on content
                button_count = 6, -- Daily/Quest/Shop/Effects/Settings + adopted Rewards (2x3);
                -- Admin floats above the tray (admin-only), Pets/Powers flank the hotbar
                -- left/bottom zero so the buttons sit flush on the pane's anchored corner
                padding = { top = 5, bottom = 0, left = 0, right = 5 },
            },
            contents = {
                -- 🌟 UNIVERSAL CONSISTENCY SYSTEM! 🌟
                -- 🎨 ONE IMAGE RULES ALL: Every button gets teal panel background (16809347055) automatically!
                -- 📏 GLOBAL DEFAULTS: Consistent icon sizing, text styling, positioning across ALL buttons
                -- ⚡ MINIMAL CONFIG: Most buttons need only 4 lines (name, icon, text, action)!
                -- 🎯 SELECTIVE OVERRIDES: Still allows custom styling when needed (shop, admin, special buttons)
                --
                -- RESULT: 90% consistency with 10% customization effort! Perfect for importing professional GUIs.

                -- 🐾 PETS: the player's main button — first in the tray. Routes to
                -- "pets_action" by name (the same action the old standalone pane used).
                {
                    type = "menu_button",
                    config = {
                        name = "Pets",
                        icon_fallback = "🐾", -- (old 13262136255 was a full-button image, not an icon)
                        text = "Pets",
                        action = "pets_action",
                    },
                },

                -- Character/powers menu (Jason): the SAME PowerChoice panel the level-up
                -- flow uses, but openable anywhere — manage owned powers + slot enhancements.
                {
                    type = "menu_button",
                    config = {
                        name = "Powers",
                        icon_fallback = "💥",
                        text = "Powers",
                        action = "powers_action",
                    },
                },

                -- (Shop button pulled — Jason, playtest audit: the catalog is Phase-7
                -- placeholder priced in dead legacy coins. Panel stays registered;
                -- re-add this entry when a real catalog lands.)

                -- (Effects button pulled — Jason: its only live content source was the
                -- placeholder shop's timed boost, and the buff-readout HUD shows active
                -- multipliers. Panel stays registered for when timed effects are real.)

                -- 🔵 ULTRA-MINIMAL: Just icon, text, action - everything else from global defaults
                {
                    type = "menu_button",
                    config = {
                        name = "Settings",
                        icon = "⚙️",
                        text = "Settings",
                        action = "settings_action",
                        -- 🎨 Automatically gets: teal background, default colors, default layout!
                    },
                },

                -- ⭐ NOTIFICATION EXAMPLE: Simple notification that inherits default styling
                {
                    type = "menu_button",
                    config = {
                        name = "Daily",
                        icon = "📅",
                        text = "Daily",
                        action = "daily_login_action",
                        -- the "!" badge is DYNAMIC now (BaseUI polls daily.status): it only
                        -- shows when a claim is actually waiting (Jason: a permanent ! trains
                        -- players to ignore it)
                        -- 🎨 Automatically gets: teal background, default icon/text styling!
                    },
                },

                -- 🚀 ABSOLUTE MINIMAL: 4 lines = professional button!
                {
                    type = "menu_button",
                    config = {
                        name = "Quest",
                        icon = "🎯",
                        text = "Quest",
                        action = "quest_claim_action",
                        -- 🎨 100% global defaults = instant professional styling!
                    },
                },

                -- EVENTS: opens the Effects panel (global events). Stacked label (text_top) so it reads
                -- "<top> / 📅 / <bottom>"; EventLiveLabel fills both lines live with the active event
                -- name + a glow (e.g. "Secret" / 📅 / "Sunday"). No action -> opens the "Effects" panel
                -- by name. Inherits the default tray theme like Settings/Daily/Quest.
                {
                    type = "menu_button",
                    config = {
                        name = "Effects",
                        icon = "📅",
                        text = "Events",
                        text_top = "",
                    },
                },

                -- AWARDS: opens the Achievements panel by name (no action = open same-named panel, like
                -- Effects). The passive-milestone counterpart to the Quest button (Jason).
                {
                    type = "menu_button",
                    config = {
                        name = "Achievements",
                        icon = "🏆",
                        text = "Awards",
                    },
                },

                -- ADMIN is LAST in the grid (Jason): the grid fills bottom-to-top / left-to-right, so
                -- the highest LayoutOrder lands in the final cell — no floating/docking needed (that
                -- overlapped the new Events button). admin_only hides it for non-admins, leaving the
                -- grid clean.
                {
                    type = "menu_button",
                    config = {
                        name = "Admin",
                        icon = "6031068421",
                        text = "Admin",
                        action = "admin_action",
                        admin_only = true,
                    },
                },

                -- (Rewards button removed — it opened the SAME Quest panel; the claim
                -- badge lives on the Quest button now. rewards_action stays defined for
                -- anything else that routes through it.)
            },
        },

        -- Single Button Panes - All aligned to same bottom edge

        -- (auto_low/auto_high panes removed — farming Off/Low/High is now the cycle
        -- button on the left of the lower-center power hotbar; see HotbarBar.lua.)

        -- Available positions: "top-left", "top-center", "top-right",
        --                     "center-left", "center", "center-right",
        --                     "bottom-left", "bottom-center", "bottom-right"
        --
        -- Layout types: "list", "grid", "single", "custom"
        -- Background: Fully configurable colors, transparency, borders
        -- Contents: Array of UI elements with their own configurations
    },

    -- === PANEL CONFIGURATIONS (Image-based panels) ===
    -- 🎯 OVERRIDE EXAMPLES: How to customize specific panels when needed
    -- Most panels will automatically use the global defaults above ⬆️
    --
    -- ✨ STANDARDIZED CLOSE BUTTON SYSTEM:
    -- ALL panels automatically get the close button from global defaults unless explicitly disabled
    -- - Icon: 89257673063270 (new X button asset)
    -- - Position: top-right-corner extending outside panel bounds
    -- - Hover effects: automatic red -> darker red transitions
    -- - No additional configuration needed per panel!
    --
    -- 🔄 ICON FALLBACK SYSTEM:
    -- Use 'icon' for asset ID and 'icon_fallback' for emoji/text backup
    -- - If asset fails to load, automatically switches to fallback
    -- - Example: icon = "12345", icon_fallback = "🎒"
    panel_configs = {
        -- 🟢 USES GLOBAL DEFAULTS: Settings panel inherits everything from defaults
        settings_panel = {
            header = {
                icon = "1003379313", -- Gear icon (only override needed)
                title_text = "Settings", -- Title text (only override needed)
                -- Everything else comes from global defaults!
            },
            settings = {
                -- Settings-specific overrides for toggles
                toggle_on = "5533192672", -- ON button toggle
                toggle_off = "5533209494", -- OFF button toggle
                setting_height = 55,
            },
        },

        -- 🟢 USES GLOBAL DEFAULTS: Inventory panel inherits everything including close button
        inventory_panel = {
            header = {
                icon = "85179217604910", -- 🎨 NEW: Custom inventory bag icon
                icon_fallback = "🎒", -- 🔄 FALLBACK: Backpack emoji if asset fails
                icon_size = { scale = 1.0 }, -- 🎨 BIGGER: 115% of header height (scales with screen)
                icon_position = "top-left-corner", -- 🎯 POSITION: Top-left corner with anchor (0,0)
                title_text = "Inventory", -- Custom title
                -- Background images and close button come from global defaults!
            },
            -- Card/grid sizing controls used by InventoryPanel
            grid = {
                card_size = Vector2.new(65, 65),
                card_padding = Vector2.new(8, 8),
                -- Absolute icon size (inside each card). If omitted, icon scales with card.
                -- You can also use `icon_scale` to size the icon as a percentage of the card
                -- (takes precedence if provided here; see InventoryPanel for logic).
                -- Explicit size overrides scale if provided
                --icon_size = Vector2.new(56, 56),
                icon_scale = 0.85, -- used when icon_size is not provided

                -- NEW: Label layout controls for better separation and readability
                name_label = {
                    height_scale = 0.18, -- portion of card height reserved for name text
                    bottom_offset_scale = 0.40, -- distance from bottom of card
                    font = Enum.Font.GothamBold,
                    color = Color3.fromRGB(255, 255, 255),
                },
                power_label = {
                    height_scale = 0.14,
                    bottom_offset_scale = 0.22,
                    font = Enum.Font.Gotham,
                    prefix = "⚡ ",
                    color_from_rarity = true,
                },
            },
        },

        -- 🔴 FULL OVERRIDE EXAMPLE: Admin panel completely different styling
        admin_panel = {
            background = {
                image = "16809347055", -- 🎨 OVERRIDE: Teal instead of blue
                corner_radius = 20, -- 🎨 OVERRIDE: Different corner radius
            },
            header = {
                height = 80, -- 🎨 OVERRIDE: Taller header
                background_image = "6208057940", -- 🎨 OVERRIDE: Blue header for contrast
                icon = "👑", -- 🎨 OVERRIDE: Admin crown icon
                icon_position = "center", -- 🎨 OVERRIDE: Centered icon
                title_text = "Admin Panel",
                title_color = Color3.fromRGB(255, 215, 0), -- 🎨 OVERRIDE: Gold title
            },
        },

        -- 🟣 SPECIAL THEME EXAMPLE: Shop panel with unique styling
        shop_panel = {
            background = {
                image = "18852000893", -- 🎨 OVERRIDE: Special shop background
                corner_radius = 12,
            },
            header = {
                background_image = "18852000893", -- 🎨 OVERRIDE: Match background
                icon = "🛒",
                title_text = "Shop",
                title_color = Color3.fromRGB(255, 215, 0), -- Gold text for shop
            },
        },

        -- 💡 HOW IT WORKS:
        -- • panels with NO CONFIG = 100% global defaults (blue panel + teal header)
        -- • panels with PARTIAL CONFIG = global defaults + your overrides
        -- • panels with FULL CONFIG = completely custom (but still inherits unspecified properties)
        --
        -- This means 90% of your panels will be visually consistent with ZERO configuration! 🎉
    },

    -- === COMPLEX MENU VIEWS (Multi-view Panes) ===
    -- For menus that can switch between different content views
    menu_views = {
        shop_panel = {
            default_view = "featured",
            views = {
                featured = {
                    name = "Featured",
                    icon = "⭐",
                    layout = { type = "grid", columns = 3, rows = 4 },
                    contents = {
                        -- Featured items configuration
                    },
                },
                pets = {
                    name = "Pets",
                    icon = "🐾",
                    layout = { type = "grid", columns = 4, rows = 5 },
                    contents = {
                        -- Pet items configuration
                    },
                },
                boosts = {
                    name = "Boosts",
                    icon = "⚡",
                    layout = { type = "list", direction = "vertical" },
                    contents = {
                        -- Boost items configuration
                    },
                },
            },
        },
    },

    -- === HELPER FUNCTIONS ===
    helpers = {
        -- Get current theme colors
        get_theme = function(config)
            return config.themes[config.active_theme] or config.themes.dark
        end,

        -- Get responsive scale factor
        get_scale_factor = function(config, screen_size)
            local width = screen_size and screen_size.X or 1200

            if width <= config.breakpoints.mobile then
                return config.scale_factors.mobile
            elseif width <= config.breakpoints.tablet then
                return config.scale_factors.tablet
            elseif width <= config.breakpoints.desktop then
                return config.scale_factors.desktop
            else
                return config.scale_factors.wide
            end
        end,

        -- Convert spacing key to UDim
        get_spacing = function(config, key)
            local value = config.spacing[key] or config.spacing.md
            return UDim.new(0, value)
        end,

        -- Convert radius key to UDim
        get_radius = function(config, key)
            local value = config.radius[key] or config.radius.md
            return UDim.new(0, value)
        end,

        -- NEW: Template system helpers
        get_template_path = function(config, template_name)
            return config.templates.storage_path .. "." .. template_name
        end,

        get_asset_id = function(config, category, key)
            local assets = config.templates.assets[category]
            return assets and assets[key] or "rbxassetid://0"
        end,

        get_template_config = function(config, template_type)
            local templates = config and config.templates
            local defaults = templates and templates.defaults
            if defaults and defaults[template_type] then
                return defaults[template_type]
            end
            return {}
        end,

        format_currency = function(config, amount)
            if amount >= 1000000 then
                return string.format("%.1fM", amount / 1000000)
            elseif amount >= 1000 then
                return string.format("%.1fK", amount / 1000)
            else
                return tostring(amount)
            end
        end,

        -- NEW: Pane system helpers
        get_pane_config = function(config, paneName)
            return config.panes and config.panes[paneName] or nil
        end,

        get_all_panes = function(config)
            return config.panes or {}
        end,

        get_menu_view_config = function(config, menuName, viewName)
            local menu = config.menu_views and config.menu_views[menuName]
            if menu and menu.views then
                return menu.views[viewName] or menu.views[menu.default_view]
            end
            return nil
        end,

        -- === ACTION SYSTEM HELPERS ===

        -- Get action configuration by name
        get_action_config = function(config, actionName)
            return config.actions and config.actions[actionName] or nil
        end,

        -- Get all available actions
        get_all_actions = function(config)
            return config.actions or {}
        end,

        -- Check if action conditions are met
        check_action_conditions = function(config, actionConfig, playerState)
            if not actionConfig.conditions then
                return true
            end

            -- Check admin_only condition
            if actionConfig.conditions.admin_only and not playerState.is_admin then
                return false
            end

            -- Check debug_mode condition
            if actionConfig.conditions.debug_mode and not playerState.debug_mode then
                return false
            end

            -- Check quest completion
            if actionConfig.conditions.quest_completed and not playerState.quest_completed then
                return false
            end

            -- Check if not claimed
            if actionConfig.conditions.not_claimed and playerState.already_claimed then
                return false
            end

            return true
        end,

        -- Execute action by name (helper for UI system)
        execute_action = function(config, actionName, playerState, actionHandler)
            local actionConfig = config.helpers.get_action_config(config, actionName)
            if not actionConfig then
                warn("Action not found:", actionName)
                return false
            end

            -- Check conditions
            if
                not config.helpers.check_action_conditions(config, actionConfig, playerState or {})
            then
                warn("Action conditions not met:", actionName)
                return false
            end

            -- Execute action through handler
            if actionHandler and actionHandler.executeAction then
                return actionHandler:executeAction(actionConfig)
            end

            warn("No action handler provided for:", actionName)
            return false
        end,

        -- Get actions by type
        get_actions_by_type = function(config, actionType)
            local actions = {}
            for name, actionConfig in pairs(config.actions or {}) do
                if actionConfig.type == actionType then
                    actions[name] = actionConfig
                end
            end
            return actions
        end,

        -- === AUTO-SIZING GRID HELPERS ===

        -- Calculate optimal grid dimensions and button sizes for a given container and button count
        calculate_auto_grid = function(
            config,
            containerWidth,
            containerHeight,
            buttonCount,
            padding
        )
            padding = padding or { top = 3, bottom = 3, left = 3, right = 3 }
            local spacing = 3

            -- Calculate available space after padding
            local availableWidth = containerWidth - padding.left - padding.right
            local availableHeight = containerHeight - padding.top - padding.bottom

            -- Find optimal grid dimensions
            local bestCols = 4 -- Start with 4 columns as preference
            local bestRows = math.ceil(buttonCount / bestCols)

            -- Try different column counts to find best fit
            for cols = 3, 5 do
                local rows = math.ceil(buttonCount / cols)
                if cols * rows >= buttonCount then
                    -- Calculate required space for this configuration
                    local reqWidth = cols * 50 + (cols - 1) * spacing -- minimum 50px buttons
                    local reqHeight = rows * 50 + (rows - 1) * spacing

                    if reqWidth <= availableWidth and reqHeight <= availableHeight then
                        bestCols = cols
                        bestRows = rows
                        break
                    end
                end
            end

            -- Calculate optimal button size
            local buttonWidth = math.floor((availableWidth - (bestCols - 1) * spacing) / bestCols)
            local buttonHeight = math.floor((availableHeight - (bestRows - 1) * spacing) / bestRows)

            -- Ensure minimum button size
            buttonWidth = math.max(buttonWidth, 45)
            buttonHeight = math.max(buttonHeight, 45)

            return {
                columns = bestCols,
                rows = bestRows,
                cell_size = { width = buttonWidth, height = buttonHeight },
                spacing = spacing,
                padding = padding,
                info = {
                    button_count = buttonCount,
                    available_size = { width = availableWidth, height = availableHeight },
                    calculated_button_size = { width = buttonWidth, height = buttonHeight },
                },
            }
        end,
    }, -- Close helpers table
} -- Close the main uiConfig table

-- 🎉 UNIVERSAL CONSISTENCY SYSTEM - Successfully loaded!

return uiConfig
