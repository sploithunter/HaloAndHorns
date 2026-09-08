-- Isolated lab UI: production ships only the renderer + preset, never this editor.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
    return
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local lab = require(ReplicatedStorage.Configs.vfx.lab)
local saved = require(ReplicatedStorage.Configs.vfx.crystal_eruption)
local schema = require(ReplicatedStorage.Configs.vfx.crystal_schema)
local Timeline = require(ReplicatedStorage.Shared.Effects.CrystalTimeline)
local CombatFX = require(ReplicatedStorage.Shared.Effects.CombatFX)
local function rgb(value)
    return Color3.fromRGB(value[1], value[2], value[3])
end
local function vector(value)
    return Vector3.new(value[1], value[2], value[3])
end
local function copy(p)
    local result = table.clone(p)
    for _, field in ipairs(schema.colors) do
        result[field.key] = table.clone(p[field.key])
    end
    return result
end
local preset = copy(saved)
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "VFXLab"
gui.ResetOnSpawn = false
gui.DisplayOrder = lab.display_order
gui.Parent = player:WaitForChild("PlayerGui")

local stage = Instance.new("Part")
stage.Name = "VFXLabStage"
stage.Anchored = true
stage.Size = vector(lab.stage_size)
stage.Position = vector(lab.stage_position)
stage.Color = rgb(lab.stage_color)
stage.Material = Enum.Material.SmoothPlastic
stage.Parent = Workspace
Lighting.Ambient = rgb(lab.ambient)
Lighting.OutdoorAmbient = rgb(lab.ambient)
Lighting.ClockTime = lab.clock_time
Lighting.Brightness = lab.brightness
local bloom = Instance.new("BloomEffect")
bloom.Intensity, bloom.Size, bloom.Threshold =
    lab.bloom_intensity, lab.bloom_size, lab.bloom_threshold
bloom.Parent = Lighting
local camera = Workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = CFrame.lookAt(vector(lab.camera_position), vector(lab.camera_look))
-- Character is irrelevant to this isolated cosmetic arena.
local function hideCharacter(character)
    for _, item in ipairs(character:GetDescendants()) do
        if item:IsA("BasePart") then
            item.LocalTransparencyModifier = 1
        end
    end
end
if player.Character then
    hideCharacter(player.Character)
end
player.CharacterAdded:Connect(hideCharacter)

local function node(className, parent, properties)
    local item = Instance.new(className)
    if item:IsA("GuiObject") then
        item.BorderSizePixel = 0
    end
    if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
        item.Font = Enum.Font.Gotham
        item.TextSize = lab.text_size
        item.TextColor3 = rgb(lab.text)
    end
    for key, value in pairs(properties) do
        item[key] = value
    end
    item.Parent = parent
    return item
