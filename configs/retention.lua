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
    -- v7: onboarding ends at Rally. Optional first quest / First Steps / first
    -- area move to the Activation named funnel so they are not compared as
    -- mandatory tutorial steps. Combat-training beats stay in onboarding.
    -- Roblox onboarding allows 100 steps; skipped steps count as completed.
    version = 7,
    onboarding = {
        enabled = true,
        steps = {
            { id = "joined", name = "Joined game", event = "retention_joined" },
            {
                id = "tutorial_hatch_first_egg",
                name = "Tutorial: Hatch first egg",
                event = "tutorial_step_completed",
                match = { stepId = "hatch_first_egg" },
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
                id = "tutorial_build_squad",
                name = "Tutorial: Build squad",
                event = "tutorial_step_completed",
                match = { stepId = "build_squad" },
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
                -- Stable live milestone ID retained for the Resonance-enhance lesson.
                id = "tutorial_completed",
                name = "Tutorial: Enhance Resonance / Complete",
                event = "tutorial_step_completed",
                match = { stepId = "slot_power" },
            },
            {
                id = "combat_ready",
                name = "Combat: Ready to fight",
                event = "tutorial_step_completed",
                match = { stepId = "combat_ready" },
            },
            {
                id = "combat_first_fight",
                name = "Combat: First training dog",
                event = "tutorial_step_completed",
                match = { stepId = "combat_first_fight" },
            },
            {
                id = "combat_advance_stage",
                name = "Combat: First pillar",
                event = "tutorial_step_completed",
                match = { stepId = "combat_advance_stage" },
            },
            {
                id = "combat_battle_brew",
                name = "Combat: Drink Berserk Brew",
                event = "tutorial_step_completed",
                match = { stepId = "combat_battle_brew" },
            },
            {
                id = "combat_ready_brew",
                name = "Combat: Enter brew fight",
                event = "tutorial_step_completed",
                match = { stepId = "combat_ready_brew" },
            },
            {
                id = "combat_brew_fight",
                name = "Combat: Brew fight",
                event = "tutorial_step_completed",
                match = { stepId = "combat_brew_fight" },
            },
            {
                id = "combat_advance_brew",
                name = "Combat: Brew pillar",
                event = "tutorial_step_completed",
                match = { stepId = "combat_advance_brew" },
            },
            {
                id = "combat_bind_heal",
                name = "Combat: Bind Heal",
                event = "tutorial_step_completed",
                match = { stepId = "combat_bind_heal" },
            },
            {
                id = "combat_ready_heal",
                name = "Combat: Enter heal fight",
                event = "tutorial_step_completed",
                match = { stepId = "combat_ready_heal" },
            },
            {
                id = "combat_select_pet",
                name = "Combat: Choose who to heal",
                event = "tutorial_step_completed",
                match = { stepId = "combat_select_pet" },
            },
            {
                id = "combat_cast_heal",
                name = "Combat: Cast Heal",
                event = "tutorial_step_completed",
                match = { stepId = "combat_cast_heal" },
            },
            {
                id = "combat_heal_fight",
                name = "Combat: Finish heal room",
                event = "tutorial_step_completed",
                match = { stepId = "combat_heal_fight" },
            },
            {
                id = "combat_advance_heal",
                name = "Combat: Heal pillar",
                event = "tutorial_step_completed",
                match = { stepId = "combat_advance_heal" },
            },
            {
                id = "combat_ready_weaken",
                name = "Combat: Enter weaken fight",
                event = "tutorial_step_completed",
                match = { stepId = "combat_ready_weaken" },
            },
            {
                id = "combat_select_enemy",
                name = "Combat: Choose who to weaken",
                event = "tutorial_step_completed",
                match = { stepId = "combat_select_enemy" },
            },
            {
                id = "combat_throw_weaken",
                name = "Combat: Throw Weakening Vial",
                event = "tutorial_step_completed",
                match = { stepId = "combat_throw_weaken" },
            },
            {
                id = "combat_weaken_fight",
                name = "Combat: Finish weaken room",
                event = "tutorial_step_completed",
                match = { stepId = "combat_weaken_fight" },
            },
            {
                id = "combat_advance_weaken",
                name = "Combat: Weaken pillar",
                event = "tutorial_step_completed",
                match = { stepId = "combat_advance_weaken" },
            },
            {
                id = "combat_stack_brew",
                name = "Combat: Stack Berserk Brews",
                event = "tutorial_step_completed",
                match = { stepId = "combat_stack_brew" },
            },
            {
                id = "combat_ready_stack",
                name = "Combat: Enter stacked fight",
                event = "tutorial_step_completed",
                match = { stepId = "combat_ready_stack" },
            },
            {
                id = "combat_stack_fight",
                name = "Combat: Stacked brew fight",
                event = "tutorial_step_completed",
                match = { stepId = "combat_stack_fight" },
            },
            {
                id = "combat_advance_stack",
                name = "Combat: Stack pillar",
                event = "tutorial_step_completed",
                match = { stepId = "combat_advance_stack" },
            },
            {
                id = "combat_ready_tank",
                name = "Combat: Equip a tank",
                event = "tutorial_step_completed",
                match = { stepId = "combat_ready_tank" },
            },
            {
                id = "combat_tank_fight",
                name = "Combat: Tank fight",
                event = "tutorial_step_completed",
                match = { stepId = "combat_tank_fight" },
            },
            {
                id = "combat_advance_tank",
                name = "Combat: Tank pillar",
                event = "tutorial_step_completed",
                match = { stepId = "combat_advance_tank" },
            },
            {
                id = "combat_ready_healer",
                name = "Combat: Enter healer room",
                event = "tutorial_step_completed",
                match = { stepId = "combat_ready_healer" },
            },
            {
                id = "combat_healer_hunt",
                name = "Combat: Kill the healer",
                event = "tutorial_step_completed",
                match = { stepId = "combat_healer_hunt" },
            },
            {
                id = "combat_healer_fight",
                name = "Combat: Finish healer room",
                event = "tutorial_step_completed",
                match = { stepId = "combat_healer_fight" },
            },
            {
                id = "combat_advance_healer",
                name = "Combat: Healer pillar",
                event = "tutorial_step_completed",
                match = { stepId = "combat_advance_healer" },
            },
            {
                id = "combat_ready_together",
                name = "Combat: Enter last room",
                event = "tutorial_step_completed",
                match = { stepId = "combat_ready_together" },
            },
            {
                id = "combat_together_fight",
                name = "Combat: Unguided room",
                event = "tutorial_step_completed",
                match = { stepId = "combat_together_fight" },
            },
            {
                id = "combat_advance_together",
                name = "Combat: Last pillar",
                event = "tutorial_step_completed",
                match = { stepId = "combat_advance_together" },
            },
            {
                id = "tutorial_first_fight",
                name = "Tutorial: Finish cave combat training",
                event = "tutorial_step_completed",
                match = { stepId = "first_fight" },
            },
            {
                id = "tutorial_rally_call",
                name = "Tutorial: Use Rally / Complete",
                event = "tutorial_step_completed",
                match = { stepId = "rally_call" },
            },
        },
    },
    -- Optional post-tutorial goals. Sequential onboarding cannot measure these
    -- fairly: Roblox treats skipped steps as complete, and first quest is not
    -- required. This named funnel starts at join so conversion is of all
    -- players, not of tutorial finishers.
    activation = {
        enabled = true,
        name = "Activation",
        steps = {
            { id = "joined", name = "Joined game", event = "retention_joined" },
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
        schema_version = 2,
        write_in_studio = false,
        flush_seconds = 15,
        events_per_chunk = 100,
        max_context_depth = 5,
        max_table_items = 200,
        max_string_length = 256,
    },
    dashboard = {
        enabled = true,
        name = "RetentionDashboard_v1",
        schema_version = 2,
        write_in_studio = false,

        -- Cohort-attributed distinct retention begins at this UTC date. Older profiles are not
        -- opportunistically backfilled because their historical return windows may already have
        -- happened and would make the rates incomplete in a non-obvious way.
        distinct_retention_start_utc = "20260816",

        -- A small, fixed key set is intentionally used instead of one global hot key or a
        -- ListKeysAsync scan. Each server replaces its absolute contribution in one deterministic
        -- bucket; an admin read merges these 16 known keys.
        bucket_count = 16,

        -- Quick launch reads exclude internal accounts before counters increment.
        -- Colorado is ID-only (see configs/internal_accounts.lua); other families
        -- may still use the prefixes listed there. Raw RetentionEvents_v1 stays.
    },
}
