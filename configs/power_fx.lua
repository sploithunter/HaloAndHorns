--[[
    Power FX registry — see docs/PET_REALM_POWER_DATA_MODEL.md §7.1.

    FIRST-VISUAL-TEST scaffold. Named effect primitives mapped onto the EXISTING CombatFX facade
    (`CombatFX.play(spec, ctx)`), so the admin FX-probe plays real effects you can eyeball — no new
    renderer to validate blind. Each primitive picks a CombatFX `pattern`; `color`/`light` default to
    "origin" (the element drives them — CombatFX already resolves per-element colour); `sound` is nil
    until audio is authored (drop SoundIds in later, same placeholder→override pattern as art).

    `probe` drives the admin FX-probe sequence: it steps each listed primitive across every element
    so one click shows the full matrix (Casting on the player, Impact on a dummy).

    Patterns available today (from CombatFX): "pbaoe" (burst around the caster), "st_aoe" (strike at
    a point), "st_attack" (ranged bolt → target), "attached" (a following aura/bubble). Expand the
    primitive list + add bespoke `asset`/`sound` per primitive as real art lands.
]]

return {
    primitives = {
        -- a NO-OP client FX: a defined primitive with an unhandled pattern, so PowerFXRender treats the
        -- power as "has FX" (no "(effect TBD)" placeholder) while CombatFX renders nothing. For powers
        -- whose entire visual is server-side / shared-world (e.g. Resonance's ground rune).
        silent = {
            pattern = "none",
            color = "origin",
            sound = nil,
            -- NOTE: no `mute` — the "(sound TBD)" placeholder SHOULD still show until a real Resonance
            -- cast sound is authored (it's the reminder). Only the effect-TBD is suppressed.
        },

        -- caster-anchored burst CENTRED on the player: dome + rising motes / ember poof, but NO
        -- encircling ground/fire ring (no_ring) — the on-player part of the self burst reads as a
        -- punchy cast without the AoE ring that felt inappropriate as a cast tell.
        cast_burst = {
            pattern = "pbaoe",
            anchor = "self",
            no_ring = true,
            color = "origin",
            light = nil,
            sound = nil,
        },
        -- caster-anchored EMISSION off the player's body (attached element motes streaming up, brief) —
        -- the default single-target cast tell: small, "emits from the player", NOT a ground AoE. Uses
        -- the per-element `damage` aura theme (embers / leaves / frost / sand), short-lived.
        cast_emit = {
            pattern = "attached",
            anchor = "self",
            category = "damage",
            duration = 0.7,
            color = "origin",
            sound = nil,
        },
        -- target-anchored strike/eruption at a point (origin="upfront" = slam, no cast beam)
        eruption = {
            pattern = "st_aoe",
            anchor = "target",
            origin = "upfront",
            color = "origin",
            sound = nil,
        },
        -- caster-anchored rising BUFF aura (attached, follows the entity ~2s) — for buffs/holds
        aura = {
            pattern = "attached",
            anchor = "self",
            category = "buff",
            duration = 2.0,
            color = "origin",
            soundPhase = "buff", -- plays the power-up clip (neutral) rather than the elemental cast
            sound = nil,
        },
        -- caster-anchored SHIELD bubble (attached ForceField look) — for absorbs/wards
        shield_bubble = {
            pattern = "attached",
            anchor = "self",
            category = "shield",
            duration = 2.0,
            color = "origin",
            soundPhase = "shield", -- plays the force-field-raise clip (neutral)
            sound = nil,
        },
        -- ranged BOLT from caster → target (projectile; element picks fireball/frost/rock/lightning)
        ranged_bolt = {
            pattern = "st_attack",
            anchor = "target",
            color = "origin",
            sound = nil,
        },
        -- caster-anchored HEAL nova (green heal pulse via the AreaFX "heal" skin)
        heal_nova = {
            pattern = "pbaoe",
            anchor = "self",
            category = "heal",
            color = "origin",
            sound = nil,
        },

        -- ===== Palette expansion (cheap unlocks over the existing renderers) =====
        -- CAST tells -------------------------------------------------------------------------------
        -- sinking dark motes gathering on the body (debuff aura, rise=false) — an ominous CURSE cast
        cast_channel = {
            pattern = "attached",
            anchor = "self",
            category = "debuff",
            duration = 0.8,
            color = "origin",
            sound = nil,
        },
        -- the ground ERUPTS in a column under the caster (st_aoe at self, no beam) — a heavy/summoning
        -- cast that reads bigger than cast_emit but is still centred on the player
        cast_geyser = {
            pattern = "st_aoe",
            anchor = "self",
            origin = "upfront",
            color = "origin",
            sound = nil,
        },
        -- chunks fly OUTWARD from the player (st_aoe self, "scatter" variant), skinned by element:
        -- lava embers / ice shards / sand grains / grass chunks — one motion, four looks. High-reuse
        -- cast tell across every origin (the "stuff flying away from the player" burst).
        cast_scatter = {
            pattern = "st_aoe",
            anchor = "self",
            origin = "upfront",
            variant = "scatter",
            color = "origin",
            sound = nil,
        },
        -- IMPACTS ----------------------------------------------------------------------------------
        -- a lingering bubbling POOL at the target (st_aoe pit variant, ~4s) — burning/scorched ground
        -- for DoT brands (Mark of Flame, Wildfire). Element-tinted.
        brand_pool = {
            pattern = "st_aoe",
            anchor = "target",
            origin = "upfront",
            variant = "pit",
            color = "origin",
            sound = nil,
        },
        -- chunks HIT the target, bounce off, roll away, and fade (st_aoe "rubble" variant) — a
        -- physical hit-and-tumble. Skinned per element: earth chunks / sand rubble / ice shards.
        rubble = {
            pattern = "st_aoe",
            anchor = "target",
            origin = "upfront",
            variant = "rubble",
            color = "origin",
            sound = nil,
        },
        -- bare point-bursts from the RangedFX impact library (no projectile), element-coloured:
        shatter = { pattern = "impact", anchor = "target", impact = "shatter", color = "origin" }, -- ice ring + glass shards
        dust_burst = { pattern = "impact", anchor = "target", impact = "dust", color = "origin" }, -- desert dust plume
        heavy_slam = { pattern = "impact", anchor = "target", impact = "big", color = "origin" }, -- heavy concussion
        -- explicit projectiles (force a specific bolt regardless of element):
        boulder = {
            pattern = "st_attack",
            anchor = "target",
            projectile = "rock",
            color = "origin",
        }, -- thrown boulder mesh + dust
        ice_boulder = {
            pattern = "st_attack",
            anchor = "target",
            projectile = "ice_boulder",
            color = "origin",
        }, -- thrown ice boulder + shatter
        asteroid = {
            pattern = "st_attack",
            anchor = "target",
            projectile = "asteroid",
            color = "origin",
        }, -- heavy meteor rock + big impact
        frost_shard = {
            pattern = "st_attack",
            anchor = "target",
            projectile = "ice_shard",
            color = "origin",
        }, -- icy shard + shatter
        arc_bolt = {
            pattern = "st_attack",
            anchor = "target",
            projectile = "lightning",
            color = "origin",
        }, -- lightning arc
    },

    -- Admin FX-probe sequence (PowerFXProbe). Steps each primitive across every element.
    probe = {
        elements = { "grass", "lava", "ice", "desert" }, -- canonical CombatFX elements (per-colour)
        casting = {
            "cast_emit",
            "cast_scatter",
            "cast_geyser",
            "cast_channel",
            "cast_burst",
            "aura",
            "shield_bubble",
        }, -- played ON the player
        impact = {
            "eruption",
            "rubble",
            "brand_pool",
            "shatter",
            "dust_burst",
            "heavy_slam",
            "ranged_bolt",
            "boulder",
            "ice_boulder",
            "asteroid",
            "frost_shard",
            "arc_bolt",
        }, -- played at a dummy
        step_seconds = 2.8, -- pause between effects so each is watchable (slowed for inspection)
        dummy_distance = 16, -- studs in front of the player to place the impact dummy
    },

    -- Sound registry — resolves by [phase][element] (like colour resolves by element). A primitive's
    -- anchor picks the phase (self ⇒ cast, target ⇒ impact); the play element picks the clip. A
    -- random variant is chosen. `seconds` = measured clip length (assets/audio/sfx/manifest.txt) —
    -- the VISUAL-TIMING BASELINE; the renderer can match an effect's length to it. PowerSound falls
    -- back to `neutral` when an element has no clip for a phase, so non-elemental clips (force-field,
    -- power-up, generic cast) play under any origin. GAPS ARE STILL SILENT where neither exists.
    -- buff/shield phases ride the aura/shield primitives. ambient = LOOPS (zone/sustained), not wired
    -- to the one-shot probe. Uploaded via scripts/upload_audio.js (ids in scripts/audio_ids.json).
    sounds = {
        -- CRIT (Jason): a ranged pet's CRITICAL hit. PetFollowController plays it on crit+ranged via
        -- PowerSound.play("crit", element, pos). Only `lava` (fire) has an entry, so a fire blaster's
        -- crit roars with "A Large Fire Igniting With A Whoosh"; other elements stay silent (gaps are
        -- silent) until they get their own. Pairs with the existing bigger crit-impact VFX.
        crit = {
            grass = {
                { id = "rbxassetid://113388600729509", seconds = 3.0 }, -- grass_crit_landslide
            },
            lava = {
                -- Jason: the whoosh didn't fit the fire crit — swapped to the heavy boom_swoosh
                -- (same slam sound used for AoE impacts below). The whoosh is freed for root/hold.
                { id = "rbxassetid://88708868978364", seconds = 4.0 }, -- boom_swoosh
            },
            ice = {
                { id = "rbxassetid://134092591115476", seconds = 1.7 }, -- ice_crit_sudden_blast (Jason)
            },
            desert = {
                { id = "rbxassetid://113394845550674", seconds = 6.0 }, -- desert_crit_boom
            },
        },
        -- MELEE/TANK CRIT (Jason): a non-ranged pet's crit is a heavy CONCUSSION, not a ranged
        -- elemental blast — mirrors the attack-VFX split (ranged bolt vs melee impact). neutral-only
        -- ⇒ every element's melee/tank crit shares the boom_swoosh slam. Authoring a per-element
        -- entry here later would override it for that element.
        crit_melee = {
            neutral = {
                { id = "rbxassetid://88708868978364", seconds = 4.0 }, -- boom_swoosh
            },
        },
        cast = {
            grass = {
                { id = "rbxassetid://132509816311774", seconds = 2.0 }, -- earth_magic_casting
                { id = "rbxassetid://126442843540204", seconds = 14.0 }, -- rippling_rock_magic (long tail)
            },
            lava = {
                { id = "rbxassetid://87704208327077", seconds = 3.0 }, -- fireball_launch
            },
            ice = {
                { id = "rbxassetid://125126568964512", seconds = 2.0 }, -- icy_wind_casting
            },
            desert = {
                { id = "rbxassetid://104317755911761", seconds = 14.0 }, -- desert_magic_cast_long (long tail)
                { id = "rbxassetid://126096328746681", seconds = 14.0 }, -- desert_magic_long (long tail)
            },
            neutral = {
                { id = "rbxassetid://140394538590179", seconds = 2.0 }, -- cartoony_spell_cast (generic)
            },
        },
        impact = {
            -- the two long-tail fireball impacts are uploaded + parked for AoE-specific sounds:
            --   fireball_impact_targeted rbxassetid://137088339818106 (14s)
            --   fireball_impact_aoe      rbxassetid://101676922943791 (14s)
            lava = {
                { id = "rbxassetid://80359931572884", seconds = 1.0 }, -- fire_impact_targeted_1
                { id = "rbxassetid://126370526115474", seconds = 1.0 }, -- fire_impact_targeted_2
                { id = "rbxassetid://77080228500140", seconds = 1.0 }, -- fire_impact_targeted_3
            },
            grass = {
                { id = "rbxassetid://115890628962398", seconds = 8.0 }, -- earthen_impact (long-ish tail)
                { id = "rbxassetid://90412394528626", seconds = 8.0 }, -- deep_earthen_impact (long-ish)
            },
            ice = {
                { id = "rbxassetid://76218561522804", seconds = 3.0 }, -- freezing_crack_single_target
            },
            desert = {
                { id = "rbxassetid://74442492755990", seconds = 2.0 }, -- arrow_impact_desert
            },
            neutral = {
                { id = "rbxassetid://70478220013693", seconds = 0.48 }, -- single_target_punch
            },
        },
        -- buff activation (rides the `aura` primitive; neutral ⇒ plays under any origin)
        buff = {
            grass = {
                { id = "rbxassetid://85355971301069", seconds = 4.0 }, -- grass_buff_lion_roar
            },
            ice = {
                { id = "rbxassetid://138731814463789", seconds = 2.3 }, -- ice_buff_storm_wind
            },
            neutral = {
                { id = "rbxassetid://105379088796995", seconds = 1.0 }, -- power_up_stronger
            },
        },
        -- shield raise (rides the `shield_bubble` primitive)
        shield = {
            -- Per-element shield/armor raise; remaining elements fall through to the neutral force-field.
            grass = {
                { id = "rbxassetid://96887340708437", seconds = 6.0 }, -- grass_shield_dark
            },
            ice = {
                { id = "rbxassetid://93258219658109", seconds = 6.8 }, -- ice_crystals_freeze
            },
            desert = {
                -- volume 1.0 (2x the 0.5 default): the snake-slither clip was barely audible on cast
                -- (Jason, via Mirage Step). Shared by all desert shield-raises (Mirage Step, Dune Shield).
                { id = "rbxassetid://97446414419976", seconds = 4.6, volume = 1.0 }, -- desert_shield_snake
            },
            neutral = {
                { id = "rbxassetid://124911631879452", seconds = 1.0 }, -- force_field_raise
            },
        },
        -- AoE SLAM (Jason): the "winds up, lands hard" boom_swoosh — played at the center of any
        -- area power as it lands, ON TOP of the per-element impact (the boom is the weight, the
        -- element impact is the flavor). neutral-only ⇒ every element's AoE gets the same slam.
        slam = {
            neutral = {
                { id = "rbxassetid://88708868978364", seconds = 4.0 }, -- boom_swoosh
            },
        },
        -- ambient LOOPS — registered for zone ambience / sustained holds; NOT one-shot. A looping
        -- player (zone or persistent-effect driven) would use these; the FX-probe doesn't.
        ambient = {
            -- neutral ambient (machine_hum) removed — source lost, dormant anyway (Jason 2026-06-27).
            -- Re-add { id = ..., seconds = ... } here + upload to the group if it's ever wanted.
            neutral = {},
            ice = {
                { id = "rbxassetid://85365931736854", seconds = 3.0 }, -- deep_winter_wind
            },
        },
    },
}
