--[[
    Hotbar / Command Bar — Halo & Horns [PROTOTYPE] (Feature 16).

    A 20-slot hotbar (1-9, 0, Shift+1-9, Shift+0). Each slot holds one bind:
    { type, target } where type is power / roster / pet / tactical. New players get
    archetype defaults; bindings persist (profile.Hotbar). Pure rules:
    `src/Shared/Game/HotbarLogic.lua`.
]]

return {
    slot_count = 20,
    bind_types = { "power", "roster", "pet", "tactical", "potion", "token" },
    tactical_commands = { "scatter", "focus_fire", "regroup", "retreat", "rally" },
    -- Exact bar used for a brand-new profile and the admin "Reset to Beginning" test path.
    -- Keep this authored separately from archetype defaults: a beginning player has no origin or
    -- selected powers yet, but Rally must already be visible for its tutorial lesson.
    beginning_binds = {
        { slot = 11, type = "tactical", target = "rally" },
    },
    tactical_details = {
        scatter = {
            display_name = "Scatter",
            type = "Squad command",
            description = "Spread your pets out so they stop clustering on the same spot.",
        },
        focus_fire = {
            display_name = "Focus Fire",
            type = "Squad command",
            description = "Order the whole squad to attack your current target together.",
        },
        regroup = {
            display_name = "Regroup",
            type = "Squad command",
            description = "Pull your pets into a tighter formation around you.",
        },
        retreat = {
            display_name = "Retreat",
            type = "Squad command",
            description = "Break off the current fight and move the squad away from danger.",
        },
        rally = {
            display_name = "Rally",
            type = "Squad command · Panic button",
            description = "Instantly call every pet back to your side when a fight goes wrong.",
        },
    },

    -- Default layout for a new player. Power slots fill from the player's OWNED powers (picked via
    -- level-up) in order — a fresh character owns none, so the bar comes up EMPTY and fills as you
    -- pick. Roster + tactical (focus_fire/scatter/regroup/retreat) commands are REAL and fully
    -- functional, but no longer auto-clutter a fresh bar — bind them yourself via Edit. (Restore the
    -- auto-defaults by repopulating roster_slots/tactical_slots, e.g. {7,8,9} / {10,11,12,13}.)
    defaults = {
        power_slots = { 1, 2, 3, 4, 5, 6 },
        roster_slots = {},
        tactical_slots = {},
    },

    -- [PROTOTYPE] Explicit default bar OVERRIDE. When set, a fresh hotbar uses exactly this layout
    -- (archetype-independent) instead of the per-archetype fill above — handy for testing a specific
    -- kit so a restart reliably comes up with it. Set to nil to fall back to the `defaults` above
    -- (power slots fill from OWNED powers, so a fresh character's power slots stay empty until they
    -- pick — the real level-up flow). Each entry is { slot, type, target }.
    --
    -- Power-bar sizes. Auto follows DisplayClass (phone → mobile, tablet →
    -- tablet, desktop → desktop). Mobile is the designed-for-phone size —
    -- same proportions, grown so the docked assembly fills most of the
    -- short phone width. Settings can pin Mobile / Tablet / Desktop.
    size = {
        -- KEEPER (2026-08-20 phone playtest): bottom-center 2×10. Keep
        -- "horizontal". "vertical_left" is leftover (wrong target — the
        -- far-left experiment is game-pass + toggle badges in ui.lua).
        orientation = "horizontal",
        default = "auto",
        modes = {
            -- 30% over the 0.80 iPad/desktop pass (0.80 × 1.30).
            desktop = 1.04,
            tablet = 1.04,
            mobile = 1.6,
        },
        -- bar 546 + left flank 88 + right flank 158 (HotbarFlank desktop)
        design_span = 792,
        -- header + 10 slots (HotbarBar vertical_left)
        vertical_span = 546,
        -- 10% narrower than the first mobile pass so Jump keeps a slot
        -- between the stacked Powers / Board column and the screen edge.
        mobile_width_scale = 0.81,
        tablet_width_scale = 0.58,
        -- Vertical experiment: share of viewport height (not width).
        mobile_height_scale = 0.82,
        tablet_height_scale = 0.72,
        flank = {
            size = 62,
            compact_size = 48,
            gap = 26,
            inner = 8,
        },
    },

    -- NIL while we test the level-up system (powers come only from picks). To re-seed a fixed kit
    -- for VFX/signature testing, restore a table here, e.g. the old Pyromancer kit:
    --   { {slot=1,type="power",target="cataclysm"}, {slot=2,type="power",target="wildfire"},
    --     {slot=3,type="power",target="firestorm"}, {slot=4,type="power",target="mark_of_flame"},
    --     {slot=5,type="power",target="ember_ward"}, {slot=6,type="power",target="eruption"},
    --     {slot=7,type="roster",target="Roster 1"}, {slot=8,type="tactical",target="scatter"},
    --     {slot=9,type="tactical",target="focus_fire"}, {slot=10,type="tactical",target="regroup"} }
    default_binds = nil,
}
