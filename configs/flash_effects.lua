-- Flash effects configuration for egg reveal phase
-- These effects are lightweight UI-based animations rendered inside the egg frame.

local config = {
    default_effect = "sparkle", -- Options: starburst, shockwave, confetti

    -- Global sound settings for egg open (prefer named asset preloads)
    sound = {
        sound_name = "egg_hatch_pop", -- references configs/sounds.lua and Assets.Sounds
        sound_id = "rbxassetid://86006129075096", -- fallback if not preloaded
        volume = 0.8,
        playback_speed = 1.0,
    },

    effects = {
        starburst = {
            type = "starburst",
            name = "Starburst",
            config = {
                star_count = 20,
                min_size = 18,
                max_size = 90,
                expansion_distance = 320,
                duration = 0.85,
                colors = {
                    Color3.fromRGB(255, 255, 255),
                    Color3.fromRGB(255, 240, 160),
                    Color3.fromRGB(255, 200, 120),
                    Color3.fromRGB(255, 150, 60),
                },
                rotation_speed = 360,
                fade_in_time = 0.1,
                fade_out_time = 0.3,
            },
        },

        sparkle = {
            type = "sparkle",
            name = "Sparkle Burst",
            config = {
                duration = 0.9,
                sparkle_count = 36,
                size = NumberRange.new(8, 18),
                spread_distance = 240,
                colors = {
                    Color3.fromRGB(255, 255, 255),
                    Color3.fromRGB(255, 240, 200),
                    Color3.fromRGB(200, 220, 255),
                },
                -- Pulsating sparkle brightness (size + transparency oscillation)
                pulsate = true,
                pulsate_rate = 0.16, -- seconds per half-cycle
                pulsate_scale_min = 0.8, -- min scale vs base size
                pulsate_scale_max = 1.25, -- max scale vs base size
                alpha_min = 0.1, -- brightest (less transparent)
                alpha_max = 0.4, -- dimmest (more transparent)
            },
        },

        shockwave = {
            type = "shockwave",
            name = "Shockwave Ring",
            config = {
                duration = 0.7,
                start_radius = 40,
                end_radius = 420,
                stroke_thickness = 6,
                color = Color3.fromRGB(255, 255, 255),
                fade_out_time = 0.25,
                rings = 2,
                ring_delay = 0.08,
            },
        },

        confetti = {
            type = "confetti",
            name = "Confetti Pop",
            config = {
                duration = 1.2,
                piece_count = 40,
                piece_size = NumberRange.new(6, 12),
                spread_distance = 280,
                fall_distance = 160,
                colors = {
                    Color3.fromRGB(255, 99, 71),
                    Color3.fromRGB(255, 215, 0),
                    Color3.fromRGB(50, 205, 50),
                    Color3.fromRGB(64, 224, 208),
                    Color3.fromRGB(30, 144, 255),
                    Color3.fromRGB(218, 112, 214),
                },
            },
        },
    },
}

return config
