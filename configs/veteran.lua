--[[
    Veteran Levels — the post-50 XP track (docs/VETERAN_LEVELS.md).

    Level 50 stays the BUILD cap (no stats, no power — the endgame power chase stays
    enhancements/sets/perma; Rebirth/dragons is the other branch). XP keeps counting past the
    cap, and every `xp_per_level` becomes a VETERAN LEVEL paying enhancement cog rolls (the
    DROPS economy — deliberately NOT a currency faucet) plus status milestones.

    FLAT curve: every vet level costs the same — a metronome, not an escalating wall.
]]

return {
    enabled = true,

    -- XP per veteran level (constant). Recalibrated 2026-07-07: level-scaled combat XP +
    -- teamed shared credit pushed endgame farming to ~2k XP/min (Jason hit VET 75 in one
    -- session at the old 2000 — "half a bar every kill"). 20000 ≈ one vet level per ~10 min
    -- of active team farming. Retro-safe: VeteranPaid is a high-water ledger, so raising
    -- this only lowers the DISPLAYED vet level — no reward double-pay, paid rolls stay paid.
    xp_per_level = 20000,

    rewards = {
        rolls_per_level = 1, -- enhancement cog rolls granted per vet level
        premium_every = 5, -- every Nth vet level is a premium beat...
        premium_bonus_rolls = 1, -- ...paying this many EXTRA rolls
        announce_every = 10, -- every Nth is the STATUS milestone (celebration + titles later)
    },
}
