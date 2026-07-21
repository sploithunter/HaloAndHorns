--[[
    Pure responsive sizing for TeamPanel. Kept separate from the Roblox UI objects so the
    phone-landscape and tablet contracts can be covered by headless tests.
]]

local TeamPanelLayout = {}

local function rounded(value)
    return math.floor(value + 0.5)
end

local function fit(value, minimum, maximum, available)
    return rounded(math.min(math.max(1, available), math.clamp(value, minimum, maximum)))
end

function TeamPanelLayout.panelSize(viewportWidth, viewportHeight)
    viewportWidth = math.max(1, tonumber(viewportWidth) or 1280)
    viewportHeight = math.max(1, tonumber(viewportHeight) or 720)

    local aspect = viewportWidth / viewportHeight
    local widthRatio = if aspect < 1.15 then 0.90 else 0.66
    local heightRatio = if aspect > 1.5 then 0.78 else 0.68

    return {
        width = fit(viewportWidth * widthRatio, 320, 760, viewportWidth - 24),
        height = fit(viewportHeight * heightRatio, 300, 520, viewportHeight - 24),
    }
end

function TeamPanelLayout.content(panelHeight, teamed)
    local compact = panelHeight < 380
    local headerHeight = if compact then 54 else 72
    local hintTop = headerHeight + (if compact then 6 else 12)
    local hintHeight = if compact then 34 else 28
    local listTop = hintTop + hintHeight + 6
    local footerReserve = if teamed
        then (if compact then 58 else 64)
        else (if compact then 12 else 16)

    return {
        compact = compact,
        headerHeight = headerHeight,
        horizontalMargin = if compact then 12 else 24,
        hintTop = hintTop,
        hintHeight = hintHeight,
        listTop = listTop,
        listHeight = math.max(80, panelHeight - listTop - footerReserve),
        leaveHeight = if compact then 36 else 40,
        leaveBottom = if compact then 10 else 12,
    }
end

return TeamPanelLayout
