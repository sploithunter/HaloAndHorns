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
    -- v2 removes the redundant manual-equip gate and teaches squad management after two guided
    -- hatches. TutorialFlow migrates persisted numeric progress with legacy_step_migration below.
    version = 2,
    legacy_step_migration = {
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
    veteran_skip = { min_claimed_level = 3 },

    steps = {
        {
            id = "hatch_first_egg",
            title = "Hatch your first egg",
            body = "Your companion needs a squadmate. Follow the trail to the Earth Egg and hatch one.",
            body_gamepad = "Your companion needs a squadmate. Follow the trail to the Earth Egg and press X to hatch one.",
            target = { kind = "egg", prefer = "Grass" },
            complete_on = { event = "egg_hatch" },
        },
        {
            id = "farm_crystals",
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
            title = "Grow your squad",
            body = "Spend those coins on another egg — more pets means faster mining.",
            body_gamepad = "Spend those coins on another egg. Walk to it and press X—more pets means faster mining.",
            target = { kind = "egg", prefer = "Grass" },
            complete_on = { event = "egg_hatch" },
        },
        {
            id = "build_squad",
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
        -- THE FIRST FIGHT (Jason: "introduce combat in the first five minutes —
        -- we can't out-cute the other pet sims, we out-GAME them"): right after
        -- the second hatch, the trail leads to the Earth cave. A sub-onramp
        -- player triggers a SOLO level-1 creature there (BaddieSpawnerService
        -- onramp wave, spawned ungated) and their pets defend them — the
        -- differentiator on screen inside the first five minutes.
        {
            id = "first_fight",
            title = "Your first fight",
            body = "Something stirs in the Earth cave! Walk over — your pets fight for you. Defeat it and take its coins!",
            target = { kind = "part", name = "BaddieSpawnerEarth", label = "⬇ FIGHT" },
            complete_on = { event = "enemy_defeated" },
        },
        -- Potion auto-binding uses the first eligible top-row slot, which may vary with the
        -- player's existing bindings. Target the live Berserk Brew binding by identity rather
        -- than guessing a slot number.
        {
            id = "battle_brew",
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
        -- THE RALLY FLAG (Jason: "teach the player even in tutorial about the
        -- rally flag" — the panic button is granted on step entry at slot 11).
        -- Target the live binding by identity, just like Berserk Brew, so the
        -- click cue remains attached to Rally if hotbar layout rules ever move it.
        -- Taught right after the cave fights while "a fight going wrong" is a
        -- fresh memory. Rejoin reapplies this idempotently so the objective can
        -- never point at an empty slot.
        {
            id = "rally_call",
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
        -- POWERS come AFTER the familiar pet-game rhythm (Jason: hook them with what they know first,
        -- THEN introduce what makes this game different). Every player is born with Resonance (innate);
        -- these two steps teach the bind flow (reused for every future power) + the cast.
        {
            id = "bind_power",
            title = "Set your power",
            body = "You were born with a power — Resonance! Hit Edit on your power bar, then drop Resonance onto a slot. You'll do this for every power you unlock.",
            body_gamepad = "You were born with Resonance! Press D-pad Right for Powers, choose Resonance with A, and assign it to a slot.",
            target = {
                kind = "ui",
                name = "Edit",
                cue = "click",
                cue_text = "CLICK HERE",
            }, -- the live power-bar Edit button (HotbarBar)
            complete_on = { event = "power_bound" },
        },
        {
            id = "cast_power",
            title = "Use Resonance",
            body = "Now press that slot (or its number key) near crystals — Resonance makes them break faster and pay more currency.",
            body_gamepad = "Use LB/RB to select Resonance, then press RT near crystals. It makes them break faster and pay more currency.",
            target = { kind = "none" },
            complete_on = { event = "power_cast" },
        },
        {
            id = "slot_power",
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
    },

    -- Shown by the client for a few seconds when the LAST step completes (Jason: the
    -- tutorial ends here — leveling is a grind away, and that's the QUEST chain's job).
    -- After this card, the quest tracker takes the HUD spot and carries the player on.
    completion = {
        -- Finishing the guided loop guarantees EARNED level 2. TutorialService adds only the
        -- missing XP, then the normal Ascension Altar flow claims level 2 and its power choice.
        grant_earned_level = 2,
        title = "🎉 TUTORIAL COMPLETE — LEVEL 2!",
        body = "You earned Level 2! Visit the Ascension Altar to choose your next power, then follow your missions.",
        show_seconds = 8,
    },
}