end
local panel = node(
    "Frame",
    gui,
    {
        Name = "Panel",
        Position = UDim2.fromScale(unpack(lab.panel_position)),
        Size = UDim2.fromScale(unpack(lab.panel_size)),
        BackgroundColor3 = rgb(lab.panel),
    }
)
node("UICorner", panel, { CornerRadius = UDim.new(0, lab.corner) })
node(
    "UISizeConstraint",
    panel,
    {
        MinSize = Vector2.new(lab.panel_min_width, 0),
        MaxSize = Vector2.new(lab.panel_max_width, math.huge),
    }
)
node(
    "UIPadding",
    panel,
    {
        PaddingTop = UDim.new(lab.padding, 0),
        PaddingBottom = UDim.new(lab.padding, 0),
        PaddingLeft = UDim.new(lab.padding, 0),
        PaddingRight = UDim.new(lab.padding, 0),
    }
)
node(
    "TextLabel",
    panel,
    {
        Text = lab.title,
        TextSize = lab.title_size,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.fromScale(1, 0.045),
        BackgroundTransparency = 1,
    }
)
node(
    "TextLabel",
    panel,
    {
        Text = lab.subtitle,
        TextColor3 = rgb(lab.accent),
        TextScaled = true,
        Position = UDim2.fromScale(0, 0.05),
        Size = UDim2.fromScale(1, 0.025),
        BackgroundTransparency = 1,
    }
)
node(
    "TextLabel",
    panel,
    {
        Text = lab.help,
        TextWrapped = true,
        TextColor3 = rgb(lab.muted),
        Position = UDim2.fromScale(0, 0.085),
        Size = UDim2.fromScale(1, 0.07),
        BackgroundTransparency = 1,
    }
)
local scroll = node(
    "ScrollingFrame",
    panel,
    {
        Name = "Controls",
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0, 0.17),
        Size = UDim2.fromScale(1, 0.55),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        ScrollBarThickness = 4,
    }
)
node("UIListLayout", scroll, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
local status = node(
    "TextLabel",
    panel,
    {
        Name = "Status",
        Text = lab.footer,
        TextWrapped = true,
        TextColor3 = rgb(lab.muted),
        Position = UDim2.fromScale(0, 0.94),
        Size = UDim2.fromScale(1, 0.06),
        BackgroundTransparency = 1,
    }
)
local current
local slow, paused = false, false
local refreshers = {}
local drag
local dirty = false
local function changed()
    dirty = true
    if current then
        current:update(copy(preset))
    end
    for _, refresh in ipairs(refreshers) do
        refresh()
    end
    status.Text = "Unsaved edits • visible immediately, including while paused."
end
local function slider(parent, field, order)
    local row = node(
        "Frame",
        parent,
        {
            Name = field.key,
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, lab.row_height),
            BackgroundTransparency = 1,
        }
    )
    node(
        "TextLabel",
        row,
        {
            Text = field.label,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.fromScale(0.69, 0.6),
            BackgroundTransparency = 1,
        }
    )
    local input = node(
        "TextBox",
        row,
        {
            Name = "Value",
            Size = UDim2.fromScale(0.28, 0.6),
            Position = UDim2.fromScale(0.7, 0),
            BackgroundColor3 = rgb(lab.field),
            ClearTextOnFocus = false,
        }
    )
    local rail = node(
        "TextButton",
        row,
        {
            Name = "Slider",
            Text = "",
            Size = UDim2.fromScale(0.98, 0.22),
            Position = UDim2.fromScale(0, 0.74),
            BackgroundColor3 = rgb(lab.field),
        }
    )
    local fill = node("Frame", rail, { BackgroundColor3 = rgb(lab.accent) })
    local function refresh()
        input.Text = string.format("%.3g", preset[field.key])
        fill.Size = UDim2.fromScale((preset[field.key] - field.min) / (field.max - field.min), 1)
    end
    local function set(value)
        preset[field.key] =
            math.clamp(math.round(value / field.step) * field.step, field.min, field.max)
        changed()
    end
    rail.InputBegan:Connect(function(event)
        if
            event.UserInputType == Enum.UserInputType.MouseButton1
            or event.UserInputType == Enum.UserInputType.Touch
        then
            drag = function(x)
                local fraction =
                    math.clamp((x - rail.AbsolutePosition.X) / rail.AbsoluteSize.X, 0, 1)
                set(field.min + fraction * (field.max - field.min))
            end
            scroll.ScrollingEnabled = false
            drag(event.Position.X)
        end
    end)
    input.FocusLost:Connect(function()
        local value = tonumber(input.Text)
        if value and value == value and math.abs(value) < math.huge then
            set(value)
        else
            refresh()
        end
    end)
    table.insert(refreshers, refresh)
    refresh()
end
for i, field in ipairs(schema.numbers) do
    slider(scroll, field, i)
end
for i, field in ipairs(schema.colors) do
    local row = node(
        "Frame",
        scroll,
        {
            Name = field.key,
            LayoutOrder = #schema.numbers + i,
            Size = UDim2.new(1, 0, 0, lab.row_height),
            BackgroundTransparency = 1,
        }
    )
    node(
        "TextLabel",
        row,
        {
            Text = field.label .. " (hex)",
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.fromScale(0.65, 0.8),
            BackgroundTransparency = 1,
        }
    )
    local input = node(
        "TextBox",
        row,
        {
            Name = "Hex",
            Size = UDim2.fromScale(0.33, 0.8),
            Position = UDim2.fromScale(0.65, 0),
            BackgroundColor3 = rgb(lab.field),
            ClearTextOnFocus = false,
        }
    )
    local function refresh()
        input.Text = rgb(preset[field.key]):ToHex()
        input.TextColor3 = rgb(preset[field.key])
    end
    input.FocusLost:Connect(function()
        local hex = input.Text:gsub("#", "")
        if #hex == 6 and hex:match("^%x+$") then
            preset[field.key] = {
                tonumber(hex:sub(1, 2), 16),
                tonumber(hex:sub(3, 4), 16),
                tonumber(hex:sub(5, 6), 16),
            }
            changed()
        else
            refresh()
        end
    end)
    table.insert(refreshers, refresh)
    refresh()
end
UserInputService.InputChanged:Connect(function(event)
    if
        drag
        and (
            event.UserInputType == Enum.UserInputType.MouseMovement
            or event.UserInputType == Enum.UserInputType.Touch
        )
    then
        drag(event.Position.X)
    end
end)
UserInputService.InputEnded:Connect(function(event)
    if
        event.UserInputType == Enum.UserInputType.MouseButton1
        or event.UserInputType == Enum.UserInputType.Touch
    then
        drag = nil
        scroll.ScrollingEnabled = true
    end
end)
local controls = node(
    "Frame",
    panel,
    {
        Position = UDim2.fromScale(0, 0.81),
        Size = UDim2.fromScale(1, 0.12),
        BackgroundTransparency = 1,
    }
)
node(
    "UIGridLayout",
    controls,
    {
        CellSize = UDim2.fromScale(0.31, 0.45),
        CellPadding = UDim2.fromScale(0.035, 0.08),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }
)
local function button(text, order, callback)
    local b = node(
        "TextButton",
        controls,
        { Name = text, Text = text, LayoutOrder = order, BackgroundColor3 = rgb(lab.field) }
    )
    node("UICorner", b, { CornerRadius = UDim.new(0, lab.corner) })
    b.Activated:Connect(callback)
    return b
