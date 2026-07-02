--[[
    UI theme — the player's HOME AREA drives a gem-color palette for the whole HUD (#HUD-restyle).

    Areas map onto the same five pill colors used by configs/pill_ui (sapphire / emerald / ruby /
    citrine / neutral), so once a player picks a home area (level 5) the tray, bars and panels can be
    re-tinted to match. Resolved purely by src/Shared/Game/UIPalette.lua (headless-tested); the client
    UITheme reads the player's HomeArea/CurrentArea and applies it.

    Palette entries are RGB triplets {r,g,b} (kept config-pure; the client wraps them in Color3).
]]

return {
    default_color = "neutral",

    -- home area -> gem-color key
    areas = {
        Spawn = { color = "neutral" },
        Grass = { color = "emerald" },
        Earth = { color = "emerald" },
        Desert = { color = "citrine" },
        Ice = { color = "sapphire" },
        Beach = { color = "sapphire" },
        Lava = { color = "ruby" },
    },

    -- gem-color key -> palette (primary = stroke/accent, fill = bar fill, text, dim = inactive)
    palettes = {
        neutral = {
            primary = { 95, 175, 255 },
            fill = { 55, 130, 235 },
            text = { 240, 242, 248 },
            dim = { 52, 60, 82 },
        },
        emerald = {
            primary = { 90, 220, 120 },
            fill = { 40, 155, 75 },
            text = { 225, 255, 230 },
            dim = { 70, 130, 90 },
        },
        sapphire = {
            primary = { 95, 165, 240 },
            fill = { 40, 110, 210 },
            text = { 220, 235, 255 },
            dim = { 80, 120, 180 },
        },
        ruby = {
            primary = { 235, 85, 85 },
            fill = { 185, 45, 45 },
            text = { 255, 225, 225 },
            dim = { 170, 80, 80 },
        },
        citrine = {
            primary = { 240, 200, 70 },
            fill = { 205, 155, 35 },
            text = { 255, 248, 220 },
            dim = { 180, 150, 80 },
        },
    },

    -- shared metrics used by the UI kit (pixels)
    metrics = { corner = 8, bar_height = 18, ring_px = 56, stroke = 2 },
}
