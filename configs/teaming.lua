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

    -- TEAM FOLLOW (client TeamFollowController + PartyService:FollowWarp): any member can
    -- auto-follow any teammate — follow chip on the mate card (mobile-first) or F with the
    -- teammate selected. Walking is client-side; manual movement input breaks it. When the
    -- target takes a realm portal the client requests team.follow_warp, which re-runs the
    -- portal's own gates server-side (never a free same-layer teleport — that idea stays a
    -- future POWER, docs/TEAMING.md).
    follow = {
        stop_distance = 7, -- studs: hang back this far instead of crowding the target
        refresh = 0.15, -- seconds between follow movement steps
        warp_cooldown = 5, -- client seconds between follow_warp requests (server holds 4 too)
        -- HYBRID PATHFINDING (Jason: "I got stuck behind a wall"): straight-line
        -- MoveTo is the default; when progress toward the target stalls (the
        -- watchdog observes "no progress", not elapsed-time-as-readiness), the
        -- client computes a real path and walks waypoints (honoring Jump labels)
        -- until line-of-sight returns, then drops back to direct.
        stuck_window = 1.2, -- seconds of no-progress before pathfinding kicks in
        stuck_epsilon = 1, -- studs: gains smaller than this count as "no progress"
        waypoint_reach = 4, -- studs: advance to the next waypoint inside this
        repath_distance = 12, -- studs the target may drift from the path goal before recompute
        path_fail_cooldown = 2, -- seconds to fall back to direct after a failed compute
    },

    -- FARMING PASS (Jason: "teaming should be encouraged" — the two paths of
    -- success both reward teams). Mining kept its proportional-contribution
    -- split; when a TEAMMATE also contributed to the same node, each teamed
    -- contributor's share is multiplied (duo even-split 50% x 1.2 = 60% each —
    -- more coins/min than solo since two squads clear nodes ~2x faster).
    -- Zero-contribution bystanders still earn NOTHING (no combat danger to
    -- gate leeching, so contribution IS the anti-leech).
    mining = {
        team_payout_mult = 1.2, -- applied to a contributor's share when a teammate also contributed
        economy_auras_shared = true, -- yield/luck pet auras also benefit FRESH teammates (consumer-side fold)
    },

    -- TEMPORARY ALLIANCE (Jason 2026-07-08): two UNTEAMED players at the same home spawn
    -- cave — the higher one trips the wave (enemies tune to THEM), so everyone co-present at
    -- the trigger moment allies for the encounter: the lower player sidekicks UP to
    -- (triggerer + sidekick.level_offset) via the existing EffectiveLevel path, and a
    -- TEMPORARY ALLIANCE banner shows on both until the fight ends. SIDEKICK-UP ONLY — the
    -- anchor is never exemplared down (that stays a consensual formal-team thing). Walking
    -- into an already-running fight forms nothing ("purple enemies are your problem").
    -- Formation radius = pack.engaged_radius (same scan as pack scaling).
    alliance = {
        enabled = true,
        min_level_gap = 3, -- triggerer must be at least this much higher (near-equals = noise)
        dissolve_radius = 140, -- studs from the spawner before the alliance drops
        linger_seconds = 5, -- grace after the wave dies before dissolving (re-triggers re-form)
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
