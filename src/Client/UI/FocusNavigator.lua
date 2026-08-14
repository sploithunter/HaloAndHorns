-- FocusNavigator — modal focus containment, directional neighbors, scrolling, and opener restore.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local FocusNavigator = {}
local previousSelection = nil
local activeRoot = nil
local descendantAddedConnection = nil
local descendantRemovingConnection = nil
local wireQueued = false

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

local function focusables(root)
    local result = {}
    if not root then
        return result
    end
    for _, item in ipairs(root:GetDescendants()) do
        if item:IsA("GuiButton") and item.Visible and item.Active then
            item.Selectable = true
            -- SelectionImageObject belongs to GuiObject, not GuiService. Assign the
            -- shared adornment to each focusable control as it enters the modal.
            item.SelectionImageObject = selectionImage
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

-- Inventory cards are rebuilt as one synchronous batch. Rewiring on every DescendantAdded used to
-- schedule one O(buttons^2) pass PER card, which locked Studio on large inventories before a staged
-- squad selection could even be activated. Coalesce the whole batch into one deferred pass, and do
-- no directional-neighbor work at all while the player is using mouse/touch input.
local function scheduleWire(root)
    if wireQueued or Players.LocalPlayer:GetAttribute("InputMode") ~= "gamepad" then
        return
    end
    wireQueued = true
    task.defer(function()
        wireQueued = false
        if activeRoot ~= root or not root.Parent then
            return
        end
        local refreshed = wire(root)
        if #refreshed > 0 and GuiService.SelectedObject == nil then
            GuiService.SelectedObject = refreshed[1]
        end
    end)
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
    if descendantAddedConnection then
        descendantAddedConnection:Disconnect()
    end
    if descendantRemovingConnection then
        descendantRemovingConnection:Disconnect()
    end
    pcall(function()
        root.SelectionGroup = true
    end)
    local gamepad = Players.LocalPlayer:GetAttribute("InputMode") == "gamepad"
    local items = gamepad and wire(root) or {}
    descendantAddedConnection = root.DescendantAdded:Connect(function(item)
        if item:IsA("GuiButton") then
            scheduleWire(root)
        end
    end)
    descendantRemovingConnection = root.DescendantRemoving:Connect(function(item)
        if item:IsA("GuiButton") then
            scheduleWire(root)
        end
    end)
    if #items > 0 and gamepad then
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
    if descendantAddedConnection then
        descendantAddedConnection:Disconnect()
        descendantAddedConnection = nil
    end
    if descendantRemovingConnection then
        descendantRemovingConnection:Disconnect()
        descendantRemovingConnection = nil
    end
    activeRoot = nil
    wireQueued = false
    if previousSelection and previousSelection.Parent then
        GuiService.SelectedObject = previousSelection
    else
        GuiService.SelectedObject = nil
    end
    previousSelection = nil
end

GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
    local selected = GuiService.SelectedObject
    if
        activeRoot
        and Players.LocalPlayer:GetAttribute("InputMode") == "gamepad"
        and selected
        and not selected:IsDescendantOf(activeRoot)
    then
        local items = wire(activeRoot)
        GuiService.SelectedObject = items[1]
    else
        reveal(selected)
    end
end)

return FocusNavigator
