--[[
    World Travel power picker. The server sends only destinations that pass all realm and saved-area
    unlock checks. The client presents realm -> origin and submits identifiers; it never decides
    permission, cost, or coordinates.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local PanelChrome = require(script.Parent.Parent.UI.Components.PanelChrome)
local UIViewportScale = require(script.Parent.Parent.UI.UIViewportScale)

local WorldTravelMenu = {}
local started = false
local gui
local shell
local content
local statusLabel
local catalog = {}
local selectedLayer
local pending = false

local COLORS = {
    panel = Color3.fromRGB(28, 30, 41),
    card = Color3.fromRGB(44, 47, 62),
    cardHover = Color3.fromRGB(57, 63, 82),
    white = Color3.fromRGB(248, 249, 253),
    body = Color3.fromRGB(201, 207, 222),
    muted = Color3.fromRGB(157, 165, 184),
    blue = Color3.fromRGB(58, 139, 224),
    green = Color3.fromRGB(37, 190, 105),
    gold = Color3.fromRGB(245, 180, 50),
    red = Color3.fromRGB(238, 91, 91),
}

local function corner(parent, radius)
    local value = Instance.new("UICorner")
    value.CornerRadius = UDim.new(0, radius)
    value.Parent = parent
end

local function textLabel(parent, name, text, size, position, textSize, color, font)
    local value = Instance.new("TextLabel")
    value.Name = name
    value.BackgroundTransparency = 1
    value.Size = size
    value.Position = position or UDim2.new()
    value.Text = text
    value.TextColor3 = color or COLORS.white
    value.TextSize = textSize or 20
    value.Font = font or Enum.Font.GothamMedium
    value.TextWrapped = true
    value.TextXAlignment = Enum.TextXAlignment.Left
    value.TextYAlignment = Enum.TextYAlignment.Center
    value.ZIndex = 104
    value.Parent = parent
    return value
end

local function clearContent()
    if not content then
        return
    end
    for _, child in ipairs(content:GetChildren()) do
        child:Destroy()
    end
end

local function destroy()
    if gui then
        gui:Destroy()
    end
    gui = nil
    shell = nil
    content = nil
    statusLabel = nil
    selectedLayer = nil
    pending = false
end

local function readableCurrency(currency)
    local words = {}
    for word in tostring(currency or "tokens"):gmatch("[^_]+") do
        words[#words + 1] = word:sub(1, 1):upper() .. word:sub(2)
    end
    return table.concat(words, " ")
end

local function setStatus(text, isError)
    if statusLabel then
        statusLabel.Text = text or ""
        statusLabel.TextColor3 = isError and COLORS.red or COLORS.body
    end
end

local function makeButton(parent, name, title, detail, y, accent, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.AutoButtonColor = false
    button.Text = ""
    button.Size = UDim2.new(1, -24, 0, 78)
    button.Position = UDim2.fromOffset(12, y)
    button.BackgroundColor3 = COLORS.card
    button.BorderSizePixel = 0
    button.ZIndex = 103
    button.Parent = parent
    corner(button, 13)

    local marker = Instance.new("Frame")
    marker.Name = "Accent"
    marker.Size = UDim2.fromOffset(7, 54)
    marker.Position = UDim2.fromOffset(12, 12)
    marker.BackgroundColor3 = accent
    marker.BorderSizePixel = 0
    marker.ZIndex = 104
    marker.Parent = button
    corner(marker, 4)

    textLabel(
        button,
        "Title",
        title,
        UDim2.new(1, -90, 0, 34),
        UDim2.fromOffset(32, 8),
        24,
        COLORS.white,
        Enum.Font.GothamBold
    )
    textLabel(
        button,
        "Detail",
        detail,
        UDim2.new(1, -90, 0, 27),
        UDim2.fromOffset(32, 42),
        17,
        COLORS.body,
        Enum.Font.Gotham
    )
    local arrow = textLabel(
        button,
        "Arrow",
        "›",
        UDim2.fromOffset(42, 54),
        UDim2.new(1, -58, 0, 12),
        38,
        accent,
        Enum.Font.GothamBold
    )
    arrow.TextXAlignment = Enum.TextXAlignment.Center

    button.MouseEnter:Connect(function()
        if not pending then
            button.BackgroundColor3 = COLORS.cardHover
        end
    end)
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = COLORS.card
    end)
    button.Activated:Connect(function()
        if not pending then
            callback()
        end
    end)
    return button
end

local renderOrigins

local function renderRealms()
    selectedLayer = nil
    clearContent()
    shell.header.Title.Text = "World Travel — Choose a Realm"

    textLabel(
        content,
        "Instruction",
        "Only realms and origins you have unlocked are shown.",
        UDim2.new(1, -24, 0, 38),
        UDim2.fromOffset(12, 2),
        18,
        COLORS.body
    )

    if #catalog == 0 then
        local empty = textLabel(
            content,
            "Empty",
            "No unlocked travel destinations are currently available.",
            UDim2.new(1, -60, 0, 100),
            UDim2.fromOffset(30, 90),
            22,
            COLORS.muted
        )
        empty.TextXAlignment = Enum.TextXAlignment.Center
        return
    end

    local y = 48
    for _, layer in ipairs(catalog) do
        local details = tostring(#(layer.origins or {})) .. " unlocked origin"
        if #(layer.origins or {}) ~= 1 then
            details ..= "s"
        end
        if (tonumber(layer.cost) or 0) > 0 then
            details ..= ("  •  %d %s"):format(layer.cost, readableCurrency(layer.currency))
        elseif layer.current then
            details ..= "  •  Current realm"
        else
            details ..= "  •  Free travel"
        end
        local accent = layer.current and COLORS.green or COLORS.blue
        makeButton(content, "Realm_" .. layer.id, layer.label, details, y, accent, function()
            selectedLayer = layer
            renderOrigins()
        end)
        y += 88
    end
    content.CanvasSize = UDim2.fromOffset(0, y + 8)
end

renderOrigins = function()
    clearContent()
    local layer = selectedLayer
    if not layer then
        renderRealms()
        return
    end
    shell.header.Title.Text = "World Travel — " .. tostring(layer.label)

    local back = Instance.new("TextButton")
    back.Name = "Back"
    back.Size = UDim2.fromOffset(116, 38)
    back.Position = UDim2.fromOffset(12, 4)
    back.BackgroundColor3 = COLORS.card
    back.BorderSizePixel = 0
    back.Text = "‹  REALMS"
    back.TextColor3 = COLORS.white
    back.TextSize = 17
    back.Font = Enum.Font.GothamBold
    back.ZIndex = 104
    back.Parent = content
    corner(back, 9)
    back.Activated:Connect(renderRealms)

    textLabel(
        content,
        "Instruction",
        "Choose an unlocked origin in " .. tostring(layer.label) .. ".",
        UDim2.new(1, -164, 0, 38),
        UDim2.fromOffset(148, 4),
        18,
        COLORS.body
    )

    local y = 52
    for _, origin in ipairs(layer.origins or {}) do
        local detail = origin.current and "You are here" or "Travel to this origin"
        local accent = origin.current and COLORS.green or COLORS.gold
        makeButton(content, "Origin_" .. origin.id, origin.label, detail, y, accent, function()
            pending = true
            setStatus("Traveling to " .. layer.label .. " — " .. origin.label .. "…", false)
            Signals.WorldTravel_Select:FireServer({
                layer = layer.id,
                origin = origin.id,
            })
        end)
        y += 88
    end
    content.CanvasSize = UDim2.fromOffset(0, y + 8)
end

local function show(payload)
    destroy()
    catalog = type(payload) == "table" and payload.layers or {}

    gui = Instance.new("ScreenGui")
    gui.Name = "WorldTravelMenu"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 126

    local dim = Instance.new("Frame")
    dim.Name = "Dim"
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = Color3.fromRGB(5, 7, 14)
    dim.BackgroundTransparency = 0.22
    dim.BorderSizePixel = 0
    dim.Parent = gui

    shell = PanelChrome.build(gui, {
        name = "WorldTravelPanel",
        title = "World Travel",
        size = UDim2.fromOffset(820, 560),
        onClose = destroy,
    })
    UIViewportScale.attach(shell.frame, { min = 0.34 })

    content = Instance.new("ScrollingFrame")
    content.Name = "Destinations"
    content.Size = UDim2.new(1, -42, 1, -132)
    content.Position = UDim2.fromOffset(21, 70)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 7
    content.ScrollBarImageColor3 = COLORS.blue
    content.CanvasSize = UDim2.new()
    content.ZIndex = 102
    content.Parent = shell.frame

    statusLabel = textLabel(
        shell.frame,
        "Status",
        "Select a realm, then an origin.",
        UDim2.new(1, -44, 0, 38),
        UDim2.new(0, 22, 1, -48),
        17,
        COLORS.body
    )
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center

    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    renderRealms()
end

function WorldTravelMenu.start()
    if started then
        return
    end
    started = true
    Signals.WorldTravel_Open.OnClientEvent:Connect(show)
    Signals.WorldTravel_Result.OnClientEvent:Connect(function(result)
        pending = false
        if type(result) == "table" and result.ok then
            destroy()
            return
        end
        local reason = type(result) == "table" and result.reason or "travel_failed"
        local messages = {
            destination_locked = "That destination is no longer unlocked.",
            insufficient_tokens = "You no longer have enough realm tokens.",
            character_not_ready = "Your character is not ready. Try again.",
            missing_spawn = "That destination is temporarily unavailable.",
            not_enough_focus = "You do not have enough Focus.",
            on_cooldown = "World Travel is still recharging.",
        }
        setStatus(messages[reason] or "Travel failed. Please try again.", true)
    end)
end

return WorldTravelMenu
