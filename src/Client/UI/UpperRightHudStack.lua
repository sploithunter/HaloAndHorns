--[[
    UpperRightHudStack — one responsive owner for Farm & Fight's upper-right HUD column.

    The quest surface and tutorial surface alternate in the first slot. The People list follows
    them in the second slot. Roblox's UIListLayout uses each visible surface's rendered size,
    including UIScale, so a presentation change cannot make the surfaces overlap or leave a gap.
]]

local UpperRightHudStack = {}

UpperRightHudStack.UPPER_SURFACE_ORDER = 10
UpperRightHudStack.PEOPLE_LIST_ORDER = 20

local GUI_NAME = "UpperRightHudGui"
local DOCK_NAME = "UpperRightHudStack"
local PADDING_NAME = "RightPadding"

local function getOrCreate(playerGui)
    local existingGui = playerGui:FindFirstChild(GUI_NAME)
    if existingGui and existingGui:IsA("ScreenGui") then
        local existingDock = existingGui:FindFirstChild(DOCK_NAME)
        if existingDock and existingDock:IsA("Frame") then
            return existingGui, existingDock
        end
        existingGui:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = GUI_NAME
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 110
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local dock = Instance.new("Frame")
    dock.Name = DOCK_NAME
    dock.Position = UDim2.fromScale(0, 0)
    dock.Size = UDim2.fromScale(1, 1)
    dock.BackgroundTransparency = 1
    dock.ClipsDescendants = false
    dock.Parent = gui

    local padding = Instance.new("UIPadding")
    padding.Name = PADDING_NAME
    padding.Parent = dock

    local layout = Instance.new("UIListLayout")
    layout.Name = "VerticalLayout"
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 0)
    layout.Parent = dock

    gui.Parent = playerGui
    return gui, dock
end

function UpperRightHudStack.mount(playerGui, surface, layoutOrder)
    local _, dock = getOrCreate(playerGui)
    surface.LayoutOrder = layoutOrder
    surface.Parent = dock
    return dock
end

function UpperRightHudStack.setRightPadding(playerGui, rightScale)
    local _, dock = getOrCreate(playerGui)
    local padding = dock:FindFirstChild(PADDING_NAME)
    if padding and padding:IsA("UIPadding") then
        padding.PaddingRight = UDim.new(math.max(0, tonumber(rightScale) or 0), 0)
    end
end

return UpperRightHudStack
