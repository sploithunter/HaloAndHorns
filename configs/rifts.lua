--[[
    Chaos Rifts — Halo & Horns [PROTOTYPE] (Feature 21). [DEFERRED]

    Rare, time-limited endgame events where the element power order reverses:
    Chaotic pets dominate (2.0x) while aligned/neutral pets are penalized (0.5x).
    Only the pure multiplier math is implemented here (headless-tested); the event
    scheduler, rift spawn, notifications, and Aether drops are [deferred]/[studio].
]]

return {
    -- Power multiplier applied to a pet's base power while inside an active rift.
    multipliers = {
        light = 0.5,
        shadow = 0.5,
        chaotic = 2.0,
        neutral = 0.5,
    },
    default_multiplier = 1.0,
    -- Endgame drop hook (Aether) — deferred until the rift event system lands.
    aether_drop = true,
    -- Scheduling placeholders ([deferred]): duration + event times.
    duration_seconds = 600,
    schedule = {},
}
