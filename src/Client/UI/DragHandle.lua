--[[
    DragHandle — make any GuiObject drag-and-droppable.

    First consumer: the mission map (Jason: "it'd be wonderful to drag and
    drop any menu items but we may start with the map"). Attach to more HUD
    panels by calling DragHandle.attach(panel [, handle]).

    Prefers the engine UIDragDetector (mouse + touch for free); falls back to
    a manual InputBegan/InputChanged drag on the handle if the instance
    isn't available. Returns a cleanup function.
]]

local UserInputService = game:GetService("UserInputService")

local DragHandle = {}

-- panel: the GuiObject to move. handle: the grab surface (defaults to panel).
function DragHandle.attach(panel, handle)
    handle = handle or panel

    -- engine path (whole-panel grabs only): UIDragDetector moves its parent
    if handle == panel then
        local okDetector = pcall(function()
            local detector = Instance.new("UIDragDetector")
            detector.Name = "DragDetector"
            detector.Parent = panel
        end)
        if okDetector then
            return function()
                local d = panel:FindFirstChild("DragDetector")
                if d then
                    d:Destroy()
                end
            end
        end
    end

    local dragging = false
    local dragStart, startPos
    local conns = {}

    table.insert(
        conns,
        handle.InputBegan:Connect(function(input)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragging = true
                dragStart = input.Position
                startPos = panel.Position
            end
        end)
    )
    table.insert(
        conns,
        handle.InputEnded:Connect(function(input)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragging = false
            end
        end)
    )
    table.insert(
        conns,
        UserInputService.InputChanged:Connect(function(input)
            if not dragging then
                return
            end
            if
                input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch
            then
                return
            end
            local delta = input.Position - dragStart
            panel.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end)
    )

    return function()
        for _, c in ipairs(conns) do
            c:Disconnect()
        end
    end
end

return DragHandle
