--[[
    combat_ranks — Halo-flavored titles earned on combat-training pillars.

    One rank per finished fight loop, granted on the pillar step (advance_*),
    never on a lobby sip. Current rank only — not a public leaderboard, not
    stacked GrantTitle strings. Ceremony plays on first earn; redo is silent.

    Crest icons are keyed PNGs in assets/exports/combat_ranks and uploaded
    group-owned. `icon` is the resolved Image id (not the Decal). Mesh stays
    empty; the ceremony flies the 2D crest.
]]

return {
    version = 1,
    ceremony = {
        hold_seconds = 0.7,
        fly_seconds = 0.85,
        world_pop_seconds = 0.75,
        chip_width = 160,
        chip_height = 36,
        -- Fallback only: the live chip docks to PlayerBar.Emblem.
        -- Kept so ceremony land has a top inset if the bar is not up yet.
        chip_top = 14,
        icon_text_gap = 8,
        nametag_studs = 2.55,
        nametag_max_distance = 80,
    },
    -- Hover source for every cave title (Spark → Skilled). This is Combat
    -- Training 1; a later course would get its own source string.
    hover_source = "Combat Training 1",
    -- Commission targets. Empty ids use the procedural placeholder.
    art = {
        icon_size_px = 256,
        icon_format = "png_transparent_circle",
        mesh_studs = 2.4,
        sting_seconds = 0.8,
    },
    ranks = {
        {
            id = "spark",
            label = "Spark",
            grant_step = "advance_stage",
            color = { 255, 196, 92 },
            glyph = "✦",
            icon = "rbxassetid://112297371350788",
            inspect = "Acquired in Combat Training after your first fight.",
            prompt = "Circular combat crest, front view, centered. A single warm-gold "
                .. "ember spark inside a thin halo ring. Halo-bright, sacred, not a "
                .. "military star or sheriff badge. One simple symbol, high contrast, "
                .. "readable as a tiny player-list icon. No text, no letters.\n"
                .. "Low poly, game ready, on a plain (magenta, blue, green) screen "
                .. "background with no shadows.",
        },
        {
            id = "kindled",
            label = "Kindled",
            grant_step = "advance_brew",
            color = { 255, 132, 48 },
            glyph = "✶",
            icon = "rbxassetid://119300402391304",
            inspect = "Acquired in Combat Training after Berserk Brew.",
            prompt = "Circular combat crest, front view, centered. A small contained "
                .. "orange flame sitting in a gold ring, like a hearth or brew-fire. "
                .. "Warm, held, not a wild campfire cartoon. One simple symbol, high "
                .. "contrast, readable as a tiny player-list icon. No text, no letters.\n"
                .. "Low poly, game ready, on a plain (magenta, blue, green) screen "
                .. "background with no shadows.",
        },
        {
            id = "warden",
            label = "Warden",
            grant_step = "advance_heal",
            color = { 92, 214, 160 },
            glyph = "✚",
            icon = "rbxassetid://102820129566164",
            inspect = "Acquired in Combat Training after you learned Heal.",
            prompt = "Circular combat crest, front view, centered. A soft green heal-cross "
                .. "inside a protective halo. Calm, warding, sacred. Not a red medical "
                .. "plus, not a hospital logo. One simple symbol, high contrast, readable "
                .. "as a tiny player-list icon. No text, no letters.\n"
                .. "Low poly, game ready, on a plain (magenta, blue, green) screen "
                .. "background with no shadows.",
        },
        {
            id = "hexed",
            label = "Hexed",
            grant_step = "advance_weaken",
            color = { 188, 112, 255 },
            glyph = "⬡",
            icon = "rbxassetid://117358589145840",
            inspect = "Acquired in Combat Training after Weakening Vial.",
            prompt = "Circular combat crest, front view, centered. A violet hex-rune or "
                .. "cracked sigil in a ring. Witchy weaken magic, angular and occult. "
                .. "Not a poison skull, not a toxic barrel. One simple symbol, high "
                .. "contrast, readable as a tiny player-list icon. No text, no letters.\n"
                .. "Low poly, game ready, on a plain (magenta, blue, green) screen "
                .. "background with no shadows.",
        },
        {
            id = "surge",
            label = "Surge",
            grant_step = "advance_stack",
            color = { 80, 210, 255 },
            glyph = "⚡",
            icon = "rbxassetid://76797304884917",
            inspect = "Acquired in Combat Training after stacking Berserk Brew.",
            prompt = "Circular combat crest, front view, centered. A cyan lightning bolt "
                .. "bursting through a ring. Stacked electric power, sharp and bright. "
                .. "Not a battery, not a power-plug icon. One simple symbol, high "
                .. "contrast, readable as a tiny player-list icon. No text, no letters.\n"
                .. "Low poly, game ready, on a plain (magenta, blue, green) screen "
                .. "background with no shadows.",
        },
        {
            id = "bulwark",
            label = "Bulwark",
            grant_step = "advance_tank",
            color = { 255, 186, 74 },
            glyph = "⛨",
            icon = "rbxassetid://91663146631343",
            inspect = "Acquired in Combat Training after you brought a tank.",
            prompt = "Circular combat crest, front view, centered. A thick gold "
                .. "fortress-shield, grounded and heavy, inside a ring. Tank, wall, "
                .. "keep. Not a police badge, not a cop shield. One simple symbol, high "
                .. "contrast, readable as a tiny player-list icon. No text, no letters.\n"
                .. "Low poly, game ready, on a plain (magenta, blue, green) screen "
                .. "background with no shadows.",
        },
        {
            id = "hunter",
            label = "Hunter",
            grant_step = "advance_healer",
            color = { 255, 92, 92 },
            glyph = "◎",
            icon = "rbxassetid://130516613680536",
            inspect = "Acquired in Combat Training after you cut down the healer.",
            prompt = "Circular combat crest, front view, centered. A crimson hunter's eye "
                .. "or bow-sight inside a ring. Focus-fire, sharp, predatory. Not a "
                .. "deer-hunting logo, not a rifle scope brand. One simple symbol, high "
                .. "contrast, readable as a tiny player-list icon. No text, no letters.\n"
                .. "Low poly, game ready, on a plain (magenta, blue, green) screen "
                .. "background with no shadows.",
        },
        {
            id = "skilled",
            label = "Skilled",
            grant_step = "advance_together",
            color = { 255, 220, 110 },
            glyph = "☼",
            icon = "rbxassetid://114240874759864",
            inspect = "Acquired by finishing Combat Training.",
            prompt = "Circular combat crest, front view, centered. A bright graduation "
                .. "halo or laurel sun, gold and complete. The closer title. Sacred, "
                .. "short, triumphant. Not a wordmark, no letters, no ribbon text. One "
                .. "simple symbol, high contrast, readable as a tiny player-list icon.\n"
                .. "Low poly, game ready, on a plain (magenta, blue, green) screen "
                .. "background with no shadows.",
        },
    },
}
