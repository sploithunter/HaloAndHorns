--!strict

-- Pure geometry for a manually positioned, recycled card grid. The inventory owns only the
-- visible rows (plus a small overscan) while this module preserves the full scroll extent.
local VirtualGridWindow = {}

export type Range = {
    first: number,
    last: number,
}

function VirtualGridWindow.columns(
    availableWidth: number,
    cardWidth: number,
    horizontalGap: number
): number
    local stride = math.max(1, cardWidth + horizontalGap)
    return math.max(1, math.floor((math.max(0, availableWidth) + horizontalGap) / stride))
end

function VirtualGridWindow.contentHeight(
    itemCount: number,
    columns: number,
    cardHeight: number,
    verticalGap: number
): number
    if itemCount <= 0 then
        return 0
    end
    local rows = math.ceil(itemCount / math.max(1, columns))
    return rows * cardHeight + math.max(0, rows - 1) * verticalGap
end

function VirtualGridWindow.visibleRange(
    itemCount: number,
    columns: number,
    cardHeight: number,
    verticalGap: number,
    viewportTop: number,
    viewportHeight: number,
    overscanRows: number?
): Range?
    if itemCount <= 0 or viewportHeight <= 0 then
        return nil
    end

    columns = math.max(1, columns)
    local stride = math.max(1, cardHeight + verticalGap)
    local height = VirtualGridWindow.contentHeight(itemCount, columns, cardHeight, verticalGap)
    local viewportBottom = viewportTop + viewportHeight
    if viewportBottom < 0 or viewportTop > height then
        return nil
    end

    local overscan = math.max(0, math.floor(overscanRows or 0))
    local firstRow = math.max(0, math.floor(math.max(0, viewportTop) / stride) - overscan)
    local lastRow = math.max(
        firstRow,
        math.floor(math.max(0, math.min(height, viewportBottom) - 1) / stride) + overscan
    )
    local first = firstRow * columns + 1
    local last = math.min(itemCount, (lastRow + 1) * columns)
    if first > itemCount then
        return nil
    end
    return { first = first, last = last }
end

function VirtualGridWindow.position(
    index: number,
    columns: number,
    cardWidth: number,
    cardHeight: number,
    horizontalGap: number,
    verticalGap: number
): (number, number)
    local zeroBased = math.max(0, index - 1)
    local column = zeroBased % math.max(1, columns)
    local row = math.floor(zeroBased / math.max(1, columns))
    return column * (cardWidth + horizontalGap), row * (cardHeight + verticalGap)
end

return VirtualGridWindow