end
local function cast(useSaved)
    if current then
        current:stop()
    end
    if useSaved then
        current = CombatFX.play(
            { pattern = "impact", vfx = "crystal_eruption" },
            { point = vector(lab.target_position) }
        )
        status.Text = "Playing the saved preset through CombatFX.play."
    else
        current = CombatFX.play({ pattern = "impact", vfx = "crystal_eruption" }, {
            point = vector(lab.target_position),
            vfxPreview = { preset = copy(preset), persistent = true },
        })
    end
    current.speed = slow and lab.slow_speed or lab.normal_speed
    current.paused = false
    paused = false
end
button("Cast", 1, function()
    cast(false)
end)
local pauseButton
pauseButton = button("Pause", 2, function()
    if not current or current.stopped then
        cast(false)
    end
    paused = not paused
    current.paused = paused
    pauseButton.Text = paused and "Resume" or "Pause"
end)
local slowButton
slowButton = button("Slow", 3, function()
    slow = not slow
    slowButton.Text = slow and "Speed: ¼" or "Slow"
    if current then
        current.speed = slow and lab.slow_speed or lab.normal_speed
    end
end)
local saving = false
button("Save", 4, function()
    if saving then
        return
    end
    saving = true
    local snapshot = copy(preset)
    status.Text = "Saving…"
    local ok, success, message = pcall(function()
        local remote = ReplicatedStorage:WaitForChild("VFXLabSave", lab.save_timeout)
        if not remote then
            return false, "Save bridge unavailable."
        end
        return remote:InvokeServer(snapshot)
    end)
    saving = false
    if ok and success then
        for key, value in pairs(snapshot) do
            saved[key] = value
        end
        dirty = false
        status.Text = message
    else
        status.Text = ok and tostring(message) or "Save failed. Start the local preset bridge."
    end
end)
button("Saved cast", 5, function()
    cast(true)
end)
button("Reset", 6, function()
    preset = copy(saved)
    changed()
    dirty = false
    cast(false)
    status.Text = "Restored the saved preset."
end)
local timeLabel = node(
    "TextLabel",
    panel,
    {
        Name = "Time",
        Text = "",
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0, 0.735),
        Size = UDim2.fromScale(1, 0.028),
        TextColor3 = rgb(lab.muted),
    }
)
local scrub = node(
    "TextButton",
    panel,
    {
        Name = "Timeline",
        Text = "",
        BackgroundColor3 = rgb(lab.field),
        Position = UDim2.fromScale(0, 0.773),
        Size = UDim2.fromScale(1, 0.018),
    }
)
local progress = node("Frame", scrub, { BackgroundColor3 = rgb(lab.accent) })
scrub.InputBegan:Connect(function(event)
    if
        event.UserInputType ~= Enum.UserInputType.MouseButton1
        and event.UserInputType ~= Enum.UserInputType.Touch
    then
        return
    end
    if not current or current.stopped then
        cast(false)
    end
    paused = true
    current.paused = true
    pauseButton.Text = "Resume"
    drag = function(x)
        current:seek(
            math.clamp((x - scrub.AbsolutePosition.X) / scrub.AbsoluteSize.X, 0, 1)
                * Timeline.duration(current.preset)
        )
    end
    drag(event.Position.X)
end)
RunService.Heartbeat:Connect(function()
    if current then
        local duration = Timeline.duration(current.preset)
        progress.Size = UDim2.fromScale(math.clamp(current.time / duration, 0, 1), 1)
        timeLabel.Text = string.format(
            "%.2fs / %.2fs%s",
            current.time,
            duration,
            dirty and "  •  edited" or ""
        )
    end
end)
-- Studio diagnostics use this local-only bindable; no production remotes or damage.
local probe = Instance.new("BindableFunction")
probe.Name = "Probe"
probe.OnInvoke = function(action, value)
    if action == "seek" then
        current.paused = true
        current:seek(value)
    elseif action == "set" then
        preset[value.key] = value.value
        changed()
    elseif action == "cast" then
        cast(value == "saved")
    end
    return {
        time = current.time,
        count = #current.model:GetChildren(),
        preset = copy(preset),
        stopped = current.stopped == true,
    }
end
probe.Parent = gui
cast(false)
