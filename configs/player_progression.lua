-- Player progression tuning.
-- Total XP (profile.Stats.Experience) is the single source of truth; the player's
-- LEVEL is derived from it via the `xp` curve below (pure: src/Shared/Game/LevelCurve.lua).
-- This config also defines how that level affects gameplay.

return {
    version = "1.0.0",
    enabled = true,

    -- XP -> level curve. `mode` picks the cost of advancing from level n to n+1:
    --   "linear" (default): per_level * n   (1->2 costs per_level, 2->3 costs 2*per_level, ...)
    --   "flat":             per_level        (every level costs the same)
    -- Total XP to REACH level L is the running sum of the step costs below it.
    xp = {
        mode = "linear",
        -- per_level=700: L2=700, L3=2100, L4=4200, L5=7000 (step n->n+1 = per_level*n). Grass yields
        -- ~1000 XP, so end-of-grass ~= level 2 (was level 5 at per_level=100). One knob for the whole
        -- curve's pace — raise to slow further, lower to speed up.
        per_level = 700,
        max_level = 50, -- level cap (City-of-Heroes-style top-out); earnedLevel saturates here
    },

    team_power = {
        enabled = true,
        stage = "boosts",
        kind = "team_power",
        start_level = 1,
        percent_per_level = 0.01,
        max_bonus_percent = 1.0,
    },

    level_rewards = {
        -- Pet EQUIP slots from leveling: base 3 (inventory.lua) + up to +7 here = 10 by ~L41.
        -- Granted as the player's CLAIMED level crosses each milestone (so it's altar/claim
        -- gated like the rest of progression). Cap also bounded by inventory.lua max_slots (10).
        equip_slots = {
            pets = {
                enabled = true,
                start_level = 8,
                every_levels = 7, -- grants at 8,15,22,29,36,43,50 -> +7 (3 base -> 10 deployed by L50)
                slots_per_milestone = 1,
                max_bonus_slots = 7,
            },
        },
    },
}
