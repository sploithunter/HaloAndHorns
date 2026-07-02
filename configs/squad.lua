--[[
    Active squad hierarchy — Halo & Horns [PROTOTYPE] (Feature 9).

    Three tiers: Inventory (all owned) -> Equipped (followers) -> Active Squad
    (fighters). Swapping the active squad mid-combat has a cooldown; out of combat
    it is instant. Read by `src/Shared/Game/ActiveSquad.lua`.
]]

return {
    limits = {
        inventory = 1000,
        equipped = 10,
        active_squad = 10, -- all 10 equipped pets deploy + show in the right bar
    },
    swap_cooldown_seconds = 5,

    -- Slot recovery (the timer the PLAYER manages). When a pet leaves its active
    -- slot the SLOT recharges before it can be re-crewed — this paces throughput
    -- regardless of how deep a stack is, so 1000 pets can't be spammed forever.
    -- Distinct from the per-pet / stack-pool spirit-form recovery (you still can't
    -- re-summon a pet that was just downed; that lives in spirit_form/stack_pool).
    --   recall_cooldown_seconds — SHORT: you proactively pulled a Strained/Critical
    --       pet before it fell (rewards attention; still capped so recall isn't spam).
    --   down_cooldown_seconds   — LONG: the slot's pet was fully downed (the real cost).
    -- Both are balance knobs (everything is config-driven); tune against enemy DPS.
    slot_recovery = {
        recall_cooldown_seconds = 4,
        down_cooldown_seconds = 60, -- SLOT lock after a down (1 min): refill with ANOTHER pet once clear
    },

    -- "A down should MATTER." The downed pet is locked at its IDENTITY (uid), persisted so re-teaming
    -- can't revive it for free. The SLOT it fell in (above) frees sooner, so a STACK (5 huge bears)
    -- can refill the slot with a different bear — but THAT specific bear stays out for the full lockout.
    down_lockout = {
        pet_lockout_seconds = 300, -- the downed pet (uid) is out this long (5 min) — survives re-team
    },

    -- RES SICKNESS (Jason 2026-07-02): a revived pet returns at this FRACTION of its max endurance
    -- — the resurrection erases the down, not the wound. Applies to EVERY revive path (PetRevive is
    -- the single definition): the Revive power, Genie of the Dunes, natural recovery. 1.0 = full
    -- health (the old behavior); 0.5 = up-but-fragile, the healer still has a job.
    revive = {
        health_frac = 0.5,
        -- SICKNESS WINDOW: for this many seconds after a partial revive, NO heal can lift the pet
        -- above its res health (ResSickness clamp at every heal path — the genie's burst, HoTs,
        -- regen, support auras). Without it, any nearby heal made every res an instant 100% res.
        sickness_seconds = 8,
    },
}
