-- Player-bay achievement banners. Runtime art, motion, copy, and imported model IDs live here;
-- the client systems only interpret this contract.

return {
    version = 2,
    tag = "AchievementBanner",

    -- Permanent award definitions. Services report facts; this catalog decides which facts are
    -- banner-worthy, how the cloth is printed, and which imported silhouette is mounted.
    awards = {
        level_50 = {
            trigger = { fact = "level", at_least = 50 },
            variant = "champion_standard",
            style = "champion",
            title = "LEVEL",
            value = "50",
            footer = "REALM CHAMPION",
            priority = 50,
        },
        veteran_100 = {
            trigger = { fact = "veteran_level", at_least = 100 },
            variant = "champion_standard",
            style = "champion",
            title = "VETERAN",
            value = "100",
            footer = "THE LONG WATCH",
            priority = 100,
        },
        wave_250 = {
            trigger = { fact = "merge_wave", at_least = 250 },
            variant = "victory_swallowtail",
            style = "battle",
            title = "WAVE",
            value = "250",
            footer = "HELD THE LINE",
            priority = 90,
        },
        heaven_2_egg = {
            trigger = { fact = "merge_egg_tier", at_least = 13 },
            variant = "champion_standard",
            style = "heaven",
            title = "HEAVEN II",
            value = "EGG",
            footer = "REALM FORGED",
            priority = 60,
        },
        hell_2_egg = {
            trigger = { fact = "merge_egg_tier", at_least = 17 },
            variant = "victory_swallowtail",
            style = "hell",
            title = "HELL II",
            value = "EGG",
            footer = "REALM FORGED",
            priority = 65,
        },
        heaven_3_egg = {
            trigger = { fact = "merge_egg_tier", at_least = 21 },
            variant = "champion_standard",
            style = "heaven",
            title = "HEAVEN III",
            value = "EGG",
            footer = "CROWN OF LIGHT",
            priority = 75,
        },
        hell_3_egg = {
            trigger = { fact = "merge_egg_tier", at_least = 25 },
            variant = "victory_swallowtail",
            style = "hell",
            title = "HELL III",
            value = "EGG",
            footer = "CROWN OF ASH",
            priority = 80,
        },
    },

    display = {
        maximum = 4,
        folder_name = "PlayerAchievementBanners",
        reference_name = "BayClaimPad",
        model_scale = 1,
        -- Local to the claim pad. Its LookVector points into the bay, so these form a gallery just
        -- inside the entrance and face back toward the public approach.
        slots = {
            { x = -21, y = 11, z = -5 },
            { x = -7, y = 11, z = -5 },
            { x = 7, y = 11, z = -5 },
            { x = 21, y = 11, z = -5 },
        },
        model_yaw_degrees = 0,
        camera = {
            distance = 17,
            height = 1,
            target_height = 0,
        },
    },

    ceremony = {
        enabled = true,
        -- Ordinary wave gaps remain untouched. A checkpoint already lasts eight seconds; only a
        -- checkpoint with pending awards requests at least this much breathing room.
        checkpoint_minimum_seconds = 5,
        stream_timeout_seconds = 2,
        camera_in_seconds = 0.35,
        hold_seconds = 0.85,
        camera_out_seconds = 0.4,
        safety_timeout_seconds = 2.5,
        field_of_view = 44,
        highlight_color = { 255, 214, 92 },
        highlight_fill_transparency = 0.68,
        highlight_outline_transparency = 0.05,
        glint_size = 0.42,
    },

    model = {
        cloth_name = "Cloth",
        root_bone = "BannerRoot",
        deform_bones = {
            "ClothUpper",
            "ClothMidUpper",
            "ClothMiddle",
            "ClothMidLower",
            "ClothTip",
        },
        variants = {
            champion_standard = {
                -- Group-owned Model asset from generated/champion_standard/champion_standard.fbx.
                asset_id = 94694565769136,
                shape = "shield",
            },
            victory_swallowtail = {
                -- Group-owned Model asset from generated/victory_swallowtail/victory_swallowtail.fbx.
                asset_id = 111373855038896,
                shape = "swallowtail",
            },
        },
    },

    texture = {
        canvas_size = 512,
        rescan_seconds = 2,
        maximum_text_characters = 18,
        weave_step = 4,
        border_margin = 28,
        border_width = 10,
        inner_border_gap = 15,
        inner_border_width = 4,
        layout = {
            crest_y = 82,
            crest_size = 22,
            ribbon_y = 120,
            ribbon_height = 58,
            title_cell = 7,
            value_y = 205,
            value_cell = 14,
            footer_y = 414,
            footer_cell = 5,
            shield_top = 150,
            shield_bottom = 400,
            shield_half_width = 103,
            laurel_half_width = 136,
        },
    },

    motion = {
        enabled = true,
        radius = 120,
        rescan_seconds = 2,
        speed = 0.82,
        pitch_ratio = 0.42,
        yaw_ratio = 0.28,
        roll_ratio = 1,
        phase_step = 0.73,
        amplitudes_degrees = { 0.55, 0.95, 1.55, 2.3, 3.15 },
    },

    styles = {
        champion = {
            title = "LEVEL",
            footer = "REALM CHAMPION",
            palette = {
                base = { 12, 36, 84 },
                deep = { 5, 11, 34 },
                accent = { 241, 184, 51 },
                ink = { 255, 239, 181 },
                shadow = { 3, 6, 18 },
                highlight = { 255, 248, 212 },
            },
        },
        battle = {
            title = "WAVE",
            footer = "BATTLE HONORS",
            palette = {
                base = { 86, 12, 19 },
                deep = { 24, 2, 5 },
                accent = { 240, 111, 24 },
                ink = { 255, 217, 126 },
                shadow = { 17, 1, 2 },
                highlight = { 255, 235, 186 },
            },
        },
        heaven = {
            title = "HEAVEN",
            footer = "REALM FORGED",
            palette = {
                base = { 218, 248, 255 },
                deep = { 70, 139, 181 },
                accent = { 245, 201, 77 },
                ink = { 255, 255, 239 },
                shadow = { 22, 63, 96 },
                highlight = { 255, 255, 255 },
            },
        },
        hell = {
            title = "HELL",
            footer = "REALM FORGED",
            palette = {
                base = { 105, 11, 19 },
                deep = { 20, 1, 4 },
                accent = { 255, 91, 20 },
                ink = { 255, 218, 146 },
                shadow = { 10, 0, 1 },
                highlight = { 255, 175, 70 },
            },
        },
        founder = {
            title = "FOUNDER",
            footer = "FIRST BANNER",
            palette = {
                base = { 43, 20, 72 },
                deep = { 12, 4, 24 },
                accent = { 87, 226, 201 },
                ink = { 226, 255, 246 },
                shadow = { 7, 2, 14 },
                highlight = { 255, 255, 255 },
            },
        },
    },
}
