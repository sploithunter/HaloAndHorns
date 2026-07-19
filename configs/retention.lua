--[[
    retention — first-session activation measurement.

    Funnel steps are intentionally stable and append-only once live. Roblox attributes an
    onboarding funnel to the player's entry cohort and treats skipped steps as completed, so
    RetentionService queues out-of-order achievements and only submits the contiguous prefix.

    Every milestone is also persisted under profile.Analytics.Retention.Milestones. This gives
    support/admin investigation an exact per-player record while Roblox Analytics supplies the
    aggregate funnel and retention dashboards.
]]

return {
    version = 1,
    onboarding = {
        enabled = true,
        steps = {
            { id = "joined", name = "Joined game", event = "retention_joined" },
            {
                id = "tutorial_hatch_first_egg",
                name = "Tutorial: Hatch first pet",
                event = "tutorial_step_completed",
                match = { stepId = "hatch_first_egg" },
            },
            {
                id = "tutorial_equip_pet",
                name = "Tutorial: Deploy pet",
                event = "tutorial_step_completed",
                match = { stepId = "equip_pet" },
            },
            {
                id = "tutorial_farm_crystals",
                name = "Tutorial: Mine crystals",
                event = "tutorial_step_completed",
                match = { stepId = "farm_crystals" },
            },
            {
                id = "tutorial_hatch_another",
                name = "Tutorial: Grow team",
                event = "tutorial_step_completed",
                match = { stepId = "hatch_another" },
            },
            {
                id = "tutorial_first_fight",
                name = "Tutorial: Win first fight",
                event = "tutorial_step_completed",
                match = { stepId = "first_fight" },
            },
            {
                id = "tutorial_battle_brew",
                name = "Tutorial: Use battle brew",
                event = "tutorial_step_completed",
                match = { stepId = "battle_brew" },
            },
            {
                id = "tutorial_rally_call",
                name = "Tutorial: Use Rally",
                event = "tutorial_step_completed",
                match = { stepId = "rally_call" },
            },
            {
                id = "tutorial_bind_power",
                name = "Tutorial: Bind Resonance",
                event = "tutorial_step_completed",
                match = { stepId = "bind_power" },
            },
            {
                id = "tutorial_cast_power",
                name = "Tutorial: Cast Resonance",
                event = "tutorial_step_completed",
                match = { stepId = "cast_power" },
            },
            {
                id = "tutorial_completed",
                name = "Tutorial complete",
                event = "tutorial_step_completed",
                match = { stepId = "slot_power" },
            },
            {
                id = "first_quest_completed",
                name = "First quest complete",
                event = "quest_complete",
                match = { quest = "fs_boost" },
            },
            {
                id = "first_steps_completed",
                name = "First Steps complete",
                event = "quest_complete",
                match = { quest = "fs_cave" },
            },
            {
                id = "first_area_unlocked",
                name = "First area unlocked",
                event = "area_unlocked",
            },
        },
    },
    custom_event = {
        enabled = true,
        name = "RetentionMilestone",
    },
    event_store = {
        enabled = true,
        name = "RetentionEvents_v1",
        schema_version = 1,
        write_in_studio = false,
        flush_seconds = 15,
        events_per_chunk = 100,
        max_context_depth = 5,
        max_table_items = 200,
        max_string_length = 256,
    },
}
