--[[
    Combat tuning + spawners — Halo & Horns [PROTOTYPE] (Feature 10).

    auto_target            — default pet targeting mode ("nearest").
    group_scaling          — enemy HP scaling for multiplayer (Feature 18):
                             scaledHp = baseHp * (1 + per_extra_player * (partySize - 1)).
    pet_down_threshold_factor — a pet has no HP stat; it can absorb
                             power * this_factor accumulated enemy damage before
                             it is downed -> Spirit Form (Feature 7) -> auto-return
                             from the active squad (Feature 9).
    spawners               — zoneId -> { biome, enemies = { {id, count}, ... } }.
                             Marker placement is authored map work ([studio]).

    Read by CombatService; pure math lives in `src/Shared/Game/CombatMath.lua`.
]]

return {
    auto_target = "nearest",

    -- COMBAT BALANCE TRACING: gates the server balance logs ([RageTrace], [CombatXP], [Defeat],
    -- [AggroTrace], [FearTrace], [PowerCast] taunt/rage/fear) that we read while tuning combat. Left
    -- in the code (Jason: "we need them for combat") but flag-gated so they don't spam a normal run —
    -- flip to true for a balancing pass.
    combat_trace = true,
    -- [GlassTrace] SUB-FLAG: the per-hit pet-endurance line fires on EVERY landed enemy hit — in a
    -- 12-enemy brawl that's a flood (it contributed to a frame-time spike). Needs combat_trace AND
    -- this. The *** DOWNED *** / DOWN markers stay on combat_trace alone (rare + always valuable).
    glass_trace = false,
    -- [DefenseTrace] SUB-FLAG: decomposes each incoming hit into damage prevented by the active
    -- player armor buff, shield absorption, Mirage healing, and final endurance damage. Enable only
    -- for an armor-vs-shield balance capture; `_G.DefenseTrace = true` also opens it live in Studio.
    defense_trace = false,
    -- [AggroTrace] SUB-FLAG: one line PER ENGAGED ENEMY PER SECOND — a 12-enemy fight floods the
    -- output so hard it evicts everything else from the log history (it buried the fear casts in
    -- the 2026-07-02 live test). Needs combat_trace AND this; flip on only when reading the threat
    -- tables directly (fear/taunt/aggro debugging). [FearTrace]/[PowerCast] stay on combat_trace.
    aggro_trace = false,

    -- CONTROL COUNTERS: encounter mechanics, not blanket duration nerfs.
    -- Support enemies cannot themselves be held, but remain vulnerable to Disarm; they telegraph
    -- an interruptible cleanse that releases nearby held allies. Bosses always grant a short useful
    -- hold window, then break out and gain brief hold resistance before they can be held again.
    control_counters = {
        support_cleanse = {
            enabled = true,
            role = "support",
            hold_immune = true,
            range = 24,
            windup_seconds = 1.5,
            cooldown_seconds = 14,
            interrupted_cooldown_seconds = 4,
        },
        boss_breakout = {
            enabled = true,
            tiers = { boss = true, archvillain = true },
            windup_seconds = 2.5,
            cooldown_seconds = 24,
            resistance_seconds = 4,
        },
    },

    group_scaling = {
        per_extra_player = 0.5,
    },

    -- 10x WORLD (Jason, 2026-06-12): pools x10 on BOTH sides (this factor + every
    -- enemies.lua hp) with damage untouched -> fights run ~10x longer at IDENTICAL
    -- win rates / survival fractions (CoH pacing: pull -> 3-4 power casts -> defeat
    -- -> breathe). Every pool-relative FLAT scaled with it: regen trickles below,
    -- power heal/absorb/DoT magnitudes in configs/powers.lua. Fractions (rage
    -- threshold, aura heals, degradation stages) scale for free.
    pet_down_threshold_factor = 10.0,

    -- Pet attack pacing (fire-rate <-> damage tradeoff). Applied to every pet swing in
    -- PetFollowService:_mine: the per-pet attack interval is multiplied by interval_mult
    -- (>1 = slower swings) and per-swing damage by damage_mult (>1 = harder hits). Setting
    -- BOTH to the same value keeps DPS constant while changing the feel — e.g. { 2, 2 } =
    -- half as many hits, each twice as big (net-same DPS, punchier + more readable). 1 = no-op.
    -- Lets us "slow down how fast things shoot" without changing balance; tune freely.
    pet_attack_pacing = {
        interval_mult = 1.0,
        damage_mult = 1.0,
    },

    -- AoE pets (PetTargeting attack_targeting = "aoe" / "targeted_aoe"): a pet whose attack hits an
    -- AREA — its swing on the primary target also splashes to OTHER targets near it (nearby enemies
    -- in a fight, nearby crystals when mining). Same SSOT field that rings the archetype badge.
    -- splash_fraction of the primary hit, within splash_radius studs, capped at max_targets others.
    pet_aoe = {
        splash_radius = 14,
        splash_fraction = 0.6,
        max_targets = 5,
    },

    -- AURA pets (PetTargeting attack_targeting = "aura"): a damage FIELD around the pet itself —
    -- every `interval`s it deals `fraction` of its effective combat power to EVERY enemy within
    -- `radius` studs, with no target needed (a "get close and everything burns" bruiser). Lower
    -- fraction than a direct hit because it's constant + multi-target. A continuous fire-ring VFX
    -- follows the pet (Power_AreaFx, sized to radius).
    pet_aura = {
        radius = 12,
        fraction = 0.5,
        interval = 1.0,
        -- The aura's VISUAL is a persistent, pet-following ground FIELD (CombatFX aurafield, themed in
        -- combat_fx.lua), not a per-tick burst — so there's no repeating cast/slam sound to dampen.
        -- The server stamps AuraFieldUntil each engaged tick; the client renders the field while live.
    },

    -- CONTAGION pets (PetTargeting attack_targeting = "contagion"): the burn SPREADS. Their hit
    -- applies a DoT (so a contagion pet needs an attack_dot — the burn that propagates), and while
    -- it ticks it jumps to the nearest un-burning enemy within `spread_radius` every
    -- `spread_interval`, chaining up to `max_spread` hops (each hop carries one fewer). The plague:
    -- light one, watch the pack catch fire. Sequential (not an instant splash) — that's what makes
    -- it a distinct targeting type vs targeted_aoe.
    pet_contagion = {
        spread_radius = 8, -- center-to-center studs; ~bodies-touching (5-6 = literally touching, 16 = jumps across a gap)
        spread_interval = 1.5,
        max_spread = 4,
    },

    -- ROAMING PATROL BANDS (Hell realms — "heaven battling evil"): a persistent pack per origin area
    -- that patrols a procedural route. Reuses everything — SpawnEnemy places members, the idle LOITER
    -- (engagement.loiter) drifts them around entry.home, and we just walk that shared `home` anchor
    -- through waypoints with dwell (Jason's "move the center of origin, pause, repeat"). Anchored to
    -- the realm's BaddieSpawner<Area> parts (same per-area parts crystals/waves use); waypoints are
    -- sampled around the anchor (grounded raycast, like crystal spawn points). SLICE 1: flag off,
    -- one placeholder enemy model for every band (per-area heaven-pet factions = the content pass).
    enemy_patrol = {
        enabled = true, -- FLAG: ships dark; flip live (Studio) to test, then per-area content
        placeholder_enemy = "lava_imp", -- fallback when a cave's origin isn't mapped below
        -- PER-AREA FACTION (Jason: "lava-only models from lava, so I know where they came from").
        -- Each cave fields a signature enemy keyed off its origin (the BaddieSpawner<Origin> suffix),
        -- so a band's model tells you at a glance which zone it sortied from. Each id is that origin's
        -- defined melee enemy (enemies.lua). Unmapped origins fall back to placeholder_enemy.
        patrol_enemy_by_origin = {
            Lava = "lava_imp", -- the lava melee (cinder_whelp is only a wave alias, not a real def)
            Ice = "frost_fox",
            Desert = "sand_jackal",
            Grass = "rabid_dog",
        },
        -- The grass cave is authored "BaddieSpawnerEarth" (player-facing), but its ore folders and
        -- faction use "Grass" (the frozen element id). Bridge the cave suffix -> element id so the
        -- areaId (Heaven_1_Grass) and enemy (rabid_dog) both resolve. Don't rename the cave/folder.
        patrol_origin_alias = { Earth = "Grass" },
        -- PET INVADERS (Jason: "heaven pets attack hell, hell pets attack heaven — same models, just
        -- attached to the attack script"). When true, a realm patrol fields the OPPOSING realm's PET
        -- models as the band (heaven realm -> hell pets, hell realm -> heaven pets) instead of the
        -- realm-neutral element packs below. The pet's mesh/texture/scale render the model; hp =
        -- base_health x pet_enemy_hp_mult, attack damage = base_power. They are NOT acquirable — pure
        -- model+stat wrappers on the enemy AI. One sortie in pet_invader_scary_chance leads with the
        -- strongest opposing pet (the "somewhat scary" band).
        use_pet_invaders = true,
        pet_enemy_hp_mult = 10, -- base_health -> enemy hp (matches the 10x world pool scaling)
        pet_enemy_cadence = 1.5, -- seconds between an invader's attacks
        pet_enemy_move_speed = 15, -- studs/sec chase speed
        -- ROLE-FAITHFUL INVADERS (Jason live-caught 2026-07-07: patrols read all-melee — the
        -- roster's tanks/ranged/control were flattened to melee by the synth). Overlays keyed by
        -- pet_roles.by_type: tank soaks (hp up, dmg down), ranged/BLASTER stands off and fires
        -- (attack_range like the crow) hitting harder but squishier, control roots a nearby pet
        -- on an interval (movement pin — the full hold stays a boss-kit power). Support is its
        -- own path (damage 0 + band mending). Melee = the unmodified baseline.
        pet_invader_roles = {
            tank = { hp_mult = 2.2, dmg_mult = 0.7 },
            ranged = { hp_mult = 0.7, dmg_mult = 1.4, attack_range = 30 },
            control = {
                dmg_mult = 0.8,
                root = { duration = 1.8, radius = 20, interval = 9, targets = 1 },
            },
        },
        pet_invader_scary_chance = 0.18, -- chance a sortie leads with the strongest opposing pet
        -- VARIED BANDS (Jason: "a random-ish mix like home; one band somewhat scary"). Each sortie
        -- rolls a weighted composition from the cave origin's pool (mirrors the home wave tables:
        -- swarm / ranged-harass / healer-escort / scary warband). scary=true marks the rare tough
        -- pack (a tank/boss anchor + escorts) — low weight so it shows up occasionally, not every
        -- sortie. All ids are DEFINED enemies (enemies.lua). Origins with no pool fall back to
        -- band_size copies of patrol_enemy_by_origin. max_band_units caps any one comp defensively.
        max_band_units = 8,
        patrol_bands_by_origin = {
            Grass = {
                { weight = 10, label = "Dog Pack", units = { { enemy = "rabid_dog", count = 3 } } },
                {
                    weight = 7,
                    label = "Crow Harass",
                    units = {
                        { enemy = "murder_crow", count = 2 },
                        { enemy = "rabid_dog", count = 1 },
                    },
                },
                {
                    weight = 6,
                    label = "Healer Escort",
                    units = {
                        { enemy = "rabid_bunny", count = 1 },
                        { enemy = "rabid_dog", count = 2 },
                    },
                },
                {
                    weight = 3,
                    scary = true,
                    label = "Bear Warband",
                    units = {
                        { enemy = "raging_bear", count = 1 },
                        { enemy = "rabid_dog", count = 2 },
                        { enemy = "murder_crow", count = 1 },
                    },
                },
            },
            Desert = {
                {
                    weight = 10,
                    label = "Jackal Pack",
                    units = { { enemy = "sand_jackal", count = 3 } },
                },
                {
                    weight = 7,
                    label = "Vulture Harass",
                    units = {
                        { enemy = "carrion_vulture", count = 2 },
                        { enemy = "sand_jackal", count = 1 },
                    },
                },
                {
                    weight = 6,
                    label = "Scarab Escort",
                    units = {
                        { enemy = "golden_scarab", count = 1 },
                        { enemy = "sand_jackal", count = 2 },
                    },
                },
                {
                    weight = 3,
                    scary = true,
                    label = "Tortoise Warband",
                    units = {
                        { enemy = "dune_tortoise", count = 1 },
                        { enemy = "sand_jackal", count = 2 },
                        { enemy = "carrion_vulture", count = 1 },
                    },
                },
            },
            Ice = {
                { weight = 10, label = "Fox Pack", units = { { enemy = "frost_fox", count = 3 } } },
                {
                    weight = 7,
                    label = "Owl Harass",
                    units = {
                        { enemy = "snowy_owl", count = 2 },
                        { enemy = "frost_fox", count = 1 },
                    },
                },
                {
                    weight = 6,
                    label = "Seal Escort",
                    units = {
                        { enemy = "aurora_seal", count = 1 },
                        { enemy = "frost_fox", count = 2 },
                    },
                },
                {
                    weight = 3,
                    scary = true,
                    label = "Mammoth Warband",
                    units = {
                        { enemy = "glacial_mammoth", count = 1 },
                        { enemy = "frost_fox", count = 2 },
                        { enemy = "snowy_owl", count = 1 },
                    },
                },
            },
            Lava = {
                { weight = 10, label = "Imp Pack", units = { { enemy = "lava_imp", count = 3 } } },
                {
                    weight = 7,
                    label = "Acolyte Escort",
                    units = {
                        { enemy = "ember_acolyte", count = 1 },
                        { enemy = "lava_imp", count = 2 },
                    },
                },
                {
                    weight = 6,
                    label = "Brute Duo",
                    units = {
                        { enemy = "ember_brute", count = 1 },
                        { enemy = "lava_imp", count = 2 },
                    },
                },
                {
                    weight = 3,
                    scary = true,
                    label = "Infernal Warband",
                    units = {
                        { enemy = "infernal_boss", count = 1 },
                        { enemy = "lava_imp", count = 2 },
                        { enemy = "ember_acolyte", count = 1 },
                    },
                },
            },
        },
        realm_layers_only = true, -- only in realm layers (heaven_/hell_), never home
        band_size = 4, -- members fielded per group (ONE batch, never trickle-refilled mid-fight)
        waypoints = 3, -- patrol-route stops sampled around the cave (A -> B -> C, then home)
        patrol_radius = 100, -- studs around the cave to pick crystal stops from
        anchor_speed = 8, -- studs/sec the band's home anchor walks between waypoints
        arrive_dist = 6, -- anchor counts a waypoint "reached" within this
        dwell_min = 2.0, -- pause range at each crystal stop (seconds)
        dwell_max = 5.0,
        cave_rest_min = 5.0, -- longer rest back at the cave between sorties (seconds)
        cave_rest_max = 10.0,
        member_scatter = 10, -- members spawn within this radius of the cave
        -- ONE GROUP AT A TIME (Jason): the cave never fields a new group until the previous one is
        -- entirely gone (killed or aged out), then waits this beat before the next sortie spawns. No
        -- mid-combat reinforcement — a second group appearing while you fought the first was the bug.
        group_respawn_min = 6.0,
        group_respawn_max = 14.0,
        -- STRAY SAFETY (Jason): a member that outlives this (a lost/abandoned straggler, never in an
        -- active fight) despawns on its own so the field can't accrete ghosts we can't find.
        member_max_age = 240,
    },

    -- Defensive stat (armor curve). Damage is reduced by armor/(armor+k): a pet's
    -- Defense attribute mitigates enemy hits, an enemy's Armor mitigates pet damage.
    -- At armor == k the hit is halved; diminishing returns, never full immunity.
    -- Tune k to set how much a point of armor is worth.
    armor_curve_k = 100,

    -- DEV CANDLES (BuffStatsHud ⏱ rows): standard SAME-LEVEL matchups for the battle-
    -- clock pacing readout (Jason: "battles are way too fast... over before you realize
    -- they've started"; then "a Lieutenant, a boss, three minions and maybe a team").
    -- One row per matchup; each pack entry references a real enemies.lua def so every
    -- candle tracks enemy rebalances automatically. Add/remove matchups freely — the
    -- panel builds a row per entry (this list IS how you manage "it's getting a lot").
    -- Packs are simulated under focus fire: incoming damage DECAYS as targets die.
    dev_candle = {
        matchups = {
            {
                label = "Lieut.",
                max_seconds = 300,
                pack = { { enemy = "ember_brute", count = 1 } },
            },
            { label = "Boss", max_seconds = 300, pack = { { enemy = "dire_bear", count = 1 } } },
            {
                label = "3 Minions",
                max_seconds = 300,
                pack = { { enemy = "lava_imp", count = 3 } },
            },
            {
                label = "Warband",
                max_seconds = 300,
                pack = {
                    { enemy = "ember_brute", count = 1 },
                    { enemy = "lava_imp", count = 3 },
                },
            },
        },
    },

    -- Defensive inverse mining (Feature 10 slice 1b). An enemy "mines" the
    -- endurance of the pets attacking it; pets attack back when an enemy is in
    -- range (combat outranks auto-mine so pets don't scatter to crystals).
    engagement = {
        aggro_range = 45, -- enemy engages a player's squad within this (studs)
        -- Which in-range enemy each pet attacks when there's no player assist target. Per-pet
        -- override via the pet's TargetPriority attribute (src/Shared/Game/TargetPriority.lua);
        -- this is the squad default. Modes: aggro (most angry at the pet, else closest) /
        -- closest / furthest / strongest / weakest / team_threat.
        target_priority = { default = "aggro" },
        attack_range = 11, -- enemy damages a pet within this of itself (studs)
        -- Chase + perception (slice 2). An idle enemy NOTICES a player by distance
        -- x probability (rolled every perception_interval; certain on top, zero past
        -- perception_range). Once it has aggro it CHASES (move_speed lives per enemy
        -- in configs/enemies.lua) until within attack_range, biting the highest-THREAT
        -- pet in range — so a tank pet (high Threat attribute, else its Power) pulls
        -- aggro off squishier pets. It drops aggro if the player leaves leash_range.
        perception_range = 70,
        perception_interval = 0.75,
        -- ANTI-HANG: an aggro'd enemy that can neither reach attack range nor close the gap toward its
        -- target for this many seconds (e.g. leashed at its boundary while the squad sits beyond it)
        -- DESPAWNS — disengaging just sends it back to patrol where it flees + re-aggros into the same
        -- loop, so we remove it outright (frees the player's InCombat); a fresh patrol fills in shortly.
        stuck_disengage_seconds = 20,
        -- (leash_range removed: persistence is now the aggro block's decay_start_range/give_up_range)
        -- COMBAT STANCE (Jason): while a player has >=1 enemy aggroed on them ("in combat"), AUTO-FARM
        -- pauses and non-engaged pets hold combat formation instead of wandering off to mine crystals.
        -- The auto-farm SETTING is untouched (player never sees it toggle) — it just doesn't fire while
        -- a fight is on, and resumes the instant no enemy is angry at them. false = keep farming mid-fight.
        pause_farm_in_combat = true,
        -- COMBAT ONRAMP (Jason): enemies stay INERT toward players below this level — they spawn,
        -- loiter, and are visible to everyone, but won't aggress, and a sub-threshold player's pets
        -- won't pull (they keep mining). So L1..(min-1) is a peaceful mining onramp with the threat
        -- on display; combat switches on at min_engage_level — the level BEFORE the first origin power
        -- (L6) + the heaven/hell choice, so the taste of combat comes before picking a direction.
        -- 0/1 disables the gate (everyone fights).
        min_engage_level = 5,
        -- FIRST FIGHT nerf (Jason: "there's no possible way a bunny can beat
        -- this thing" — a stock trash mob wiped the starter squad): the
        -- onramp cave's solo creature spawns with its def scaled by these.
        -- A quarter-strength Jackalope dies fast and barely scratches —
        -- "the odds of being defeated are pretty low" by construction.
        onramp = {
            hp_mult = 0.25,
            dmg_mult = 0.2,
        },
        -- ENGAGED FLYERS DESCEND (Jason, level-3 foxes vs a ceiling-height
        -- Ember Moth: "they're not even trying to get to the moth... this is
        -- a locked game"): while a flyer has aggro it clamps to this hover so
        -- ground melee can trade — flyer identity lives in the DISENGAGE (it
        -- escapes upward) and in endgame control-counter play, not in being
        -- unhittable by a new player's starter squad.
        flyer_combat_hover = 3,
        -- Probe the aggro OWNER'S support floor from only this far above their
        -- HumanoidRootPart while a flyer is engaged. The normal ground ray starts
        -- 80 studs above the enemy so it can recover from caves, but that also
        -- mistakes tall decorative geometry (the Lava spikes are 73 studs tall)
        -- for the combat floor. Owner-relative probing finds the surface the
        -- player/squad is actually standing on and keeps the flyer melee-reachable.
        flyer_combat_floor_probe_above_owner = 4,
        -- FILL LIGHT (Jason): an internal PointLight on each spawned creature so its baked texture
        -- doesn't read gray/washed-out in the low-ambient biomes (it lifts the mesh out of the murk;
        -- the light sits at the body centre, just inside the mesh, so nothing is visible). Range
        -- auto-scales to the model (range_factor x max extent), shadows off. Per-enemy `fill_light`
        -- in configs/enemies.lua: false disables, a number overrides brightness. enabled=false = off.
        fill_light = { enabled = true, brightness = 1.75, range_factor = 0.6 },
        -- GROUND SNAP (Jason): enemies born in an elevated spawner (a cave) were hovering at spawn
        -- height because nothing pulled their Y to the terrain. Each move step now raycasts down to
        -- the floor and sits the body on it (+ per-enemy hover_height for flyers). false = off.
        ground_snap = true,
        -- Ground support probes start just above the enemy pivot. Starting 80 studs overhead made
        -- multi-level Trial rooms select a mezzanine/roof as the "floor" and freeze chase below it.
        ground_probe_above = 2,
        -- Max studs an enemy may snap UP in one move step. Slopes rise a little per step and pass;
        -- a vertical wall makes the downcast jump to the wall top (a big rise) -> the step is
        -- rejected, so enemies don't climb onto walls/ledges. Steps DOWN are always allowed.
        ground_climb_max = 10,
        -- Chase uses the same per-step rise ceiling as ordinary movement. Authored mountains remain
        -- climbable because their slopes rise gradually; an abrupt wall/ledge produces one large
        -- downcast jump and is rejected instead of becoming a 28-stud jump-assist landing.
        ground_jump_max = 10,
        -- Chase routing: direct scene ray first; only a blocked wall/pillar pays for a Roblox path.
        -- The nav agent is intentionally small because enemies are collideless and imported art can
        -- have broad bounding boxes. The normal shared chase step follows each returned waypoint.
        pathfinding = {
            enabled = true,
            agent_radius = 1,
            agent_height = 2,
            can_jump = true,
            can_climb = false,
            waypoint_spacing = 4,
            waypoint_reached_distance = 3,
            replan_target_distance = 8,
        },
        -- RALLY (tactical command): for this many seconds the player's pets ignore combat and
        -- return to formation around the player; the enemies keep their aggro on the pets and
        -- chase them home, so the fight comes back to the player instead of drifting off.
        rally_seconds = 3.5,
        -- FOCUS / assist target (clicking an enemy to direct the squad) is a TRANSIENT order, not a
        -- permanent lock: it expires this many seconds after it's issued, then pets fall back to
        -- their normal auto-targeting (nearest aggressor). Re-click to refresh. Prevents the
        -- "stuck on an unreachable focus, squad does nothing" trap (Jason): orders are nudges you
        -- re-issue as the field changes, like real squad commands.
        assist_seconds = 5,
        -- IDLE DESPAWN (engagement timer): an enemy that has been DISENGAGED (no aggro on anyone)
        -- this many seconds leaves the field — so abandoned/leashed packs (and a fled-from death
        -- zone) clean themselves up instead of piling to max_alive. A live fight refreshes the clock
        -- every tick the enemy holds aggro, so it NEVER fires mid-battle (Jason). 0 disables.
        despawn_idle_seconds = 30,
        default_move_speed = 12,
        -- When chasing, the enemy presses this many studs INSIDE attack_range instead of
        -- parking on its edge — otherwise it stalls just out of bite range of a kiting
        -- target (float boundary) and never lands a hit. Keep < attack_range.
        attack_press = 3,
        -- Surround spacing: when several enemies pile onto ONE pet they fan out around it
        -- (RingSeparate) instead of stacking on the same point. This is how close two of them
        -- may sit (studs) before they slide tangentially apart — bigger = a looser fan. Purely
        -- positional: each stays the same distance from the target, so threat/damage are unchanged.
        surround_gap = 6,
        -- Client render smoothing: the server moves enemies in ~update_interval steps;
        -- EnemyMotion (client) interpolates the visible model toward each step at this
        -- exponential rate (higher = snappier, lower = floatier). Server stays the
        -- authority for position; this only smooths what the player sees.
        render_lerp_rate = 12,
        -- Procedural walk gait (client, EnemyMotion): rig-less mesh enemies get a
        -- waddle while moving — a vertical bob plus a bank/wiggle about the facing axis.
        -- Driven by distance travelled, so it scales with speed and stops when the enemy
        -- is still. This is the DEFAULT; each enemy in configs/enemies.lua can override
        -- any field via its own `gait = {...}` (merged over this), so different pets move
        -- differently. `style` selects the motion shape (EnemyMotion STYLES):
        --   waddle  — bob 2x/stride + left/right bank 1x (the classic down->L->up->down->R->up)
        --   march   — stiff bob, no tilt
        --   hop     — one big bounce per stride, no tilt
        --   slither — no bob, heading wiggles left/right (snake-like)
        gait = {
            enabled = true,
            style = "waddle",
            bob_height = 0.6, -- studs of vertical bob at full amplitude
            tilt_degrees = 12, -- max bank / wiggle (degrees) at full amplitude
            stride_length = 5, -- studs travelled per full cycle (2 bobs / 1 tilt L+R)
            ref_speed = 8, -- speed (studs/s) at which the gait reaches full amplitude
            ease_rate = 8, -- how fast the gait fades in/out as it starts/stops
        },
        -- Idle LOITER (#217): an unaware enemy drifts around its home like idle
        -- pets meander (same PetMeander machine, server-side; the client gait
        -- renders the stroll). Slower + ranger than pets - they're patrolling,
        -- not pottering. Aggro/chase overrides instantly. enabled=false to kill.
        loiter = {
            enabled = true,
            radius = 10,
            speed = 3,
            pause_min = 2,
            pause_max = 6,
        },
        -- A downed pet (taken all the way down) is out for this long, then fully
        -- heals — the "fully defeated takes X to heal" consequence. Partially
        -- damaged pets bleed their damage back at regen.partial_per_second once
        -- they have been out of combat for regen.delay_seconds.
        -- NATURAL regen is deliberately SLOW (a trickle) so heal powers / support pets / potions are
        -- the FAST way back — that's what makes them worth slotting. Tune the trickle here.
        full_defeat_heal_seconds = 25,
        regen = {
            partial_per_second = 15, -- a slow trickle (x10 world; same relative rate) — heals/support/potions are the FAST way back
            delay_seconds = 5, -- the "must disengage" window before the trickle even starts
            -- DOWNTIME CATCH-UP: once the whole squad is out of combat and this pet has gone
            -- uninjured for 15s, recover a fraction of its own pool each second. Flat regen alone
            -- made high-power tanks take many minutes to refill. 12.5%/s = at most 8s after the
            -- catch-up begins; downed pets still require their normal recovery/revive path.
            fast_delay_seconds = 15,
            fast_fraction_per_second = 0.125,
        },
        -- ENEMY regen (Jason: "enemies and pets are essentially supposed to be the exact
        -- same mechanic") — same shape as the pet trickle above, at A THIRD of the pet
        -- rate (15 / 3 = 5 HP/sec; the anchor is the CURRENT pet rate — if the pet
        -- trickle gets retuned, revisit this). Disengage from a half-dead enemy and it
        -- slowly knits back together, so you can't whittle one down across visits for free.
        enemy_regen = {
            partial_per_second = 5,
            delay_seconds = 5,
        },
        -- Instant effects (heals etc.) have no duration to show, so we flash a blinking
        -- badge on the pet's squad card for this long + pop a world puff — a visible
        -- "tell" of what just happened. Server stamps `HealFxUntil = os.time()+this`.
        instant_fx_seconds = 3,
        -- Aggro / threat table (src/Shared/Game/AggroTable). The enemy chases + bites the
        -- highest-aggro attacker. Aggro builds from DAMAGE dealt to the enemy
        -- (damage_factor per point) plus PASSIVE threat each second (× the attacker's
        -- Threat stat, so a tank holds aggro). It DECAYS at decay_per_second, so once
        -- nothing keeps hitting the enemy the top entry bleeds away; when the top drops
        -- to/below disengage_threshold the enemy gives up and idles. taunt_amount is the
        -- chunk a taunt/provoke power adds (player or tank drawing aggro; wired later).
        aggro = {
            passive_per_second = 1.5,
            -- passive threat (a tank's Threat stat holding aggro) only builds while the pet is within
            -- this many studs of the enemy. A pet idling farther away — even inside give_up_range —
            -- adds nothing, so the always-on decay WINS and the enemy bleeds out → disengages →
            -- patrols. Without this, a non-fighting pet loitering across the area refilled aggro as
            -- fast as it decayed and pinned the enemy "in combat" forever (never despawned). Keep
            -- above attack/proximity range so an actively-fighting tank never starves mid-bite.
            passive_range = 60,
            damage_factor = 1.0,
            decay_per_second = 4,
            disengage_threshold = 0.5,
            taunt_amount = 250,
            -- LEASH (src/Shared/Game/AggroLeash) — how long an enemy stays angry as its target moves
            -- away. PURE DECAY (Jason): no hard "locked on" zone — the enemy stays engaged only while
            -- some threat remains, and threat bleeds faster the farther you run, so keep your distance
            -- and it gives up. Measured to the NEAREST LIVE PET (combat is vs pets; pets follow the
            -- player). This replaced the old player-keyed leash(90)/draft(45) (wrong frame, too short).
            --   <= decay_start_range        : threat decays at the base rate (you're "in the fight").
            --   decay_start_range..give_up  : threat decays chase_decay_mult× faster (and
            --                                 leave_area_decay_mult× once you've left the enemy's home
            --                                 area) -> a fleeing target is forgotten after a short chase.
            --   > give_up_range             : DROP instantly — the ONE hard cutoff, teleport insurance.
            -- (Initial aggro / how close you must get to be NOTICED is separate: perception_range.)
            decay_start_range = 90,
            give_up_range = 300,
            chase_decay_mult = 3,
            leave_area_decay_mult = 6,
            -- Proximity aggro: any attacker within proximity_range of the enemy keeps a
            -- baseline aggro of proximity_floor (> disengage_threshold), so decay can't
            -- make the enemy "forget" a pet right next to it — get close enough and it
            -- engages. Only once everything leaves range does aggro bleed to zero and the
            -- enemy disengages. (A future stealth flag exempts a target from this floor.)
            proximity_range = 30,
            proximity_floor = 6,
            -- Implicit taunt: roles flagged `implicit_taunt` (tanks) automatically grab
            -- the enemy's attention. Every `interval` seconds a taunting pet's aggro is
            -- bumped to `lead` × the highest OTHER attacker — so it leads the pack and
            -- holds the enemy. It is NOT absolute: between pulses a pet doing a huge burst
            -- of damage out-aggros and rips the enemy off the tank until the next pulse.
            -- Tune interval/lead to balance how sticky tanks are.
            taunt = {
                interval = 3,
                lead = 1.3,
            },
        },
        -- Hit / crit rolls (src/Shared/Game/CombatRoll). Every attack and taunt rolls to
        -- land and to crit; a miss does nothing, a crit multiplies the effect by crit_mult.
        --   pet_attack  — a pet's damage to an enemy
        --   enemy_attack — an enemy's bite on a pet
        --   taunt       — a tank's implicit-taunt pulse (miss = the taunt fizzles this
        --                 pulse; crit = a stronger grab, lead × crit_mult)
        rolls = {
            pet_attack = { hit_chance = 0.92, crit_chance = 0.15, crit_mult = 2.0 },
            enemy_attack = { hit_chance = 0.85, crit_chance = 0.1, crit_mult = 1.8 },
            taunt = { hit_chance = 0.9, crit_chance = 0.2, crit_mult = 1.5 },
            -- CRIT LEVEL SCALING (enemy_attack only): +1.5%/level above the
            -- pet, floor 5%, cap 25% — a +3 boss (rank-baked +2, so ~+5)
            -- crits ~17-18% of swings, and crits PIERCE shields (EnemyService)
            -- v2 (Jason: +1 fights too easy): steeper ladder, higher cap —
            -- a +1 lieutenant crits ~14%, a +3 boss ~20%, all shield-piercing
            crit_level_scale = { per_level = 0.02, floor = 0.05, cap = 0.3 },
        },
    },

    -- Level-diff TO-HIT curve (src/Shared/Game/Accuracy). hit_chance = clamp(base_to_hit +
    -- per_level_step*(attackerEffectiveLevel - defenderLevel), floor, cap). The defender's
    -- published Level already bakes in its rank_offset (boss reads +2), so a boss is naturally
    -- harder to land on — no separate rank term needed. MINING is exempt (crystals can't dodge):
    -- mining_hit_chance applies to breakables with no EnemyId. This replaces the old flat
    -- engagement.rolls.pet_attack.hit_chance for the HIT decision; CombatRoll still owns crit.
    accuracy = {
        base_to_hit = 0.92, -- even-level to-hit (8% miss baseline)
        per_level_step = 0.04, -- to-hit lost per level the target is above you (gained if below)
        floor = 0.05,
        cap = 0.95,
        mining_hit_chance = 1.0, -- crystals never miss (fixes the old 8% mining whiff)
    },

    -- Staged degradation (§11.3): a pet visibly weakens before it is downed, so the
    -- player can RECALL it first (the agency that makes recall worthwhile). Keyed off
    -- the pet's health fraction (1 = full, 0 = downed): at/below strained_at -> Strained,
    -- at/below critical_at -> Critical. The *_damage_penalty fractions reduce the damage
    -- a pet DEALS in that state (0 = off for now; wired with the HUD's combat effects).
    degradation = {
        strained_at = 0.6,
        critical_at = 0.3,
        strained_damage_penalty = 0.0,
        critical_damage_penalty = 0.0,
    },

    -- Squad-HUD status badges (the buff/debuff icons on the right-side pet cards).
    -- When a timed effect is within `blink_lead_seconds` of expiring, its badge
    -- blinks so the player notices it's about to drop. `blink_period_seconds` is one
    -- full on/off cycle. Pool effects with no expiry (e.g. shield) never blink.
    status_badges = {
        blink_lead_seconds = 5,
        blink_period_seconds = 0.5,
    },

    spawners = {
        hell_1_lava = {
            biome = "lava",
            enemies = {
                { id = "lava_imp", count = 4 },
                { id = "ember_brute", count = 1 },
            },
        },
    },
}
