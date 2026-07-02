--[[
    Buff stacking config — Halo & Horns.

    The ONE rule (docs/PET_REALM_ICONS_AND_POWERS.md Part E): every % buff is an ADDITIVE fraction
    on a base of 1.0, summed per axis, then clamped to that axis's cap. Multiplicative compounding
    is banned EXCEPT a small set of global (whole-account) multipliers. BuffStack.lua implements it.

      multiplier(axis) = clamp(1 + Σ live fractions, 1, 1 + cap)
      final            = base × multiplier(axis) × Π(globals)

    Caps are FRACTION ceilings: cap = 3.0 means +300% max (×4.0). Concurrency (pick-10 + hotbar +
    cooldowns) is the first guard; these caps are the hard backstop. Every number is a dev knob.
]]

return {
    -- Per-axis bonus caps. An axis is any stat a % buff targets; sources in the same axis ADD.
    axes = {
        luck = { cap = 3.0 }, -- egg-hatch / rare-find luck (+300% max)
        coin_yield = { cap = 5.0 }, -- coins per pickup/mine
        mining = { cap = 5.0 }, -- mining throughput / ore
        pet_damage = { cap = 5.0 }, -- pet attack damage (power buff + offense aura, additive)
        xp = { cap = 3.0 }, -- xp gain
        move_speed = { cap = 1.0 }, -- +100% move speed max
        recharge = { cap = 0.75 }, -- power recharge rate (+75% faster max)
        crit = { cap = 0.5 }, -- +crit CHANCE (FLAT add to the roll's crit_chance, not a multiplier); Critical Strike
        -- `defense` is a FLAT additive stat fed to the armor curve (not a fraction); BuffStack.sum
        -- handles it, but it has no fraction cap here (mitigation curve is the natural limiter).
    },

    -- Cap used when an axis isn't listed above.
    default_cap = 3.0,
}
