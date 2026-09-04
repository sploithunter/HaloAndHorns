-- Client-only quality policy. These settings never change server/world authority.
return {
    shadows = {
        default_mode = "auto",
        modes = { "auto", "on", "off" },
        label = "Shadows",
        options = {
            { value = "auto", display = "Auto (Nearby)" },
            { value = "on", display = "On (Nearby)" },
            { value = "off", display = "Off" },
        },
        -- Distance to the nearest point of a part, not its center. Large nearby
        -- walls/floors still cast shadows even when their pivots are far away.
        near_studs = 100,
        far_studs = 120,
        update_seconds = 0.5,
        sample_seconds = 1,
        warmup_seconds = 10,
        disable_below_fps = 35,
        recover_above_fps = 55,
        slow_seconds = 5,
        recovery_seconds = 20,
        cooldown_seconds = 60,
        max_sample_frame_seconds = 0.25,
    },
}
