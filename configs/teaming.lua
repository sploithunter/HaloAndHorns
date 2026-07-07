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

    -- Sidekick/exemplar (task #150): a teamed member's COMBAT level anchors to the lead.
    -- A lower-level member is raised to lead + level_offset (CoH-style: one below the
    -- lead, so the lead stays the strongest); a higher-level member is lowered to the
    -- lead's level exactly. Power axis only — entitlements stay on claimed level.
    sidekick = {
        level_offset = -1,
    },

    -- Enemy pack scaling: when a spawner/patrol triggers with N engaged team members,
    -- wave count = ceil(base * (1 + (N-1) * count_per_extra)), capped by max_count_mult.
    -- Enemy HP additionally scales via combat.group_scaling.per_extra_player
    -- (PartyMath.scaledHp) so packs are more bodies AND meatier — tune either axis to 0
    -- to disable it. Boss-tier enemies never multiply in COUNT (hp only).
    pack = {
        count_per_extra = 1.0, -- 2 engaged = double pack (was 0.8 — read too thin vs 15 pets)
        max_count_mult = 3.0, -- hard ceiling on the count multiplier
        hp_scaling = true, -- apply PartyMath.scaledHp on top
        count_scales_tiers = { minion = true, elite = true }, -- boss/archvillain: hp only
        engaged_radius = 90, -- studs from the spawn trigger that counts a teammate as engaged
        -- Realm-cave PATROL bands scale by the biggest team near the cave stop at sortie
        -- time; patrols roam, so the "near" test is looser than the homeworld spawner one.
        patrol_engaged_radius = 150,
    },
}
