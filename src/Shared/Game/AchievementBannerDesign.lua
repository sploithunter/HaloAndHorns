--!strict

-- Rasterizes a complete heraldic cloth design into an RGBA buffer. Copy is drawn into the same
-- texture as the weave, shield, ribbon, and laurels, so it follows the skinned UV instead of
-- hovering over the banner as a SurfaceGui/TextLabel.

local AchievementBannerDesign = {}

-- Roblox/Luau's buffer library is newer than Selene's bundled runtime globals.
local Buffer = (getfenv() :: any).buffer

local GLYPHS = {
    A = { "01110", "10001", "10001", "11111", "10001", "10001", "10001" },
    B = { "11110", "10001", "10001", "11110", "10001", "10001", "11110" },
    C = { "01111", "10000", "10000", "10000", "10000", "10000", "01111" },
    D = { "11110", "10001", "10001", "10001", "10001", "10001", "11110" },
    E = { "11111", "10000", "10000", "11110", "10000", "10000", "11111" },
    F = { "11111", "10000", "10000", "11110", "10000", "10000", "10000" },
    G = { "01111", "10000", "10000", "10111", "10001", "10001", "01111" },
    H = { "10001", "10001", "10001", "11111", "10001", "10001", "10001" },
    I = { "11111", "00100", "00100", "00100", "00100", "00100", "11111" },
    J = { "00111", "00010", "00010", "00010", "10010", "10010", "01100" },
    K = { "10001", "10010", "10100", "11000", "10100", "10010", "10001" },
    L = { "10000", "10000", "10000", "10000", "10000", "10000", "11111" },
    M = { "10001", "11011", "10101", "10101", "10001", "10001", "10001" },
    N = { "10001", "11001", "10101", "10011", "10001", "10001", "10001" },
    O = { "01110", "10001", "10001", "10001", "10001", "10001", "01110" },
    P = { "11110", "10001", "10001", "11110", "10000", "10000", "10000" },
    Q = { "01110", "10001", "10001", "10001", "10101", "10010", "01101" },
    R = { "11110", "10001", "10001", "11110", "10100", "10010", "10001" },
    S = { "01111", "10000", "10000", "01110", "00001", "00001", "11110" },
    T = { "11111", "00100", "00100", "00100", "00100", "00100", "00100" },
    U = { "10001", "10001", "10001", "10001", "10001", "10001", "01110" },
    V = { "10001", "10001", "10001", "10001", "10001", "01010", "00100" },
    W = { "10001", "10001", "10001", "10101", "10101", "10101", "01010" },
    X = { "10001", "10001", "01010", "00100", "01010", "10001", "10001" },
    Y = { "10001", "10001", "01010", "00100", "00100", "00100", "00100" },
    Z = { "11111", "00001", "00010", "00100", "01000", "10000", "11111" },
    ["0"] = { "01110", "10001", "10011", "10101", "11001", "10001", "01110" },
    ["1"] = { "00100", "01100", "00100", "00100", "00100", "00100", "01110" },
    ["2"] = { "01110", "10001", "00001", "00010", "00100", "01000", "11111" },
    ["3"] = { "11110", "00001", "00001", "01110", "00001", "00001", "11110" },
    ["4"] = { "00010", "00110", "01010", "10010", "11111", "00010", "00010" },
    ["5"] = { "11111", "10000", "10000", "11110", "00001", "00001", "11110" },
    ["6"] = { "01110", "10000", "10000", "11110", "10001", "10001", "01110" },
    ["7"] = { "11111", "00001", "00010", "00100", "01000", "01000", "01000" },
    ["8"] = { "01110", "10001", "10001", "01110", "10001", "10001", "01110" },
    ["9"] = { "01110", "10001", "10001", "01111", "00001", "00001", "01110" },
    ["-"] = { "00000", "00000", "00000", "11111", "00000", "00000", "00000" },
    [" "] = { "00000", "00000", "00000", "00000", "00000", "00000", "00000" },
}

