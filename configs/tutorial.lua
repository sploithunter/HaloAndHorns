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
    -- v3 teaches the complete Resonance loop before the cave fight, then closes with combat,
    -- Berserk Brew, and Rally. Versioned migrations preserve the semantic lesson for active saves.
    version = 3,
    -- Hall-era new-player stamp. Written only onto brand-new (or Reset) tutorial records.
    -- Legacy saves have no `track`; do not Reconcile this through the profile template.
    hall_track = 2,
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
    },
    veteran_skip = { min_claimed_level = 3 },

    steps = {
        {
            id = "hatch_first_egg",
            localization_key = "tutorial.hatch_first_egg",
            title = "Hatch your first egg",
            body = "Your companion needs a squadmate. Follow the trail to the Wayfinder Egg and hatch one.",
            body_gamepad = "Your companion needs a squadmate. Follow the trail to the Wayfinder Egg and press X to hatch one.",
            target = { kind = "egg", prefer = "wayfinder_egg" },
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
            target = { kind = "egg", prefer = "wayfinder_egg" },
            complete_on = { event = "egg_hatch" },
        },
        {
            id = "build_squad",
            localization_key = "tutorial.build_squad",
            title = "Build your squad",
            body = "This is where you choose which pets fight beside you. Open Pets and take a look—you can keep your current squad.",
            body_gamepad = "This is where you choose which pets fight beside you. Press D-pad Left to open Pets, then use A to choose.",
            body_with_unequipped = "You have more pets to choose from now. Open Pets and choose who fights beside you. Swap someone if you want—or keep your current squad.",
            target = {
                kind = "ui",
                name = "PetsButton",
                cue = "click",
                cue_text = "CLICK HERE",
            },
            complete_on = { event = "tutorial_squad_reviewed" },
        },
        -- Teach the complete Resonance loop before combat. This prevents cave XP from opening an
        -- Ascend choice while the player is still learning how to bind and enhance their first power.
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
            body = "Now press that slot (or its number key) near resources — Resonance makes crystals and Hall caches break faster and pay more currency.",
            body_gamepad = "Use LB/RB to select Resonance, then press RT near resources. It makes crystals and Hall caches break faster and pay more currency.",
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
            complete_on = { event = "enhancement_slotted" },
        },
        -- Close with one uninterrupted combat sequence: fight, drink, then recall. The level-2
        -- top-up happens only after Rally completes the tutorial.
        {
            id = "first_fight",
            localization_key = "tutorial.first_fight",
            title = "Your first fight",
            body = "Something got into the barn! Head over — your pets fight for you. Drive it out and collect its Waycoins!",
            target = { kind = "part", name = "BaddieSpawnerHallBarn", label = "⬇ FIGHT" },
            complete_on = { event = "enemy_defeated" },
        },
        -- Potion auto-binding uses the first eligible top-row slot, which may vary with the
        -- player's existing bindings. Target the live Berserk Brew binding by identity.
        {
            id = "battle_brew",
            localization_key = "tutorial.battle_brew",
            title = "Drink for battle",
            grant = { potions = { { id = "berserk_brew", count = 2 } } },
            body = "CLICK the flashing Berserk Brew in your power bar. It makes every pet hit harder!",
            body_gamepad = "You found two Berserk Brews! Use LB/RB to select the flashing brew, then RT to drink it.",
            target = {
                kind = "ui",
                hotbar_type = "potion",
                hotbar_target = "berserk_brew",
                cue = "click",
                cue_text = "CLICK HERE",
            },
            complete_on = { event = "potion_used" },
        },
        -- Rally is the final lesson and therefore the event that triggers the completion card and
        -- exact earned-level-2 top-up. Rejoin reapplies its bind idempotently.
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
