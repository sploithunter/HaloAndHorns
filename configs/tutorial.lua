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
    veteran_skip = { min_claimed_level = 3 },

    steps = {
        {
            id = "hatch_first_egg",
            title = "Hatch your first pet",
            body = "Walk to the glowing egg and hatch it — pets do everything for you here.",
            target = { kind = "egg", prefer = "Grass" },
            complete_on = { event = "egg_hatch" },
        },
        {
            id = "equip_pet",
            title = "Deploy your pet",
            -- DRAFT-DEPLOY: clicking a pet only stages it; the squad isn't live until ✓ Activate. New
            -- players stall here, so the copy spells out Activate and the panel pulses the button while
            -- the draft is un-deployed (InventoryPanel:_setActivatePulse). Step completes on the commit
            -- (pet_equipped fires from the Activate path, not the draft edit).
            body = "Open the Pets menu, click your new pet to add it to your squad — then press ✓ Activate to send it out! Squad pets follow you and mine. New players can run 3.",
            target = { kind = "ui", name = "PetsButton" },
            complete_on = { event = "pet_equipped" },
        },
        {
            id = "farm_crystals",
            title = "Mine some crystals",
            body = "Pets mine nearby crystals when Farm Near is ON — click a crystal to BOOST it, scoop up the coins. Earn 100 coins so you can afford your next egg!",
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
            title = "Grow your team",
            body = "Spend those coins on another egg — more pets means faster mining.",
            target = { kind = "egg", prefer = "Grass" },
            complete_on = { event = "egg_hatch" },
        },
        -- POWERS come AFTER the familiar pet-game rhythm (Jason: hook them with what they know first,
        -- THEN introduce what makes this game different). Every player is born with Resonance (innate);
        -- these two steps teach the bind flow (reused for every future power) + the cast.
        {
            id = "bind_power",
            title = "Set your power",
            body = "You were born with a power — Resonance! Hit Edit on your power bar, then drop Resonance onto a slot. You'll do this for every power you unlock.",
            target = { kind = "ui", name = "Edit" }, -- the power-bar Edit button (HotbarBar) — blinking arrow points at it
            complete_on = { event = "power_bound" },
        },
        {
            id = "cast_power",
            title = "Use Resonance",
            body = "Now press that slot (or its number key) to pulse Resonance near some crystals — it super-charges them so your pets mine way harder.",
            target = { kind = "none" },
            complete_on = { event = "power_cast" },
        },
        {
            id = "slot_power",
            title = "Power up Resonance",
            -- GRANT-ON-ENTER (TutorialService:_applyStepGrant): ONE level-3 natural Potency + an
            -- inherent slot on Resonance so a level-1 player has somewhere to drop it. L3 is exactly
            -- slottable at level 1 (window=2 → 3 ≤ 1+2) and stronger than L1 (per_level scaling). Potency
            -- boosts Resonance's magnitude (the crystal-boost amount) — its first real upgrade. (Jason)
            grant = {
                enhancements = { { type = "potency", origins = {}, level = 3, count = 1 } },
                ensure_slot = "resonance",
            },
            body = "You earned a Potency enhancement! Open POWERS, tap Resonance, and drop the Potency into a slot — every pulse will hit even harder.",
            target = { kind = "ui", name = "PowersButton" },
            complete_on = { event = "enhancement_slotted" },
        },
    },

    -- Shown by the client for a few seconds when the LAST step completes (Jason: the
    -- tutorial ends here — leveling is a grind away, and that's the QUEST chain's job).
    -- After this card, the quest tracker takes the HUD spot and carries the player on.
    completion = {
        title = "🎉 QUESTS UNLOCKED!",
        body = "Your missions are in the tracker up top — claim your first rewards and climb to Level 2!",
        show_seconds = 8,
    },
}
