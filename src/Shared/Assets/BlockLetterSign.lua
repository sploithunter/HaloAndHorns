--[[
    BlockLetterSign — world titles built from anchored Parts.

    Each glyph is a 5-wide (or narrower) 7-row bitmap. Callers pass lines and a
    world pose; the module lays out solid block letters plus an optional backing
    plate. Used for shop/landmark signs that must read in 3D, not as a billboard.
]]

local BlockLetterSign = {}

-- 7 rows, top to bottom. "1" is a filled cell.
local GLYPHS = {
    [" "] = { "   ", "   ", "   ", "   ", "   ", "   ", "   " },
    ["'"] = { "11", "11", "1 ", "  ", "  ", "  ", "  " },
    A = { " 111 ", "1   1", "1   1", "11111", "1   1", "1   1", "1   1" },
    B = { "1111 ", "1   1", "1   1", "1111 ", "1   1", "1   1", "1111 " },
    C = { " 111 ", "1   1", "1    ", "1    ", "1    ", "1   1", " 111 " },
    D = { "1111 ", "1   1", "1   1", "1   1", "1   1", "1   1", "1111 " },
    E = { "11111", "1    ", "1    ", "1111 ", "1    ", "1    ", "11111" },
    F = { "11111", "1    ", "1    ", "1111 ", "1    ", "1    ", "1    " },
    G = { " 111 ", "1   1", "1    ", "1 111", "1   1", "1   1", " 111 " },
    H = { "1   1", "1   1", "1   1", "11111", "1   1", "1   1", "1   1" },
    I = { "111", " 1 ", " 1 ", " 1 ", " 1 ", " 1 ", "111" },
    J = { "  111", "    1", "    1", "    1", "    1", "1   1", " 111 " },
    K = { "1   1", "1  1 ", "1 1  ", "11   ", "1 1  ", "1  1 ", "1   1" },
    L = { "1    ", "1    ", "1    ", "1    ", "1    ", "1    ", "11111" },
    M = { "1   1", "11 11", "1 1 1", "1   1", "1   1", "1   1", "1   1" },
    N = { "1   1", "11  1", "1 1 1", "1  11", "1   1", "1   1", "1   1" },
    O = { " 111 ", "1   1", "1   1", "1   1", "1   1", "1   1", " 111 " },
    P = { "1111 ", "1   1", "1   1", "1111 ", "1    ", "1    ", "1    " },
    Q = { " 111 ", "1   1", "1   1", "1   1", "1 1 1", "1  1 ", " 11 1" },
    R = { "1111 ", "1   1", "1   1", "1111 ", "1 1  ", "1  1 ", "1   1" },
    S = { " 1111", "1    ", "1    ", " 111 ", "    1", "    1", "1111 " },
    T = { "11111", "  1  ", "  1  ", "  1  ", "  1  ", "  1  ", "  1  " },
    U = { "1   1", "1   1", "1   1", "1   1", "1   1", "1   1", " 111 " },
    V = { "1   1", "1   1", "1   1", "1   1", "1   1", " 1 1 ", "  1  " },
    W = { "1   1", "1   1", "1   1", "1   1", "1 1 1", "11 11", "1   1" },
    X = { "1   1", "1   1", " 1 1 ", "  1  ", " 1 1 ", "1   1", "1   1" },
    Y = { "1   1", "1   1", " 1 1 ", "  1  ", "  1  ", "  1  ", "  1  " },
    Z = { "11111", "    1", "   1 ", "  1  ", " 1   ", "1    ", "11111" },
    ["1"] = { "  1  ", " 11  ", "1 1  ", "  1  ", "  1  ", "  1  ", "11111" },
    ["2"] = { " 111 ", "1   1", "    1", "   1 ", "  1  ", " 1   ", "11111" },
    ["3"] = { "1111 ", "    1", "    1", " 111 ", "    1", "    1", "1111 " },
    ["4"] = { "   1 ", "  11 ", " 1 1 ", "1  1 ", "11111", "   1 ", "   1 " },
    ["5"] = { "11111", "1    ", "1    ", "1111 ", "    1", "    1", "1111 " },
    ["6"] = { " 111 ", "1    ", "1    ", "1111 ", "1   1", "1   1", " 111 " },
    ["7"] = { "11111", "    1", "   1 ", "  1  ", "  1  ", "  1  ", "  1  " },
    ["8"] = { " 111 ", "1   1", "1   1", " 111 ", "1   1", "1   1", " 111 " },
    ["9"] = { " 111 ", "1   1", "1   1", " 1111", "    1", "    1", " 111 " },
    ["0"] = { " 111 ", "1   1", "1   1", "1   1", "1   1", "1   1", " 111 " },
}

