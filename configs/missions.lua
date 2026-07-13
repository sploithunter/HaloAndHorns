--[[
    Missions config — CoH-style door missions with deterministic procedural
    interiors (docs/MISSION_WORLDGEN.md §6).

    `worldgen_version` is folded into every mission seed: bump it when the
    solver algorithm changes so old seeds are invalidated DELIBERATELY
    instead of silently producing different maps.

    `slots`: same-server instance slots on a far X-band. spacing must stay
    > 2× StreamingTargetRadius (1024) so instances never stream into each
    other; keep origin_x + count*spacing well under ~50k studs (float
    precision).

    `seed_policy` per mission:
      "team_stable" — the same party re-entering gets the same map
      "per_attempt" — fresh map each run (attempt counter in the context
                      key); the resolved seed is stored on the instance so
                      any map a player saw can be regenerated for debugging

    Solver knobs are LayoutSolver params (docs §4); `solver_defaults` apply
    to every mission, `solver_overrides` merge on top per mission.
]]

return {
    -- v2: 6x tile scale (2026-07-08 playtest — "vastly too small" at v1 scale)
    worldgen_version = 2,

    slots = {
        origin_x = 24000,
        spacing = 3072, -- wider berth for the 6x-scale maps (envelope below caps sprawl)
        count = 8, -- last slot at 24000 + 7*3072 = 45504, inside float comfort
        y = 0,
    },

    limits = {
        per_team = 1, -- live instances per team
        global = 6, -- live instances per server
        max_lifetime = 1800, -- seconds; TTL sweep abandons older instances
    },

    -- Camera clamp while inside a mission: paired with the 48-stud kit walls
    -- so you can't zoom above the maze and scout the glowy; restored on exit.
    camera = {
        max_zoom = 45,
    },

    -- Trials are combat instances, not peaceful realm overworlds. Every pet/enemy pairing may
    -- initiate here; CurrentRealm still independently applies the configured 0.8x/1.5x resonance.
    -- Individual future mission types can override this with aggression_policy = "realm".
    combat = {
        default_aggression_policy = "universal",
    },

    -- PLAYER TRIAL DENSITY: a persistent, player-facing Settings slider. The opener's
    -- value owns the generated instance for the whole party; the server clamps it here
    -- before composing it with automatic team-size scaling. Keep the range deliberately
    -- broad while the level-14 baseline is playtested, then tighten these config values
    -- without another UI/service change. Boss and titan anchors never scale in count.
    player_tuning = {
        group_scale = {
            default = 1.0,
            min = 0.25,
            max = 2.0,
            step = 0.05,
        },
    },

    solver_defaults = {
        tile_budget = 30,
        target_depth = { min = 4, max = 8 },
        class_weights_by_band = {
            { upto = 0.5, corridor = 3, room = 1, junction = 1 },
            { upto = 1.0, corridor = 1, room = 3, junction = 1 },
        },
        -- hard slot envelope: at 6x tile scale a map must stay within
        -- ±max_half_extent of its slot origin or it could reach the next slot
        max_half_extent = 1200,
    },

    -- RANDOM MISSIONS (Jason: "always be on a random quest"): a MissionDoor
    -- with MissionId="random" rolls one of pool per entry with a fresh seed.
    -- Locked behind the quest unlock flag (GameData.Unlocks.random_missions,
    -- granted by the mi_first_trial quest claim).
    -- AUTO gates (MissionId="auto"): the active quest's mission binding
    -- (quests.lua def.mission) decides the trial; no binding = a roll from
    -- this pool. No unlock — the gate itself is the entry point.
    random = {
        pool = { "hell_trial", "heaven_trial", "lava_trial", "ice_trial" },
        -- REALM-AFFINE gates (Jason: "why when I go through the heaven gate
        -- on random trials do I get hell trials?"): an unbound gate inside a
        -- realm deals randoms from ITS side (element trials by dressing
        -- alignment: lava→hell, ice→heaven). Gates outside any realm — and
        -- unknown realms — fall back to the full pool.
        -- FULL-VARIETY realm pools (Jason: "I did want random enemies — a
        -- random hell trial should sometimes be a Hell Ice map or a Hell Sand
        -- map, not just the generic baddies"): the matrix trials ARE the
        -- enemy variety (pet-model rosters per element), so the random roll
        -- covers all five per side, uniform. NOTE the design shift: matrix
        -- counters now ALSO tick from random rolls — harmless by the
        -- retroactive-credit model (claims stay sequential, Century keeps
        -- claim-once + level 50); activation remains the way to CHOOSE.
        realm_pools = {
            hell = {
                "hell_trial",
                "lava_trial",
                "hell_lava_trial",
                "hell_ice_trial",
                "hell_grass_trial",
                "hell_desert_trial",
            },
            heaven = {
                "heaven_trial",
                "ice_trial",
                "heaven_lava_trial",
                "heaven_ice_trial",
                "heaven_grass_trial",
                "heaven_desert_trial",
            },
        },
        display = "Trials",
    },

    -- MISSION static-enemy scaling (Jason 2026-07-09, heaven boss + 2 LT =
    -- "good but not hard... lieutenants and minions need a little boost"):
    -- multiplies STATIC faction defs at mission spawn ONLY — homeworld
    -- spawner waves keep their own balance. Boss tier untouched (landing
    -- well). By enemies.lua tier key.
    -- v2 (Jason live: "I run through eight of them in five seconds...
    -- lieutenants and minions are just soft; bosses about right"): the
    -- first pass (+30/50%) was a rounding error against an L50 slotted
    -- squad. Minions should die in a few focused seconds EACH and hurt
    -- while alive; lieutenants should anchor.
    -- RANK AXIS RULE (Jason): rank scales its OWN way — a +0 boss ≫ a +3
    -- minion, a +0 lieutenant > a +1 minion. Level tuning must never be the
    -- substitute for rank identity: minions = volume, lieutenants = anchor
    -- + SPLASH, bosses = slam + splash + huge. (LT powers = future kit.)
    -- TEAM SCALING (Jason 2026-07-09, first duo run: "they seem pretty easy
    -- teamed up"): each extra team member multiplies non-boss unit COUNTS.
    -- Duo = 1 + 0.75 = 1.75x rank-and-file; bosses/titans stay singular.
    -- Applied after the seeded rolls, so trial #N keeps the same layout and
    -- pack picks at any team size — just denser.
    team_scaling = {
        count_per_extra_member = 0.75,
        max_mult = 2.5,
    },

    static_scaling = {
        trash_mob = { hp_mult = 2.0, dmg_mult = 1.5 },
        mid_tier = {
            hp_mult = 2.75,
            dmg_mult = 1.6,
            splash = { radius = 6, frac = 0.2 }, -- the lieutenant's rank tell
            -- WARCRY: the lieutenant RALLIES its band (+30% dmg, 5s, every
            -- 10s, 30 studs) — kill-the-LT-first becomes doctrine, the way
            -- healers already are. Generic band_buff executor (capital kit).
            abilities = {
                band_buff = { mult = 1.3, radius = 30, duration = 5, interval = 10 },
            },
        },
    },

    -- PET-MODEL enemy rank ladder (element trials: the realm's own pets as
    -- enemies — Jason: "use any of the models... boss versions by making
    -- huges of them"). Baseline = EnemyService._petEnemyDef (hp = base_health
    -- x enemy_patrol.pet_enemy_hp_mult, dmg = base_power); these multiply it.
    pet_ranks = {
        -- v2 alongside static_scaling (same softness verdict)
        minion = { hp_mult = 0.5, dmg_mult = 0.6 },
        lieutenant = {
            hp_mult = 1.4,
            dmg_mult = 1.0,
            armor = 60,
            tier = "mid_tier",
            scale_mult = 1.25,
            splash = { radius = 6, frac = 0.2 }, -- rank tell (matches statics)
            abilities = {
                band_buff = { mult = 1.3, radius = 30, duration = 5, interval = 10 },
            },
        },
        boss = {
            -- THE MIDDLE (Jason: the titan 'is fighting at archvillain
            -- level... put one in the middle') — what trial packs field by
            -- default. Calibrated against the static bosses (Magma Wyrm =
            -- the reference; dmg_mult stays low because apex species carry
            -- big base_power already).
            hp_mult = 8,
            dmg_mult = 1.5,
            armor = 150,
            tier = "boss",
            scale_mult = 4, -- big, not doorway-filling
            role = "tank",
            splash = { radius = 10, frac = 0.3 }, -- THE HUGE RULE
            abilities = {
                slam = { damage = 120, radius = 14, cooldown = 12, telegraph = 1.4, range = 40 },
            },
        },
        titan = {
            -- THE APEX (the thing that wiped Jason repeatedly, now honestly
            -- labeled): archvillain TIER — +3 rank levels, 6x XP, 12x loot
            -- premium, and the danger to match. NOT for regular trial packs;
            -- this is named-mission / event material.
            hp_mult = 14,
            dmg_mult = 2.2,
            armor = 200,
            tier = "archvillain",
            scale_mult = 6, -- the doorway-filler
            role = "tank",
            splash = { radius = 12, frac = 0.35 },
            abilities = {
                slam = { damage = 160, radius = 16, cooldown = 11, telegraph = 1.4, range = 40 },
            },
            display_prefix = "Titan ",
        },
    },

    missions = {
        -- REALM-SPLIT trials (Jason): hell = dark torch-lit (DOORS pole),
        -- heaven = bright low-poly (Dungeon Quest pole). Same gray-box kit —
        -- `theme` drives dressing palettes server-side and the client
        -- MissionAtmosphere lighting preset. Rosters are REALM-CORRECT
        -- (2026-07-08): each realm's trial pits you against its own kind —
        -- hell = the lava natives, heaven = the celestial host.
        hell_trial = {
            display = "Hell Trial",
            -- BOSS EGG (0.5% per credited player, ANY boss-tier kill in this
            -- trial — injected into pet-model boss defs at spawn) + the same
            -- 0.5% on FIRST-TIME sequence completion (replays don't advance,
            -- so short maps can't be re-run to farm eggs — Jason).
            boss_egg = { egg = "obsidian_egg", name = "Obsidian Egg", chance = 0.005 },
            kit = "gray_box",
            theme = "hell",
            -- everyone plays the same mission #1, #2, #3... (Jason: shared experience)
            seed_policy = "shared_sequence",
            -- CoH clear-gate: the glowy stays inert until every mission enemy
            -- is defeated — which also makes pets mandatory (players are
            -- invulnerable; only pets can clear). "reach_beacon" remains the
            -- ungated variant for future courier-style missions.
            objective = { kind = "clear_then_beacon" },
            -- static per-room packs (enemies.lua wave shape); one pack rolls
            -- per MissionSpawn point on the seeded "spawns" stream
            -- CoH SPAWN TABLES (Jason, L50/10-pet playtest: "way too easy"):
            -- minimum ~8 minions, or 2 lieutenants + 4 minions, or 1 boss +
            -- 3 minions — role variety (melee/blaster/support/tank) in every
            -- comp. Enemies tune to the team lead's level at spawn.
            packs = {
                { -- minion swarm (8): melee wave + blasters + a healer
                    weight = 10,
                    units = {
                        { enemy = "lava_imp", count = 4 },
                        { enemy = "murder_crow", count = 2 },
                        { enemy = "ember_acolyte", count = 2 },
                    },
                },
                { -- lieutenant pack: 2 brutes walling for 4 minions
                    weight = 7,
                    units = {
                        { enemy = "ember_brute", count = 2 },
                        { enemy = "lava_imp", count = 2 },
                        { enemy = "murder_crow", count = 1 },
                        { enemy = "ember_acolyte", count = 1 },
                    },
                },
                { -- boss pack: the Magma Wyrm + a screen of 3
                    weight = 3,
                    boss = true, -- population FORCES one of these at the objective room
                    units = {
                        { enemy = "infernal_boss", count = 1 },
                        { enemy = "lava_imp", count = 2 },
                        { enemy = "ember_acolyte", count = 1 },
                    },
                },
            },
            -- treasure chests (CoH glowie-lite): seeded placement in ~40% of
            -- room-class tiles (min 1); opening pays 1-2 guaranteed
            -- enhancement drops to the opener. Magnet is OFF in-mission.
            -- M5a dressing: per-room tint jitter + seeded clutter density.
            -- Farmable-crate scaling: HP = base + openerLevel*per_level
            -- (flat HP was a one-shot for endgame squads, 2026-07-08).
            decor = {
                props_min = 2,
                props_max = 5,
                color_jitter = 0.12,
                crate_health_base = 60,
                crate_health_per_level = 12,
                crate_value_base = 15,
                crate_value_per_level = 1,
                wall_decor_min = 2, -- playtest: 0..2 read as "very sparse"; pool is 8 names now
                wall_decor_max = 4,
                feature_chance = 0.6, -- chamber odds of a wall-backed showpiece (throne/fountain/...)
            },
            treasure = {
                room_fraction = 0.4,
                min_chests = 1,
                rolls_min = 1,
                rolls_max = 2,
                open_hold = 3, -- seconds standing at the chest to open it
            },
            solver_overrides = {},
        },
        heaven_trial = {
            display = "Heaven Trial",
            -- BOSS EGG (0.5% per credited player, ANY boss-tier kill in this
            -- trial — injected into pet-model boss defs at spawn) + the same
            -- 0.5% on FIRST-TIME sequence completion (replays don't advance,
            -- so short maps can't be re-run to farm eggs — Jason).
            boss_egg = { egg = "celestial_egg", name = "Celestial Egg", chance = 0.005 },
            kit = "gray_box",
            theme = "heaven",
            -- everyone plays the same mission #1, #2, #3... (Jason: shared experience)
            seed_policy = "shared_sequence",
            objective = { kind = "clear_then_beacon" },
            -- CoH SPAWN TABLES (see hell_trial note): swarm / lieutenants /
            -- boss comps with role variety; tuned to the team lead's level.
            packs = {
                { -- minion swarm (8): cherub wave + seraph blasters + healers
                    weight = 10,
                    units = {
                        { enemy = "zealous_cherub", count = 4 },
                        { enemy = "lance_seraph_guard", count = 2 },
                        { enemy = "radiant_sprite_guard", count = 2 },
                    },
                },
                { -- lieutenant pack: 2 wardens walling for 4 minions
                    weight = 7,
                    units = {
                        { enemy = "prism_warden", count = 2 },
                        { enemy = "zealous_cherub", count = 2 },
                        { enemy = "lance_seraph_guard", count = 1 },
                        { enemy = "radiant_sprite_guard", count = 1 },
                    },
                },
                { -- boss pack: the Archon + a screen of 3
                    weight = 3,
                    boss = true, -- population FORCES one of these at the objective room
                    units = {
                        { enemy = "celestial_archon", count = 1 },
                        { enemy = "zealous_cherub", count = 2 },
                        { enemy = "radiant_sprite_guard", count = 1 },
                    },
                },
            },
            decor = {
                props_min = 2,
                props_max = 5,
                color_jitter = 0.08, -- heaven reads cleaner with less drift
                crate_health_base = 60,
                crate_health_per_level = 12,
                crate_value_base = 15,
                crate_value_per_level = 1,
                wall_decor_min = 2, -- playtest: 0..2 read as "very sparse"; pool is 8 names now
                wall_decor_max = 4,
                feature_chance = 0.6, -- chamber odds of a wall-backed showpiece (throne/fountain/...)
            },
            treasure = {
                room_fraction = 0.4,
                min_chests = 1,
                rolls_min = 1,
                rolls_max = 2,
                open_hold = 3,
            },
            solver_overrides = {},
        },

        -- ==================== THE MATRIX TRIALS (2 realms x 4 elements) ====================
        -- Jason's endgame lattice (docs §12 + memory): each combo = its own
        -- sequence line, counter, quest track, and 100-clear Platinum chase.
        -- Gates deal these only via QUEST BINDINGS (not in random.pool yet).
        hell_lava_trial = {
            display = "Hell Lava Trial",
            kit = "gray_box",
            theme = "lava", -- element palette/atmosphere; pools alias realms
            area = "lava", -- biome RPS + lava-origin drops
            realm = "hell", -- light/shadow resonance axis
            seed_policy = "shared_sequence",
            objective = { kind = "clear_then_beacon" },
            boss_egg = { egg = "obsidian_egg", name = "Obsidian Egg", chance = 0.005 },
            packs = {
                { -- swarm: statics + realm pets
                    weight = 10,
                    units = {
                        { enemy = "lava_imp", count = 3 },
                        { pet = "frostcinder_imp", count = 2 },
                        { enemy = "ember_acolyte", count = 2 },
                        { enemy = "murder_crow", count = 1 },
                    },
                },
                { -- lieutenants: static wall + a pet captain
                    weight = 7,
                    units = {
                        { enemy = "ember_brute", count = 1 },
                        { pet = "rimemane_lion", rank = "lieutenant", count = 1 },
                        { enemy = "lava_imp", count = 2 },
                        { pet = "frostbrand_salamander", count = 2 },
                    },
                },
                { -- boss: the realm-origin apex
                    weight = 3,
                    boss = true, -- population FORCES one at the objective room
                    units = {
                        { pet = "abyssal_wyrm", rank = "boss", count = 1 },
                        { enemy = "lava_imp", count = 2 },
                        { enemy = "ember_acolyte", count = 1 },
                    },
                },
            },
            decor = {
                props_min = 2,
                props_max = 5,
                color_jitter = 0.1,
                crate_health_base = 60,
                crate_health_per_level = 12,
                crate_value_base = 15,
                crate_value_per_level = 1,
                wall_decor_min = 2,
                wall_decor_max = 4,
                feature_chance = 0.6,
            },
            treasure = {
                room_fraction = 0.4,
                min_chests = 1,
                rolls_min = 1,
                rolls_max = 2,
                open_hold = 3,
            },
            solver_overrides = {},
        },
        heaven_lava_trial = {
            display = "Heaven Lava Trial",
            kit = "gray_box",
            theme = "lava", -- element palette/atmosphere; pools alias realms
            area = "lava", -- biome RPS + lava-origin drops
            realm = "heaven", -- light/shadow resonance axis
            seed_policy = "shared_sequence",
            objective = { kind = "clear_then_beacon" },
            boss_egg = { egg = "celestial_egg", name = "Celestial Egg", chance = 0.005 },
            packs = {
                { -- swarm: statics + realm pets
                    weight = 10,
                    units = {
                        { enemy = "lava_imp", count = 3 },
                        { pet = "coronal_cherub", count = 2 },
                        { enemy = "ember_acolyte", count = 2 },
                        { enemy = "murder_crow", count = 1 },
                    },
                },
                { -- lieutenants: static wall + a pet captain
                    weight = 7,
                    units = {
                        { enemy = "ember_brute", count = 1 },
                        { pet = "prism_lion", rank = "lieutenant", count = 1 },
                        { enemy = "lava_imp", count = 2 },
                        { pet = "lance_seraph", count = 2 },
                    },
                },
                { -- boss: the realm-origin apex
                    weight = 3,
                    boss = true, -- population FORCES one at the objective room
                    units = {
                        { pet = "empyrean_dragon", rank = "boss", count = 1 },
                        { enemy = "lava_imp", count = 2 },
                        { enemy = "ember_acolyte", count = 1 },
                    },
                },
            },
            decor = {
                props_min = 2,
                props_max = 5,
                color_jitter = 0.1,
                crate_health_base = 60,
                crate_health_per_level = 12,
                crate_value_base = 15,
                crate_value_per_level = 1,
                wall_decor_min = 2,
                wall_decor_max = 4,
                feature_chance = 0.6,
            },
            treasure = {
                room_fraction = 0.4,
                min_chests = 1,
                rolls_min = 1,
                rolls_max = 2,
                open_hold = 3,
            },
            solver_overrides = {},
        },
        hell_ice_trial = {
            display = "Hell Ice Trial",
            kit = "gray_box",
            theme = "ice", -- element palette/atmosphere; pools alias realms
            area = "ice", -- biome RPS + ice-origin drops
            realm = "hell", -- light/shadow resonance axis
            seed_policy = "shared_sequence",
            objective = { kind = "clear_then_beacon" },
            boss_egg = { egg = "obsidian_egg", name = "Obsidian Egg", chance = 0.005 },
            packs = {
                { -- swarm: statics + realm pets
                    weight = 10,
                    units = {
                        { enemy = "frost_fox", count = 3 },
                        { pet = "dread_fox", count = 2 },
                        { enemy = "aurora_seal", count = 2 },
                        { enemy = "snowy_owl", count = 1 },
                    },
                },
                { -- lieutenants: static wall + a pet captain
                    weight = 7,
                    units = {
                        { enemy = "glacial_mammoth", count = 1 },
                        { pet = "rimewraith_fox", rank = "lieutenant", count = 1 },
                        { enemy = "frost_fox", count = 2 },
                        { pet = "dread_owl", count = 2 },
                    },
                },
                { -- boss: the realm-origin apex
                    weight = 3,
                    boss = true, -- population FORCES one at the objective room
                    units = {
                        { pet = "black_ice_leviathan", rank = "boss", count = 1 },
                        { enemy = "frost_fox", count = 2 },
                        { enemy = "aurora_seal", count = 1 },
                    },
                },
            },
            decor = {
                props_min = 2,
                props_max = 5,
                color_jitter = 0.1,
                crate_health_base = 60,
                crate_health_per_level = 12,
                crate_value_base = 15,
                crate_value_per_level = 1,
                wall_decor_min = 2,
                wall_decor_max = 4,
                feature_chance = 0.6,
            },
            treasure = {
                room_fraction = 0.4,
                min_chests = 1,
                rolls_min = 1,
                rolls_max = 2,
                open_hold = 3,
            },
            solver_overrides = {},
        },
        heaven_ice_trial = {
            display = "Heaven Ice Trial",
            kit = "gray_box",
            theme = "ice", -- element palette/atmosphere; pools alias realms
            area = "ice", -- biome RPS + ice-origin drops
            realm = "heaven", -- light/shadow resonance axis
            seed_policy = "shared_sequence",
            objective = { kind = "clear_then_beacon" },
            boss_egg = { egg = "celestial_egg", name = "Celestial Egg", chance = 0.005 },
            packs = {
                { -- swarm: statics + realm pets
                    weight = 10,
                    units = {
                        { enemy = "frost_fox", count = 3 },
                        { pet = "frostlight_doe", count = 2 },
                        { enemy = "aurora_seal", count = 2 },
                        { enemy = "snowy_owl", count = 1 },
                    },
                },
                { -- lieutenants: static wall + a pet captain
                    weight = 7,
                    units = {
                        { enemy = "glacial_mammoth", count = 1 },
                        { pet = "prism_fox", rank = "lieutenant", count = 1 },
                        { enemy = "frost_fox", count = 2 },
                        { pet = "starlight_owl", count = 2 },
                    },
                },
                { -- boss: the realm-origin apex
                    weight = 3,
                    boss = true, -- population FORCES one at the objective room
                    units = {
                        { pet = "aurora_leviathan", rank = "boss", count = 1 },
                        { enemy = "frost_fox", count = 2 },
                        { enemy = "aurora_seal", count = 1 },
                    },
                },
            },
            decor = {
                props_min = 2,
                props_max = 5,
                color_jitter = 0.1,
                crate_health_base = 60,
                crate_health_per_level = 12,
                crate_value_base = 15,
                crate_value_per_level = 1,
                wall_decor_min = 2,
                wall_decor_max = 4,
                feature_chance = 0.6,
            },
            treasure = {
                room_fraction = 0.4,
                min_chests = 1,
                rolls_min = 1,
                rolls_max = 2,
                open_hold = 3,
            },
            solver_overrides = {},
        },
        hell_grass_trial = {
            display = "Hell Grass Trial",
            kit = "gray_box",
            theme = "grass", -- element palette/atmosphere; pools alias realms
            area = "grass", -- biome RPS + grass-origin drops
            realm = "hell", -- light/shadow resonance axis
            seed_policy = "shared_sequence",
            objective = { kind = "clear_then_beacon" },
            boss_egg = { egg = "obsidian_egg", name = "Obsidian Egg", chance = 0.005 },
            packs = {
                { -- swarm: statics + realm pets
                    weight = 10,
                    units = {
                        { enemy = "rabid_dog", count = 3 },
                        { pet = "dread_hare", count = 2 },
                        { enemy = "rabid_bunny", count = 2 },
                        { enemy = "murder_crow", count = 1 },
                    },
                },
                { -- lieutenants: static wall + a pet captain
                    weight = 7,
                    units = {
                        { enemy = "raging_bear", count = 1 },
                        { pet = "icerot_stag", rank = "lieutenant", count = 1 },
                        { enemy = "rabid_dog", count = 2 },
                        { pet = "rimewither_sprite", count = 2 },
                    },
                },
                { -- boss: the realm-origin apex
                    weight = 3,
                    boss = true, -- population FORCES one at the objective room
                    units = {
                        { pet = "wither_sprite", rank = "boss", count = 1 },
                        { enemy = "rabid_dog", count = 2 },
                        { enemy = "rabid_bunny", count = 1 },
                    },
                },
            },
            decor = {
                props_min = 2,
                props_max = 5,
                color_jitter = 0.1,
                crate_health_base = 60,
                crate_health_per_level = 12,
                crate_value_base = 15,
                crate_value_per_level = 1,
                wall_decor_min = 2,
                wall_decor_max = 4,
                feature_chance = 0.6,
            },
            treasure = {
                room_fraction = 0.4,
                min_chests = 1,
                rolls_min = 1,
                rolls_max = 2,
                open_hold = 3,
            },
            solver_overrides = {},
        },
        heaven_grass_trial = {
            display = "Heaven Grass Trial",
            kit = "gray_box",
            theme = "grass", -- element palette/atmosphere; pools alias realms
            area = "grass", -- biome RPS + grass-origin drops
            realm = "heaven", -- light/shadow resonance axis
            seed_policy = "shared_sequence",
            objective = { kind = "clear_then_beacon" },
            boss_egg = { egg = "celestial_egg", name = "Celestial Egg", chance = 0.005 },
            packs = {
                { -- swarm: statics + realm pets
                    weight = 10,
                    units = {
                        { enemy = "rabid_dog", count = 3 },
                        { pet = "lightleaf_hare", count = 2 },
                        { enemy = "rabid_bunny", count = 2 },
                        { enemy = "murder_crow", count = 1 },
                    },
                },
                { -- lieutenants: static wall + a pet captain
                    weight = 7,
                    units = {
                        { enemy = "raging_bear", count = 1 },
                        { pet = "crystalbark_stag", rank = "lieutenant", count = 1 },
                        { enemy = "rabid_dog", count = 2 },
                        { pet = "radiant_sprite", count = 2 },
                    },
                },
                { -- boss: the realm-origin apex
                    weight = 3,
                    boss = true, -- population FORCES one at the objective room
                    units = {
                        { pet = "worldbloom_ent", rank = "boss", count = 1 },
                        { enemy = "rabid_dog", count = 2 },
                        { enemy = "rabid_bunny", count = 1 },
                    },
                },
            },
            decor = {
                props_min = 2,
                props_max = 5,
                color_jitter = 0.1,
                crate_health_base = 60,
                crate_health_per_level = 12,
                crate_value_base = 15,
                crate_value_per_level = 1,
                wall_decor_min = 2,
                wall_decor_max = 4,
                feature_chance = 0.6,
            },
            treasure = {
                room_fraction = 0.4,
                min_chests = 1,
                rolls_min = 1,
                rolls_max = 2,
                open_hold = 3,
            },
            solver_overrides = {},
        },
        hell_desert_trial = {
            display = "Hell Desert Trial",
            kit = "gray_box",
            theme = "desert", -- element palette/atmosphere; pools alias realms
            area = "desert", -- biome RPS + desert-origin drops
            realm = "hell", -- light/shadow resonance axis
            seed_policy = "shared_sequence",
            objective = { kind = "clear_then_beacon" },
            boss_egg = { egg = "obsidian_egg", name = "Obsidian Egg", chance = 0.005 },
            packs = {
                { -- swarm: statics + realm pets
                    weight = 10,
                    units = {
                        { enemy = "sand_jackal", count = 3 },
                        { pet = "gloom_jackal", count = 2 },
                        { enemy = "golden_scarab", count = 2 },
                        { enemy = "carrion_vulture", count = 1 },
                    },
                },
                { -- lieutenants: static wall + a pet captain
                    weight = 7,
                    units = {
                        { enemy = "dune_tortoise", count = 1 },
                        { pet = "wraith_dove", rank = "lieutenant", count = 1 },
                        { enemy = "sand_jackal", count = 2 },
                        { pet = "rime_scarab", count = 2 },
                    },
                },
                { -- boss: the realm-origin apex
                    weight = 3,
                    boss = true, -- population FORCES one at the objective room
                    units = {
                        { pet = "dread_couatl", rank = "boss", count = 1 },
                        { enemy = "sand_jackal", count = 2 },
                        { enemy = "golden_scarab", count = 1 },
                    },
                },
            },
            decor = {
                props_min = 2,
                props_max = 5,
                color_jitter = 0.1,
                crate_health_base = 60,
                crate_health_per_level = 12,
                crate_value_base = 15,
                crate_value_per_level = 1,
                wall_decor_min = 2,
                wall_decor_max = 4,
                feature_chance = 0.6,
            },
            treasure = {
                room_fraction = 0.4,
                min_chests = 1,
                rolls_min = 1,
                rolls_max = 2,
                open_hold = 3,
            },
            solver_overrides = {},
        },
        heaven_desert_trial = {
            display = "Heaven Desert Trial",
            kit = "gray_box",
            theme = "desert", -- element palette/atmosphere; pools alias realms
            area = "desert", -- biome RPS + desert-origin drops
            realm = "heaven", -- light/shadow resonance axis
            seed_policy = "shared_sequence",
            objective = { kind = "clear_then_beacon" },
            boss_egg = { egg = "celestial_egg", name = "Celestial Egg", chance = 0.005 },
            packs = {
                { -- swarm: statics + realm pets
                    weight = 10,
                    units = {
                        { enemy = "sand_jackal", count = 3 },
                        { pet = "aurora_dove", count = 2 },
                        { enemy = "golden_scarab", count = 2 },
                        { enemy = "carrion_vulture", count = 1 },
                    },
                },
                { -- lieutenants: static wall + a pet captain
                    weight = 7,
                    units = {
                        { enemy = "dune_tortoise", count = 1 },
                        { pet = "prism_scarab", rank = "lieutenant", count = 1 },
                        { enemy = "sand_jackal", count = 2 },
                        { pet = "mirage_meerkat", count = 2 },
                    },
                },
                { -- boss: the realm-origin apex
                    weight = 3,
                    boss = true, -- population FORCES one at the objective room
                    units = {
                        { pet = "empyreal_couatl", rank = "boss", count = 1 },
                        { enemy = "sand_jackal", count = 2 },
                        { enemy = "golden_scarab", count = 1 },
                    },
                },
            },
            decor = {
                props_min = 2,
                props_max = 5,
                color_jitter = 0.1,
                crate_health_base = 60,
                crate_health_per_level = 12,
                crate_value_base = 15,
                crate_value_per_level = 1,
                wall_decor_min = 2,
                wall_decor_max = 4,
                feature_chance = 0.6,
            },
            treasure = {
                room_fraction = 0.4,
                min_chests = 1,
                rolls_min = 1,
                rolls_max = 2,
                open_hold = 3,
            },
            solver_overrides = {},
        },

        -- ELEMENT-THEMED trials (Jason: "a lava trial or an ice trial where
        -- pet selection actually matters and enhancement drops change").
        -- realm = NEUTRAL: their pet-choice axis is the biome RPS (zone
        -- element via mission.area pseudo-zone), and drops brand to the
        -- element's origin (area_origins). Realm trials stay the resonance +
        -- random-origin variety. Enemies mix the static faction with PET-
        -- model units — boss = a HUGE-scaled pet.
        lava_trial = {
            display = "Lava Trial",
            -- BOSS EGG (0.5% per credited player, ANY boss-tier kill in this
            -- trial — injected into pet-model boss defs at spawn) + the same
            -- 0.5% on FIRST-TIME sequence completion (replays don't advance,
            -- so short maps can't be re-run to farm eggs — Jason).
            boss_egg = { egg = "obsidian_egg", name = "Obsidian Egg", chance = 0.005 },
            kit = "gray_box",
            theme = "lava", -- bespoke palette + atmosphere (pools alias hell's)
            area = "lava", -- pseudo-zone: biome RPS + pyromancer-branded drops
            realm = "neutral",
            seed_policy = "shared_sequence",
            objective = { kind = "clear_then_beacon" },
            packs = {
                { -- swarm: whelps + heaven-lava cherubs + moth healers
                    weight = 10,
                    units = {
                        { enemy = "lava_imp", count = 3 },
                        { pet = "coronal_cherub", count = 2 },
                        { enemy = "ember_acolyte", count = 2 },
                        { enemy = "murder_crow", count = 1 },
                    },
                },
                { -- lieutenants: brute wall + a lion captain
                    weight = 7,
                    units = {
                        { enemy = "ember_brute", count = 1 },
                        { pet = "rimemane_lion", rank = "lieutenant", count = 1 },
                        { enemy = "lava_imp", count = 2 },
                        { pet = "lumen_salamander", count = 2 },
                    },
                },
                { -- boss: the HUGE Empyrean Dragon holds the deep room
                    weight = 3,
                    boss = true, -- population FORCES one of these at the objective room
                    units = {
                        { pet = "empyrean_dragon", rank = "boss", count = 1 },
                        { enemy = "lava_imp", count = 2 },
                        { enemy = "ember_acolyte", count = 1 },
                    },
                },
            },
            decor = {
                props_min = 2,
                props_max = 5,
                color_jitter = 0.12,
                crate_health_base = 60,
                crate_health_per_level = 12,
                crate_value_base = 15,
                crate_value_per_level = 1,
                wall_decor_min = 2,
                wall_decor_max = 4,
                feature_chance = 0.6,
            },
            treasure = {
                room_fraction = 0.4,
                min_chests = 1,
                rolls_min = 1,
                rolls_max = 2,
                open_hold = 3,
            },
            solver_overrides = {},
        },
        ice_trial = {
            display = "Ice Trial",
            -- BOSS EGG (0.5% per credited player, ANY boss-tier kill in this
            -- trial — injected into pet-model boss defs at spawn) + the same
            -- 0.5% on FIRST-TIME sequence completion (replays don't advance,
            -- so short maps can't be re-run to farm eggs — Jason).
            boss_egg = { egg = "celestial_egg", name = "Celestial Egg", chance = 0.005 },
            kit = "gray_box",
            theme = "ice", -- bespoke palette + atmosphere (pools alias heaven's)
            area = "ice", -- pseudo-zone: biome RPS + cryomancer-branded drops
            realm = "neutral",
            seed_policy = "shared_sequence",
            objective = { kind = "clear_then_beacon" },
            packs = {
                { -- swarm: foxes + prism foxes + seal healers
                    weight = 10,
                    units = {
                        { enemy = "frost_fox", count = 3 },
                        { pet = "prism_fox", count = 2 },
                        { enemy = "aurora_seal", count = 2 },
                        { enemy = "snowy_owl", count = 1 },
                    },
                },
                { -- lieutenants: mammoth wall + a doe captain
                    weight = 7,
                    units = {
                        { enemy = "glacial_mammoth", count = 1 },
                        { pet = "frostlight_doe", rank = "lieutenant", count = 1 },
                        { enemy = "frost_fox", count = 2 },
                        { pet = "starlight_owl", count = 2 },
                    },
                },
                { -- boss: the HUGE Black Ice Leviathan
                    weight = 3,
                    boss = true, -- population FORCES one of these at the objective room
                    units = {
                        { pet = "black_ice_leviathan", rank = "boss", count = 1 },
                        { enemy = "frost_fox", count = 2 },
                        { enemy = "aurora_seal", count = 1 },
                    },
                },
            },
            decor = {
                props_min = 2,
                props_max = 5,
                color_jitter = 0.08,
                crate_health_base = 60,
                crate_health_per_level = 12,
                crate_value_base = 15,
                crate_value_per_level = 1,
                wall_decor_min = 2,
                wall_decor_max = 4,
                feature_chance = 0.6,
            },
            treasure = {
                room_fraction = 0.4,
                min_chests = 1,
                rolls_min = 1,
                rolls_max = 2,
                open_hold = 3,
            },
            solver_overrides = {},
        },
    },
}
