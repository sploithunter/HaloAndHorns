-- One-time Merge defense combat-mode notices.
--
-- `full_intro` is an informational click-through for an already-eligible first visitor.
-- `full_unlock_choice` is a blocking two-button decision for someone who previously played while
-- Full was locked. The server owns persistence and validates every response.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local UIViewportScale = require(script.Parent.Parent.UIViewportScale)

local MergeDefenseModeNotice = {}

local activeGui = nil

local function corner(parent, radius)
    local value = Instance.new("UICorner")
    value.CornerRadius = UDim.new(0, radius)
    value.Parent = parent
end

local function stroke(parent, color, thickness)
    local value = Instance.new("UIStroke")
    value.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    value.Color = color
    value.Thickness = thickness
    value.Parent = parent
end

local function button(parent, name, text, color, position)
    local value = Instance.new("TextButton")
    value.Name = name
    value.AnchorPoint = Vector2.new(0.5, 1)
    value.Position = position
    value.Size = UDim2.fromOffset(250, 62)
    value.BackgroundColor3 = color
    value.BorderSizePixel = 0
    value.AutoButtonColor = true
    value.Selectable = true
    value.Text = text
    value.TextColor3 = Color3.new(1, 1, 1)
    value.TextSize = 21
    value.Font = Enum.Font.GothamBlack
    value.ZIndex = 5
    corner(value, 16)
    stroke(value, color:Lerp(Color3.new(1, 1, 1), 0.48), 3)

    local selection = Instance.new("Frame")
    selection.Name = "RoundedSelection"
    selection.BackgroundTransparency = 1
    corner(selection, 16)
    stroke(selection, Color3.fromRGB(255, 220, 70), 4)
    value.SelectionImageObject = selection
    value.Parent = parent
    return value
end

function MergeDefenseModeNotice.show(notice, respond)
    notice = type(notice) == "table" and notice or {}
    local kind = tostring(notice.kind or "")
    if kind ~= "full_intro" and kind ~= "full_unlock_choice" then
        return
    end
    if activeGui then
        activeGui:Destroy()
        activeGui = nil
    end

    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return
    end
    local priorSelection = GuiService.SelectedObject
    local gui = Instance.new("ScreenGui")
    gui.Name = "MergeDefenseModeNotice"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 1150
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    activeGui = gui

    local scrim = Instance.new("TextButton")
    scrim.Name = "Scrim"
    scrim.Size = UDim2.fromScale(1, 1)
    scrim.BackgroundColor3 = Color3.new(0, 0, 0)
    scrim.BackgroundTransparency = 0.38
    scrim.BorderSizePixel = 0
    scrim.Text = ""
    scrim.AutoButtonColor = false
    scrim.Active = true
    scrim.Modal = true
    scrim.Selectable = false
    scrim.ZIndex = 1
    scrim.Parent = gui

    local panel = Instance.new("Frame")
    panel.Name = "ModeNotice"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.46)
    panel.Size = UDim2.fromOffset(650, 310)
    panel.BackgroundColor3 = Color3.fromRGB(22, 27, 39)
    panel.BorderSizePixel = 0
    panel.ZIndex = 2
    corner(panel, 22)
    stroke(panel, Color3.fromRGB(75, 211, 255), 4)
    panel.Parent = gui

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 82)
    header.BackgroundColor3 = Color3.fromRGB(25, 128, 190)
    header.BorderSizePixel = 0
    header.ZIndex = 3
    corner(header, 18)
    header.Parent = panel

    local headerMask = Instance.new("Frame")
    headerMask.Size = UDim2.new(1, 0, 0, 22)
    headerMask.Position = UDim2.new(0, 0, 1, -22)
    headerMask.BackgroundColor3 = header.BackgroundColor3
    headerMask.BorderSizePixel = 0
    headerMask.ZIndex = 3
    headerMask.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.fromOffset(20, 0)
    title.BackgroundTransparency = 1
    title.Text = tostring(notice.title or "MERGE DEFENSE COMBAT")
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 31
    title.Font = Enum.Font.GothamBlack
    title.ZIndex = 4
    title.Parent = header

    local body = Instance.new("TextLabel")
    body.Size = UDim2.new(1, -64, 0, 112)
    body.Position = UDim2.fromOffset(32, 102)
    body.BackgroundTransparency = 1
    body.Text = tostring(notice.body or "Choose how your pets fight in Merge Defense.")
    body.TextColor3 = Color3.fromRGB(224, 233, 245)
    body.TextSize = 21
    body.Font = Enum.Font.GothamMedium
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Center
    body.TextYAlignment = Enum.TextYAlignment.Center
    body.ZIndex = 3
    body.Parent = panel

    local closed = false
    local function resolve(action)
        if closed then
            return
        end
        closed = true
        if type(respond) == "function" then
            respond(action)
        end
        gui:Destroy()
        if activeGui == gui then
            activeGui = nil
        end
        if priorSelection and priorSelection.Parent then
            GuiService.SelectedObject = priorSelection
        else
            GuiService.SelectedObject = nil
        end
    end

    local primary
    if kind == "full_unlock_choice" then
        local secondary = button(
            panel,
            "StaySimple",
            tostring(notice.secondaryLabel or "STAY SIMPLE"),
            Color3.fromRGB(88, 99, 118),
            UDim2.new(0.29, 0, 1, -24)
        )
        primary = button(
            panel,
            "SwitchFull",
            tostring(notice.primaryLabel or "SWITCH TO FULL"),
            Color3.fromRGB(34, 194, 91),
            UDim2.new(0.71, 0, 1, -24)
        )
        secondary.Activated:Connect(function()
            resolve("stay_simple")
        end)
        primary.Activated:Connect(function()
            resolve("switch_full")
        end)
    else
        primary = button(
            panel,
            "Acknowledge",
            tostring(notice.primaryLabel or "OKAY"),
            Color3.fromRGB(34, 194, 91),
            UDim2.new(0.5, 0, 1, -24)
        )
        primary.Activated:Connect(function()
            resolve("acknowledge_full_intro")
        end)
    end

    gui.Parent = playerGui
    UIViewportScale.attach(panel, { min = 0.55 })
    if player:GetAttribute("InputMode") == "gamepad" then
        GuiService.SelectedObject = primary
    end
end

return MergeDefenseModeNotice
