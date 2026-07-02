--[[
    UIPalette (pure) — resolve a player's HOME AREA to a HUD color palette.

    No Roblox APIs: takes configs/ui_theme and an area name, returns the palette (RGB triplets) the
    client wraps in Color3. Unknown / nil area falls back to the configured default color (neutral).
    Headless-tested so the area->color mapping can't silently drift.
]]

local UIPalette = {}

-- area name -> gem-color key (e.g. "Lava" -> "ruby"), default when unmapped.
function UIPalette.colorKeyForArea(area, config)
    config = config or {}
    local areas = config.areas or {}
    local entry = area ~= nil and areas[area] or nil
    if entry and type(entry.color) == "string" then
        return entry.color
    end
    return config.default_color or "neutral"
end

-- Full resolved palette for an area: { color, primary, fill, text, dim, metrics }.
function UIPalette.resolve(area, config)
    config = config or {}
    local key = UIPalette.colorKeyForArea(area, config)
    local palettes = config.palettes or {}
    local pal = palettes[key] or palettes.neutral or {}
    return {
        color = key,
        primary = pal.primary,
        fill = pal.fill,
        text = pal.text,
        dim = pal.dim,
        metrics = config.metrics or {},
    }
end

return UIPalette
