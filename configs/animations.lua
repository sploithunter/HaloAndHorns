--[[
    Pet skeletal animations (rigged Meshy pets).

    A pet whose pets.lua entry carries `rig_class = "<class>"` spawns as a skinned rig
    (Bones + AnimationController) and plays these published clips instead of the code-driven
    bob/gait/flourish. Clips are GROUP-owned Animation assets produced by
    scripts/import_animation.sh or Clip Editor publishes (see scripts/animation_ids.json).

    One clip set per rig class drives EVERY pet of that body type: Meshy auto-rigs share a
    standard skeleton per class, and Roblox animations are skeleton-relative (verified live:
    the biped set drives both Worldbloom and Worldroot rigs, at any Model scale).

    CLIP VALUE SHAPES (PetAnimator normalizes all three):
      - "rbxassetid://N"          one clip
      - { "rbxassetid://N", ... } a POOL — each pet picks one, STABLE per pet (seeded by its
                                  lockout identity + slot), so squads vary without flicker
      - attack only: a ROLE map { default = <clip|pool>, tank = ..., ranged = ... } — the
        pet's combat role (PetRole attr / pet_roles.by_type) selects its lane; casts for
        blasters/support, swings for the front line.
]]

return {
    rig_classes = {
        biped = {
            idle = {
                "rbxassetid://107633065661523", -- MeshyStretchIdle
                "rbxassetid://135125543047142", -- MeshyLazyIdle
            },
            walk = {
                "rbxassetid://94535910240811", -- biped_walk_crystalwood
                "rbxassetid://85051630214138", -- biped_walk_cryoshard
                "rbxassetid://139269964220454", -- biped_walk_molten_sentinel (Cinder Golemite)
                "rbxassetid://107700051813744", -- biped_walk_cinderling_imp (GLB zip -> rig_glb_to_fbx lane)
            },
            run = {
                "rbxassetid://130063719118527", -- biped_run (auto pipeline)
                "rbxassetid://116710242362195", -- MeshyRun (editor publish)
            },
            attack = {
                default = {
                    "rbxassetid://125428500789381", -- Meshy12Punch
                    "rbxassetid://94514790292736", -- MeshyPunchCombo
                },
                tank = {
                    "rbxassetid://125428500789381", -- Meshy12Punch
                    "rbxassetid://99468897317934", -- MeshySpartanKick
                },
                melee = {
                    "rbxassetid://125428500789381", -- Meshy12Punch
                    "rbxassetid://94514790292736", -- MeshyPunchCombo
                    "rbxassetid://99468897317934", -- MeshySpartanKick
                },
                ranged = {
                    "rbxassetid://104092507617195", -- MeshyUnderhandSpellCast
                    "rbxassetid://89717257727043", -- MeshyHeavyPushSpellCast
                },
                support = "rbxassetid://104092507617195", -- MeshyUnderhandSpellCast
                control = "rbxassetid://89717257727043", -- MeshyHeavyPushSpellCast
            },
            -- Banked, unwired: biped_jump 71078514678985, biped_jump_down 83347370148290,
            -- biped_walk_crystalwood 94535910240811 (see scripts/animation_ids.json).
        },
        quadruped = {
            -- Meshy's quadruped library ships ONE clip (walking); the rig is what matters.
            -- The rest of the set is retargeted from the CC0 Quaternius Ultimate Animated
            -- Animal Pack onto the standardized Meshy quadruped skeleton (verified: lion +
            -- bear diff = identical 27 bones) via tools/rigging (2026-08-13, in-place,
            -- rotations only — code owns locomotion/lunge translation).
            -- Direct-converter clips (tools/rigging, live-verified lineup 2026-08-13).
            -- Retarget-lane clips use the pitch-inverted formula; Meshy-authored
            -- clips (walks) use the base formula — see PET_RIGGING_PIPELINE.md.
            idle = {
                "rbxassetid://120395367179101", -- quadruped_idle (weight shifts)
                "rbxassetid://115550781975626", -- quadruped_idle2 (head-low sniff)
            },
            walk = {
                "rbxassetid://91206058452622", -- quadruped_walk (ashmane lion)
                "rbxassetid://96781308918926", -- quadruped_walk_nightdrake
                "rbxassetid://87604652590062", -- quadruped_walk_lioncub
                "rbxassetid://100017650497490", -- quadruped_walk_camel (GLB zip -> rig_glb_to_fbx lane)
                "rbxassetid://75670337695139", -- quadruped_walking_doggy (direct converter, live-verified)
            },
            run = "rbxassetid://128064023011880", -- quadruped_gallop (wolf source)
            attack = "rbxassetid://111937572695311", -- quadruped_attack (wolf bite lunge, in place)
            -- Banked, unwired until hit-react playback lands in PetAnimator:
            -- quadruped_hitreact_left 111085424878340,
            -- quadruped_hitreact_right 76199902341988.
            -- Flavor bank: quadruped_headbutt_stag 81713302701738 (hooved pets).
        },
    },

    -- Per-PET clip substitutions, keyed pet type -> clip name -> id/pool.
    -- Wins over the rig_classes pool pick for that pet. For rigs a specific
    -- pool clip misbehaves on (2026-07-15: MeshyStretchIdle's root-motion
    -- lift makes the winged cinderling imp "fly up" mid-stretch).
    clip_overrides = {
        cinderling_imp = {
            idle = "rbxassetid://135125543047142", -- MeshyLazyIdle (no lift)
        },
        doggy = {
            -- pin to its own Meshy walk (direct converter); pool clips from the July
            -- anim2rbx lane read mirrored on this rig (Blender 5.1 conversion diff)
            walk = "rbxassetid://75670337695139",
            -- dog-flavored combat (ShibaInu source) over the wolf class defaults
            attack = "rbxassetid://72325480360761",
            run = "rbxassetid://115727517942095",
        },
        -- Conveyor batch 1 (2026-08-13): each pinned to its own direct-converter walk.
        bear = { walk = "rbxassetid://78543048164211" },
        kitty = { walk = "rbxassetid://123311784869667" },
        dragon = { walk = "rbxassetid://78019637212851" },
    },

    -- Per-class playback knobs (kept OUT of rig_classes so clip tables stay pure ids).
    class_knobs = {
        quadruped = {
            -- Was 1.6 when run reused the walk clip at tempo; the wired run is now a
            -- real gallop cycle, so play it at authored speed.
            run_speed_mult = 1.0,
        },
    },

    -- Locomotion state machine (client, PetAnimator): horizontal speed in studs/sec, THREE
    -- states — idle / walk / run. The meander stroll (~4 studs/s) reads as a WALK; real
    -- formation-chasing (player at full speed) reads as a RUN. `hysteresis` scales each
    -- enter threshold down for the exit, so a pet hovering at a boundary never flickers.
    locomotion = {
        walk_speed = 1.0, -- above this (from idle) -> walk
        run_speed = 8.0, -- above this -> run
        hysteresis = 0.7, -- exit thresholds = enter × this
        fade = 0.2, -- crossfade seconds between states
    },

    -- Attack: played ONCE per real server swing (Combat_PetHit), layered over locomotion.
    attack = {
        fade = 0.1,
        speed = 1.0, -- playback speed multiplier (tune so the swing reads at combat cadence)
    },
}
