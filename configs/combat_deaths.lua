--[[
    combat_deaths — dramatic enemy kill candy (config-as-code).

    EnemyService stamps Dying + DeathStyle; the client plays the pose.
    Sounds are stand-ins until dedicated clips upload. Each style has an
    ElevenLabs-style prompt for the replacement SFX.
]]

return {
    hold_seconds = 0.95,
    styles = {
        {
            id = "flop",
            weight = 28,
            boss_weight = 8,
            seconds = 0.75,
            sound = "death_flop",
            color = { 235, 90, 90 },
            prompt = "Short cartoon body-fall: a meaty slap on dirt, then a little "
                .. "armor rattle. No scream. 0.6s, mono, punchy, not cartoony-boing.",
        },
        {
            id = "pop",
            weight = 22,
            boss_weight = 6,
            seconds = 0.7,
            sound = "death_pop",
            color = { 255, 170, 70 },
            prompt = "Satisfying creature pop: compressed whoosh then a crisp burst "
                .. "of specks. Fantasy minion, not a balloon. 0.5s, bright, no voice.",
        },
        {
            id = "shatter",
            weight = 16,
            boss_weight = 22,
            seconds = 0.85,
            sound = "death_shatter",
            color = { 180, 230, 255 },
            prompt = "Crystal-armor shatter: glass crack that blooms into a dozen "
                .. "tinkling shards. Heroic, not horror. 0.8s, bright high end.",
        },
        {
            id = "whirl",
            weight = 14,
            boss_weight = 14,
            seconds = 0.95,
            sound = "death_whirl",
            color = { 200, 140, 255 },
            prompt = "Spinning knockout: rising whoosh that corkscrews, then a soft "
                .. "thump as they vanish. Playful, 0.8s, no cartoon zip.",
        },
        {
            id = "sink",
            weight = 12,
            boss_weight = 10,
            seconds = 0.9,
            sound = "death_sink",
            color = { 90, 70, 80 },
            prompt = "Body sinking into earth: low grit rumble, dirt swallow, muted "
                .. "last clink. Dark but clean. 0.8s, bass-heavy, no scream.",
        },
        {
            id = "launch",
            weight = 8,
            boss_weight = 24,
            seconds = 1.05,
            sound = "death_launch",
            color = { 255, 210, 90 },
            prompt = "Dramatic send-off: heavy upward impact, short air whistle, "
                .. "distant pop. Boss-worthy, 1.0s, cinematic, no vocal yell.",
        },
        {
            id = "robux",
            weight = 12,
            boss_weight = 10,
            seconds = 1.15,
            sound = "death_robux",
            color = { 245, 205, 55 },
            cubes = {
                count = 16,
                size = 0.36,
                stagger = 0.055,
                lifetime = 2.15,
                scatter = 6.8,
                peak = 2.1,
                image = "rbxasset://textures/ui/common/robux.png",
            },
            prompt = "Tiny gold coins popping out one by one: soft metallic clinks "
                .. "in a rising scatter, then they settle. Playful loot burst, "
                .. "1.2s, no voice, not a slot-machine jackpot.",
        },
    },
}
