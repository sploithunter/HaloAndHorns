--[[
    game_events — the EVENT -> REACTIONS registry (config-as-code).

    Code fires a named gameplay event (GameEvents.fire("level_up", ctx)); THIS config decides what
    reacts. Each reaction kind is a key the client dispatcher (src/Client/Systems/GameEvents.lua)
    knows how to apply:

        sound = "<key in configs/sounds.lua>"   -- play that sound on its configured bus
        --   (or { key = "...", volume = 0.5 } to scale loudness for THIS event only)
        banner = { seconds, color }             -- lingering screen-center card (text = ctx.name)
        -- RULE (Jason): if another player can SEE it, they should HEAR it — world
        -- moments (level-ups, meets, the future epic level-up animation) use
        -- world_sound + world-visible visuals together; UI-only moments (achievement
        -- toasts) stay personal `sound`.
        -- RULE (Jason): never a sound without a visual — every row with `sound` must
        -- also have vfx/float/banner (CI-enforced; world_visual=true marks diegetic
        -- exceptions like pet_down where the world itself is the visual)
        -- (planned) vfx = "<CombatFX/effect spec>", toast = "<text>", ...

    Add or extend a row to react to an event WITHOUT touching the firing code; remove a row to
    silence it. The only inherently-code part is detecting the event and calling fire().

    Event sources:
      level_up   — the player's claimed level increased        (client: LevelUpController)
    Planned (wire the source, then add a row here): death, hit, area_change, egg_hatch, purchase.
]]

