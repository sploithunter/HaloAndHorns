--!strict

-- Pure, viewport-bounded layout for the hatch/reveal grid.
--
-- The frame itself is not the full visual footprint: after reveal, result names and duplicate
-- counts sit below the representative frame. `resultFooterScale` reserves that proportional
-- footer while solving the square size, so the final readout fits as well as the initial egg.

local HatchGridLayout = {}

local GRID_LAYOUTS = {
    { columns = 1, rows = 1, minItems = 1, maxItems = 1, name = "1x1" },
    { columns = 2, rows = 1, minItems = 2, maxItems = 2, name = "2x1" },
    { columns = 2, rows = 2, minItems = 3, maxItems = 4, name = "2x2" },
    { columns = 3, rows = 2, minItems = 5, maxItems = 6, name = "3x2" },
    { columns = 3, rows = 3, minItems = 7, maxItems = 9, name = "3x3" },
    { columns = 4, rows = 3, minItems = 10, maxItems = 12, name = "4x3" },
    { columns = 4, rows = 4, minItems = 13, maxItems = 16, name = "4x4" },
    { columns = 5, rows = 4, minItems = 17, maxItems = 20, name = "5x4" },
    { columns = 5, rows = 5, minItems = 21, maxItems = 25, name = "5x5" },
    { columns = 6, rows = 5, minItems = 26, maxItems = 30, name = "6x5" },
    { columns = 6, rows = 6, minItems = 31, maxItems = 36, name = "6x6" },
    { columns = 7, rows = 6, minItems = 37, maxItems = 42, name = "7x6" },
    { columns = 7, rows = 7, minItems = 43, maxItems = 49, name = "7x7" },
    { columns = 8, rows = 7, minItems = 50, maxItems = 56, name = "8x7" },
    { columns = 8, rows = 8, minItems = 57, maxItems = 64, name = "8x8" },
    { columns = 9, rows = 8, minItems = 65, maxItems = 72, name = "9x8" },
    { columns = 9, rows = 9, minItems = 73, maxItems = 81, name = "9x9" },
    { columns = 10, rows = 9, minItems = 82, maxItems = 90, name = "10x9" },
    { columns = 10, rows = 10, minItems = 91, maxItems = 100, name = "10x10" },
}

local function number(value: unknown, fallback: number): number
    local parsed = tonumber(value)
    return parsed or fallback
end

local function layoutForCount(eggCount: number)
    for _, layout in ipairs(GRID_LAYOUTS) do
        if eggCount >= layout.minItems and eggCount <= layout.maxItems then
            return layout
        end
    end
    return GRID_LAYOUTS[#GRID_LAYOUTS]
end

function HatchGridLayout.resolve(eggCount: number, width: number, height: number, policy)
    eggCount = math.max(1, math.floor(number(eggCount, 1)))
    width = math.max(1, number(width, 1280))
    height = math.max(1, number(height, 720))
    policy = type(policy) == "table" and policy or {}

    local layout = layoutForCount(eggCount)
    local padding = math.max(0, number(policy.padding, 20))
    local safeMargin = math.max(0, number(policy.safeMargin, 16))
    local footerBase = math.max(0, number(policy.resultFooterBase, 4))
    local footerScale = math.max(0, number(policy.resultFooterScale, 0.4))
    local maxEggSize = math.max(1, number(policy.maxEggSize, 300))
    local compactThreshold = math.max(1, math.floor(number(policy.compactThreshold, 37)))
    local configuredMinEggSize = eggCount >= compactThreshold
            and math.max(1, number(policy.compactMinEggSize, 70))
        or math.max(1, number(policy.minEggSize, 100))

    local safeWidth = math.max(1, width - safeMargin * 2)
    local safeHeight = math.max(1, height - safeMargin * 2)
    local horizontalGaps = padding * math.max(0, layout.columns - 1)
    local verticalGaps = padding * math.max(0, layout.rows - 1)
    local widthLimited = math.max(1, (safeWidth - horizontalGaps) / layout.columns)
    -- gridHeight + footerBase + eggSize*footerScale <= safeHeight
    local heightLimited =
        math.max(1, (safeHeight - verticalGaps - footerBase) / (layout.rows + footerScale))
    local eggSize = math.min(maxEggSize, widthLimited, heightLimited)
    local resultFooter = footerBase + eggSize * footerScale
    local gridWidth = eggSize * layout.columns + horizontalGaps
    local gridHeight = eggSize * layout.rows + verticalGaps
    local compositionHeight = gridHeight + resultFooter

    return {
        layout = layout,
        eggSize = eggSize,
        startX = safeMargin + (safeWidth - gridWidth) / 2,
        startY = safeMargin + (safeHeight - compositionHeight) / 2,
        padding = padding,
        safeMargin = safeMargin,
        resultFooter = resultFooter,
        minEggSize = math.min(configuredMinEggSize, eggSize),
        maxEggSize = maxEggSize,
        compactMode = eggCount >= compactThreshold,
        totalWidth = gridWidth,
        totalHeight = gridHeight,
        compositionHeight = compositionHeight,
        containerWidth = width,
        containerHeight = height,
    }
end

function HatchGridLayout.positions(eggCount: number, gridInfo)
    local positions = {}
    local layout = gridInfo.layout
    local fullRows = math.floor(eggCount / layout.columns)
    local remainingEggs = eggCount % layout.columns

    for index = 1, math.min(eggCount, layout.maxItems) do
        local gridIndex = index - 1
        local column = gridIndex % layout.columns
        local row = math.floor(gridIndex / layout.columns)
        local adjustedColumn = column
        local isPartialRow = row == fullRows and remainingEggs > 0
        if isPartialRow then
            adjustedColumn += (layout.columns - remainingEggs) / 2
        end

        positions[#positions + 1] = {
            x = gridInfo.startX + adjustedColumn * (gridInfo.eggSize + gridInfo.padding),
            y = gridInfo.startY + row * (gridInfo.eggSize + gridInfo.padding),
            size = gridInfo.eggSize,
            gridCol = adjustedColumn,
            gridRow = row,
            index = index,
            isPartialRow = isPartialRow,
        }
    end
    return positions
end

return HatchGridLayout