local ROWS = 7

local function glyphFor(ch)
    if type(ch) ~= "string" or ch == "" then
        return nil
    end
    return GLYPHS[ch] or GLYPHS[string.upper(ch)]
end

function BlockLetterSign.glyph(ch)
    return glyphFor(ch)
end

function BlockLetterSign.missingGlyphs(lines)
    local missing = {}
    if type(lines) ~= "table" then
        return missing
    end
    local seen = {}
    for _, line in ipairs(lines) do
        if type(line) == "string" then
            for i = 1, #line do
                local ch = string.sub(line, i, i)
                if not glyphFor(ch) and not seen[ch] then
                    seen[ch] = true
                    table.insert(missing, ch)
                end
            end
        end
    end
    return missing
end

function BlockLetterSign.colorableCount(lines)
    local count = 0
    if type(lines) ~= "table" then
        return count
    end
    for _, line in ipairs(lines) do
        if type(line) == "string" then
            for i = 1, #line do
                local ch = string.sub(line, i, i)
                if ch ~= " " and glyphFor(ch) then
                    count += 1
                end
            end
        end
    end
    return count
end

-- Hue in [0, 1). Subtracting phase walks the cascade left to right (English reading order).
function BlockLetterSign.rainbowHue(index, count, phase)
    local n = math.max(1, tonumber(count) or 1)
    local i = math.max(1, tonumber(index) or 1)
    local p = tonumber(phase) or 0
    if n == 1 then
        return ((-p % 1) + 1) % 1
    end
    return (((i - 1) / n) - p) % 1
end

function BlockLetterSign.measure(lines, cell, letterGap, lineGap)
    cell = tonumber(cell) or 0.75
    letterGap = tonumber(letterGap) or cell
    lineGap = tonumber(lineGap) or (cell * 2)
    local maxWidth = 0
    local count = 0
    if type(lines) == "table" then
        for _, line in ipairs(lines) do
            if type(line) == "string" then
                count += 1
                local width = 0
                for i = 1, #line do
                    local glyph = glyphFor(string.sub(line, i, i))
                    if glyph then
                        if width > 0 then
                            width += letterGap
                        end
                        width += #glyph[1] * cell
                    end
                end
                if width > maxWidth then
                    maxWidth = width
                end
            end
        end
    end
    local height = 0
    if count > 0 then
        height = count * ROWS * cell + (count - 1) * lineGap
    end
    return maxWidth, height
end

local function color3(rgb, fallback)
    rgb = type(rgb) == "table" and rgb or {}
    return Color3.fromRGB(
        tonumber(rgb[1] or rgb.r) or fallback.R * 255,
        tonumber(rgb[2] or rgb.g) or fallback.G * 255,
        tonumber(rgb[3] or rgb.b) or fallback.B * 255
    )
end