return {
    -- TOGGLE CRASH: a player's always-on toggles dropped because Focus couldn't pay their upkeep
    -- (the CoH "detoggle"). Fired server-side from PowerService:_detoggleAll. The power_down SFX +
    -- a dim slate burst = the "everything winds down" moment. Personal (your own toggles crashing).
    toggle_crash = {
        sound = "power_down",
        vfx = { kind = "burst", color = { 130, 130, 160 } }, -- dim slate "power down" at the player
    },

    -- CAST FIZZLE: a power the player tried to fire just couldn't (no valid target / no tank to
    -- taunt onto / not enough focus). The generic "that didn't work" feedback — the flub buzzer +
    -- a small muted-red puff at the player. Personal (UI feedback, not a shared-world moment).
    -- Reusable: fire "power_cast_failed" from ANY path that can't cast (Jason).
    power_cast_failed = {
        sound = "flub",
        vfx = { kind = "burst", color = { 200, 70, 70 }, count = 6 }, -- small red "nope" puff
        -- The sound/puff says the cast failed; this says what the player can do about it. Reasons
        -- are server-authored machine keys, while all visible wording stays config-driven here.
        failure_float = {
            seconds = 2.4,
            color = { 255, 220, 105 },
            -- Default farm float is 360x44. Every bonk refusal uses this
            -- larger box so the line reads against grass and sky.
            size = 460,
            height = 60,
            default = "That power can't be used here.",
            messages = {
                no_crystals_in_range = "No resources in range — move closer.",
                no_enemy_target = "No enemy target — engage an enemy first.",
                no_enemy_or_crystal_target = "No enemy or crystal target.",
                no_pets_deployed = "No pets deployed.",
                no_downed_pets = "No downed pets to revive.",
                no_pets_or_enemies_in_range = "No pets or enemies in range.",
                no_tank = "Select a pet or deploy a Tank.",
                not_enough_focus = "Not enough Focus to use this power.",
                on_cooldown = "That power is still recharging.",
                travel_unavailable = "World Travel is unavailable.",
                invalid_destination = "Choose an unlocked destination.",
                destination_locked = "That destination is locked.",
                missing_spawn = "That destination is temporarily unavailable.",
                character_not_ready = "Your character is not ready.",
                travel_failed = "Travel failed — try again.",
                no_recall_egg = "Hatch an egg before using Recall.",
                invalid_recall_egg = "Your last egg cannot be recalled.",
                recall_unavailable = "Recall is unavailable.",
                recall_egg_missing = "That egg is no longer available.",
                recall_no_safe_arrival = "No safe landing spot near that egg.",
            },
        },
    },

    -- POTION FIZZLE: drinking or throwing failed before inventory consumption. This mirrors the
    -- failed-power feedback, but keeps potion-specific language and a distinct server event so
    -- item activation remains independently auditable.
    potion_use_failed = {
        sound = "flub",
        vfx = { kind = "burst", color = { 200, 70, 70 }, count = 6 },
        failure_float = {
            seconds = 2.4,
            color = { 255, 220, 105 },
            size = 460,
            height = 60,
            default = "That item can't be used here.",
            messages = {
                no_enemy_target = "No enemy target — engage an enemy first.",
                target_unavailable = "That enemy target is unavailable.",
                target_out_of_range = "Enemy target is out of range — move closer.",
                meter_full = "That effect is already full.",
                too_fast = "Wait a moment before using another.",
                none_left = "None left.",
                enemy_target_requires_throw = "Use this potion on an enemy.",
                not_throwable = "That item cannot be thrown.",
                unknown_potion = "That potion is unavailable.",
                no_meter = "That potion is unavailable.",
                service_unavailable = "Items are temporarily unavailable.",
                consume_failed = "Could not use that item — try again.",
            },
        },
    },

    -- level_up (client-fired from ClaimedLevel) keeps a small immediate confirmation burst.
    level_up = {
        vfx = { kind = "burst", color = { 255, 205, 70 } }, -- gold celebratory burst at the player
    },

    -- LEVEL EARNED: the bar just filled and the arrow starts blinking (server truth,
    -- once per earned level). This stays deliberately light: the full transformation belongs to
    -- the player's successful altar claim, not merely filling the XP bar.
    level_earned = {
        vfx = { kind = "burst", color = { 255, 225, 120 }, count = 8 },
    },

    -- LEVEL CLAIMED / ASCEND: the City-of-Heroes-style payoff. The approved 7.5-second crescendo
    -- plays positionally so nearby players hear it; the claimant rises, spins through layered
    -- rings/sparkles, and lands on the final reveal. `level_claimed` is server truth and fires only
    -- after the atomic claim succeeds.
    level_claimed = {
        world_sound = "level_up_epic",
        ascension = { seconds = 7.5 },
    },

    -- A new area/gate was unlocked (client: init.client ZoneUnlockResult ok). Celebratory, and no
    -- prior fanfare, so no conflict with existing reactions.
    area_unlocked = {
        sound = "unlock_gate_sting",
        vfx = { kind = "burst", color = { 120, 230, 150 } }, -- green "new ground" burst
    },

    -- VETERAN LEVEL reached (docs/VETERAN_LEVELS.md — the post-cap track; server:
    -- PlayerProgressionService:_veteranPass). Payload: { level, rolls, milestone }. Milestone
    -- beats (every 10th) get the world-announce treatment later; for now one celebration row.
    veteran_level = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 200, 160, 255 } }, -- veteran purple
    },

    -- ===== Batch 1: server-fired celebrations (FireGameEvent at each success spot). All reuse the
    -- celebratory jingle for now (swap per-event sounds here later, config-only); burst colors
    -- differentiate them visually. =====

    -- An achievement tier completed (server: AchievementsService alongside AchievementCompleted).
    -- an enhancement was slotted into a power (EnhancementService:Slot). A personal lightning zap +
    -- electric-blue burst (the rule: never a sound without a visual; the menu slot-fill is the close-up
    -- cue, this burst is the world flourish).
    enhancement_slotted = {
        sound = "enhancement_slot_zap",
        vfx = { kind = "burst", color = { 120, 200, 255 } }, -- electric blue
    },

    -- A player met a registered CREATOR for the first time (MeetCreatorService) —
    -- once ever per creator; the reward egg rides the event payload.
    -- A PERMANENT-class pet (huge+/creator) leveled up and AWAKENED a new enchant —
    -- fated and unchangeable the moment it lands (Jason). World-visible celebration:
    -- shared world effect per the see-it -> hear-it rule.
    enchant_awakened = {
        world_sound = "celebratory_jingle",
        -- PLACEHOLDER big explosion (Jason: "a big explosion or something" until the
        -- real awakening animation lands). Purely visual — never blocks combat/input,
        -- so an awakening mid-fight can't get anyone killed.
        vfx = { kind = "burst", color = { 170, 90, 255 }, count = 40 }, -- enchant purple, BIG
        float = { color = { 170, 90, 255 }, prefix = "✨ ", size = 160 },
        banner = { seconds = 6, color = { 170, 90, 255 } },
    },

    -- A HUGE WORLD FIRST (Jason: "if the index updates you basically get a global
    -- announcement that there's a new huge in the realm"): serial #1 of a huge
    -- species:variant, fired to EVERY player on EVERY server (PetWorldFirst topic via
    -- PetIndexService). Banner text rides ctx.name ("🌍 FIRST HUGE POLAR BEAR EVER —
    -- hatched by X!"). Personal `sound` (not world_sound): the hatcher may be on
    -- another server, so there's no position to play it at.
    huge_world_first = {
        sound = "celebratory_jingle",
        banner = { seconds = 10, color = { 255, 105, 180 } }, -- huge pink
    },

    met_creator = {
        world_sound = "discovery_fanfare", -- audible around the meeting, not just to the met player
        vfx = { kind = "burst", color = { 255, 215, 0 } }, -- creator gold
        banner = { seconds = 10, color = { 255, 215, 0 } },
        -- Jason: "it wasn't very obvious that the creator's on this server" — a big
        -- gold crown float over the player on top of the banner
        float = { color = { 255, 215, 0 }, prefix = "👑 ", size = 200 },
    },

    -- Level-5 Future Call entitlement and explicit admin grants. The banner carries
    -- the granted count; the purple burst makes the new hotbar consumable hard to miss.
    future_call_awarded = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 145, 95, 255 }, count = 24 },
        banner = { seconds = 8, color = { 145, 95, 255 } },
    },

    future_call_unlocked = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 145, 95, 255 }, count = 24 },
        banner = { seconds = 8, color = { 145, 95, 255 } },
    },

    -- Pressing the visible Level-2 promise token before it unlocks should teach
    -- the goal, not silently fail or consume anything.
    future_call_locked = {
        banner = { seconds = 5, color = { 145, 95, 255 } },
    },

    -- One free, player-controlled paid-style boost at claimed levels 2, 3, and 4.
    early_boost_awarded = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 90, 215, 255 }, count = 24 },
        banner = { seconds = 8, color = { 90, 215, 255 } },
    },

    tester_reward_awarded = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 70, 210, 255 }, count = 28 },
        banner = { seconds = 9, color = { 70, 210, 255 } },
    },

    -- Weekly/creator/event code reward. The server supplies the authored success message as
    -- ctx.name, while this shared reaction path supplies the standard reward fanfare.
    promo_code_redeemed = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 75, 225, 145 }, count = 24 },
        banner = { seconds = 8, color = { 75, 225, 145 } },
    },

    -- Durable server award delivery (leaderboard windows now; future offline exchange receipts).
    -- The producer supplies the exact award summary as ctx.name after the profile mutation succeeds.
    award_delivered = {
        sound = "daily_claim_chime",
        vfx = { kind = "burst", color = { 255, 205, 70 }, count = 28 },
        award_receipt = {},
    },

    -- One-way gifts arrive unopened. The banner points to Inventory > Gifts;
    -- the pet reveal happens only when the receiver opens the present.
    gift_received = {
        sound = "daily_claim_chime",
        vfx = { kind = "burst", color = { 70, 180, 255 }, count = 22 },
        banner = { seconds = 8, color = { 70, 180, 255 } },
    },

    gift_sent = {
        sound = "daily_claim_chime",
        vfx = { kind = "burst", color = { 255, 205, 70 }, count = 14 },
        banner = { seconds = 4, color = { 255, 205, 70 } },
    },

    -- Guided-hatch squad auto-fill. EggService delays this until the reveal sequence finishes so
    -- the summary reads as the consequence of what the player just saw, not an overlapping popup.
    tutorial_squad_autofill = {
        sound = "power_up_stronger",
        vfx = { kind = "burst", color = { 80, 225, 125 }, count = 18 },
        banner = { seconds = 5, color = { 80, 225, 125 } },
    },

    tester_reward_upgraded = {
        sound = "power_up_stronger",
        vfx = { kind = "burst", color = { 255, 190, 55 }, count = 24 },
        banner = { seconds = 7, color = { 255, 190, 55 } },
    },

    trial_egg_awarded = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 120, 205, 255 }, count = 28 },
        banner = { seconds = 10, color = { 120, 205, 255 } },
    },

    trial_egg_upgraded = {
        sound = "power_up_stronger",
        vfx = { kind = "burst", color = { 255, 215, 70 }, count = 26 },
        banner = { seconds = 9, color = { 255, 215, 70 } },
    },

    -- Launch social event. Uses the same large floating celebration pattern as
    -- Future Call tokens; ctx.name contains either the invitation or live totals.
    friend_boost_active = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 80, 210, 255 }, count = 24 },
        banner = { seconds = 8, color = { 80, 210, 255 } },
    },

    -- First-10,000-player permanent benefit. The availability beat is intentionally as prominent
    -- as Future Call tokens; selection is a shorter confirmation after the dedicated chooser.
    founders_choice_available = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 255, 198, 55 }, count = 28 },
        banner = { seconds = 9, color = { 255, 198, 55 } },
    },

    founders_choice_selected = {
        sound = "power_up_stronger",
        vfx = { kind = "burst", color = { 126, 90, 225 }, count = 20 },
        banner = { seconds = 5, color = { 126, 90, 225 } },
    },

    founders_choice_reselection = {
        banner = { seconds = 7, color = { 255, 198, 55 } },
    },

    -- A Founder who already owned every public choice receives the hidden Legacy entitlement.
    -- Their first presence transition turns on the non-stacking 1.5x server hatch aura; every
    -- player receives this large gold notice in addition to the chat announcement.
    founders_legacy_active = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 255, 198, 55 }, count = 24 },
        banner = { seconds = 8, color = { 255, 198, 55 } },
    },

    -- Level-derived deploy capacity (L8, then every seven levels through L50).
    pet_slot_awarded = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 95, 235, 145 }, count = 24 },
        banner = { seconds = 8, color = { 95, 235, 145 } },
    },

    -- Token activation is a shorter confirmation: the authored future squad is the
    -- persistent world visual for the two-minute effect.
    future_call_used = {
        sound = "power_up_stronger",
        vfx = { kind = "burst", color = { 90, 190, 255 }, count = 18 },
        banner = { seconds = 4, color = { 90, 190, 255 } },
        effect_transfer = {},
    },

    -- The matching closing beat when a successful Future Call naturally reaches the end of its
    -- two-minute visit. Deliberately banner-only: the disappearing world squad is already the
    -- visual transition, and admin resets / failed activations do not fire this farewell.
    future_call_departed = {
        banner = { seconds = 4, color = { 90, 190, 255 } },
    },

    -- Trade invitations close the player picker as soon as they are sent. The asker is waiting for
    -- one of these terminal responses, so use the shared award-style floating banner instead of the
    -- compact top-screen toast (which is easy to miss beside the Roblox player bar).
    trade_request_declined = {
        banner = { seconds = 5, color = { 235, 95, 95 } },
    },

    trade_request_timed_out = {
        banner = { seconds = 5, color = { 255, 190, 75 } },
    },

    -- Team invitations use the same prominent response treatment as trade invitations. The
    -- requester may be hatching or have closed the Team picker by the time the response arrives.
    team_request_declined = {
        banner = { seconds = 5, color = { 235, 95, 95 } },
    },

    team_request_timed_out = {
        banner = { seconds = 5, color = { 255, 190, 75 } },
    },

    team_request_expired = {
        banner = { seconds = 5, color = { 255, 190, 75 } },
    },

    team_request_in_range = {
        banner = { seconds = 5, color = { 255, 190, 75 } },
    },

    achievement_completed = {
        sound = "celebratory_jingle", -- (loudness fixed at the SOURCE: sounds.lua base volume)
        vfx = { kind = "burst", color = { 255, 120, 220 } }, -- magenta
        -- the WHAT, lingering (Jason: "a floating something... that lingers for five
        -- seconds or so" — and NEVER a sound without a visual): "🏆 Egg Hatchery 10"
        banner = { seconds = 5, color = { 255, 200, 90 } },
    },

    -- A quest was claimed (server: QuestService:Claim success).
    quest_complete = {
        sound = "quest_complete_chime",
        vfx = { kind = "burst", color = { 90, 180, 255 } }, -- sky blue
    },

    -- A whole quest TRACK just unlocked (server: QuestService:_announceUnlocks when the player crosses
    -- its unlock_level). "New quests available!" — sound + a lingering banner (ctx.name carries the
    -- "🆕 New Quests: <Track>!" text). Jason: nothing passive — the level-cross is an EVENT.
    track_unlocked = {
        sound = "quest_complete_chime",
        vfx = { kind = "burst", color = { 120, 200, 255 } }, -- bright blue
        banner = { seconds = 5, color = { 120, 200, 255 } },
    },

    -- The daily streak reward was claimed (server: DailyService:Claim success).
    daily_claim = {
        sound = "daily_claim_chime",
        vfx = { kind = "burst", color = { 80, 220, 210 } }, -- teal
    },

    -- The Daily Reward zone auto-claim landed (server: DailyRewardZoneService). A
    -- LINGERING ~8s float describing the reward (text = ctx.name, e.g. "Daily Reward!
    -- +500 Earth Coins  ·  Streak 3"). Float-only on purpose — daily_claim above already
    -- fires the sound + burst, so this just adds the readable description over the player.
    daily_reward = {
        float = { color = { 90, 230, 215 }, size = 420, seconds = 8 }, -- teal, lingers ~8s
    },

    -- An escrow trade completed — fired to BOTH players (server: TradeService:_deliver).
    trade_complete = {
        sound = "trade_complete_chime",
        vfx = { kind = "burst", color = { 240, 240, 255 } }, -- white sparkle
    },

    -- Chaotic Fusion produced a new pet (server: FusionService:Fuse success).
    pet_fusion = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 185, 120, 255 } }, -- chaotic purple
    },

    -- First-ever Robux purchase bonus granted (server: MonetizationService).
    first_purchase_bonus = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 255, 160, 60 }, count = 24 }, -- big warm gold-orange
    },

    -- ===== Batch 2: combat / discovery moments =====

    -- An enemy your pets contributed to went down (server: EnemyService:_onDefeated, per
    -- contributor). FREQUENT during farming — small silent burst only; no stinger by design.
    enemy_defeated = {
        -- Corpse drama is on the enemy (Dying + combat_deaths). This is a
        -- small personal burst so the kill still pops for the contributor.
        vfx = { kind = "burst", color = { 255, 140, 80 }, count = 12 },
        world_visual = true,
    },

    -- A downed pet was revived by the Revive power (server: PowerService revive family).
    pet_revive = {
        sound = "power_up_stronger",
        vfx = { kind = "burst", color = { 140, 235, 140 }, count = 12 }, -- soft green comeback
    },

    -- First-ever discovery of a species/variant (server: PetIndexService — the Pet Index grew).
    new_species = {
        sound = "discovery_fanfare",
        vfx = { kind = "burst", color = { 255, 235, 120 }, count = 18 }, -- star gold
    },

    -- A hatch batch contained golden/rainbow/special reveals (server: EggService — fired ONCE per
    -- batch with the special count, not per pet).
    egg_hatch_rare = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 255, 120, 255 }, count = 24 }, -- big rainbow-pink
    },

    -- SECRET hatch (Jason: "keep the secret fireworks, it's fun"): a batch contained a SECRET-tier
    -- pet. Fired once per batch from EggService when secretCount > 0. Gold firework burst. Personal
    -- sound (hatching stays owner-only). Exclusive + Huge escalate above this (own events below).
    egg_hatch_secret = {
        sound = "hatch_fireworks",
        vfx = { kind = "burst", color = { 255, 215, 120 }, count = 40 }, -- gold firework burst
    },

    -- EXCLUSIVE hatch — a rung above secret (exclusive outranks secret: "meet a creator or buy an
    -- egg"). Same fun fireworks sound, a bigger cyan burst so it reads as more than a secret.
    egg_hatch_exclusive = {
        sound = "hatch_fireworks",
        vfx = { kind = "burst", color = { 120, 255, 255 }, count = 56 }, -- cyan, bigger than secret
    },

    -- HUGE hatch — the apex celebration (Jason: the first huge in the game was ~100 hrs across 4
    -- accounts; "should be celebratory like a lot"). Its OWN, louder fireworks track + the biggest,
    -- huge-pink burst so nothing else in the game looks like it. Fired once per batch when a huge is
    -- in the results. (Titanic/colossal, when pets exist, escalate above this.)
    egg_hatch_huge = {
        sound = "huge_fireworks",
        vfx = { kind = "burst", color = { 255, 90, 210 }, count = 90 }, -- huge-pink, grandest burst
    },

    -- ===== Batch 3: economy / enchant / pet-down (existing toasts stay; the bus adds the juice) =====

    -- A shop item was bought (server: EconomyService — the PurchaseSuccess toast still shows).
    purchase_success = {
        vfx = { kind = "burst", color = { 255, 215, 120 }, count = 8 }, -- small gold, no stinger
    },

    -- Items sold for coins (server: EconomyService — SellSuccess toast still shows).
    sell_success = {
        vfx = { kind = "burst", color = { 150, 230, 150 }, count = 8 }, -- small green, no stinger
    },

    -- An enchant reroll SUCCEEDED (server: EnchantService — fired at the same reveal moment as
    -- EnchantPetResult so the juice syncs with the reveal).
    enchant_success = {
        sound = "enchant_reveal_sparkle",
        vfx = { kind = "burst", color = { 200, 120, 255 }, count = 14 }, -- arcane purple
    },

    -- One of YOUR pets went down (server: EnemyService:_downPet). Somber low thud, no burst.
    pet_down = {
        sound = "pet_down_thud",
        world_visual = true, -- the pet visibly collapses — the world IS the visual
    },

    -- An enhancement pickup revealed its identity (server: DropService _collect). The float TEXT
    -- comes from the event ctx (the rolled name, e.g. "Pyro Damage"); config only styles it.
    enhancement_pickup = {
        float = { color = { 255, 235, 170 } },
        sound = "power_up_stronger",
    },

    -- All mission enemies down — the glowy AWAKENS (server: the objective
    -- monitor). The celebration beat (Jason: fanfare when it becomes active).
    objective_active = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 90, 255, 160 } }, -- beacon green
        float = { color = { 140, 255, 190 } },
    },

    -- Mission COMPLETE (server: the beacon's E-prompt). Reward TBD — this
    -- event is the hook; for now the full fireworks treatment.
    mission_complete = {
        sound = "hatch_fireworks",
        vfx = { kind = "burst", color = { 255, 230, 120 }, count = 40 },
        float = { color = { 255, 235, 150 } },
    },

    gauntlet_next_room = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 255, 180, 80 } },
        float = { color = { 255, 200, 120 } },
    },

    gauntlet_wipe = {
        float = { color = { 255, 90, 90 } },
    },

    -- Combat tutorial: player clicked the frost door before the lobby lesson.
    combat_tutorial_door_blocked = {
        banner = { seconds = 2.5, color = { 255, 200, 70 } },
    },

    -- Combat tutorial: pets left the marked healer after they had been on it.
    combat_tutorial_healer_lost = {
        banner = { seconds = 3, color = { 255, 160, 70 } },
    },

    -- Combat-training pillar rank. Ceremony (crest fly) is client-owned;
    -- this row is the sting + burst. Text = ctx.name ("Kindled achieved.").
    combat_rank_achieved = {
        sound = { key = "celebratory_jingle", volume = 0.5 },
        vfx = { kind = "burst", color = { 255, 210, 100 }, count = 18 },
    },

    -- Combat tutorial finished the last room. Text = ctx.name.
    combat_tutorial_complete = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 255, 215, 90 }, count = 24 },
        banner = { seconds = 4, color = { 255, 215, 90 } },
    },

    -- An EXCLUSIVE boss egg was picked up (server: DropService _collect,
    -- kind "egg_item"). Jason: "it's a big deal" — full fireworks, gold
    -- burst, the float carries "<Egg> acquired!" from ctx.
    exclusive_egg_pickup = {
        sound = "hatch_fireworks",
        vfx = { kind = "burst", color = { 255, 215, 120 }, count = 40 },
        float = { color = { 255, 220, 120 } },
    },

    -- The boss DROPPED the egg (server: EnemyService death hook). A loud
    -- announce so the drop moment lands even mid-fight chaos.
    exclusive_egg_drop = {
        sound = "celebratory_jingle",
        float = { color = { 255, 220, 120 } },
    },

    -- A potion drop was picked up (server: DropService _collect). Float TEXT = the potion's name
    -- from ctx; config only styles it. Mirrors enhancement_pickup.
    -- The squad was RALLIED (EnemyService tactical). Tutorial's rally step
    -- completes on this; styling config-only.
    rally_used = {
        float = { color = { 120, 200, 255 } },
    },

    -- A potion was DRUNK (server: PotionService.Drink). Tutorial's battle_brew
    -- completes on this; styling is config-only like every bus event.
    potion_used = {
        float = { color = { 255, 90, 60 }, size = 200 },
        vfx = { kind = "burst", color = { 255, 90, 50 }, count = 18 },
        effect_transfer = {},
        sound = "power_up_stronger",
    },

    -- Structured inventory consumables (paid boosts and future config-authored tokens) use the
    -- same center-bloom -> destination animation as potions. Context selects player/pets/enemy.
    consumable_used = {
        effect_transfer = {},
        sound = "power_up_stronger",
    },

    health_potion_used = {
        effect_transfer = {},
        sound = "power_up_stronger",
    },

    potion_pickup = {
        float = { color = { 190, 130, 240 } },
        sound = "power_up_stronger",
    },

    -- A mined crystal paid out (server: BreakableSpawner, per contributor, at the NODE's
    -- position — #172). FREQUENT during farming: small silent gold float, no sound.
    coin_payout = {
        float = { color = { 255, 215, 90 }, size = 160 },
    },

    -- The tutorial's final step completed (server: TutorialService). Big moment — the
    -- handoff card ("QUESTS UNLOCKED") shows at the same time (TutorialController).
    tutorial_complete = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 255, 215, 90 }, count = 24 }, -- big gold
    },

    -- The Range is a solo archetype test. A teamed player is refused at the door
    -- and again on ChallengeRun_Start so a party cannot share the ranked instance.
    -- Door / StartChallengeRun refused. The prompt still fires, so without a
    -- float it looks like E did nothing (the Colorado Plays trial miss).
    mission_enter_blocked = {
        sound = "flub",
        vfx = { kind = "burst", color = { 200, 70, 70 }, count = 6 },
        failure_float = {
            seconds = 2.8,
            color = { 255, 220, 105 },
            size = 460,
            height = 60,
            default = "You can't enter that right now.",
            messages = {
                team_busy = "Your team is already in a trial. Leave the team or wait for them.",
                server_full = "Too many trials on this server — try again shortly.",
                no_slot = "No free trial slot — try again shortly.",
            },
        },
    },

    range_solo_required = {
        sound = "flub",
        vfx = { kind = "burst", color = { 200, 70, 70 }, count = 6 },
        failure_float = {
            seconds = 2.8,
            color = { 255, 220, 105 },
            size = 460,
            height = 60,
            default = "Leave your team to enter The Range.",
            messages = {
                teamed = "Leave your team to enter The Range.",
            },
        },
    },

    -- SOURCES WIRED, NO DEFAULT REACTIONS (add a row to react — the fire is already in place):
    --   egg_hatch     — every successful hatch batch {count} (the reveal pop is animation-synced
    --                   choreography in EggHatchingService and stays there)
    --   economy_error — purchase/sell failures {message} (the error notice already informs;
    --                   add an error blip here if/when one is uploaded)
    --   level_claimed — a level was CLAIMED, server truth {level} (client level_up owns the juice;
    --                   this one exists for server consumers — the tutorial taps it)
    --   tutorial_level_awarded — tutorial completion guarantee processed {level, xpAdded}; raw
    --                            analytics only, including a zero top-up if already earned
    --   power_selected — a power pick committed {power, level} (PowerService:Select)
    --   power_cast    — a power cast succeeded {power} (PowerService:Cast; frequent — keep silent)
    --   power_bound   — a POWER was bound to a hotbar slot {power, slot} (HotbarService:Rebind; the
    --                   tutorial taps it for the "set your power" step, and a bind sound can hook here)
    --   pet_equipped  — a pet equip TOGGLED {action} (InventoryService; tutorial equip step)
    --   new_enhancement — first-ever discovery of an enhancement identity {key,name}
    --                     (EnhancementService Grant; the Enhancement Index grew)
}
