--[[
    Pet follow / movement — Halo & Horns + template [PROTOTYPE] (issue #4).

    Config-as-code for the service-owned pet-follow loop (PetFollowService), which
    replaces the legacy cloned per-pet PetScripts/Follow + FollowBox scripts. The
    pure formation math lives in `src/Shared/Game/PetFormation.lua`; this file
    holds every tuning knob that used to be hardcoded across the cloned scripts
    (FOLLOW_SPACING, PET_CIRCLE_RADIUS, responsiveness 200/75, float, etc.).

    service_owned: the rollout flag (issue #4). While false, the legacy cloned
    scripts drive movement exactly as before and PetFollowService is inert. When
    true, PetFollowService owns movement and the cloned scripts no-op. This lets
    us verify live and roll back instantly.
]]

return {
    -- false: the legacy cloned Follow/FollowBox scripts own pet movement (they
    -- include the teleport-watchdog + tuned forces that keep pets from falling
    -- off the map — issue #4's known 10-months-ago bug). PetFollowService stays
    -- inert. Damage still routes through CombatService (the legacy Follow calls
    -- CombatService:ResolvePetDamage). A service-owned movement loop can only take
    -- over once it ports that anti-fall machinery — see issue #4 / CURRENT_STATUS.
    service_owned = true,

    -- Legacy "ring mining": the old animation where pets ORBIT a node while mining, via an
    -- invisible Star ring of physics boxes BreakableSpawner builds on each mined node. Those boxes
    -- are unanchored and simulated on the SERVER (plus a per-node server spin loop), so leaving
    -- this on tanks server FPS once several nodes are being mined. The current pet system uses its
    -- own mining animation and does NOT use this ring, so it is OFF. If ring-mining is ever brought
    -- back, prefer wiring `enabled` to a player attack-style setting rather than a global on switch,
    -- and keep point_count near the equipped-pet cap (10) — not the old hardcoded 108.
    ring_mining = {
        enabled = false,
        point_count = 12,
    },

    -- How pets arrange behind/around the player.
    formation = {
        mode = "rows", -- "rows" (marching grid) | "circle" (arc behind)
        follow_distance = 6, -- studs behind the player to the first row / arc center
        height = 2, -- studs above the player's root

        -- rows mode
        per_row = 3,
        row_spacing = 4,
        col_spacing = 4,

        -- circle mode
        radius = 8,
        arc_degrees = 120,

        -- === Size-aware formations (PetFormation.resolve; wired in Stage 2+) ===
        -- Pets are sorted smallest -> front, huge -> back, and gaps scale with each
        -- pet's footprint. `default_mode` is the fallback; each player overrides it
        -- with their saved choice (Stage 3). Modes: "conga" | "risers" | "arc".
        default_mode = "risers",
        size = {
            default_footprint = 4, -- studs, used when a pet's model extents are unknown
            gap = 1.5, -- base gap added between neighbours, on top of their radii
        },
        -- conga: single file (uses follow_distance + size.gap)
        -- risers: tiered rows; huge anchored in the back row
        risers = { per_row = 3, row_gap = 2, col_spacing = 3 },
        -- arc: concave cradle; huge curling back at the horns
        arc = { radius = 11, arc_step_degrees = 20, spread_factor = 0.15, depth_factor = 0.1 },
    },

    -- Gentle vertical bob (replaces the legacy globalPetFloat oscillator).
    float = {
        amplitude = 0.5,
        period = 2,
    },

    -- Vertical float touch-up (studs, +up / -down), layered on top of formation.height + the bob.
    -- A huge pet scales its MODEL up but keeps the flat `height`, so most huges end up floating
    -- above the ground; a few (tall tanks like the ents) sink as they bob. EXTENSIBLE + OPTIONAL —
    -- every value defaults to 0, so pets you don't tune are unaffected. Per-pet resolution order:
    -- by_type[petType].{huge|normal} (if set) OVERRIDES the class default below. Applied in
    -- PetFollowController. Jason: "config for huges + normals, not required, add as needed."
    float_offsets = {
        normal = 0, -- class default for NON-huge pets
        huge = -1.5, -- class default for HUGE pets (most float; -1.5 grounds hare/cherub/lion)
        by_type = {
            -- Per-pet overrides (replace the class default for that pet). Add entries as needed.
            -- The Worldroot Ent is a tall tank whose feet SINK as it bobs → lift instead of drop.
            worldroot_ent = { huge = 2 },
        },
    },

    -- Idle meander (Jason: "pets should meander near their group location so they
    -- don't just stand there — frozen statues unless they're in combat"). Once the
    -- PLAYER has stood still for player_still_seconds, each untargeted follower
    -- strolls to random points within `radius` of its formation slot at `speed`,
    -- pausing pause_min..pause_max between strolls (randomized per pet, so the
    -- squad desyncs naturally). Purely cosmetic + client-side: the moment the
    -- player moves or the pet gets a target it glides back to formation. Keep
    -- `speed` above movement.face_move_speed so strolling pets face their walk.
    -- Logic: src/Shared/Game/PetMeander.lua (pure), applied by PetFollowController.
    meander = {
        enabled = true,
        -- soft separation (Jason: "not via collisions — they move away from each
        -- other so the other system can take over"): follower TARGETS closer than
        -- this get nudged apart; the normal lerp walks the pets off each other.
        -- Applies whenever pets follow (not just while meandering). 0 = off.
        separation = 3,
        player_still_seconds = 2,
        radius = 6,
        speed = 4,
        pause_min = 1.5,
        pause_max = 4,
    },

    -- Attack mode: pets arrange around the target while attacking (client-driven, purely
    -- visual). `style` is the default; players override it with a saved PetAttackStyle setting,
    -- live-switchable via the PetAttackStyle attribute.
    --   "orbit" (ring spins) | "static_ring" | "lunge" (jab in) | "spiral" (vortex) |
    --   "pincer" (two arcs squeeze) | "firing_line" (row, recoil volley) | "swarm" (jitter cloud)
    -- (No distance leash: AutoTargetService owns target selection + range; the pet clears its
    --  target only when the breakable is mined out, like the legacy.)
    attack = {
        style = "orbit", -- the TEAM style: used when `mode` (below) is "team", and as fallback
        -- mode = how the squad arranges, per target type (PetFormation.resolveStyle):
        --   "team"       — every pet shares `style` (one shared formation, the classic look)
        --   "individual" — each pet uses its ROLE's style from `role_styles` (fights in character)
        -- Starting split (Jason): farm as a team cluster, then break into role positions in a fight.
        mode = { mining = "team", combat = "individual" },
        -- Per-role attack styles for "individual" mode. Role = PetRole / pet_roles.by_type.
        -- (A per-species override + the PetAttackStyle player attribute both still win over this.)
        role_styles = {
            tank = "static_ring", -- a wall holds the line, doesn't pirouette
            -- melee = orbit (not lunge): the constant circling reads as DODGING/weaving — an agile,
            -- never-still melee (superhero feel) — where lunge read as a telegraphed brute. One pet
            -- circling its OWN target is "slippery", not the whole-team swirl that was the problem.
            melee = "orbit",
            ranged = "firing_line", -- stands back and volleys (blaster)
            support = "orbit", -- weaves around the squad
            control = "pincer", -- flanks to set up debuffs
        },
        -- COMBAT ring orientation — which way the attack wheel's angle-0 points (the slot a lone
        -- pet takes). This decides whether your squad SHOVES enemies away from you or PULLS them
        -- toward you, and it is a real tactical tension (see docs/wiki/EMERGENT_BEHAVIORS.md):
        --   "toward_player"      — pet bodies up between you and its target → the enemy backs to the
        --                          far side to keep range → the squad PEELS/SHOVES enemies AWAY
        --                          from you. Great solo (a bodyguard pushing the threat off you),
        --                          but multiple tanks each shove toward a DIFFERENT "away" → the
        --                          fight SPREADS and de-centres. (default — Jason: leave as is.)
        --   "away_from_player"   — pet takes the far side → enemies are DRAWN TOWARD you. Multiple
        --                          pets all pull to the same point (you) → the fight CONCENTRATES.
        -- The spread under many tanks is intentional friction: a full tank team is unwieldy/chaotic,
        -- so team composition is a CHOICE, not a free stack. Players learn to mix roles.
        combat_ring_zero = "toward_player",
        ring_radius = 6,
        ring_height = 3,
        orbit_speed = 2.5, -- radians/sec wheel spin (orbit)
        lunge_distance = 3, -- jab depth toward center (lunge)
        lunge_speed = 6,

        -- spiral (rotating mining vortex): inner -> outer arm, rises with t. The spin rate
        -- lerps inner -> outer, so the inner ring whirls faster than the rim; set
        -- spiral_outer_speed negative to make the two rings counter-rotate instead.
        spiral_turns = 1.5,
        spiral_inner_speed = 3.0, -- rad/sec at the centre
        spiral_outer_speed = 1.5, -- rad/sec at the rim (half the inner -> inner spins ~2x)
        spiral_rise = 2,
        -- pincer (two arcs clamping the target)
        pincer_arc = 80, -- degrees each arc spans
        pincer_squeeze = 2, -- studs the clamp pulses in/out
        pincer_speed = 3,
        -- firing line (a row facing the target, staggered recoil volley)
        line_spacing = 2.5,
        line_recoil = 2,
        line_speed = 5,
        -- swarm (jitter cloud)
        swarm_radius_frac = 0.85,
        swarm_speed = 3,
        swarm_bob = 1.2,

        -- Attack FLOURISH layered on the base pivot while engaged (src/Shared/Game/AttackAnim.lua),
        -- the time-driven companion to the walk gait. Chosen by target type: `mining` plays on
        -- breakables/ore, `combat` on enemies. Styles:
        --   "pounce" — periodic jab toward the target + recoil (looks like striking it)
        --   "peck"   — repeated downward dip toward the target (headbutt/pickaxe); peck_speed,
        --              bob_height set the rhythm + dip depth
        --   "none"   — no flourish, just face the target
        --   "spin"   — whirl about up (available, but looked sloppy for mining — not used)
        -- More styles drop into AttackAnim.STYLES; add a config block here. Swap mining.style
        -- below to "peck" or "none" to taste.
        anim = {
            mining = { style = "pounce", pounce_depth = 1.5, pounce_period = 0.5 },
            combat = { style = "none" }, -- enemies: face them for now; pounce/etc. later
        },
    },

    -- Client movement smoothing (frame-rate-independent exponential approach;
    -- higher = snappier, lower = more momentum/float). Used by PetFollowController.
    movement = {
        follow_lerp_rate = 10,
        attack_lerp_rate = 16,

        -- Hard cap on how fast (studs/sec) a pet can physically travel toward its
        -- goal. Without this the exponential lerp above covers any distance almost
        -- instantly, so a pet "teleports" onto a new mining target. The cap makes
        -- pets visibly FLY OVER to a target (so move speed matters + mining DPS
        -- ramps as they arrive). Scaled by the same move-speed multiplier below;
        -- raise it for a snappier feel, lower it for slower, more deliberate travel.
        max_travel_speed = 26,

        -- Pet move speed multiplies the lerp rates + travel cap above. Driven by the
        -- player attribute `PetMoveSpeed` (a stat/upgrade, default 1.0) and an optional
        -- per-pet model attribute `MoveSpeedMult` (for unique fast pets); the two
        -- multiply against `base`, clamped to [min, max].
        speed = { base = 1.0, min = 0.25, max = 4.0 },

        -- Smoothing for OTHER players' pets (server-relayed at ~10Hz): the client lerps them
        -- toward each relayed transform so they read smooth despite the lower update rate. Your
        -- OWN pets never use this — they're driven locally at full framerate.
        remote_lerp_rate = 14,

        -- Catch-up safety: if a pet ends up further than this (studs) from its target —
        -- the player teleported (zone/realm change) — snap it there instead of crawling
        -- across the map. INVARIANT: keep this ABOVE auto_systems.lua
        -- auto_target.max_target_distance (120) so a pet only ever snaps for a real
        -- teleport, never to reach a normal far target (which it should travel to).
        catchup_distance = 200,

        -- Facing: a pet turns to face the direction it's actually MOVING whenever it's
        -- travelling faster than face_move_speed (studs/sec) — so returning/repositioning
        -- pets head forward instead of moonwalking. Below that speed it settles onto its
        -- "rest facing" (player-forward when following, the target when attacking).
        -- face_turn_rate is the exponential turn smoothing (higher = snaps to heading faster).
        face_turn_rate = 12,
        face_move_speed = 2,
    },

    -- Procedural walk gait (client, PetFollowController) — the SAME system enemies use
    -- (src/Shared/Game/Gait.lua). Pets get a waddle/march/hop/etc. layered on their
    -- follow/attack movement, driven by distance travelled so it scales with speed and
    -- rests when still. `gait` is the default for every pet; `gait_by_type` overrides it
    -- per pet PetType so different species move differently. Styles: waddle (bob + L/R
    -- bank), march (stiff stomp), hop (one bounce/stride), slither (heading wiggle).
    -- stride_length is the WAVELENGTH of the waddle/hop in studs travelled: the gait phase
    -- advances stepDist/stride per frame, so a BIGGER stride = the pet rocks back-and-forth
    -- HALF as often (slower animation) WITHOUT changing how fast it actually moves. These were
    -- doubled (4->8, etc.) to calm an over-bouncy idle/walk feel — raise further to slow the
    -- rock more, lower to speed it up. (bob_height/tilt are AMPLITUDE, not speed.)
    gait = {
        enabled = true,
        style = "waddle",
        bob_height = 0.4, -- pets are smaller + already float; keep the bob gentle
        tilt_degrees = 10,
        stride_length = 8,
        ref_speed = 12, -- pets travel faster than enemies; reach full waddle around here
        ease_rate = 9,
    },
    gait_by_type = {
        bunny = { style = "hop", bob_height = 0.9, tilt_degrees = 0, stride_length = 6 },
        bear = { style = "waddle", bob_height = 0.5, tilt_degrees = 13, stride_length = 9 },
    },

    -- Ranged pets (pet_roles role == "ranged") fire a cosmetic lightning bolt from the
    -- pet to its target while attacking — the same procedural bolt as the enchanter
    -- (src/Shared/Effects/EnchantLightning). `interval` is the client-side cadence; the
    -- rest are EnchantLightning params tuned for a short, snappy combat zap (no thunder
    -- per shot). Purely visual; damage stays server-side via the mining tick.
    ranged_bolt = {
        enabled = true,

        -- Which ranged visual to fire (RangedFX dispatcher). `kind` is the default for every
        -- ranged pet; `by_type` overrides it per PetType so you can test one pet in isolation.
        -- Kinds: "lightning" (arc) | "fireball"/"plasma"/"frost"/"ice_shard"/"poison" (themed
        -- projectile orbs, params under `projectile`) | "beam" (laser) | "rock" (desert boulder).
        -- Area/element flavour map (assign per pet, or auto-pick by element later):
        --   grass  -> "lightning"      lava   -> "fireball"
        --   ice    -> "frost"/"ice_shard"   desert -> "rock"
        kind = "lightning",
        by_type = {
            colorado = "fireball", -- TEST: colorado throws a fireball instead of lightning
        },

        -- NOTE: firing cadence is now the SERVER's real attack interval (PetCombat.attackInterval)
        -- — each visual is driven by an actual hit via Combat_PetHit, not this client timer.
        -- `interval` is retained only as a legacy/fallback knob and no longer paces the visuals.
        interval = 0.9,

        -- Floating combat text over the target on each hit (Combat_PetHit): the damage number,
        -- a bigger gold "N!" on a crit, or "MISS". enabled=false turns it off. rise = studs it
        -- floats up; duration = seconds; size/crit_size = font px; colors = { r,g,b } each.
        combat_text = {
            enabled = true,
            rise = 6,
            duration = 0.9,
            size = 22,
            crit_size = 34,
            miss_text = "MISS",
            colors = {
                normal = { 255, 255, 255 },
                crit = { 255, 200, 60 },
                miss = { 175, 175, 175 },
                blind_miss = { 255, 150, 40 }, -- orange MISS: a BLINDED enemy whiffed (Sandstorm), vs grey for a plain miss
                heal = { 90, 230, 110 }, -- green "+N" on heals
            },
        },

        -- Melee/mining hit feedback (kind = "melee", fired by Combat_PetHit for non-ranged pets):
        -- an impact at the target + the hit sound, no projectile (the pet is adjacent). Tier
        -- scales with crit. colors = { core, accent }.
        melee = {
            impact = "small",
            impact_crit = "medium",
            colors = { { 255, 235, 190 }, { 255, 210, 140 } },
        },
        -- Per-biome upfront/melee impacts (CombatFX passes the element) so an upfront grass pet
        -- looks different from upfront lava — ice shatters, desert kicks up dust, etc.
        melee_by_element = {
            grass = {
                impact = "small",
                impact_crit = "medium",
                colors = { { 120, 220, 90 }, { 200, 255, 150 } },
            },
            lava = {
                impact = "small",
                impact_crit = "medium",
                colors = { { 255, 150, 40 }, { 255, 210, 120 } },
            },
            ice = {
                impact = "shatter",
                impact_crit = "big",
                colors = { { 150, 220, 255 }, { 235, 250, 255 } },
            },
            desert = {
                impact = "dust",
                impact_crit = "big",
                colors = { { 200, 170, 115 }, { 150, 125, 90 } },
            },
        },

        -- Sounds played by RangedFX: `delivery` at launch (the firing pet), `impact` at the hit.
        -- An empty id = silent (so sounds can be added as we get them). impact was the egg-pop
        -- placeholder (annoying on every hit) — now a punch (single_target_punch, group-owned);
        -- swap to a crystal-crack/whoosh later if a better one is sourced.
        sounds = {
            delivery = { id = "", volume = 0.5 },
            impact = { id = "rbxassetid://70478220013693", volume = 0.45 },
        },

        -- Gap-close counter: after firing, the ranged pet is movement-locked this long
        -- (it's "casting"), so it can't freely kite — a melee enemy gets a window to
        -- close. Keep < interval so it frees up briefly between shots.
        cast_lock_seconds = 0.45,
        duration = 0.3,
        thickness = 0.22,
        segments = 16,
        origin_limit = 1,
        strands_per_origin = 1,
        min_radius = 0,
        max_radius = 0.6,
        curve_size0 = 2,
        curve_size1 = 2,
        animation_speed = 9,
        flicker = 0.4,
        fade_out_seconds = 0.12,
        target_offset = { 0, 1.5, 0 }, -- {x,y,z} aim mid-body (client builds the Vector3)
        colors = { { 120, 150, 255 }, { 200, 235, 255 } }, -- electric blue/white

        -- Library impact played at the lightning strike point (RangedFX.IMPACTS), tinted with the
        -- electric colours above: "none" (arc + EnchantLightning's own flash only) | "small" |
        -- "medium" | "big". `impact` is the normal-hit tier; `impact_crit` fires when the server
        -- flags a crit (LastHitCrit on the pet) — so crits land a bigger blast. impact_scale /
        -- impact_sparks (normal) and crit_scale / crit_sparks (crit) optionally override defaults.
        impact = "small",
        impact_crit = "big",

        -- Projectile themes (kind = "fireball"/"plasma"/"frost"/"poison"): one travelling-orb
        -- engine, themed by colour/size/speed/burst. colors = { core, trail+burst }. travel_time
        -- = seconds orb takes to reach the target (keep < interval); burst = impact flash size;
        -- sparks = ember/shard bits the impact explosion sprays outward (0 = flash only). Each
        -- theme also supports impact / impact_crit (RangedFX.IMPACTS tier names) — default normal
        -- "small", crit "big" — so crits (server LastHitCrit) auto-land a bigger blast.
        projectile = {
            fireball = {
                colors = { { 255, 150, 40 }, { 255, 90, 20 } },
                size = 1.6,
                travel_time = 0.18,
                burst = 3.5,
                sparks = 9,
                impact = "small",
                impact_crit = "big",
            },
            plasma = {
                colors = { { 150, 90, 255 }, { 210, 170, 255 } },
                size = 1.3,
                travel_time = 0.13,
                burst = 3,
                sparks = 7,
            },
            -- ICE themes use the "shatter" impact (frost ring + glass shards) instead of embers.
            frost = {
                colors = { { 150, 220, 255 }, { 225, 245, 255 } },
                size = 1.4,
                travel_time = 0.2,
                burst = 3,
                sparks = 8,
                impact = "shatter",
                impact_crit = "big",
            },
            ice_shard = {
                colors = { { 170, 225, 255 }, { 235, 250, 255 } },
                size = 1.1,
                travel_time = 0.13,
                burst = 3,
                sparks = 6,
                impact = "shatter",
                impact_crit = "big",
            },
            poison = {
                colors = { { 120, 230, 90 }, { 175, 255, 120 } },
                size = 1.5,
                travel_time = 0.22,
                burst = 3.5,
                sparks = 8,
            },
            -- HEAL bolt: a soft green/gold orb that blooms (not explodes) on the ally. Used by
            -- the CombatFX heal category for single-target heals (ranged support + touch-heal).
            heal = {
                colors = { { 120, 230, 120 }, { 220, 255, 200 } },
                size = 1.2,
                travel_time = 0.16,
                burst = 3,
                sparks = 10,
                impact = "bloom",
                impact_crit = "bloom",
            },
            -- Per-biome heal-bolt tints (CombatFX picks heal_<element>): green / warm-gold / mint /
            -- amber — distinct per origin but still reads as a restorative bloom.
            heal_grass = {
                colors = { { 130, 240, 130 }, { 220, 255, 200 } },
                size = 1.2,
                travel_time = 0.16,
                burst = 3,
                sparks = 10,
                impact = "bloom",
                impact_crit = "bloom",
            },
            heal_lava = {
                colors = { { 255, 215, 120 }, { 255, 245, 200 } },
                size = 1.2,
                travel_time = 0.16,
                burst = 3,
                sparks = 10,
                impact = "bloom",
                impact_crit = "bloom",
            },
            heal_ice = {
                colors = { { 170, 245, 215 }, { 230, 255, 240 } },
                size = 1.2,
                travel_time = 0.16,
                burst = 3,
                sparks = 10,
                impact = "bloom",
                impact_crit = "bloom",
            },
            heal_desert = {
                colors = { { 240, 220, 140 }, { 215, 255, 185 } },
                size = 1.2,
                travel_time = 0.16,
                burst = 3,
                sparks = 10,
                impact = "bloom",
                impact_crit = "bloom",
            },
        },
        -- Beam theme (kind = "beam"): instant laser that flashes + fades.
        beam = { colors = { { 255, 70, 70 } }, thickness = 0.5, duration = 0.18, sparks = 5 },
        -- Rock throw (kind = "rock"): hurls a tumbling boulder, landing with a "dust" impact (tan
        -- cloud + rubble). DESERT theme. size = target max studs; colors = { rock tint, rubble/dust }.
        -- Uses the `boulder` mesh (UsePartColor tints it); falls back to a procedural Slate block if
        -- the asset hasn't replicated yet.
        rock = {
            model_asset = 111170421641061,
            colors = { { 150, 130, 105 }, { 200, 175, 135 } },
            size = 3.5,
            travel_time = 0.3,
            impact = "dust",
            impact_crit = "big",
        },

        -- Thrown-boulder VARIANTS (kind = the key). Each routes through the same tumbling-rock
        -- animation as `rock`, with its own mesh + tint + impact. Selected explicitly via a power-FX
        -- primitive's `projectile` (configs/power_fx.lua), or map an element to one in RANGED_KIND.
        boulders = {
            -- earth/desert rock (same mesh as `rock`, kept here so the `boulder` primitive resolves)
            boulder = {
                model_asset = 111170421641061,
                colors = { { 150, 130, 105 }, { 200, 175, 135 } },
                size = 3.5,
                travel_time = 0.3,
                impact = "dust",
                impact_crit = "big",
            },
            -- ice boulder: pale blue, shatters on impact (frost ring + shards) instead of dust
            ice_boulder = {
                model_asset = 111280557292002,
                colors = { { 170, 220, 255 }, { 230, 248, 255 } },
                size = 3.2,
                travel_time = 0.22,
                impact = "shatter",
                impact_crit = "big",
            },
            -- asteroid: dark rocky meteor, heavier + slower, big dusty impact
            asteroid = {
                model_asset = 134283982892096,
                colors = { { 90, 80, 75 }, { 140, 120, 105 } },
                size = 4.2,
                travel_time = 0.34,
                impact = "big",
                impact_crit = "big",
            },
        },
    },

    -- Server tick throttle (seconds): target leash + the mining damage tick only.
    -- Movement is client-side (PetFollowController), not done here.
    update_interval = 0.1,

    -- Enemy spawning (Feature 10 combat). distance = studs in front of the player a test enemy
    -- spawns (slice 1a: admin-spawned, stationary; pets engage it like a breakable).
    enemy_spawn = {
        distance = 16,
    },

    -- Mining gate: a pet only deals mining damage once it's within `range` studs of its target,
    -- so move speed affects mining throughput (DPS ramps as pets arrive). The server reads
    -- per-pet positions the owning client reports (see `replication`). If a pet has no reported
    -- position yet, mining is allowed — the gate never breaks the legacy "near = mines" behaviour.
    mining = {
        range = 9,
    },

    -- Mining impact FX — OPT-IN previewer for the impact library (RangedFX.IMPACTS). When enabled,
    -- each ore being mined plays a named impact on a cadence, so you can audit ANY impact (small /
    -- big / future entries) just by walking up to ore — no enemy or attack needed. Off by default:
    -- ranged pets already fire their real projectile at crystals/coins (the proper mining visual),
    -- so this is a tuning/preview tool, not gameplay. Flip enabled = true to A/B impacts.
    mining_fx = {
        enabled = false,
        impact = "big", -- "small" (projectile hit) | "medium" (shockwave + smoke) | "big" (really big)
        interval = 0.7, -- seconds between impacts per ore
        colors = { { 255, 150, 40 }, { 255, 90, 20 } }, -- fiery; swap per taste
        scale = 6,
        sparks = 16,
    },

    -- Client -> server pet position reporting (drives the mining gate; foundation for multiplayer
    -- pet visibility). Throttled to keep bandwidth modest.
    replication = {
        interval = 0.1, -- seconds between position reports (~10 Hz)
        stale_seconds = 0.5, -- a report older than this is ignored (gate falls back to "allow")
    },
}
