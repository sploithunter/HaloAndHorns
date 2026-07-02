--[[
    Combat FX facade — Halo & Horns [PROTOTYPE].

    Config for src/Shared/Effects/CombatFX.lua, the facade that routes a single effect spec
        { pattern, origin, category, element, ... }
    to the right effect module:
      pattern "st_attack" / "st_aoe" / "pbaoe" -> RangedFX / AreaFX (existing)
      pattern "attached"                       -> CombatFX's own follow-an-entity engine (below)

    The `attached` pattern is the new capability: a continual effect that FOLLOWS an entity for a
    duration — auras (buff/debuff/damage/heal) and the shield bubble. Categories:
      buff   -> rising aura on an ally        debuff -> sinking aura on an enemy
      shield -> ForceField bubble on a target damage/heal -> ambient aura
    `element` is the biome origin (grass/lava/ice/desert) — each gets its OWN look (not a recolor).
    This slice ships LAVA end-to-end; other elements fill in the same shape.
]]

return {
    -- Combat element origin (CombatOrigin.resolve). Canonical elements = the four biomes:
    -- grass / lava / ice / desert. Hybrid + configurable:
    --   unify_to_player = false -> each pet fights as its OWN biome origin (collection variety)
    --   unify_to_player = true  -> the whole squad fights as the PLAYER's archetype element
    -- archetype_element maps each archetype's theme onto a canonical element (earth -> grass).
    origin = {
        unify_to_player = false,
        default_element = "grass",
        archetype_element = {
            geomancer = "grass", -- "earth" theme reconciled to grass
            pyromancer = "lava",
            cryomancer = "ice",
            sandwalker = "desert",
        },

        -- DISC-ONLY override (PetBadge.elementForPetType): creator-egg-origin pets wear the Colorado
        -- flag disc + white ring, independent of their COMBAT element (pettype_element below stays
        -- lava so their VFX/resonance are unchanged — Colorado is a fire blaster).
        badge_element = {
            colorado = "creator",
            colorado_creator = "creator",
        },

        -- Interim pet-element source: until the hatch biome is persisted onto the pet record,
        -- the pet's combat element is read from its PetType (the model already carries this attr).
        -- Tune freely; missing/unknown types fall back to default_element. (Swap to a true
        -- hatch-biome OriginElement attribute later without touching the resolver.)
        pettype_element = {
            -- Hell 1 + Heaven-1 desert (were missing -> defaulted grass). origin = biome RPS element.
            sun_scarab = "desert",
            mirage_jackal = "desert",
            dawn_camel = "desert",
            gilded_sphinx = "desert",
            solar_roc = "desert",
            carrion_scarab = "desert",
            phantom_jackal = "desert",
            dust_camel = "desert",
            glass_sphinx = "desert",
            ash_roc = "desert",
            cinderling_imp = "lava",
            brimstone_salamander = "lava",
            ashmane_lion = "lava",
            ashfeather_phoenix = "lava",
            abyssal_wyrm = "lava",
            rimelight_hare = "ice",
            rimewraith_fox = "ice",
            dread_owl = "ice",
            black_seraph = "ice",
            black_ice_leviathan = "ice",
            blightlamb = "grass",
            dread_hare = "grass",
            rotleaf_stag = "grass",
            wither_sprite = "grass",
            gravewood_ent = "grass",
            -- Layer 2 (Heaven 2 / Hell 2) — origin = biome RPS element (mirrors pet config .origin).
            coronal_cherub = "lava",
            prism_lion = "lava",
            lance_seraph = "lava",
            lumen_salamander = "lava",
            dawnfire_phoenix = "lava",
            frostcinder_imp = "lava",
            rimemane_lion = "lava",
            hoarfrost_phoenix = "lava",
            frostbrand_salamander = "lava",
            deadfire_phoenix = "lava",
            frostlight_doe = "ice",
            prism_fox = "ice",
            starlight_owl = "ice",
            glacial_bear = "ice",
            aurora_dragon = "ice",
            rimegloom_hare = "ice",
            dread_fox = "ice",
            gravefrost_owl = "ice",
            rimeguard_bear = "ice",
            rimewraith_dragon = "ice",
            bloomspirit_lamb = "grass",
            lightleaf_hare = "grass",
            crystalbark_stag = "grass",
            radiant_sprite = "grass",
            worldbloom_ent = "grass",
            frostblight_lamb = "grass",
            gloom_hare = "grass",
            icerot_stag = "grass",
            rimewither_sprite = "grass",
            frostgrave_ent = "grass",
            aurora_dove = "desert",
            prism_scarab = "desert",
            mirage_meerkat = "desert",
            sunwell_camel = "desert",
            empyreal_couatl = "desert",
            wraith_dove = "desert",
            rime_scarab = "desert",
            gloom_jackal = "desert",
            frostdust_camel = "desert",
            dread_couatl = "desert",
            bunny = "grass",
            doggy = "grass",
            bear = "grass",
            kitty = "ice",
            dragon = "grass", -- home dragon's origin SSOT (pets.lua) is grass; align the VFX element
            colorado = "lava",
            colorado_creator = "lava", -- the Creator apex is a FIRE blaster (bolt + AoE fire-ring)
            -- Ember family = lava origin (RPS / element stats / VFX).
            emberling = "lava",
            emberfox = "lava",
            emberimp = "lava",
            emberowl = "lava",
            emberlion = "lava",
            -- Ice family = ice origin (RPS / element stats / VFX).
            snowflakeowl = "ice",
            snowfox = "ice",
            penguin = "ice",
            snowleopard = "ice",
            polarbear = "ice",
            -- Sand family = desert origin (RPS / element stats / VFX).
            fennec = "desert",
            camel = "desert",
            meerkat = "desert",
            desertiguana = "desert",
            scorpion = "desert",
            -- Heaven 1 roster: origin element drives RPS/stats/VFX; realm tag (heaven) is separate.
            emberling_cherub = "lava",
            sunmane_lion = "lava",
            solar_phoenix = "lava",
            radiant_salamander = "lava",
            empyrean_dragon = "lava",
            frostlight_hare = "ice",
            aurora_fox = "ice",
            seraph_owl = "ice",
            glacial_seraph = "ice",
            aurora_leviathan = "ice",
            bloomlamb = "grass",
            halo_hare = "grass",
            goldleaf_stag = "grass",
            verdant_sprite = "grass",
            worldroot_ent = "grass",
        },

        -- Canonical element -> ranged projectile kind (damage). Melee + heal are routed
        -- separately (RangedFX melee_by_element / heal_<element>). Mirrors CombatFX.RANGED_KIND.
        element_kind = {
            grass = "lightning",
            lava = "fireball",
            ice = "frost",
            desert = "rock",
        },

        -- Element -> armor reskin (configs/combat_fx.lua reskins): when a pet gains a shield in
        -- live combat, CombatAuraController stones it out in its biome armor (grass->stone slate,
        -- lava->cracked lava, ice->glacier, desert->sandstone) under the shield bubble.
        element_reskin = {
            grass = "stone",
            lava = "lava",
            ice = "ice",
            desert = "sand",
        },

        -- Per-element STAT modifiers (CombatOrigin.statMod). These give each origin a combat
        -- identity on top of its look, kept in a TIGHT band so no element dominates (avg ~1.0):
        --   attack_mult — multiplies the pet's outgoing damage (PetFollowService:_mine)
        --   taken_mult  — multiplies incoming damage to the pet (EnemyService); lower = tankier
        -- grass  = neutral baseline (nature/geomancer)
        -- lava   = glass cannon (pyro): hits hardest, also takes the most
        -- ice    = durable controller (cryo): softer hits, tankiest
        -- desert = sturdy skirmisher (sand): slightly under on offense, mildly tanky
        -- NEUTRALIZED (Jason, 2026-06-12: a static element bias — "weird fire pets
        -- are just better" — was never the lore). Element power is now GEOGRAPHY:
        -- the biome RPS in elements.lua (strong in the zone you beat, weak in the
        -- zone that beats you). These stay as knobs if a flat per-element identity
        -- is ever wanted again.
        element_stats = {
            grass = { attack_mult = 1.00, taken_mult = 1.00 },
            lava = { attack_mult = 1.00, taken_mult = 1.00 },
            ice = { attack_mult = 1.00, taken_mult = 1.00 },
            desert = { attack_mult = 1.00, taken_mult = 1.00 },
        },
    },

    -- Armor reskins: temporarily retexture the WHOLE pet for a defensive (shield) effect — the
    -- four armor origins. CombatFX.attach reads spec.reskin = one of these. material = a Roblox
    -- Material name (real materials sell each look); color = the tint. (Variant pets re-apply
    -- their own colour each frame so the Material reads on them; plain pets reskin fully.)
    --   stone -> Geomancer (stone_skin)   lava -> Pyromancer (ember_ward)
    --   ice   -> Cryomancer (ice_armor)   sand -> Sandwalker (dune_shield)
    reskins = {
        stone = { material = "Slate", color = { 120, 114, 105 } },
        lava = { material = "CrackedLava", color = { 95, 45, 30 } }, -- molten crust w/ glowing cracks
        ice = { material = "Glacier", color = { 190, 228, 255 } },
        sand = { material = "Sandstone", color = { 214, 184, 130 } },
    },

    attached = {
        duration = 5, -- default seconds an attached effect lasts (spec.duration overrides)

        -- DoT BURN tell: a small element-themed rising-flame ParticleEmitter pinned on an enemy while
        -- it carries a live burn (BurnUntil/BurnFxUntil + BurnElement). Replaces the old hardcoded
        -- orange Roblox Fire so a frost burn reads blue, a wither burn green, etc. — reusing the same
        -- alpha mote textures as the aura fields. CombatFX.enemyBurn reads this; lava is the fallback.
        burn = {
            lava = {
                color = { 255, 120, 30 },
                secondary = { 255, 210, 120 },
                texture = "83142936306716",
            }, -- fire_up_alpha
            ice = {
                color = { 120, 210, 255 },
                secondary = { 235, 250, 255 },
                texture = "72374879557879",
            }, -- snowflake1_alpha
            grass = {
                color = { 120, 240, 80 },
                secondary = { 210, 255, 150 },
                texture = "107757365168186",
            }, -- leaf_alpha
            desert = {
                color = { 255, 210, 110 },
                secondary = { 255, 240, 180 },
                texture = "123216505778060",
            }, -- sun_alpha
        },

        -- Per-element, per-category skins. colors = { core, accent }. rate = particles/sec;
        -- rise = float up (buff/heal) vs sink (debuff); size = particle studs. shield uses a
        -- ForceField bubble (transparency/colors). Add grass/ice/desert blocks the same way.
        themes = {
            lava = {
                -- ally damage-up buff: rising embers, hot orange
                buff = {
                    colors = { { 255, 150, 40 }, { 255, 215, 120 } },
                    rate = 18,
                    rise = true,
                    size = 0.7,
                    light_emission = 0.5,
                },
                -- enemy debuff (e.g. burn/vuln): sinking ash + dark ember
                debuff = {
                    colors = { { 120, 55, 20 }, { 60, 40, 35 } },
                    rate = 14,
                    rise = false,
                    size = 0.8,
                    light_emission = 0.2,
                },
                -- shield bubble: fiery ForceField sphere
                shield = { colors = { { 255, 140, 50 } }, transparency = 0.5, light_emission = 0.4 },
                -- damage aura (burning): dense embers streaming up
                damage = {
                    colors = { { 255, 110, 30 }, { 255, 200, 90 } },
                    rate = 24,
                    rise = true,
                    size = 0.8,
                    light_emission = 0.6,
                },
                -- heal aura: warm restorative gold (heal reads warm even from a lava origin)
                heal = {
                    colors = { { 255, 220, 120 }, { 180, 255, 170 } },
                    rate = 14,
                    rise = true,
                    size = 0.7,
                    light_emission = 0.5,
                },
                -- AURA FIELD (lava): rising flame motes (UPRIGHT — directional art, no spin) + a
                -- cranked Roblox Fire ring (fire is dynamic), molten-tinted ground. Same renderer.
                aurafield = {
                    colors = { { 255, 110, 30 }, { 255, 210, 120 } },
                    radius = 12,
                    rate = 1.0,
                    rise = true,
                    size = 1.6,
                    upright = true, -- flame textures point up; never tumble them
                    light_emission = 1,
                    transparency = 0.1,
                    texture = "92085149955316", -- "Fire_up" rising flame mote
                    accent = {
                        texture = "133296876434530",
                        light_emission = 1,
                        rate = 0.3,
                        size = 1.3,
                    }, -- Flame_up
                    ground_texture = "95384385791305", -- "Sun/spore": circular + bright rim = lava floor (Jason)
                    ground_color = { 255, 70, 25 }, -- red tint => molten
                    ground_transparency = 0.3,
                    ground_spin = 14,
                    fire = {
                        count = 8,
                        ring_frac = 0.82,
                        size = 5,
                        heat = 8,
                        spin = 0.4,
                        color = { 255, 110, 30 },
                        secondary = { 255, 200, 90 },
                    },
                    orbit = {
                        count = 3,
                        radius_frac = 0.7,
                        speed = 1.6,
                        height = 1.5,
                        orb_size = 0.6,
                        width = 1.4,
                        life = 0.6,
                        color = { 255, 180, 90 },
                    },
                    rim = {
                        shape = "Cylinder",
                        thickness = 0.001,
                        radius_frac = 1.0,
                        rate = 1000,
                        size = 0.8,
                        speed_min = 0,
                        speed_max = 0.6,
                        color = { 255, 170, 80 },
                    },
                    ground = { rate = 0.5, size = 0.6, transparency = 0.2 },
                    -- ONE-SHOT burst extras (targeted fire AoE only — read by spawnAuraField's burst
                    -- block): a real Roblox Explosion flash + a rapid expanding neon sphere. The
                    -- persistent aura ignores these (it never sets burst).
                    burst = {
                        explosion = true, -- classic Roblox Explosion ball (visual only, no physics)
                        sphere_color = { 255, 130, 40 }, -- expanding fireball tint
                        sphere_frac = 1.15, -- final diameter = radius*2 * this
                        sphere_time = 0.26, -- swell-out duration (sec)
                    },
                },
            },
            grass = {
                -- nature growth — rising leafy green motes
                buff = {
                    colors = { { 90, 210, 80 }, { 180, 245, 130 } },
                    rate = 18,
                    rise = true,
                    size = 0.8,
                    light_emission = 0.35,
                },
                -- wither — sinking sickly brown/yellow
                debuff = {
                    colors = { { 110, 130, 50 }, { 70, 80, 40 } },
                    rate = 14,
                    rise = false,
                    size = 0.8,
                    light_emission = 0.1,
                },
                shield = { colors = { { 110, 220, 90 } }, transparency = 0.5, light_emission = 0.3 },
                damage = {
                    colors = { { 120, 230, 90 }, { 200, 255, 140 } },
                    rate = 22,
                    rise = true,
                    size = 0.7,
                    light_emission = 0.4,
                },
                heal = {
                    colors = { { 130, 240, 130 }, { 220, 255, 200 } },
                    rate = 14,
                    rise = true,
                    size = 0.7,
                    light_emission = 0.5,
                },
                -- AURA FIELD (bear's ground AoE): a persistent, ground-hugging green field that
                -- follows the pet. `rate` is particles/sec PER SQUARE STUD of field area (scaled by
                -- radius², capped in code) — density has to scale with area or a wide field reads as
                -- empty. `light_emission` high so the green pops even on green grass. `ground` = the
                -- low edge-flecks layer. `texture` = leaf art (default "" = soft built-in circle).
                aurafield = {
                    colors = { { 110, 235, 70 }, { 225, 255, 150 } }, -- vivid green core + bright tip
                    radius = 12, -- fallback if the server doesn't pass AuraFieldRadius
                    rate = 2.2, -- rising motes per square stud — denser (MORE leaves, not bigger ones)
                    rise = true,
                    size = 0.85, -- smaller leaves; density (rate) carries the look, not size
                    life_min = 0.9,
                    life_max = 2.0, -- live longer so they fly HIGHER before fading
                    speed_min = 3,
                    speed_max = 7, -- launch faster => higher column
                    light_emission = 0.3, -- main motes = drifting LEAVES, read solid green (not glow)
                    transparency = 0.15,
                    texture = "117110051645662", -- "Leaf" (alpha, Jason's pick); inverted/lighter: 112670614273744
                    -- accent: sparser GLOWING flower sparkles mixed over the leaves (variety layer)
                    accent = {
                        texture = "121221014966173", -- "Flower" (alpha)
                        light_emission = 1, -- additive glow (petals shine, black bg vanishes)
                        rate = 0.6, -- per square stud of area (sparser than the leaves)
                        size = 0.7,
                    },
                    -- Ground disc: a flat CIRCLE on the floor (SurfaceGui image clipped round), tinted
                    -- to the element + slowly spinning. THE contrast layer (reads where motes don't).
                    -- NON-alpha WaterTurbulence (Jason's pick): the full pattern fills the circle —
                    -- dark areas read as translucent shadow through ground_transparency, bright bits as
                    -- green energy. (alpha version 90880959780230 looked too sparse.)
                    ground_texture = "103350191895581", -- "WaterTurbulence" (non-alpha). Alt Squiggles
                    -- (alpha): dark=87434912029157, light=102230380007272
                    ground_color = { 90, 240, 70 }, -- tint applied to the grayscale texture
                    ground_transparency = 0.4,
                    ground_spin = 18, -- degrees/sec the circle rotates (0 = static)
                    ground = { -- low flecks hugging the floor (the field footprint)
                        rate = 0.5,
                        size = 0.6,
                        life_min = 0.4,
                        life_max = 0.9,
                        speed_min = 0.5,
                        speed_max = 2,
                        transparency = 0.2,
                    },
                    -- green spirit-FIRE wisps slowly circling the rim (Roblox Fire). Remove this block
                    -- to drop the layer. color/secondary tint the flame.
                    fire = {
                        count = 6,
                        ring_frac = 0.82, -- placed at radius * this
                        size = 4,
                        heat = 6,
                        spin = 0.4, -- radians/sec the fire ring rotates
                        color = { 70, 230, 90 },
                        secondary = { 200, 255, 150 },
                    },
                    -- orbiting TRAIL-orbs: glowing motes circling the pet, leaving light-ribbons.
                    orbit = {
                        count = 3,
                        radius_frac = 0.7,
                        speed = 1.6, -- radians/sec
                        height = 1.5, -- studs above the floor
                        orb_size = 0.6,
                        width = 1.4, -- trail width
                        life = 0.6, -- trail lifetime (sec)
                        color = { 160, 255, 130 },
                    },
                    -- RIM ring at the field edge so the circle dissolves instead of cutting hard.
                    -- Jason live-tuned: a thin CYLINDER emission (clean ring, no flat-chord edge) at a
                    -- high rate for a dense glow. NOTE: rate is heavy — this runs on every bear aura;
                    -- dial it down if perf bites. Remove the block to drop the layer.
                    rim = {
                        shape = "Cylinder", -- emission shape; "Disc" left a flat edge
                        thickness = 0.001, -- ultra-thin host = a crisp line ring (Jason: more surface)
                        radius_frac = 1.0, -- ring radius as a fraction of the field radius
                        rate = 1000, -- dense enough; 10k was imperceptibly heavier (Jason)
                        size = 0.8,
                        life_min = 0.4,
                        life_max = 0.8,
                        speed_min = 0,
                        speed_max = 0.6,
                        color = { 150, 255, 120 },
                    },
                    -- ONE-SHOT burst extras (earth targeted AoE). NO `explosion` key — the Roblox
                    -- Explosion is always orange (fire-only); earth uses just the tinted expanding
                    -- sphere. NO damage-over-time here either: the burn is a SEPARATE config-gated
                    -- layer (power kind.dot / burn_spread), so a non-contagion earth AoE never ignites.
                    burst = {
                        sphere_color = { 120, 240, 80 }, -- expanding green energy ball
                        sphere_frac = 1.1,
                        sphere_time = 0.3,
                    },
                },
            },
            ice = {
                -- frost — rising pale crystals
                buff = {
                    colors = { { 150, 220, 255 }, { 235, 250, 255 } },
                    rate = 18,
                    rise = true,
                    size = 0.7,
                    light_emission = 0.45,
                },
                -- chill — sinking deep-blue mist
                debuff = {
                    colors = { { 60, 110, 170 }, { 120, 160, 200 } },
                    rate = 14,
                    rise = false,
                    size = 0.9,
                    light_emission = 0.2,
                },
                shield = {
                    colors = { { 170, 225, 255 } },
                    transparency = 0.45,
                    light_emission = 0.45,
                },
                damage = {
                    colors = { { 140, 215, 255 }, { 225, 245, 255 } },
                    rate = 22,
                    rise = true,
                    size = 0.8,
                    light_emission = 0.55,
                },
                heal = {
                    colors = { { 190, 245, 220 }, { 230, 255, 235 } },
                    rate = 14,
                    rise = true,
                    size = 0.7,
                    light_emission = 0.5,
                },
                -- AURA FIELD (ice): drifting snowflake motes (symmetric — they CAN spin) + a frost-
                -- tinted ground; no Roblox Fire (ice doesn't flame). Same renderer.
                aurafield = {
                    colors = { { 150, 220, 255 }, { 235, 250, 255 } },
                    radius = 12,
                    rate = 1.0,
                    rise = true,
                    size = 1.4,
                    light_emission = 0.5,
                    transparency = 0.15,
                    texture = "105999264891352", -- "Snowflake1"
                    accent = {
                        texture = "82240057547918",
                        light_emission = 1,
                        rate = 0.3,
                        size = 1.2,
                    }, -- Snowflake2
                    ground_texture = "101205975129531", -- Water (alpha/"inverted") — frost wisps on a
                    -- clear disc instead of the murky non-alpha fill; reads icy once tinted.
                    ground_color = { 170, 220, 255 },
                    ground_transparency = 0.2,
                    ground_spin = 12,
                    orbit = {
                        count = 3,
                        radius_frac = 0.7,
                        speed = 1.4,
                        height = 1.5,
                        orb_size = 0.6,
                        width = 1.4,
                        life = 0.6,
                        color = { 200, 240, 255 },
                    },
                    rim = {
                        shape = "Cylinder",
                        thickness = 0.001,
                        radius_frac = 1.0,
                        rate = 1000,
                        size = 0.8,
                        speed_min = 0,
                        speed_max = 0.6,
                        color = { 210, 245, 255 },
                    },
                    ground = { rate = 0.5, size = 0.6, transparency = 0.2 },
                },
            },
            desert = {
                -- sand uplift — rising tan grains (earthy, low glow)
                buff = {
                    colors = { { 215, 185, 120 }, { 245, 225, 170 } },
                    rate = 18,
                    rise = true,
                    size = 0.8,
                    light_emission = 0.15,
                },
                -- sandblast debuff — sinking dusty brown
                debuff = {
                    colors = { { 150, 120, 80 }, { 90, 70, 50 } },
                    rate = 16,
                    rise = false,
                    size = 0.9,
                    light_emission = 0.1,
                },
                shield = {
                    colors = { { 205, 175, 120 } },
                    transparency = 0.4,
                    light_emission = 0.15,
                },
                damage = {
                    colors = { { 200, 165, 110 }, { 235, 205, 150 } },
                    rate = 20,
                    rise = true,
                    size = 0.85,
                    light_emission = 0.2,
                },
                heal = {
                    colors = { { 235, 220, 150 }, { 215, 255, 190 } },
                    rate = 14,
                    rise = true,
                    size = 0.7,
                    light_emission = 0.4,
                },
                -- AURA FIELD (desert): an Egyptian-style MANDALA ground (alpha "magic circle") + rising
                -- golden SUN motes + yellow spirit-fire (mirrors grass's green fire). Crystals didn't
                -- read so they're dropped; suns + the rune circle carry the Egyptian theme. Same renderer.
                aurafield = {
                    colors = { { 255, 210, 110 }, { 255, 240, 180 } },
                    radius = 12,
                    rate = 0.7,
                    rise = true,
                    size = 1.3,
                    light_emission = 0.7, -- suns glow
                    transparency = 0.15,
                    texture = "123216505778060", -- "Sun" (alpha) — golden suns rising
                    accent = {
                        texture = "135525038297036", -- fine gold speckles (alpha, glowing)
                        light_emission = 1,
                        rate = 0.3,
                        size = 0.7,
                    },
                    -- Egyptian MANDALA ground (alpha "magic circle"): reads as a glowing rune circle on
                    -- the sand instead of the murky water swirl. Slow majestic spin. Alt: MagicCircle
                    -- 136557266765344. Sand tiles: sandfloor 78509147193799 / organic 77128025956446.
                    ground_texture = "129307746768270", -- "Mandara" (alpha mandala)
                    ground_color = { 245, 205, 110 },
                    ground_transparency = 0.15,
                    ground_spin = 6,
                    -- yellow spirit-FIRE wisps circling the rim (Roblox Fire), like grass's green fire.
                    fire = {
                        count = 6,
                        ring_frac = 0.82,
                        size = 4,
                        heat = 6,
                        spin = 0.4,
                        color = { 255, 200, 60 },
                        secondary = { 255, 240, 150 },
                    },
                    orbit = {
                        count = 3,
                        radius_frac = 0.7,
                        speed = 1.4,
                        height = 1.5,
                        orb_size = 0.6,
                        width = 1.4,
                        life = 0.6,
                        color = { 255, 220, 120 },
                    },
                    rim = {
                        shape = "Cylinder",
                        thickness = 0.001,
                        radius_frac = 1.0,
                        rate = 1000,
                        size = 0.8,
                        speed_min = 0,
                        speed_max = 0.6,
                        color = { 255, 225, 140 },
                    },
                    ground = { rate = 0.5, size = 0.6, transparency = 0.2 },
                },
            },
        },
    },
}
