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
            walk = "rbxassetid://94535910240811", -- biped_walk_crystalwood (meander stroll pace)
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
        -- quadruped = { ... }  -- pending the first quadruped clip set
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