type RGB = { number }
type NormalizedSpec = {
    style: string,
    title: string,
    value: string,
    footer: string,
}

local function clampByte(value: number): number
    return math.clamp(math.floor(value + 0.5), 0, 255)
end

local function cleanCopy(value: any, maximum: number): string
    local copy = string.upper(tostring(value or ""))
    copy = string.gsub(copy, "[^A-Z0-9 %-]", "")
    copy = string.gsub(copy, "%s+", " ")
    copy = string.gsub(copy, "^%s+", "")
    copy = string.gsub(copy, "%s+$", "")
    return string.sub(copy, 1, maximum)
end

function AchievementBannerDesign.normalizeSpec(spec: any, config: any): NormalizedSpec
    local requestedStyle = cleanCopy(spec and spec.style or "champion", 32)
    requestedStyle = string.lower(string.gsub(requestedStyle, " ", "_"))
    local style = config.styles[requestedStyle] and requestedStyle or "champion"
    local definition = config.styles[style]
    local maximum = config.texture.maximum_text_characters
    local title = cleanCopy(spec and spec.title or definition.title, maximum)
    local value = cleanCopy(spec and spec.value or "0", maximum)
    local footer = cleanCopy(spec and spec.footer or definition.footer, maximum)
    return {
        style = style,
        title = if title ~= "" then title else definition.title,
        value = if value ~= "" then value else "0",
        footer = if footer ~= "" then footer else definition.footer,
    }
end

function AchievementBannerDesign.cacheKey(spec: NormalizedSpec): string
    return table.concat({ spec.style, spec.title, spec.value, spec.footer }, "|")
end

local function writePixel(pixels: buffer, size: number, x: number, y: number, color: RGB)
    x = math.floor(x)
    y = math.floor(y)
    if x < 0 or y < 0 or x >= size or y >= size then
        return
    end
    local offset = (y * size + x) * 4
    Buffer.writeu8(pixels, offset, clampByte(color[1]))
    Buffer.writeu8(pixels, offset + 1, clampByte(color[2]))
    Buffer.writeu8(pixels, offset + 2, clampByte(color[3]))
    Buffer.writeu8(pixels, offset + 3, 255)
end

local function blendPixel(
    pixels: buffer,
    size: number,
    x: number,
    y: number,
    color: RGB,
    alpha: number
)
    x = math.floor(x)
    y = math.floor(y)
    if x < 0 or y < 0 or x >= size or y >= size then
        return
    end
    local offset = (y * size + x) * 4
    local inverse = 1 - alpha
    Buffer.writeu8(
        pixels,
        offset,
        clampByte(Buffer.readu8(pixels, offset) * inverse + color[1] * alpha)
    )
    Buffer.writeu8(
        pixels,
        offset + 1,
        clampByte(Buffer.readu8(pixels, offset + 1) * inverse + color[2] * alpha)
    )
    Buffer.writeu8(
        pixels,
        offset + 2,
        clampByte(Buffer.readu8(pixels, offset + 2) * inverse + color[3] * alpha)
    )
    Buffer.writeu8(pixels, offset + 3, 255)
end

local function rect(
    pixels: buffer,
    size: number,
    x0: number,
    y0: number,
    x1: number,
    y1: number,
    color: RGB,
    alpha: number?
)
    local blend = alpha or 1
    for y = math.max(0, math.floor(y0)), math.min(size - 1, math.ceil(y1) - 1) do
        for x = math.max(0, math.floor(x0)), math.min(size - 1, math.ceil(x1) - 1) do
            if blend >= 1 then
                writePixel(pixels, size, x, y, color)
            else
                blendPixel(pixels, size, x, y, color, blend)
            end
        end
    end
end

