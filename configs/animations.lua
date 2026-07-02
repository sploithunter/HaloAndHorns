--[[
    Pet skeletal animations (rigged Meshy pets).

    A pet whose pets.lua entry carries `rig_class = "<class>"` spawns as a skinned rig
    (Bones + AnimationController) and plays these published clips instead of the code-driven
    bob/gait/flourish. Clips are GROUP-owned Animation assets produced by
    scripts/import_animation.sh (see scripts/animation_ids.json for the id manifest).

    One clip set per rig class drives EVERY pet of that body type: Meshy auto-rigs share a
    standard skeleton per class, and Roblox animations are skeleton-relative (verified: the
    biped set plays on separately-uploaded rigs, and survives Model:ScaleTo, so normal and
    huge share clips). Add per-pet override sets only for signature pets (bosses/huges).
]]

return {
    rig_classes = {
        biped = {
            idle = "rbxassetid://107633065661523", -- MeshyStretchIdle
            run = "rbxassetid://130063719118527", -- biped_run (auto pipeline)
            attack = "rbxassetid://125428500789381", -- Meshy12Punch (one-two)
        },
        -- quadruped = { ... }  -- pending the first quadruped clip set
    },

    -- Locomotion state machine (client, PetAnimator): horizontal speed in studs/sec with
    -- hysteresis so the pet doesn't flicker between idle and run at the threshold.
    locomotion = {
        run_speed = 2.0, -- speed above this (while idle) -> run
        idle_speed = 0.8, -- speed below this (while running) -> idle
        fade = 0.2, -- crossfade seconds between idle/run
    },

    -- Attack: played ONCE per real server swing (Combat_PetHit), layered over locomotion.
    attack = {
        fade = 0.1,
        speed = 1.0, -- playback speed multiplier (tune so the swing reads at combat cadence)
    },
}
