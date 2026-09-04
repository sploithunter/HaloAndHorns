-- Player-bay achievement banners. Runtime art, motion, copy, and imported model IDs live here;
-- the client systems only interpret this contract.

return {
    version = 1,
    tag = "AchievementBanner",

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
