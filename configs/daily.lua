--[[
    Daily login streak — Halo & Horns [PROTOTYPE] (Phase 7).

    A streak is a Claim with a time/cadence gate instead of a Condition. Day indices
    are passed to the pure DailyStreak resolver (no clock in the core). The calendar
    repeats every `cycle_length` days; missing more than `max_gap_days` resets it.
    The "Daily ❗" badge = 1 when a claim is available today.
]]

return {
    max_gap_days = 1,
    cycle_length = 7,
    -- AREA COINS at real income scale (Jason round 2: flat "crystals" were noise —
    -- a developed squad mines ~1k/min, and the coin should be the ZONE'S, not
    -- Spawn's). "area_coins" resolves at claim time to the mining coin of the area
    -- the player is standing in (RewardService). Yardsticks (Jason, measured live):
    -- fresh-in-a-new-zone squad ~1000/min (14-20/sec in Desert with a Lava team);
    -- true-fresh squad ~600/min; Ice gate = 8000. Day 6 pays a full zone gate.
    -- Day 7 escalates over time: golden bear -> rainbow bear (now) -> maybe a
    -- rainbow cat someday ("which would be pretty rare") as the cycle extends.
    calendar = {
        [1] = { currencies = { area_coins = 3000 } },
        [2] = { currencies = { area_coins = 6000 } },
        [3] = { currencies = { gems = 2 } },
        [4] = { currencies = { area_coins = 12000 } },
        [5] = { currencies = { gems = 5 } },
        [6] = { currencies = { area_coins = 25000 } },
        [7] = { pets = { { id = "bear", variant = "rainbow" } } },
    },
}
