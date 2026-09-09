-- Spoken copy and routing for the optional Crossroads introduction.
return {
    enabled = true,
    progress = {
        ready_attribute = "CrossroadsIntroReady",
        attributes = {
            welcome = "CrossroadsWelcomeSeen",
            hell_handoff = "CrossroadsExchangeSeen",
            heaven_return = "CrossroadsReturnSeen",
            farm_visited = "CrossroadsFarmVisited",
            siege_visited = "CrossroadsSiegeVisited",
        },
    },
    dialogue_timeout_seconds = 150,
    caption_min_seconds = 3,
    caption_characters_per_second = 18,
    caption_max_seconds = 18,
    group_name = "CrossroadsVoice",
    welcome = { "crossroads.welcome", "crossroads.explore" },
    hell_handoff = {
        "crossroads.handoff.angel",
        "crossroads.handoff.demon",
        "crossroads.handoff.reply",
        "crossroads.hell",
    },
    heaven_return = { "crossroads.heaven" },
    ui = {
        title = "CROSSROADS",
        explore = "Explore freely • Choose a gate when ready",
        position = { 0.5, 0.72 },
        size = { 0.62, 0.16 },
        background = { 24, 20, 38 },
        text = { 255, 250, 237 },
        angel = { 255, 219, 131 },
        demon = { 255, 140, 108 },
        corner_scale = 0.12,
        display_order = 65,
        speaker_position = { 0.04, 0.06 },
        speaker_size = { 0.92, 0.17 },
        line_position = { 0.04, 0.27 },
        line_size = { 0.92, 0.48 },
        footer_position = { 0.04, 0.8 },
        footer_size = { 0.92, 0.13 },
    },
    playbackVolumeSource = {
        config = "merge_egg_prototype",
        angel = { "watcher", "voice", "volume" },
        demon = { "watcher", "themes", "hell", "voice", "volume" },
    },
    sections = {
        {
            speaker = "angel",
            lines = {
                {
                    id = "CR_A01",
                    cue = "crossroads.welcome",
                    text = "Welcome to Crossroads, little light. Through my gate lies Farm and Fight: a place to farm, hatch eggs, and raise a happy team of pets. They love helping you gather treasure. There are battles too, whenever you feel ready for adventure.",
                },
                {
                    id = "CR_A02",
                    cue = "crossroads.explore",
                    text = "Choose either gate when you are ready, and we will show you how to play. There is no hurry. You can fish, visit the coin garden, hatch a pet, or explore Crossroads first.",
                },
                {
                    id = "CR_A03",
                    cue = "crossroads.handoff.angel",
                    text = "Heading toward the hell side? I believe that is your cue.",
                },
                {
                    id = "CR_A04",
                    cue = "crossroads.handoff.reply",
                    text = "Show them around. And do try to keep the dramatic threats to a minimum.",
                },
                {
                    id = "CR_A05",
                    cue = "crossroads.heaven",
                    text = "Back on the brighter side, little light? I am here if you need me. Choose a gate for your next adventure, or keep exploring. The choice is yours.",
                },
            },
        },
        {
            speaker = "demon",
            lines = {
                {
                    id = "CR_D01",
                    cue = "crossroads.handoff.demon",
                    text = "Finally! A traveler with excellent taste. I will take it from here.",
                },
                {
                    id = "CR_D02",
                    cue = "crossroads.hell",
                    text = "Welcome to my side of Crossroads. My gate leads to Pet Siege. Enemy waves, eggs to defend, and your tactical brilliance on public display. Hatch defenders, build your defenses, and try to keep something alive. I do adore an optimist.",
                },
            },
        },
    },
}