local function ellipse(
    pixels: buffer,
    size: number,
    centerX: number,
    centerY: number,
    radiusX: number,
    radiusY: number,
    angle: number,
    color: RGB
)
    local radius = math.ceil(math.max(radiusX, radiusY)) + 2
    local cosine, sine = math.cos(angle), math.sin(angle)
    for y = math.floor(centerY - radius), math.ceil(centerY + radius) do
        for x = math.floor(centerX - radius), math.ceil(centerX + radius) do
            local dx, dy = x - centerX, y - centerY
            local localX = cosine * dx + sine * dy
            local localY = -sine * dx + cosine * dy
            if (localX / radiusX) ^ 2 + (localY / radiusY) ^ 2 <= 1 then
                writePixel(pixels, size, x, y, color)
            end
        end
    end
end

local function insidePolygon(x: number, y: number, points: { { number } }): boolean
    local inside = false
    local previous = points[#points]
    for _, current in points do
        local xa, ya = previous[1], previous[2]
        local xb, yb = current[1], current[2]
        if (ya > y) ~= (yb > y) and x < (xb - xa) * (y - ya) / (yb - ya) + xa then
            inside = not inside
        end
        previous = current
    end
    return inside
end

local function polygon(
    pixels: buffer,
    size: number,
    points: { { number } },
    color: RGB,
    alpha: number?
)
    local minX, maxX, minY, maxY = size, 0, size, 0
    for _, point in points do
        minX, maxX = math.min(minX, point[1]), math.max(maxX, point[1])
        minY, maxY = math.min(minY, point[2]), math.max(maxY, point[2])
    end
    for y = math.floor(minY), math.ceil(maxY) do
        for x = math.floor(minX), math.ceil(maxX) do
            if insidePolygon(x + 0.5, y + 0.5, points) then
                if alpha then
                    blendPixel(pixels, size, x, y, color, alpha)
                else
                    writePixel(pixels, size, x, y, color)
                end
            end
        end
    end
end

local function drawText(
    pixels: buffer,
    size: number,
    copy: string,
    centerX: number,
    topY: number,
    maxWidth: number,
    maximumCell: number,
    ink: RGB,
    shadow: RGB,
    highlight: RGB
)
    local units = math.max(1, #copy * 6 - 1)
    local cell = math.max(1, math.min(maximumCell, math.floor(maxWidth / units)))
    local originX = math.floor(centerX - units * cell * 0.5)
    for characterIndex = 1, #copy do
        local glyph = GLYPHS[string.sub(copy, characterIndex, characterIndex)] or GLYPHS[" "]
        local baseX = originX + (characterIndex - 1) * 6 * cell
        for row, bits in glyph do
            for column = 1, 5 do
                if string.sub(bits, column, column) == "1" then
                    local x = baseX + (column - 1) * cell
                    local y = topY + (row - 1) * cell
                    rect(pixels, size, x + 2, y + 2, x + cell + 2, y + cell + 2, shadow, 0.82)
                    rect(pixels, size, x, y, x + cell, y + cell, ink)
                    if cell >= 4 then
                        rect(pixels, size, x, y, x + cell, y + 1, highlight, 0.48)
                    end
                end
            end
        end
    end
end

function AchievementBannerDesign.render(spec: any, config: any): any
    local normalized = AchievementBannerDesign.normalizeSpec(spec, config)
    local style = config.styles[normalized.style]
    local palette = style.palette
    local texture = config.texture
    local layout = texture.layout
    local size = texture.canvas_size
    local pixels = Buffer.create(size * size * 4)

    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local vertical = 0.82 + 0.16 * math.cos((y / size) * math.pi)
            local fold = 0.93 + 0.07 * math.sin((x / size) * math.pi * 8 + (y / size) * 0.8)
            local grain = (((x * 37 + y * 19 + (x * y) % 17) % 31) / 30 - 0.5) * 0.045
            local tone = math.clamp(vertical * fold + grain, 0, 1)
            local color = {
                palette.deep[1] + (palette.base[1] - palette.deep[1]) * tone,
                palette.deep[2] + (palette.base[2] - palette.deep[2]) * tone,
                palette.deep[3] + (palette.base[3] - palette.deep[3]) * tone,
            }
            writePixel(pixels, size, x, y, color)
        end
    end
    for y = 0, size - 1, texture.weave_step do
        rect(pixels, size, 0, y, size, y + 1, palette.highlight, 0.035)
    end
    for x = 1, size - 1, texture.weave_step + 1 do
        rect(pixels, size, x, 0, x + 1, size, palette.shadow, 0.08)
    end

    local margin, width = texture.border_margin, texture.border_width
    rect(pixels, size, margin, margin, size - margin, margin + width, palette.accent)
    rect(pixels, size, margin, size - margin - width, size - margin, size - margin, palette.accent)
    rect(pixels, size, margin, margin, margin + width, size - margin, palette.accent)
    rect(pixels, size, size - margin - width, margin, size - margin, size - margin, palette.accent)
    local inner = margin + texture.inner_border_gap
    local innerWidth = texture.inner_border_width
    rect(pixels, size, inner, inner, size - inner, inner + innerWidth, palette.ink, 0.62)
    rect(
        pixels,
        size,
        inner,
        size - inner - innerWidth,
        size - inner,
        size - inner,
        palette.ink,
        0.62
    )

    local cx = size * 0.5
    local shield = {
        { cx - layout.shield_half_width, layout.shield_top },
        { cx + layout.shield_half_width, layout.shield_top },
        { cx + layout.shield_half_width * 0.80, layout.shield_bottom - 58 },
        { cx, layout.shield_bottom },
        { cx - layout.shield_half_width * 0.80, layout.shield_bottom - 58 },
    }
    polygon(pixels, size, shield, palette.shadow, 0.56)
    local shieldInner = {}
    for _, point in shield do
        table.insert(shieldInner, { cx + (point[1] - cx) * 0.90, 12 + point[2] * 0.94 })
    end
    polygon(pixels, size, shieldInner, palette.base, 0.90)

    polygon(pixels, size, {
        { cx, layout.crest_y - layout.crest_size },
        { cx + layout.crest_size, layout.crest_y },
        { cx, layout.crest_y + layout.crest_size },
        { cx - layout.crest_size, layout.crest_y },
    }, palette.accent)

    for side = -1, 1, 2 do
        for index = 0, 8 do
            local progress = index / 8
            local angle = (-0.95 + progress * 1.85) * side
            local leafX = cx + side * (layout.laurel_half_width - 36 * math.sin(progress * math.pi))
            local leafY = 175 + progress * 190
            ellipse(pixels, size, leafX, leafY, 18, 7, angle, palette.accent)
        end
    end

    local ribbonY, ribbonHeight = layout.ribbon_y, layout.ribbon_height
    rect(pixels, size, 92, ribbonY, size - 92, ribbonY + ribbonHeight, palette.shadow, 0.90)
    polygon(pixels, size, {
        { 60, ribbonY + 8 },
        { 92, ribbonY + 8 },
        { 92, ribbonY + ribbonHeight - 8 },
        { 50, ribbonY + ribbonHeight + 6 },
    }, palette.accent, 0.82)
    polygon(pixels, size, {
        { size - 60, ribbonY + 8 },
        { size - 92, ribbonY + 8 },
        { size - 92, ribbonY + ribbonHeight - 8 },
        { size - 50, ribbonY + ribbonHeight + 6 },
    }, palette.accent, 0.82)
    drawText(
        pixels,
        size,
        normalized.title,
        cx,
        ribbonY + 10,
        size * 0.54,
        layout.title_cell,
        palette.ink,
        palette.shadow,
        palette.highlight
    )
    drawText(
        pixels,
        size,
        normalized.value,
        cx,
        layout.value_y,
        size * 0.48,
        layout.value_cell,
        palette.ink,
        palette.shadow,
        palette.highlight
    )
    drawText(
        pixels,
        size,
        normalized.footer,
        cx,
        layout.footer_y,
        size * 0.70,
        layout.footer_cell,
        palette.ink,
        palette.shadow,
        palette.highlight
    )

    return {
        pixels = pixels,
        size = size,
        spec = normalized,
        cacheKey = AchievementBannerDesign.cacheKey(normalized),
    }
end

return AchievementBannerDesign
