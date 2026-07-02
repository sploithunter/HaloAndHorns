--[[
    Spirit Form / cooldowns — Halo & Horns [PROTOTYPE] (Feature 7).

    Unique pets enter Spirit Form when downed and can't redeploy until their
    cooldown elapses. The cooldown is set by the content tier where they were
    downed; Heaven biomes recharge faster (halve the cooldown). Read by
    `src/Shared/Game/SpiritForm.lua`.
]]

return {
    cooldown_tiers = {
        trash_mob = 60,
        mid_tier = 300,
        boss = 1800,
        chaos_rift = 3600,
    },
    -- Heaven biomes recharge 2x faster (effective cooldown / 2).
    heaven_recharge_multiplier = 2,
}
