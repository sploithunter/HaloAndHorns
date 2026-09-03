--[[
    people_list — our People list (replaces Roblox CoreGui PlayerList).

    Same three glance columns as before (Rank / Status / Location). Name
    carries one role badge (first match). Clicking a row opens a slide-out
    with headshot, how the Status title is earned, and Examine Avatar
    (live in-game character, not Roblox inspect). Friend / Block stay on
    that card. Report stays on Esc → Report.
]]

return {
    version = 1,
    enabled = true,
    disable_core_player_list = true,

    -- Every visible list dimension is a share of the live viewport. Do not replace these with
    -- offsets: the People list must retain the same proportions on phones, tablets, and desktop.
    layout = {
        modes = {
            desktop = {
                width = 0.221,
                header_height = 0.0276,
                row_height = 0.0253,
                max_body_height = 0.276,
                top = 0.069,
                merge_top = 0.113,
                tutorial_top = 0.168,
                right = 0.0022,
                card_width = 0.127,
                card_gap = 0.0045,
                card_headshot_height = 0.0644,
                card_viewport_height = 0.207,
            },
            tablet = {
                width = 0.30,
                header_height = 0.04,
                row_height = 0.037,
                max_body_height = 0.40,
                top = 0.07,
                merge_top = 0.115,
                tutorial_top = 0.17,
                right = 0.004,
                card_width = 0.22,
                card_gap = 0.008,
                card_headshot_height = 0.093,
                card_viewport_height = 0.30,
            },
            phone = {
                width = 0.36,
                header_height = 0.0665,
                row_height = 0.061,
                max_body_height = 0.465,
                top = 0.08,
                merge_top = 0.13,
                tutorial_top = 0.17,
                right = 0.006,
                card_width = 0.28,
                card_gap = 0.01,
                card_headshot_height = 0.155,
                card_viewport_height = 0.45,
            },
            ten_foot = {
                width = 0.221,
                header_height = 0.0276,
                row_height = 0.0253,
                max_body_height = 0.276,
                top = 0.069,
                merge_top = 0.113,
                tutorial_top = 0.168,
                right = 0.0022,
                card_width = 0.127,
                card_gap = 0.0045,
                card_headshot_height = 0.0644,
                card_viewport_height = 0.207,
            },
        },
        -- When the live Merge wave meter exists, dock beneath its rendered bottom with a
        -- viewport-relative breathing gap and inherit its rendered chrome scale. This keeps the
        -- phone list from becoming wider/taller than the scaled wave card above it.
        merge_wave_gap = 0.006,
        merge_wave_width_ratio = 1.0,
        merge_wave_header_height_ratio = 0.32,
        merge_wave_row_height_ratio = 0.30,
        -- Farm & Fight's tutorial and quest surfaces are the live leader for this vertical stack.
        -- Zero is intentional: their lower border and the People list's upper border tile directly.
        farm_upper_surface_gap = 0,
        column_header_to_header = 0.67,
        column_gutter = 0.012,
    },

    toggle = {
        key = "Tab",
        start_expanded = true,
    },

    card = {
        examine_label = "Examine Avatar",
        badge_heading = "How you get this",
        -- List row still shows one mark. The card lists every role.
        roles_heading = "Roles",
    },

    look = {
        background = { 12, 14, 20 },
        background_transparency = 0.42,
        header_transparency = 0.32,
        stroke = { 220, 224, 236 },
        stroke_transparency = 0.55,
        text = { 245, 248, 255 },
        muted = { 170, 176, 188 },
        row_hover_transparency = 0.72,
    },

    columns = {
        { id = "name", label = "Name", width = 0.43 },
        { id = "rank", label = "Rank", width = 0.14 },
        { id = "status", label = "Status", width = 0.23 },
        { id = "location", label = "Location", width = 0.20 },
    },

    -- One mark left of the name. First match wins. Founder's Legacy
    -- grants every game pass (including VIP) plus the founder benefit,
    -- so the star sits above the crown and replaces it.
    one_badge = true,
    prefixes = {
        -- Place owner / game creator. Same Creator Colorado disc as the
        -- apex pet (flag C + blaster), no PetBadge ring around it.
        {
            id = "owner",
            hover = "Owner",
            label = "Owner",
            attribute = "IsOwner",
            icon = { element = "creator", symbol = "arrow_right" },
        },
        {
            id = "developer",
            hover = "Dev",
            label = "Developer",
            glyph = "🔧",
            attribute = "IsAdmin",
        },
        {
            id = "content_creator",
            hover = "Creator",
            label = "Creator",
            glyph = "🎬",
            attribute = "IsCreator",
        },
        {
            id = "tester",
            hover = "Tester",
            label = "Tester",
            glyph = "β",
            attribute = "IsBetaTester",
        },
        {
            id = "founder",
            hover = "Founder",
            label = "Founder",
            glyph = "⭐",
            attribute = "FounderLegacyActive",
        },
        { id = "vip", hover = "VIP", label = "VIP", glyph = "👑", attribute = "HasVIPPass" },
    },

    roles = {
        owner_user_ids = {
            3200870803, -- coloradoplays — experience owner
        },
        -- Official Studio testers only. An open-beta campaign egg/pet
        -- does not make someone a Tester on the People list.
        tester_user_ids = {},
    },

    social = {
        friend = true,
        block = true,
        report = false,
    },

    inspect = {
        default_title = "Status",
        default_body = "Progress title. Combat Training titles come from the cave pillars.",
        leaderboard = "Current top-100 placement on that world board.",
        huge_hatcher = "Hatched a Huge",
        huge_hatcher_icon = "rbxassetid://105338046020621",
        level_titles = {
            Noob = {
                icon = "rbxassetid://109253922126750",
                body = "New but going somewhere!",
                hover = "New but going somewhere!",
                prompt = "Circular adventure crest, front view, centered. A tiny warm-gold "
                    .. "seed or first footstep inside a thin unfinished halo. Hopeful, "
                    .. "new, going somewhere. Not a baby bottle, not a schoolhouse, not "
                    .. "a cartoon newbie stamp. One simple symbol, high contrast, "
                    .. "readable as a tiny player-list icon. No text, no letters.\n"
                    .. "Low poly, game ready, on a plain (magenta, blue, green) screen "
                    .. "background with no shadows.",
            },
            Novice = {
                icon = "rbxassetid://127026500451476",
                body = "Finding their feet.",
                hover = "Finding their feet.",
                prompt = "Circular adventure crest, front view, centered. A small rising "
                    .. "path or two footprints finding a trail inside a thin gold ring. "
                    .. "Steady, learning, not lost. Not a hiking-brand logo, not a boot "
                    .. "catalog icon. One simple symbol, high contrast, readable as a "
                    .. "tiny player-list icon. No text, no letters.\n"
                    .. "Low poly, game ready, on a plain (magenta, blue, green) screen "
                    .. "background with no shadows.",
            },
            Adventurer = {
                icon = "rbxassetid://129328186554395",
                body = "Out in the world.",
                hover = "Out in the world.",
                prompt = "Circular adventure crest, front view, centered. A simple compass "
                    .. "rose or open-world trail marker inside a gold ring. Outward, "
                    .. "curious, travel. Not a tourist sticker, not a globe emoji. One "
                    .. "simple symbol, high contrast, readable as a tiny player-list "
                    .. "icon. No text, no letters.\n"
                    .. "Low poly, game ready, on a plain (magenta, blue, green) screen "
                    .. "background with no shadows.",
            },
            Hero = {
                icon = "rbxassetid://103517372435641",
                body = "A regular in the realms.",
                hover = "A regular in the realms.",
                prompt = "Circular adventure crest, front view, centered. A clean gold "
                    .. "hero-mark or small radiant banner inside a halo ring. Trusted, "
                    .. "known, regular of the realms. Not a comic-book S-shield, not a "
                    .. "superhero logo. One simple symbol, high contrast, readable as a "
                    .. "tiny player-list icon. No text, no letters.\n"
                    .. "Low poly, game ready, on a plain (magenta, blue, green) screen "
                    .. "background with no shadows.",
            },
            Master = {
                icon = "rbxassetid://132111995758746",
                body = "Deep progression.",
                hover = "Deep progression.",
                prompt = "Circular adventure crest, front view, centered. A refined gold "
                    .. "sigil or stacked rings showing depth inside a halo. Mastered, "
                    .. "deep, earned. Not a diploma, not a black-belt patch. One simple "
                    .. "symbol, high contrast, readable as a tiny player-list icon. No "
                    .. "text, no letters.\n"
                    .. "Low poly, game ready, on a plain (magenta, blue, green) screen "
                    .. "background with no shadows.",
            },
            Legend = {
                icon = "rbxassetid://98082259621432",
                body = "Level cap.",
                hover = "Level cap.",
                prompt = "Circular adventure crest, front view, centered. A bright gold "
                    .. "laurel sun or completed halo at the ceiling. Legendary, finished "
                    .. "the climb. Not a trophy cup, not a winner-ribbon, no letters. "
                    .. "One simple symbol, high contrast, readable as a tiny player-list "
                    .. "icon.\n"
                    .. "Low poly, game ready, on a plain (magenta, blue, green) screen "
                    .. "background with no shadows.",
            },
        },
        huge_hatcher_prompt = "Circular adventure crest, front view, centered. A single "
            .. "oversized egg or huge-pet silhouette bursting a gold ring. Rare hatch, "
            .. "celebratory, not a supermarket egg carton, not a chicken. One simple "
            .. "symbol, high contrast, readable as a tiny player-list icon. No text, "
            .. "no letters.\n"
            .. "Low poly, game ready, on a plain (magenta, blue, green) screen "
            .. "background with no shadows.",
    },
}
