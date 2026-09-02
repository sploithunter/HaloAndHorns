--[[
    tutorial — the new-player guided path (config-as-code, EVENT-DRIVEN).

    Each step COMPLETES off a named GameEvents bus event (docs/GAME_EVENTS.md) — the tutorial
    never polls game state and no gameplay service knows it exists. TutorialService taps every
    server-side fireGameEvent(player, name, ctx) call; when the current step's `complete_on`
    event arrives (count times), the player advances. Add/reorder/remove steps HERE only.

    Step shape:
      id          stable key (progress persists by index, id is for logs/UI)
      title/body  what the objective capsule shows
      target      where the client should point the player:
                    { kind = "egg" }                 — beacon over the nearest world egg
                    { kind = "ui", name = "<gui>" }  — pulse the named GuiObject (recursive find)
                    { kind = "none" }                — text only
      complete_on { event = "<bus event>", count = N (default 1) }

    `veteran_skip`: an existing save with claimed level >= this (or any pet hatched before the
    tutorial existed) silently completes the whole thing — only genuinely new players see it.
]]

return {
    -- v6: after Resonance, first_fight hands Combat Training to Quest (Okay
    -- banner, no FIGHT trail). Finishing the Earth cave still advances. Rally
    -- stays the last Homeworld beat.
    version = 6,
    -- XP still accrues. Claim/COMMIT/altar wait until Rally finishes so the
    -- Resonance enhance lesson cannot land inside a level-up beat.
    -- Ascension is introduced only after either this crystal/Homeworld track or the independent
    -- Combat Training track is complete. Earned XP may exist earlier, but it cannot be claimed.
    hold_level_claim = true,
    step_migrations = {
        -- v1 -> v2 removed the redundant manual-equip gate and added explicit squad review.
        [1] = {
            [1] = { step = 1 },
            [2] = { step = 2 },
            [3] = { step = 2, preserve_count = true },
            [4] = { step = 3 },
            [5] = { step = 5 },
            [6] = { step = 6 },
            [7] = { step = 7 },
            [8] = { step = 8 },
            [9] = { step = 9 },
            [10] = { step = 10 },
        },
        -- v2 -> v3 follows each lesson to its new index rather than preserving its old number.
        [2] = {
            [1] = { step = 1 }, -- hatch_first_egg
            [2] = { step = 2, preserve_count = true }, -- farm_crystals
            [3] = { step = 3 }, -- hatch_another
            [4] = { step = 4 }, -- build_squad
            [5] = { step = 8 }, -- first_fight
            [6] = { step = 9 }, -- battle_brew
            [7] = { step = 10 }, -- rally_call
            [8] = { step = 5 }, -- bind_power
            [9] = { step = 6 }, -- cast_power
            [10] = { step = 7 }, -- slot_power
        },
        -- v3 -> v4 returned each active lesson to the fight-then-Resonance ordering.
        [3] = {
            [1] = { step = 1 }, -- hatch_first_egg
            [2] = { step = 2, preserve_count = true }, -- farm_crystals
            [3] = { step = 3 }, -- hatch_another
            [4] = { step = 4 }, -- build_squad
            [5] = { step = 8 }, -- bind_power
            [6] = { step = 9 }, -- cast_power
            [7] = { step = 10 }, -- slot_power
            [8] = { step = 5 }, -- first_fight
            [9] = { step = 6 }, -- battle_brew
            [10] = { step = 7 }, -- rally_call
        },
        -- v4 -> v5 puts Resonance back after squad; combat tail stays 8–10 for now.
        [4] = {
            [1] = { step = 1 }, -- hatch_first_egg
            [2] = { step = 2, preserve_count = true }, -- farm_crystals
            [3] = { step = 3 }, -- hatch_another
            [4] = { step = 4 }, -- build_squad
            [5] = { step = 8 }, -- first_fight
            [6] = { step = 9 }, -- battle_brew
            [7] = { step = 10 }, -- rally_call
            [8] = { step = 5 }, -- bind_power
            [9] = { step = 6 }, -- cast_power
            [10] = { step = 7 }, -- slot_power
        },
        -- v5 -> v6 folds the cave fight + brew into the combat-training cave.
        -- Rally stays the last Homeworld beat after they exit.
        [5] = {
            [1] = { step = 1 },
            [2] = { step = 2, preserve_count = true },
            [3] = { step = 3 },
            [4] = { step = 4 },
            [5] = { step = 5 },
            [6] = { step = 6 },
            [7] = { step = 7 },
            [8] = { step = 8 }, -- first_fight (now the cave-training handoff)
            [9] = { step = 8 }, -- battle_brew absorbed into the cave track
            [10] = { step = 9 }, -- rally_call
        },
    },
    veteran_skip = { min_claimed_level = 3 },
    -- Live-save contract when combat training replaced the old first-enemy beat.
    -- Cave enter did not exist in v1–v5. Players who already scored that beat
    -- (or finished) get Heal + Rally and are marked done so they cannot stick
    -- on combat_tutorial_complete. Players who have not fought yet stay on
    -- the Homeworld path and can enter the new cave. See
    -- TutorialFlow.reconcileGrandfather.
    grandfather = {
        unlock_heal = true,
        complete_if_first_enemy = true,
    },

    steps = {
        {
            id = "hatch_first_egg",
            localization_key = "tutorial.hatch_first_egg",
            title = "Hatch your first egg",
            body = "Your companion needs a squadmate. Follow the trail to the Earth Egg and hatch one.",
            body_gamepad = "Your companion needs a squadmate. Follow the trail to the Earth Egg and press X to hatch one.",
            target = { kind = "egg", prefer = "Grass" },
            complete_on = { event = "egg_hatch" },
        },
        {
            id = "farm_crystals",
            localization_key = "tutorial.farm_crystals",
            title = "Mine some crystals",
            body = "Your squad mines nearby crystals when Farm Near is ON—click a small crystal to BOOST it, then earn 100 coins for another egg!",
            body_gamepad = "Your squad mines nearby crystals when Farm Near is ON. Walk near a small crystal to BOOST it, then earn 100 coins for another egg!",
            -- trail + MINE beacon to the nearest SMALL crystal (fast first break), and
            -- the Farm button still pulses as the secondary cue
            target = { kind = "crystal", ui = "Farming" },
            -- COIN gate (Jason): 3 payouts didn't guarantee the 100 coins the next egg
            -- costs — sum payout amounts so the counter reads "coins earned / 100" and
            -- the step holds until the second hatch is affordable
            complete_on = { event = "coin_payout", sum_ctx = "amount", count = 100 },
        },
        {
            id = "hatch_another",
            localization_key = "tutorial.hatch_another",
            title = "Grow your squad",
            body = "Spend those coins on another egg — more pets means faster mining.",
            body_gamepad = "Spend those coins on another egg. Walk to it and press X—more pets means faster mining.",
            target = { kind = "egg", prefer = "Grass" },
            complete_on = { event = "egg_hatch" },
        },
        {
            id = "build_squad",
            localization_key = "tutorial.build_squad",
            title = "Build your squad",
            -- GRANT-ON-ENTER: a Rainbow Kitty so Inventory has an obviously stronger
            -- pick than the early hatches. The lesson walks unequip → pick → Activate.
            grant = {
                pets = {
                    { id = "kitty", variant = "rainbow", source = "tutorial_build_squad" },
                },
            },
            body = "The top row is your equipped squad — those pets fight and mine with you. Everyone else waits in Inventory. Open Pets and we'll swap one on.",
            body_gamepad = "The top row is your equipped squad. Press D-pad Left to open Pets — we'll swap one on.",
            body_with_unequipped = "You have a Rainbow Kitty waiting in Inventory — your strongest pet. Open Pets: take one off the equipped row, put the Kitty on, then Activate.",
            guide = {
                open = {
                    title = "Build your squad",
                    body = "The top row is your equipped squad — those pets fight and mine with you. Everyone else waits in Inventory. Open Pets and we'll swap one on.",
                    body_gamepad = "The top row is your equipped squad. Press D-pad Left to open Pets — we'll swap one on.",
                    cue_text = "CLICK HERE",
                },
                unequip = {
                    title = "Take one off",
                    body = "Click the X on an equipped pet to unequip it. That frees a squad slot.",
                    body_gamepad = "Select an equipped pet and press A to take it off. That frees a squad slot.",
                    cue_text = "TAKE OFF",
                },
                pick = {
                    title = "Pick your strongest",
                    body = "Click the strongest pet in Inventory — your Rainbow Kitty. You can pick any pet, even the one you just took off.",
                    body_gamepad = "Select the strongest pet in Inventory — your Rainbow Kitty — and press A. You can pick any pet, even the one you just took off.",
                    cue_text = "CLICK HERE",
                },
                activate = {
                    title = "Activate",
                    body = "Press Activate to send the new squad out. The top row is who fights; Inventory is everyone else.",
                    body_gamepad = "Press Activate (A) to send the new squad out. The top row is who fights; Inventory is everyone else.",
                    cue_text = "ACTIVATE",
                },
            },
            target = {
                kind = "ui",
                name = "PetsButton",
                cue = "equip_squad",
                cue_text = "CLICK HERE",
            },
            complete_on = { event = "tutorial_squad_reviewed" },
        },
        -- Powers follow the familiar pet-game loop after squad review. Resonance is innate;
        -- these lessons teach binding, casting, and enhancing before the combat tail.
        {
            id = "bind_power",
            localization_key = "tutorial.bind_power",
            title = "Set your power",
            body = "You were born with a power — Resonance! Hit Edit on your power bar, then drop Resonance onto a slot. You'll do this for every power you unlock.",
            body_gamepad = "You were born with Resonance! Press D-pad Right for Powers, choose Resonance with A, and assign it to a slot.",
            target = {
                kind = "ui",
                name = "Edit",
                cue = "click",
                cue_text = "CLICK HERE",
            }, -- the live power-bar Edit button (HotbarBar)
            -- Binding Resonance is only the middle of this lesson. The server completes the step
            -- after the player presses Done and verifies that Resonance is actually on the bar.
            complete_on = { event = "tutorial_hotbar_finished" },
        },
        {
            id = "cast_power",
            localization_key = "tutorial.cast_power",
            title = "Use Resonance",
            body = "Now press that slot (or its number key) near crystals — Resonance makes them break faster and pay more currency.",
            body_gamepad = "Use LB/RB to select Resonance, then press RT near crystals. It makes them break faster and pay more currency.",
            -- Resolve by binding identity, never by slot number: the preceding lesson lets the
            -- player place Resonance anywhere on the bar.
            target = {
                kind = "ui",
                hotbar_type = "power",
                hotbar_target = "resonance",
                cue = "click",
                cue_text = "CLICK HERE",
            },
            complete_on = { event = "power_cast" },
        },
        {
            id = "slot_power",
            localization_key = "tutorial.slot_power",
            title = "Power up Resonance",
            -- GRANT-ON-ENTER (TutorialService:_applyStepGrant): ONE level-3 natural Potency + an
            -- inherent slot on Resonance so a level-1 player has somewhere to drop it. L3 is
            -- slottable at level 1 (window=5 → 3 ≤ 1+5) and stronger than L1 (per_level scaling). Potency
            -- boosts Resonance's magnitude (the crystal-boost amount) — its first real upgrade. (Jason)
            grant = {
                enhancements = { { type = "potency", origins = {}, level = 3, count = 1 } },
                ensure_slot = "resonance",
            },
            body = "You earned a Potency enhancement! Open POWERS, tap Resonance, and drop it into a slot — stronger pulses mean faster, richer crystals.",
            body_gamepad = "You earned a Potency enhancement! Press D-pad Right, select Resonance with A, and slot Potency for stronger pulses.",
            target = {
                kind = "ui",
                name = "PowersButton",
                cue = "click",
                cue_text = "CLICK HERE",
            },
            complete_on = {
                event = "enhancement_slotted",
                context = { powerId = "resonance" },
            },
        },
        -- Combat training lives in the Earth cave. The FIGHT trail stays
        -- until they enter, or they tap Later and Okay the Quest banner.
        {
            id = "first_fight",
            localization_key = "tutorial.first_fight",
            title = "Combat training",
            body = "The Earth cave is a training ground. Press E to enter and learn how to fight.",
            body_gamepad = "The Earth cave is a training ground. Press X to enter and learn how to fight.",
            target = {
                kind = "part",
                name = "EarthLair",
                root = "Maps.Home",
                label = "⬇ FIGHT",
            },
            handoff = {
                later_label = "Later",
                title = "TO CONTINUE THE TUTORIAL",
                body = "It's in Quest.\n\nOpen Quest anytime to start Combat Training — the Earth cave — and learn how to fight.",
                ok_label = "Okay",
            },
            complete_on = {
                event = "combat_tutorial_complete",
                events = { "combat_tutorial_complete", "combat_training_quest_ack" },
            },
        },
        -- Rally closes the Homeworld loop after they exit the cave. Rejoin reapplies its bind.
        {
            id = "rally_call",
            localization_key = "tutorial.rally_call",
            title = "Call them back",
            grant = {
                hotbar_bind = { slot = 11, type = "tactical", target = "rally" },
            },
            body = "See the FLAG at the top-left of your power bar? That's Rally — press it and your pets instantly return to your side. Your escape button when a fight goes wrong!",
            body_gamepad = "See the FLAG at the top-left of your power bar? Select it with LB/RB and press RT to call every pet back!",
            target = {
                kind = "ui",
                hotbar_type = "tactical",
                hotbar_target = "rally",
                cue = "click",
                cue_text = "CLICK HERE",
            },
            complete_on = { event = "rally_used" },
        },
    },

    -- Shown by the client for a few seconds when the LAST step completes (Jason: the
    -- tutorial ends here — leveling is a grind away, and that's the QUEST chain's job).
    -- After this card, the quest tracker takes the HUD spot and carries the player on.
    completion = {
        localization_key = "tutorial.completion",
        -- Finishing the guided loop guarantees EARNED level 2. TutorialService adds only the
        -- missing XP, then the normal Ascension Altar flow claims level 2 and its power choice.
        grant_earned_level = 2,
        title = "🎉 TUTORIAL COMPLETE — LEVEL 2!",
        body = "You earned Level 2! Visit the Ascension Altar to choose your next power, then follow your missions.",
        show_seconds = 8,
    },
}
