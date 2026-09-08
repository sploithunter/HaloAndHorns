-- Shared audio preferences and bus limits. Slider levels are stored from 0 to 1.
return {
    voices = {
        label = "Voices Volume",
        default_level = 0.5,
        min_level = 0,
        max_level = 1,
        curve_exponent = 2,
        maximum_gain = 4,
        slider_step = 0.01,
        endpoint_snap_fraction = 0.03,
    },
    buses = {
        effects = { name = "Effects", default_volume = 1, maximum_volume = 1 },
        music = { name = "Music", default_volume = 1, maximum_volume = 1 },
        ui = { name = "UI", default_volume = 1, maximum_volume = 1 },
        voices = { name = "Voices", default_volume = 1, maximum_volume = 4 },
    },
}
