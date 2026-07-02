-- Centralized sound catalog
-- Sounds are preloaded into ReplicatedStorage.Assets.Sounds by AssetPreloadService

return {
    -- Named sounds
    egg_hatch_pop = {
        -- betterpop.wav (Jason's improved egg-open pop), group-uploaded via scripts/upload_audio.js.
        id = "rbxassetid://114572398311789",
        volume = 0.8,
        playback_speed = 1.0,
    },

    egg_roll_snare = {
        -- BetterSnare.wav (Jason's improved egg-rattle snare roll), group-uploaded.
        id = "rbxassetid://112745556256821",
        volume = 0.78, -- 0.6 +30% (Jason: louder egg-hatch snare)
        playback_speed = 1.0,
    },

    enchant_thunder = {
        id = "rbxassetid://71266985896124",
        volume = 0.9,
        playback_speed = 0.85,
    },

    -- Slotting an enhancement into a power slot — ELECZap "Anime-style lightning" (ElevenLabs),
    -- group-uploaded via scripts/upload_audio.js. Wired to the enhancement_slotted event.
    enhancement_slot_zap = {
        id = "rbxassetid://112202092041303",
        volume = 0.3, -- ElevenLabs zaps run hot; lowered (Jason). Tune here.
        playback_speed = 1.0,
        bus = "effects", -- rides the SFX slider (the "ui" bus is a binary on/off that ignores it)
    },

    -- Add more named sounds here as needed

    -- Short celebratory stinger (non-looping) — level-up / ascend. Uploaded via scripts/upload_audio.js.
    celebratory_jingle = {
        id = "rbxassetid://118066342271463",
        volume = 0.18, -- halved twice (Jason: 0.7 -> 0.35 "still too loud" -> 0.18) — this
        -- field IS the per-sound base level; events can still scale it per-use
        -- via sound = { key, volume } in configs/game_events.lua
        playback_speed = 1.0,
        bus = "effects", -- was "ui": the UI bus is a binary toggle, so level-up/area-
        -- unlock/achievement jingles IGNORED the SFX slider (Jason: "really loud...
        -- not on the sound bus"). effects = rides the slider like everything else.
    },

    -- LEVEL-UP theme ("An Epic Modern-day Video Game", instrumental) — the full 7.5s level-up
    -- fanfare. `duration_seconds` is the SSOT for the song length so the level-up ANIMATION can
    -- time itself to the track (LevelUpController reads it). Uploaded via scripts/upload_audio.js
    -- (assets/audio/sfx/level_up_epic.mp3 -> id below). New uploads moderate before they play.
    level_up_epic = {
        id = "rbxassetid://71208785111265",
        volume = 0.5, -- starting point; tune like the jingle if it's hot
        playback_speed = 1.0,
        duration_seconds = 7.5, -- track length; the level-up animation runs to this
        bus = "effects", -- rides the SFX slider (same reasoning as celebratory_jingle above)
    },

    -- Ice CONTROL: giant crystals forming / cracking as the world freezes (Jason) — played
    -- positionally at an enemy the instant a HOLD lands on it (EnemyService:_auraHold). The same
    -- track also skins ice shields (power_fx sounds.shield.ice). Server-created -> everyone hears it.
    freeze_hold = {
        id = "rbxassetid://93258219658109",
        volume = 0.5,
        playback_speed = 1.0,
        bus = "effects",
    },

    -- DAZE (parked): action-lock CC sound, sibling of the hold/freeze (AggroLeash header). The daze
    -- power/effect isn't built yet — when it lands, play this positionally on the dazed target the
    -- same way _auraHold plays freeze_hold. Uploaded + ready.
    daze_hit = {
        id = "rbxassetid://94200687927271",
        volume = 0.5,
        playback_speed = 1.0,
        bus = "effects",
    },

    -- PARKED (Jason: "very good whoosh with loud impact, not sure where to use this"). Uploaded +
    -- recorded; pick a slot later — best fits a heavy AoE/slam power impact or a big cast.
    boom_swoosh = {
        id = "rbxassetid://88708868978364",
        volume = 0.5,
        playback_speed = 1.0,
        bus = "effects",
    },

    -- Fireworks for a SECRET / EXCLUSIVE hatch (Jason: "keep it, it's fun"). Personal (hatching
    -- stays owner-only). NOTE: ~15s track; trim if it feels long.
    hatch_fireworks = {
        id = "rbxassetid://135447759304480",
        volume = 0.5,
        playback_speed = 1.0,
        bus = "effects",
    },

    -- POWER DOWN — the CoH "detoggle": you ran out of endurance (focus) so your always-on toggles
    -- drop. Played on the toggle_crash game event (PowerService:_detoggleAll). Group-owned upload.
    power_down = {
        id = "rbxassetid://95513836690825",
        volume = 0.8,
        playback_speed = 1.0,
        bus = "effects",
    },

    -- FLUB — the generic "that cast just didn't work" buzzer. NOT a cast cue: it plays ONLY when a
    -- power genuinely can't fire (e.g. Taunt with no tank deployed and no pet selected). Reusable
    -- anywhere a cast is impossible. Source file was quiet, so volume is cranked. Group-owned upload.
    flub = {
        id = "rbxassetid://118307585251245",
        volume = 3.0,
        playback_speed = 1.0,
        bus = "effects",
    },

    -- HUGE hatch — the showstopper (Jason: first huge in the game was ~100 hrs across 4 accounts,
    -- "should be celebratory like a lot"). Its OWN, bigger fireworks track; louder than the secret
    -- fireworks so a huge is unmistakably rarer. Group-owned upload (scripts/audio_ids.json).
    -- New audio → moderation; plays once approved.
    huge_fireworks = {
        id = "rbxassetid://139307085793979",
        volume = 0.7,
        playback_speed = 1.0,
        bus = "effects",
    },

    -- PARKED (Jason): "A Large Fire Igniting With A Whoosh" — was the fire crit, but the whoosh
    -- "didn't fit" a hard crit; boom_swoosh took that slot. Freed for a LESS impactful, sustained
    -- moment — Jason: "might be better for like a root or hold or something." Best next slot: the
    -- ROOT family (PowerService RootedUntil) — play it positionally on the rooted target the way
    -- _auraHold plays freeze_hold. Uploaded + ready; not yet wired (confirm root vs hold first).
    root_whoosh = {
        id = "rbxassetid://125336332308951",
        volume = 0.5,
        playback_speed = 1.0,
        bus = "effects",
    },

    -- COIN GAIN (Jason): "throwing coins" — played on the client whenever a HUD currency counter
    -- ticks UP (BaseUI currency-update path). Personal UI sound on the effects bus. Debounced by
    -- coin_collect_min_gap so a farming burst doesn't machine-gun the clip.
    coin_collect = {
        id = "rbxassetid://133263123825856",
        volume = 0.5,
        playback_speed = 1.0,
        bus = "effects",
    },
    coin_collect_min_gap = 0.12, -- min seconds between coin-gain sounds (anti-spam during farming)

    -- Rising "power up" sting (uploaded SFX) — pet revive and similar comeback moments.
    power_up_stronger = {
        id = "rbxassetid://105379088796995",
        volume = 0.6,
        playback_speed = 1.0,
        bus = "effects",
    },

    -- Sparkly cartoon spell cast (uploaded SFX) — enchant success reveal.
    cartoony_spell_cast = {
        id = "rbxassetid://140394538590179",
        volume = 0.6,
        playback_speed = 1.0,
        bus = "effects",
    },

    -- Low heavy thud (uploaded SFX) — a pet going DOWN (somber, quiet).
    deep_earthen_impact = {
        id = "rbxassetid://90412394528626",
        volume = 0.35,
        playback_speed = 0.9,
        bus = "effects",
    },

    -- LOOPING AREA MUSIC. AreaMusicController plays the track for the player's CURRENT area, looped,
    -- on the "music" SoundGroup bus (so the Music volume slider controls it), crossfading on area
    -- change. New uploads play once Roblox moderation approves them.
    music = {
        awe = { id = "rbxassetid://137816344186500", volume = 0.45 }, -- LoopingAweMusic (now Desert)
        spa = { id = "rbxassetid://102792461632018", volume = 0.45 }, -- gentle spa loop (Spawn/Grass, Jason)
        viking_drum = { id = "rbxassetid://92543861599965", volume = 0.45 }, -- VikingDrumLooping
        epic_drum = { id = "rbxassetid://131000740431597", volume = 0.45 }, -- DrumEpicLooping
        arctic_hunt = { id = "rbxassetid://99187284116833", volume = 0.45 }, -- Arctic Hunt (Ice, Jason)
        desert_hunt = { id = "rbxassetid://103598343626981", volume = 0.45 }, -- Desert Hunt (Desert, Jason)
        -- COMBAT loops (~30s drum instrumentals, Jason). Chosen at RANDOM from combat_music below
        -- whenever the player is InCombat; same looping "music" bus as the area tracks.
        combat_1 = { id = "rbxassetid://94019382405359", volume = 0.5 },
        combat_2 = { id = "rbxassetid://80895188313881", volume = 0.5 },
        combat_3 = { id = "rbxassetid://84419590288422", volume = 0.5 },
    },

    -- COMBAT MUSIC: while the local player is InCombat (server-set Player attribute), AreaMusicController
    -- crossfades from the area track to a RANDOM key in this list; when combat ends it crossfades back
    -- to the area track after combat_music_exit_delay seconds (the delay rides out brief aggro flicker so
    -- the music doesn't restart). Grow this array freely — selection is uniform-random over its length.
    combat_music = { "combat_1", "combat_2", "combat_3" },
    combat_music_exit_delay = 3.0,

    -- SAFETY NET: if an area track's ASSET fails to load (still moderating at publish time, or taken
    -- down by Roblox after approval), AreaMusicController swaps to this track so the area is never
    -- silent. Must be a long-stable, guaranteed-approved key in `music` (awe = the original hub theme,
    -- now otherwise unassigned). `default` above only covers UNKNOWN AREAS; this covers DEAD ASSETS.
    music_fallback = "awe",

    -- Which looping track plays in each AREA (edit freely — falls back to `default`). Only 3 tracks
    -- so far, so some areas share; add more tracks + remap for fully distinct per-area music.
    area_music = {
        default = "awe",
        Spawn = "spa", -- calm hub (gentle spa loop)
        Grass = "spa", -- gentle starter biome (gentle spa loop)
        Desert = "desert_hunt", -- Desert Hunt (Jason: better than the old track)
        Ice = "arctic_hunt", -- harsh cold (Arctic Hunt)
        Lava = "epic_drum", -- intense endgame
    },
}
