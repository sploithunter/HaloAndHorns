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
    },

    -- level_up (client-fired) keeps the VISUAL juice; the SOUND moved to the
    -- server-fired level_claimed row as a world_sound, so EVERYONE nearby hears a
    -- level-up, not just the leveler (Jason: "it should be server-wide... everybody
    -- should hear those sounds").
    level_up = {
        vfx = { kind = "burst", color = { 255, 205, 70 } }, -- gold celebratory burst at the player
    },

    -- LEVEL EARNED: the bar just filled and the arrow starts blinking (server truth,
    -- once per earned level). THIS is the public moment — the epic level-up animation
    -- + sound land here (Jason). The 7.5s "An Epic Modern-day Video Game" theme; plays AT
    -- the player's character, audible nearby (3D falloff, ~120 studs). The level-up ANIMATION
    -- times itself to sounds.lua level_up_epic.duration_seconds.
    level_earned = {
        world_sound = "level_up_epic",
        -- the local world fanfare around the leveler (sparkles + glow), timed to the song's length
        -- (sounds.lua level_up_epic.duration_seconds). Non-interrupting; everyone nearby hears the
        -- world_sound, the leveler sees the effect centred on their character.
        fanfare = { sound = "level_up_epic" },
    },

    -- A new area/gate was unlocked (client: init.client ZoneUnlockResult ok). Celebratory, and no
    -- prior fanfare, so no conflict with existing reactions.
    area_unlocked = {
        sound = "celebratory_jingle",
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
        world_sound = "celebratory_jingle", -- audible around the meeting, not just to the met player
        vfx = { kind = "burst", color = { 255, 215, 0 } }, -- creator gold
        banner = { seconds = 10, color = { 255, 215, 0 } },
        -- Jason: "it wasn't very obvious that the creator's on this server" — a big
        -- gold crown float over the player on top of the banner
        float = { color = { 255, 215, 0 }, prefix = "👑 ", size = 200 },
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
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 90, 180, 255 } }, -- sky blue
    },

    -- A whole quest TRACK just unlocked (server: QuestService:_announceUnlocks when the player crosses
    -- its unlock_level). "New quests available!" — sound + a lingering banner (ctx.name carries the
    -- "🆕 New Quests: <Track>!" text). Jason: nothing passive — the level-cross is an EVENT.
    track_unlocked = {
        sound = "celebratory_jingle",
        vfx = { kind = "burst", color = { 120, 200, 255 } }, -- bright blue
        banner = { seconds = 5, color = { 120, 200, 255 } },
    },

    -- The daily streak reward was claimed (server: DailyService:Claim success).
    daily_claim = {
        sound = "celebratory_jingle",
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
        sound = "celebratory_jingle",
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
        vfx = { kind = "burst", color = { 235, 90, 90 }, count = 6 },
    },

    -- A downed pet was revived by the Revive power (server: PowerService revive family).
    pet_revive = {
        sound = "power_up_stronger",
        vfx = { kind = "burst", color = { 140, 235, 140 }, count = 12 }, -- soft green comeback
    },

    -- First-ever discovery of a species/variant (server: PetIndexService — the Pet Index grew).
    new_species = {
        sound = "celebratory_jingle",
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
        sound = "cartoony_spell_cast",
        vfx = { kind = "burst", color = { 200, 120, 255 }, count = 14 }, -- arcane purple
    },

    -- One of YOUR pets went down (server: EnemyService:_downPet). Somber low thud, no burst.
    pet_down = {
        sound = "deep_earthen_impact",
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
    -- A potion was DRUNK (server: PotionService.Drink). Tutorial's battle_brew
    -- completes on this; styling is config-only like every bus event.
    potion_used = {
        float = { color = { 190, 130, 240 } },
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

    -- SOURCES WIRED, NO DEFAULT REACTIONS (add a row to react — the fire is already in place):
    --   egg_hatch     — every successful hatch batch {count} (the reveal pop is animation-synced
    --                   choreography in EggHatchingService and stays there)
    --   economy_error — purchase/sell failures {message} (the error notice already informs;
    --                   add an error blip here if/when one is uploaded)
    --   level_claimed — a level was CLAIMED, server truth {level} (client level_up owns the juice;
    --                   this one exists for server consumers — the tutorial taps it)
    --   power_selected — a power pick committed {power} (PowerService:Select)
    --   power_cast    — a power cast succeeded {power} (PowerService:Cast; frequent — keep silent)
    --   power_bound   — a POWER was bound to a hotbar slot {power, slot} (HotbarService:Rebind; the
    --                   tutorial taps it for the "set your power" step, and a bind sound can hook here)
    --   pet_equipped  — a pet equip TOGGLED {action} (InventoryService; tutorial equip step)
    --   new_enhancement — first-ever discovery of an enhancement identity {key,name}
    --                     (EnhancementService Grant; the Enhancement Index grew)
}
