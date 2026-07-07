--[[
    Teaming (docs/TEAMING.md): cross-player support casts + team-scaled enemy packs.
    Party membership itself lives in configs/party.lua (max_size etc.) — these are the
    combat-facing knobs.
]]

return {
    -- Cast-through-player: which power families may be redirected at a TEAMMATE's squad
    -- (resolved to actual pets by TeamCast). Everything else stays self/owner-only.
    -- Keys MUST be the actual effect_kinds family ids in configs/powers.lua (live-caught
    -- 2026-07-07: "damage_buff"/"heal_over_time" matched nothing — the real damage-buff
    -- family is "buff" — so those casts silently never redirected, and taunt landed on the
    -- CASTER's same-numbered slot). Rule of thumb: every family whose effect lands ON PETS
    -- is a support family; player-economy buffs (luck/coin/xp/...) stay self-only.
    support_families = {
        heal = true,
        heal_blind = true, -- heal + blind the attackers
        revive = true,
        absorb = true, -- shields (aegis / bastion)
        defense_buff = true,
        buff = true, -- damage buff
        taunt = true, -- pull aggro onto their tank
        fortify = true,
        root_guard = true, -- squad +Def half (the knockback half stays battlefield-side)
        evade = true, -- dodge (mirage)
    },

    -- Sidekick/exemplar (task #150): a teamed member's COMBAT level anchors to the lead.
    -- A lower-level member is raised to lead + level_offset (CoH-style: one below the
    -- lead, so the lead stays the strongest); a higher-level member is lowered to the
    -- lead's level exactly. Power axis only — entitlements stay on claimed level.
    sidekick = {
        level_offset = -1,
    },

    -- Kill credit (TM5): teammates of any damage contributor SHARE the kill award when
    -- within `radius` studs of the down site — the healer/buffer gets paid without landing
    -- a hit. Contributors themselves are always paid regardless of distance.
    kill_credit = {
        radius = 150,
    },

    -- Enemy pack scaling: when a spawner/patrol triggers with N engaged team members,
    -- wave count = ceil(base * (1 + (N-1) * count_per_extra)), capped by max_count_mult.
    -- Enemy HP additionally scales via combat.group_scaling.per_extra_player
    -- (PartyMath.scaledHp) so packs are more bodies AND meatier — tune either axis to 0
    -- to disable it. Boss-tier enemies never multiply in COUNT (hp only).
    pack = {
        count_per_extra = 1.5, -- duo = 2.5× pack (1.0 read trivial: duo invader bands of 8 vs 16 pets)
        max_count_mult = 3.0, -- hard ceiling on the count multiplier
        hp_scaling = true, -- apply PartyMath.scaledHp on top
        count_scales_tiers = { minion = true, elite = true }, -- boss/archvillain: hp only
        engaged_radius = 90, -- studs from the spawn trigger that counts a teammate as engaged
        -- Realm-cave PATROL bands scale by the biggest team near the cave stop at sortie
        -- time; patrols roam, so the "near" test is looser than the homeworld spawner one.
        patrol_engaged_radius = 150,
        -- TEAMS ATTRACT SCARY BANDS (variance smoothing — Jason: "most times 8 and trivial,
        -- sometimes ridiculous and hard"): each extra engaged teammate ADDS this to the
        -- pet_invader_scary_chance, so teamed caves anchor far more bands with a
        -- strongest-invader instead of leaving difficulty to the 18% dice.
        scary_chance_per_extra = 0.3,
    },
}
