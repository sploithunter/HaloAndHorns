--[[
    Teaming (docs/TEAMING.md): cross-player support casts + team-scaled enemy packs.
    Party membership itself lives in configs/party.lua (max_size etc.) — these are the
    combat-facing knobs.
]]

return {
    -- Cast-through-player: which power families may be redirected at a TEAMMATE's squad
    -- (resolved to actual pets by TeamCast). Everything else stays self/owner-only.
    support_families = {
        heal = true,
        heal_over_time = true,
        revive = true,
        absorb = true,
        defense_buff = true,
        damage_buff = true,
    },

    -- Enemy pack scaling: when a spawner/patrol triggers with N engaged team members,
    -- wave count = ceil(base * (1 + (N-1) * count_per_extra)), capped by max_count_mult.
    -- Enemy HP additionally scales via combat.group_scaling.per_extra_player
    -- (PartyMath.scaledHp) so packs are more bodies AND meatier — tune either axis to 0
    -- to disable it. Boss-tier enemies never multiply in COUNT (hp only).
    pack = {
        count_per_extra = 0.8, -- +80% pack size per extra engaged teammate
        max_count_mult = 3.0, -- hard ceiling on the count multiplier (4p ≈ 2.6 finds it)
        hp_scaling = true, -- apply PartyMath.scaledHp on top
        count_scales_tiers = { minion = true, elite = true }, -- boss/archvillain: hp only
        engaged_radius = 60, -- studs from the spawn trigger that counts a teammate as engaged
    },
}
