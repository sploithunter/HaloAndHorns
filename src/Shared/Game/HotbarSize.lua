--!strict

-- Power-bar size: Auto follows the device, or the player picks Mobile / Tablet / Desktop.
-- Mobile is the designed-for-phone size (bigger tap targets). Desktop is the current
-- pixel-designed bar. Tablet sits between them.

local HotbarSize = {}

HotbarSize.PREFERENCES = { "auto", "mobile", "tablet", "desktop" }
HotbarSize.SIZES = { "mobile", "tablet", "desktop" }

function HotbarSize.normalize(preference)
    if preference == "mobile" or preference == "tablet" or preference == "desktop" then
        return preference
    end
    -- Earlier compact/expanded toggle.
    if preference == "expanded" then
        return "mobile"
    end
    return "auto"
end

function HotbarSize.deviceSize(displayClass)
    if displayClass == "phone" or displayClass == "compact" then
        return "mobile"
    end
    if displayClass == "tablet" then
        return "tablet"
    end
    return "desktop"
end

function HotbarSize.resolve(preference, displayClass)
    preference = HotbarSize.normalize(preference)
    if preference ~= "auto" then
        return preference
    end
    return HotbarSize.deviceSize(displayClass)
end

-- "horizontal" is the saved phone-playtest keeper. "vertical_left" is the
-- look-at-it experiment (two columns on the far left edge).
function HotbarSize.orientation(config)
    config = type(config) == "table" and config or {}
    if config.orientation == "vertical_left" then
        return "vertical_left"
    end
    return "horizontal"
end

local function viewportFactor(viewportWidth, viewportHeight)
    local width = tonumber(viewportWidth) or 1280
    local height = tonumber(viewportHeight) or 720
    return math.clamp(math.min(width / 1280, height / 720), 0.45, 1)
end

-- Uniform multiplier on top of UIViewportScale. Phone landscape (short edge
-- under 700) still grows the bar. iPad and desktop (810 / 1080 tall) use the
-- configured tablet/desktop mode and never the phone 1.6 grow — even if
-- Settings still say Mobile.
function HotbarSize.multiplier(size, viewportWidth, viewportHeight, config)
    if size ~= "mobile" and size ~= "tablet" then
        size = "desktop"
    end
    config = type(config) == "table" and config or {}
    local modes = type(config.modes) == "table" and config.modes or {}
    local width = tonumber(viewportWidth) or 1280
    local height = tonumber(viewportHeight) or 720
    local shortEdge = math.min(width, height)
    if shortEdge >= 700 then
        -- iPad (≤1024) and large desktops share the 1.04 scale (30% over
        -- the 0.80 pass). Never apply the phone 1.6 grow here.
        if size == "tablet" or shortEdge <= 1024 then
            return tonumber(modes.tablet) or 1.04
        end
        return tonumber(modes.desktop) or 1.04
    end
    if size == "desktop" then
        return tonumber(modes.desktop) or 1
    end
    local factor = viewportFactor(width, height)
    if HotbarSize.orientation(config) == "vertical_left" then
        local span = tonumber(config.vertical_span) or 546
        local compactHeight = span * factor
        local fracName = size == "mobile" and "mobile_height_scale" or "tablet_height_scale"
        local targetFrac = tonumber(config[fracName]) or (size == "mobile" and 0.82 or 0.72)
        if compactHeight <= 1 then
            return tonumber(modes[size]) or 1
        end
        local fitted = (height * targetFrac) / compactHeight
        local maxFit = (height * 0.90) / compactHeight
        -- The horizontal 1.6 floor would overflow a 390-tall phone.
        return math.clamp(fitted, 0.85, math.max(0.85, maxFit))
    end
    local span = tonumber(config.design_span) or 792
    local compactWidth = span * factor
    local fracName = size == "mobile" and "mobile_width_scale" or "tablet_width_scale"
    local targetFrac = tonumber(config[fracName]) or (size == "mobile" and 0.90 or 0.72)
    if compactWidth <= 1 then
        return tonumber(modes[size]) or 1
    end
    local fitted = (width * targetFrac) / compactWidth
    local maxFit = (width * 0.94) / compactWidth
    local minMul = tonumber(modes[size]) or (size == "mobile" and 1.6 or 1.2)
    return math.clamp(fitted, minMul, math.max(minMul, maxFit))
end

return HotbarSize
