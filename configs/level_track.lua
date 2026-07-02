--[[
    Level track — what each level-up GRANTS (Halo & Horns, City-of-Heroes style).

    Total XP -> earnedLevel (LevelCurve). The player CLAIMS one level at a time; each claim
    runs this track for the new level. Pure lookup lives in src/Shared/Game/LevelTrack.lua;
    PlayerProgressionService:ClaimLevel applies it (S2). Every number here is a dev knob.

    A level can carry several rewards at once (flags are independent), but `kind` picks the
    headline the UI leads with: "power" > "milestone" > "slot" > "reward".

    IMPORTANT (sync): `power_levels` MUST match configs/powers.lua `selection_levels` and
    `slot_levels` MUST match configs/augmentation.lua `slot_grant_levels` — those configs gate
    the actual PowerService/Augmentation eligibility; this track only decides the level-up
    presentation + the bundled rewards. Together they cover EVERY level 2–50 (15 power picks +
    34 slot grants), so every claim hands you a real choice.
]]

return {
    version = "1.0.0",
    max_level = 50,

    -- +1 egg max-hatch EVERY level: hatch = base + (claimedLevel - 1) * per_level.
    -- base 3 at L1 climbs to ~52 at L50. Consumed in HatchEntitlementService:GetMaxHatchCount.
    egg_hatch = {
        base = 3,
        per_level = 1,
    },

    -- Levels where the claim opens the POWER PICKER (PowerSelection / PowerService:Select).
    -- MUST mirror powers.lua selection_levels (15 picks, reaches the L44 capstones + L40/L46 tail).
    power_levels = { 2, 4, 6, 8, 10, 12, 15, 18, 22, 26, 30, 36, 40, 44, 46 },

    -- Levels where the claim GRANTS empty enhancement slots to place on owned powers (Augmentation).
    -- MUST mirror augmentation.lua slot_grant_levels: EVERY level 2–50 that isn't a power level (34
    -- levels). `slots_per_grant` (2) slots each = 68 granted. With each picked power's 1 free inherent
    -- slot (15) and a 6-slot cap, that's 83 placeable of 90 capacity → slots stay scarce, every one a
    -- real build choice.
    slot_levels = {
        3,
        5,
        7,
        9,
        11,
        13,
        14,
        16,
        17,
        19,
        20,
        21,
        23,
        24,
        25,
        27,
        28,
        29,
        31,
        32,
        33,
        34,
        35,
        37,
        38,
        39,
        41,
        42,
        43,
        45,
        47,
        48,
        49,
        50,
    },
    slots_per_grant = 2,

    -- Big moments. Headline flair + a bundle from milestone_rewards below.
    milestones = { 10, 20, 30, 40, 50 },

    -- Level the player CHOOSES their origin (archetype). ArchetypeService gates the actual pick;
    -- surfacing it as an auto-prompt at this level is a follow-up (config recorded here now).
    origin_choice_level = 5,

    -- HYBRID gate (City-of-Heroes "train at a trainer"): which level KINDS must be claimed at
    -- the Ascension Altar vs auto-claimed in the field. Filler reward levels auto-apply with a
    -- toast; power/slot/milestone levels stall until you visit the altar (-> reveal modal).
    -- Set all false to revert to claim-anywhere.
    altar_kinds = {
        power = true,
        slot = true,
        milestone = true,
        reward = false,
    },

    -- The Ascension Altar station (a world part tagged "AscensionAltar"). If the map already has
    -- a tagged part, that's used; otherwise AscensionAltarService spawns a placeholder pillar at
    -- `position` (reskin later — the logic keys off the tag, not the visual).
    altar = {
        enabled = true,
        -- Bind the altar to a named map object (an invisible prompt host is placed at it) so the
        -- station is the building, not a placeholder pillar. Falls back to a tagged part, then to
        -- the placeholder at `position`. Tune the host with `bind_offset`.
        bind_to_name = "Low Poly Shop",
        bind_offset = { 0, 0, 0 }, -- nudge the prompt host off the bound object's ground-center (studs)
        position = { 0, 6, 0 }, -- placeholder fallback position (only if bind_to_name not found)
        size = { 6, 12, 6 },
        color = { 255, 205, 70 },
        action_text = "Ascend",
        object_text = "Ascension Altar",
        max_distance = 18, -- a bit larger so you don't have to stand dead-center on a building
        hold_duration = 0,
        key = "E",
        -- Floating label above the station ("" to hide).
        label_text = "Ascend", -- matches the ASCEND button language (building is placeholder)
        label_color = { 255, 230, 140 },
        label_max_distance = 250,
    },

    -- Optional reward bundles (RewardBundle shape: { currencies = {...}, pets = {...}, ... }).
    -- Level-up's real entitlements are powers/slots/milestones/egg-hatch capacity; currency
    -- faucets belong in quests, drops, shop/reward systems, and other explicit economy loops.
    rewards = {},

    -- Optional milestone bundles, granted IN ADDITION to the per-level reward when present.
    milestone_rewards = {},
}
