-- FocusNavigator — modal focus containment, directional neighbors, scrolling, and opener restore.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local FocusNavigator = {}
local previousSelection = nil
local activeRoot = nil
local descendantConnection = nil

local selectionImage = Instance.new("Frame")
selectionImage.Name = "ConsoleSelection"
selectionImage.BackgroundTransparency = 1
local selectionCorner = Instance.new("UICorner")
selectionCorner.CornerRadius = UDim.new(0, 10)
selectionCorner.Parent = selectionImage
local selectionStroke = Instance.new("UIStroke")
selectionStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
selectionStroke.Color = Color3.fromRGB(255, 220, 55)
selectionStroke.Thickness = 4
selectionStroke.Parent = selectionImage
GuiService.SelectionImageObject = selectionImage

local function focusables(root)
    local result = {}
    if not root then
        return result
    end
    for _, item in ipairs(root:GetDescendants()) do
        if item:IsA("GuiButton") and item.Visible and item.Active then
            item.Selectable = true
            result[#result + 1] = item
        end
    end
    table.sort(result, function(a, b)
        if a.LayoutOrder ~= b.LayoutOrder then
            return a.LayoutOrder < b.LayoutOrder
        end
        local ap, bp = a.AbsolutePosition, b.AbsolutePosition
        return ap.Y == bp.Y and ap.X < bp.X or ap.Y < bp.Y
    end)
    return result
end

local function nearest(items, source, dx, dy)
    local sp = source.AbsolutePosition + source.AbsoluteSize / 2
    local best, bestScore
    for _, candidate in ipairs(items) do
        if candidate ~= source then
            local cp = candidate.AbsolutePosition + candidate.AbsoluteSize / 2
            local vx, vy = cp.X - sp.X, cp.Y - sp.Y
            local forward = vx * dx + vy * dy
            if forward > 1 then
                local lateral = math.abs(vx * dy - vy * dx)
                local score = forward + lateral * 2.5
                if bestScore == nil or score < bestScore then
                    best, bestScore = candidate, score
                end
            end
        end
    end
    return best
end

local function wire(root)
    local items = focusables(root)
    for _, item in ipairs(items) do
        item.NextSelectionUp = nearest(items, item, 0, -1)
        item.NextSelectionDown = nearest(items, item, 0, 1)
        item.NextSelectionLeft = nearest(items, item, -1, 0)
        item.NextSelectionRight = nearest(items, item, 1, 0)
    end
    return items
end

local function reveal(selected)
    local node = selected and selected.Parent
    while node and node ~= activeRoot do
        if node:IsA("ScrollingFrame") then
            local itemTop = selected.AbsolutePosition.Y
                - node.AbsolutePosition.Y
                + node.CanvasPosition.Y
            local itemBottom = itemTop + selected.AbsoluteSize.Y
            local top, bottom =
                node.CanvasPosition.Y, node.CanvasPosition.Y + node.AbsoluteWindowSize.Y
            if itemTop < top then
                node.CanvasPosition = Vector2.new(node.CanvasPosition.X, math.max(0, itemTop - 12))
            elseif itemBottom > bottom then
                node.CanvasPosition =
                    Vector2.new(node.CanvasPosition.X, itemBottom - node.AbsoluteWindowSize.Y + 12)
            end
            break
        end
        node = node.Parent
    end
end

function FocusNavigator.open(root)
    previousSelection = GuiService.SelectedObject
    activeRoot = root
    if descendantConnection then
        descendantConnection:Disconnect()
    end
    pcall(function()
        root.SelectionGroup = true
    end)
    local items = wire(root)
    descendantConnection = root.DescendantAdded:Connect(function(item)
        if item:IsA("GuiButton") then
            task.defer(function()
                local refreshed = wire(root)
                if
                    #refreshed > 0
                    and Players.LocalPlayer:GetAttribute("InputMode") == "gamepad"
                    and GuiService.SelectedObject == nil
                then
                    GuiService.SelectedObject = refreshed[1]
                end
            end)
        end
    end)
    if #items > 0 and Players.LocalPlayer:GetAttribute("InputMode") == "gamepad" then
        GuiService.SelectedObject = items[1]
    end
end

Players.LocalPlayer:GetAttributeChangedSignal("InputMode"):Connect(function()
    if
        activeRoot
        and Players.LocalPlayer:GetAttribute("InputMode") == "gamepad"
        and GuiService.SelectedObject == nil
    then
        local items = wire(activeRoot)
        GuiService.SelectedObject = items[1]
    end
end)

function FocusNavigator.close()
    if descendantConnection then
        descendantConnection:Disconnect()
        descendantConnection = nil
    end
    activeRoot = nil
    if previousSelection and previousSelection.Parent then
        GuiService.SelectedObject = previousSelection
    else
        GuiService.SelectedObject = nil
    end
    previousSelection = nil
end

GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
    local selected = GuiService.SelectedObject
    if activeRoot and selected and not selected:IsDescendantOf(activeRoot) then
        local items = wire(activeRoot)
        GuiService.SelectedObject = items[1]
    else
        reveal(selected)
    end
end)

return FocusNavigator
