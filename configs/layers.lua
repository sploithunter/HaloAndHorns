--[[
    Layer config — Halo & Horns.

    Stacked vertical layers: base, Heaven 1-5, Hell 1-5. Owns the reward economics
    (Feature 4), element/realm mapping (Feature 5/6), and access gating
    (Feature 3 + World S3: Soul magnitude + token cost + player level, validated
    server-side). Geometry (Y-offsets) and the visual portals are authored map work;
    this config is the contract those bind to.

    `multipliers`     : reward scaling per layer (base = 1.0).
    `token_currency`  : side-reward / access token per layer.
    `realm_alignment` : "neutral"/"heaven"/"hell" (drives element resonance).
    `hatch_element`   : element a pet is born with when hatched on the layer.
    `access`          : per-layer { y_offset, requires_soul, token_cost, requires_level }.
                        base has no requirement; Heaven needs soul >= requires_soul
                        (positive), Hell needs soul <= requires_soul (negative);
                        requires_level gates by the player's earned Level (World S3).

    Retention note (design doc §12/§14): these layers are the NON-terminal endgame —
    `token_cost` is a recurring traversal SINK (LayerService:UseLayer deducts per move),
    not a one-time unlock. Deeper = higher soul + level + token cost AND richer rewards.
]]

return {
    -- Boot-to-base: on join, reset the player to the base layer and publish the layer attributes
    -- (CurrentLayer/CurrentRealm) so the client realm skin + RealmHellFaces apply on spawn. Without
    -- the publish, those attributes were only ever set by a portal toggle, so a restored realm never
    -- lit up on boot (and entering took two clicks). Realms are entered deliberately each session.
    boot_to_base = true,

    -- Traversal sink shape (design doc §14, fork 2 — gameplay-tunable knob):
    --   "deeper_only" = free to retreat toward base/neutral; pay the target layer's token_cost
    --                   only when moving to a DEEPER layer (greater magnitude depth). [default]
    --   "every_move"  = pay the target's token_cost on every layer change (the original behavior).
    -- The recurring token sink that anchors the realm economy; flip live to compare feel.
    traversal = {
        charge_on = "deeper_only",
    },

    -- Token-earning loop (design doc §14, fork 1 — feeds the traversal sink above).
    -- Light/shadow tokens are earned only while in a realm layer (heaven -> light,
    -- hell -> shadow). income_cut converts that fraction of biome-coin income into the
    -- realm token (income_min floors a positive trickle); conquest/hatch are flat grants.
    earning = {
        income_cut = 0.1,
        income_min = 1,
        conquest_tokens = 25,
        hatch_tokens = 2,
    },

    -- Depth = desirability (design doc §12/§15): deeper realm layers add hatch luck on top of
    -- the player's own entitlements, so the rarest pulls (golden/rainbow/eternal) live deep.
    -- hatch_luck_per_depth is added per layer depth (heaven_3 / hell_3 -> +0.3, the 5s -> +0.5).
    depth_rewards = {
        hatch_luck_per_depth = 0.1,
    },

    -- TEST portals (RealmPortalService): named workspace parts you walk up to, mapped to a realm
    -- layer. Toggling enters that realm (or returns to base if already in it). `bypass_access`
    -- skips the soul/level/token gate so the realm is reachable for testing before the economy
    -- is grindable — flip false once gating is being verified. Reuses the same map (the
    -- RealmAtmosphere client skin retints the world); not the production realm-geometry path.
    realm_portals = {
        -- OPEN (Jason): realms have content now. Travel is a TOUCH → yes/no offer (RealmPortalService).
        -- The gate is per-portal by GEOMETRY: a portal whose realm folder exists is touchable; one
        -- without keeps the "COMING SOON" badge and does nothing. `locked=false` just lets the travel
        -- action run for everyone (no admin gate); the geometry check still prevents void-falls.
        locked = false,
        admin_unlock = true, -- retained; no effect on the touch path now that locked=false
        lock_badge_studs = 10, -- "COMING SOON" badge size on still-unbuilt realm portals
        bypass_access = true,
        prompt_hold = 0,
        max_distance = 14,
        -- Portal_Halo1-5 -> heaven_1-5, Portal_Horn1-5 -> hell_1-5. Each jumps DIRECTLY to its
        -- layer (touch again while standing on it to return to base), so you can hop base ->
        -- Halo3 -> Halo5 to test any depth.
        portals = {
            { part = "Portal_Halo1", layer = "heaven_1", action = "Enter Heaven 1" },
            { part = "Portal_Halo2", layer = "heaven_2", action = "Enter Heaven 2" },
            { part = "Portal_Halo3", layer = "heaven_3", action = "Enter Heaven 3" },
            { part = "Portal_Halo4", layer = "heaven_4", action = "Enter Heaven 4" },
            { part = "Portal_Halo5", layer = "heaven_5", action = "Enter Heaven 5" },
            { part = "Portal_Horn1", layer = "hell_1", action = "Enter Hell 1" },
            { part = "Portal_Horn2", layer = "hell_2", action = "Enter Hell 2" },
            { part = "Portal_Horn3", layer = "hell_3", action = "Enter Hell 3" },
            { part = "Portal_Horn4", layer = "hell_4", action = "Enter Hell 4" },
            { part = "Portal_Horn5", layer = "hell_5", action = "Enter Hell 5" },
        },
    },

    -- Client realm skin (RealmAtmosphere, World S3 A1) — DEPTH-SCALED. The client captures the
    -- map's real base lighting and blends base -> the realm's `deep` anchor below by t = depth /
    -- max_depth (RealmTheme): layer 1 = a faint 20% wash, the deepest layer = the full `deep` look.
    -- So each descent step intensifies; the most dramatic look is reserved for layer 5.
    -- `tint` is a ColorCorrection TintColor (0-1); ambient / fog / atmosphere colors are 0-255 RGB.
    -- (Only the `deep` endpoint is configured — the shallow end is the live captured base.)
    atmosphere = {
        tween_seconds = 1.2,
        max_depth = 5,
        -- Heaven deep (layer 5): blinding, radiant celestial.
        heaven = {
            tint = { 1, 0.99, 0.92 },
            brightness = 0.2,
            contrast = 0.05,
            clock_time = 14,
            ambient = { 200, 195, 170 },
            outdoor_ambient = { 235, 228, 200 },
            fog_color = { 250, 248, 235 },
            fog_end = 4000,
            atmosphere = {
                density = 0.4,
                offset = 0.05,
                color = { 252, 248, 235 },
                decay = { 245, 238, 215 },
                glare = 0.7,
                haze = 2.0,
            },
        },
        -- Hell deep (layer 5): red, oppressive MOOD — but lit enough to see your own character +
        -- the ground (the dark/dramatic SKY now comes from the per-layer skybox, so the lighting
        -- doesn't need to crush the world). Enemies can still lurk in the red murk.
        hell = {
            tint = { 1, 0.58, 0.5 },
            brightness = 0.02,
            contrast = 0.12,
            clock_time = 2,
            ambient = { 0, 0, 0 }, -- ambient OFF — pitch-black hell (user: "it was black, the red wash is wrong")
            outdoor_ambient = { 0, 0, 0 },
            fog_color = { 45, 14, 12 },
            fog_end = 1000,
            atmosphere = {
                density = 0.35, -- was 0.55 — thin the murk so you're not lost in it
                offset = 0.2,
                color = { 120, 40, 32 },
                decay = { 80, 22, 16 },
                glare = 0.2,
                haze = 2.2,
            },
        },
        -- Per-LAYER skybox swap (RealmAtmosphere). One sky per layer — base + heaven_1-5 +
        -- hell_1-5 — so the sky escalates with depth alongside the lighting (Hell 1 = brooding red
        -- clouds -> Hell 5 = the eyes-in-the-abyss). Authoring: generate an equirectangular 2:1
        -- panorama per layer, convert to 6 cubemap faces, upload, and drop the asset ids below
        -- (numbers or "rbxassetid://..."). `textures = { ft, bk, lf, rt, up, dn, sun?, moon? }`.
        -- A layer left nil keeps the map's base sky (captured + restored), so fill them in as you
        -- generate each. Applied per layer; the lighting ramp above scales intensity within it.
        sky = {
            per_layer = {
                -- base = nil means "don't swap" — RealmAtmosphere leaves the place's own Sky alone
                -- (so whatever sky you set in the map shows in Play too). The ORIGINAL aurora sky
                -- is RECORDED here for restore (not active, so it can't override your tests):
                --   aurora faces: ft=340908468 bk=340908398 lf=340908504 rt=340908530
                --                 up=340908586 dn=340908450  (CelestialBodiesShown=false, StarCount=5000)
                --   aurora mood: Atmosphere Density 0.28 / Color (0.247,0.635,0.220) green / Haze 1;
                --                Lighting ClockTime 13 / Brightness 1.88 / FogEnd 100000.
                -- To make a layer use a sky, fill its `textures = { ft, bk, lf, rt, up, dn, ... }`.
                base = { textures = nil },
                heaven_1 = { textures = nil },
                heaven_2 = { textures = nil },
                heaven_3 = { textures = nil },
                heaven_4 = { textures = nil },
                heaven_5 = { textures = nil },
                hell_1 = {
                    textures = {
                        ft = 72553765826706,
                        bk = 92241207750302,
                        lf = 138038201122541,
                        rt = 94865800916028,
                        up = 89930062014588,
                        dn = 97468777327797,
                        celestial_bodies_shown = false,
                    },
                },
                hell_2 = {
                    textures = {
                        ft = 104546429898763,
                        bk = 99960987517987,
                        lf = 102019268027119,
                        rt = 106724041487205,
                        up = 130939998101973,
                        dn = 127294774735759,
                        celestial_bodies_shown = false,
                    },
                },
                -- Hyper3D "nightmarish demon-infested hellscape, glowing red eyes, jagged spired
                -- cities" — dramatic mid-hell (you can still see). One-line move to hell_2 if shallower.
                hell_3 = {
                    textures = {
                        ft = 136769467498269,
                        bk = 76076955500596,
                        lf = 96726444149379,
                        rt = 128315364827628,
                        up = 128070223417654,
                        dn = 80101487417158,
                    },
                },
                hell_4 = {
                    textures = {
                        ft = 115778938011231,
                        bk = 140409478026965,
                        lf = 106621185787267,
                        rt = 133932701501959,
                        up = 121688909163908,
                        dn = 82579821400928,
                        celestial_bodies_shown = false, -- custom sky: hide the default sun/moon
                    },
                },
                hell_5 = {
                    textures = {
                        ft = 102213954263406,
                        bk = 100049080158700,
                        lf = 74423796663126,
                        rt = 86898675313846,
                        up = 138010467678345,
                        dn = 70514714416769,
                        celestial_bodies_shown = false, -- the abyss: custom sky, no default sun/moon
                    },
                },
            },
        },
    },

    multipliers = {
        base = 1.0,
        -- SINGLE SOURCE OF TRUTH for per-layer coin income. Crystals pay their base `value`
        -- everywhere (no per-world value_mult); this multiplier is the only income-by-depth lever
        -- (crystal `health_mult` is a SEPARATE toughness/feel lever, not income). Curve is monotonic
        -- "deeper = richer". L1 stays 5.0 (entry eggs must be affordable). L2 = 8.0 holds the layer-2
        -- realms at their current income while removing the crystal value_mult (8.0 = the 2.0 it had
        -- × the 4x value_mult that's now gone), so this change is income-neutral for L2 and the
        -- magnitude is tuned via egg cost. L3-5 ramp +3/layer (untuned placeholders).
        heaven_1 = 5.0,
        heaven_2 = 8.0,
        heaven_3 = 11.0,
        heaven_4 = 14.0,
        heaven_5 = 17.0,
        hell_1 = 5.0,
        hell_2 = 8.0,
        hell_3 = 11.0,
        hell_4 = 14.0,
        hell_5 = 17.0,
    },

    -- CONTENT LEVEL offset per realm depth (World S3 — the 50-level / 6-realm progression plan).
    -- Home content spans levels 1-6 (grass 1 -> desert 6, +0/1/2 for S/M/L). Because LevelDiffYield
    -- pays FULL XP for any target at-or-above you and only diminishes content BELOW you, home gives
    -- ~6 full + 2 effort levels then floors at ~9 (Jason: "home was perfect"). A REALM must replicate
    -- that band shifted up, so leveling continues — each depth adds +9 (home's band width) to every
    -- crystal/enemy's effective level. So heaven_1/hell_1 content = 10-15 (covers players ~8-17),
    -- depth 2 = 19-24, … depth 5 = 46-51 — six bands tiling 1->50, each ~7 normal + 2 effort + floor.
    -- "Any direction" is fine: a fresh realm's content is all ABOVE you, so every biome pays full XP
    -- regardless of unlock order; the grass->desert staircase re-emerges as you out-level the low end.
    -- heaven_N and hell_N share depth N's offset (parallel directions, same band). Consumed via
    -- LayerService:GetLevelOffset in the XP diminishing (BreakableSpawner / CombatService).
    level_offsets = {
        base = 0,
        heaven_1 = 9,
        heaven_2 = 18,
        heaven_3 = 27,
        heaven_4 = 36,
        heaven_5 = 45,
        hell_1 = 9,
        hell_2 = 18,
        hell_3 = 27,
        hell_4 = 36,
        hell_5 = 45,
    },

    token_currency = {
        heaven_1 = "light_tokens",
        heaven_2 = "light_tokens",
        heaven_3 = "light_tokens",
        heaven_4 = "light_tokens",
        heaven_5 = "light_tokens",
        hell_1 = "shadow_tokens",
        hell_2 = "shadow_tokens",
        hell_3 = "shadow_tokens",
        hell_4 = "shadow_tokens",
        hell_5 = "shadow_tokens",
    },

    realm_alignment = {
        base = "neutral",
        heaven_1 = "heaven",
        heaven_2 = "heaven",
        heaven_3 = "heaven",
        heaven_4 = "heaven",
        heaven_5 = "heaven",
        hell_1 = "hell",
        hell_2 = "hell",
        hell_3 = "hell",
        hell_4 = "hell",
        hell_5 = "hell",
    },

    hatch_element = {
        base = "neutral",
        heaven_1 = "light",
        heaven_2 = "light",
        heaven_3 = "light",
        heaven_4 = "light",
        heaven_5 = "light",
        hell_1 = "shadow",
        hell_2 = "shadow",
        hell_3 = "shadow",
        hell_4 = "shadow",
        hell_5 = "shadow",
    },

    -- requires_soul: Heaven layers need soul >= value; Hell layers need soul <=
    -- value (negative). requires_level: the player's earned Level must be >= value
    -- (skipped when the caller doesn't supply a level — the pure module stays judgable).
    -- token_cost is paid in the layer's token_currency EVERY traversal (recurring sink).
    -- base has no requirement.
    access = {
        base = { y_offset = 0, requires_soul = nil, token_cost = 0, requires_level = nil },

        -- entry_anchor: a named anchor Part inside the destination realm's map folder
        -- (workspace.Maps.<Folder>) that the gate teleports the player TO, instead of a pure
        -- Y-shift from where they stood. Lets each realm START the player in a specific area
        -- (Heaven 1 -> Lava, where the Fire/Dragon roster lives). Falls back to the Y-shift if
        -- the anchor is absent.
        heaven_1 = {
            y_offset = 2000,
            requires_soul = 20,
            token_cost = 100,
            requires_level = 7, -- Jason: realm travel gated by Level (1=7, +7 per layer). Layers 3-5
            -- ALSO need their realm geometry built (the COMING SOON gate) before the level gate matters.
            entry_anchor = "SpawnLocationLava",
        },
        heaven_2 = { y_offset = 4000, requires_soul = 40, token_cost = 250, requires_level = 14 },
        heaven_3 = { y_offset = 6000, requires_soul = 60, token_cost = 500, requires_level = 21 },
        heaven_4 = { y_offset = 8000, requires_soul = 80, token_cost = 1000, requires_level = 28 },
        heaven_5 = {
            y_offset = 10000,
            requires_soul = 100,
            token_cost = 2000,
            requires_level = 35,
        },

        hell_1 = { y_offset = -2000, requires_soul = -20, token_cost = 100, requires_level = 7 },
        hell_2 = { y_offset = -4000, requires_soul = -40, token_cost = 250, requires_level = 14 },
        hell_3 = { y_offset = -6000, requires_soul = -60, token_cost = 500, requires_level = 21 },
        hell_4 = { y_offset = -8000, requires_soul = -80, token_cost = 1000, requires_level = 28 },
        hell_5 = {
            y_offset = -10000,
            requires_soul = -100,
            token_cost = 2000,
            requires_level = 35,
        },
    },

    -- The watcher: a giant demon head that haunts HELL 5 ONLY (RealmHellFaces). The server
    -- LoadAssets the model once into ReplicatedStorage.RealmModels at boot; the client clones it,
    -- scales it huge, darkens the face into shadow, and raycast-seats two recessed Neon eyes deep
    -- in the sockets. It appears INTERMITTENTLY (not always there) and FOLLOWS the player — gliding
    -- to hover at ~45 deg up, 200 studs out, always turning to face you. Client-side per player.
    hell_faces = {
        enabled = true,
        model_asset_id = 87113428787101,
        template_name = "HellFace", -- runtime cache under ReplicatedStorage.RealmModels

        only_layer = "hell_5", -- ONLY ever appears in Hell 5 (nil = any hell layer)
        scale = 168, -- target max-dimension in studs (70% of the original 240 — looming but not overwhelming)

        -- Follow behavior: trails the player at a fixed WORLD bearing (not camera-locked — a
        -- camera-locked offset at this distance would swing through a huge arc on every turn and
        -- whip the head at insane speed). Movement mirrors pet_follow.movement: frame-rate-
        -- independent exponential approach + a HARD max_travel_speed cap (so it can never
        -- accelerate without bound) + a catchup snap on real teleports (realm/zone change).
        follow_distance = 100, -- horizontal studs from the player
        follow_height = 100, -- studs above the player (100 out + 100 up = ~45 deg elevation)
        follow_azimuth_deg = 0, -- world bearing it hovers at relative to the player
        follow_lerp_rate = 4, -- exponential approach rate (higher = snappier, lower = floatier)
        max_travel_speed = 120, -- HARD studs/sec cap — the head can never move faster than this
        catchup_distance = 400, -- beyond this (a real teleport) snap instead of flying across the map
        face_turn_rate = 2, -- how fast it turns to keep facing you (slow = gentle, never whips/spins)
        -- KITING: it holds the `follow_distance` ring along its current bearing, so walking toward
        -- it pushes it away (it never lets you reach it). Speed cap keeps the kite from whipping.

        -- Intermittent presence: it only shows up SOMETIMES, fading in and back out.
        -- TESTING: appear_chance = 1.0 keeps it always present (no waiting / hunting in the dark).
        -- For the real eerie effect drop this back toward ~0.4.
        appear_chance = 1.0, -- chance it's present on each roll (1.0 = always there)
        appear_interval = 12, -- seconds between appear/vanish rolls
        fade_seconds = 1.5, -- fade in/out duration

        -- Face body: dark so only the eyes read (the head silhouettes against the skybox).
        face_color = { 35, 12, 10 },
        face_material = "SmoothPlastic",

        -- Internal head light: a PointLight INSIDE the head that lights the whole crystal face from
        -- within, so it glows in pitch-black hell with no world light. This is the master INTENSITY
        -- knob — keep it modest for a subtle resting presence, then crank it at runtime for events
        -- (e.g. an enemy wave) to make the head blaze. brightness 4 = the vivid hero look.
        face_light = {
            enabled = true,
            brightness = 4, -- resting intensity (lower = subtler; raise/animate for events)
            range = 40, -- resting reach (kept low; lightning throws it far for a beat)
            color = { 255, 45, 25 },
        },

        -- Lightning: pulse the face light for a fraction of a second — brightness + range spike,
        -- then snap back to resting. The range jump (40 -> 120) is what makes the glow flash out
        -- and recoil. Auto-fires on a jittered interval now; the same pulse can be triggered by
        -- future events (enemy wave incoming, etc.) to herald them.
        lightning = {
            enabled = true,
            flash_brightness = 20,
            flash_range = 120,
            flash_seconds = 0.1, -- per-flicker on/off time
            stutter = 3, -- flickers per strike (lightning stammer)
            interval = 9, -- avg seconds between strikes
            interval_jitter = 6, -- +/- randomization on the interval
        },

        -- Glowing eyes = NEON pupils raycast-seated into the sockets (self-emissive, so they read at
        -- any distance and in pitch black — a bare light is invisible from afar). Welded + anchored
        -- to the head. Offsets are FRACTIONS of the head's size so they hold at any scale. Tuned by
        -- hand on HellFaceGateTest. Set enabled=false to drop them (the face then needs its own glow).
        eyes = {
            enabled = true, -- pupils are BUILT (welded in place) but invisible by default...
            transparency = 1, -- ...via transparency=1. 0 = solid glow; flip lower at runtime for events.
            up_frac = 0.125, -- brow height as a fraction of head size
            side_frac = 0.146, -- half-separation
            recess_frac = 0.125, -- how deep into the socket
            size_frac = 0.14, -- pupil diameter
            color = { 255, 30, 12 }, -- Neon red
        },
    },
}
