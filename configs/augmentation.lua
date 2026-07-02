--[[
    Augmentation slots — Halo & Horns [PROTOTYPE] (Feature 15).

    Players earn unallocated slots at slot-grant levels and place them on UNLOCKED
    (selected) powers (Feature 14). Each slot has a type; matching types on the same
    power trigger escalating set bonuses. Slots persist (profile.Slots) and are
    returned to unallocated on respec. Pure rules: `src/Shared/Game/Augmentation.lua`.
]]

return {
    -- Keep IN SYNC with level_track.lua slot_levels: EVERY level 2–50 that isn't a power level (34
    -- levels). Each grants `slots_per_grant` (2) EMPTY slots = 68 granted. With each power's free
    -- inherent slot (granted on pick) and the 6-slot cap, that's scarce on purpose — you choose which
    -- powers to deepen.
    slot_grant_levels = {
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
    max_slots_per_power = 6, -- includes the free inherent slot every picked power starts with

    -- FUTURE (enhancements layer): a slot is EMPTY today — just capacity on a power. Later, typed
    -- ENHANCEMENTS drop into slots and carry the bonus; the power gates which types fit (no Range on
    -- a melee power, etc.). These tables are parked for that system; empty slots consume none of it.
    slot_types = { "recharge", "strength", "range", "duration", "efficiency", "reliability" },

    -- Per-slot effect magnitude by type (e.g. each recharge slot = -5% cooldown).
    per_slot = {
        recharge = 0.05,
        strength = 0.05,
        range = 0.05,
        duration = 0.05,
        efficiency = 0.05,
        reliability = 0.05,
    },

    -- Set bonuses by number of MATCHING-type slots on one power. Higher tiers are
    -- stronger and stack with lower tiers (4 matching => 3-tier AND 4-tier apply).
    set_bonuses = {
        [3] = 0.10,
        [4] = 0.20,
        [5] = 0.30,
        [6] = 0.45,
    },
}