function BlockLetterSign.build(parent, config)
    config = type(config) == "table" and config or {}
    local lines = config.lines
    if type(lines) ~= "table" or #lines == 0 then
        return nil
    end
    local cell = tonumber(config.cell) or 0.75
    local depth = tonumber(config.depth) or 1.1
    local letterGap = tonumber(config.letter_gap) or cell
    local lineGap = tonumber(config.line_gap) or (cell * 2)
    local width, height = BlockLetterSign.measure(lines, cell, letterGap, lineGap)
    if width <= 0 or height <= 0 then
        return nil
    end

    local origin = CFrame.new(
        tonumber(config.x) or 0,
        tonumber(config.y) or 0,
        tonumber(config.z) or 0
    ) * CFrame.Angles(0, math.rad(tonumber(config.yaw_degrees) or 0), 0)

    local model = Instance.new("Model")
    model.Name = config.name or "BlockLetterSign"

    local fill = color3(config.color, Color3.fromRGB(255, 214, 80))
    local rainbow = config.color_mode == "rainbow"
    local rainbowCount = rainbow and BlockLetterSign.colorableCount(lines) or 0
    local rainbowIndex = 0
    local saturation = tonumber(config.rainbow_saturation) or 1
    local value = tonumber(config.rainbow_value) or 1
    local materialName = config.material or "Neon"
    local material = Enum.Material[materialName] or Enum.Material.Neon

    if config.backing ~= false then
        local pad = cell * 1.4
        local back = Instance.new("Part")
        back.Name = "Backing"
        back.Anchored = true
        back.CanCollide = false
        back.CanQuery = false
        back.CastShadow = false
        back.Material = Enum.Material.SmoothPlastic
        back.Color = color3(config.backing_color, Color3.fromRGB(18, 22, 16))
        back.Transparency = tonumber(config.backing_transparency) or 0
        back.Size = Vector3.new(width + pad, height + pad, 0.35)
        back.CFrame = origin * CFrame.new(0, 0, depth * 0.5 + 0.22)
        back.Parent = model
        if config.light ~= false then
            local light = Instance.new("PointLight")
            light.Brightness = tonumber(config.light_brightness) or 0.7
            light.Range = tonumber(config.light_range) or 18
            light.Color = fill
            light.Parent = back
        end
    end

    local top = height * 0.5
    for _, line in ipairs(lines) do
        if type(line) == "string" then
            local lineWidth = select(1, BlockLetterSign.measure({ line }, cell, letterGap, lineGap))
            local cursorX = -lineWidth * 0.5
            for i = 1, #line do
                local ch = string.sub(line, i, i)
                local glyph = glyphFor(ch)
                if glyph then
                    local glyphWidth = #glyph[1] * cell
                    local letterColor = fill
                    if rainbow and ch ~= " " then
                        rainbowIndex += 1
                        letterColor = Color3.fromHSV(
                            BlockLetterSign.rainbowHue(rainbowIndex, rainbowCount),
                            saturation,
                            value
                        )
                    end
                    for row = 1, ROWS do
                        local bits = glyph[row] or ""
                        for col = 1, #bits do
                            if string.sub(bits, col, col) == "1" then
                                local part = Instance.new("Part")
                                part.Name = "Cell"
                                part.Anchored = true
                                part.CanCollide = false
                                part.CanQuery = false
                                part.CastShadow = false
                                part.Material = material
                                part.Color = letterColor
                                if rainbow and ch ~= " " then
                                    part:SetAttribute("RainbowIndex", rainbowIndex)
                                end
                                part.Size = Vector3.new(cell, cell, depth)
                                local x = cursorX + (col - 0.5) * cell
                                local y = top - (row - 0.5) * cell
                                part.CFrame = origin * CFrame.new(x, y, 0)
                                part.Parent = model
                            end
                        end
                    end
                    cursorX += glyphWidth + letterGap
                end
            end
            top -= ROWS * cell + lineGap
        end
    end

    if rainbow then
        model:SetAttribute("RainbowCount", rainbowCount)
        model:SetAttribute("RainbowSpeed", tonumber(config.rainbow_speed) or 0.3)
        model:SetAttribute("RainbowSaturation", saturation)
        model:SetAttribute("RainbowValue", value)
        game:GetService("CollectionService"):AddTag(model, "BlockLetterRainbow")
    end

    model.Parent = parent
    return model
end

return BlockLetterSign
