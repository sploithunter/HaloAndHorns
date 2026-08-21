--[[
    HallRouteGates

    Hall progression remains server-authoritative in ZoneService. This client
    presentation lowers an authored wall after its target area appears in
    UnlockedAreasJson and shows one citrine cost pill instead of the baked
    SurfaceGui + default E prompt. Clicking the pill asks ZoneService to unlock;
    walking through is the travel.
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
local HallOfWorldsLogic = require(ReplicatedStorage.Shared.Game.HallOfWorldsLogic)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local PanelChrome = require(script.Parent.Parent.UI.Components.PanelChrome)

local HallRouteGates = {}
local started = false
local hallConfig = ConfigLoader:LoadConfig("hall_of_worlds") or {}
local areasConfig = ConfigLoader:LoadConfig("areas") or {}
local appearance = hallConfig.gate_appearance or {}
local promptLook = hallConfig.gate_prompt or {}
local PILL_NAME = "HallGateUnlockPill"

local function applyAppearance(gate)
    local material = Enum.Material[appearance.material or "Ice"]
    if material then
        gate.Material = material
    end
    local color = appearance.color
    if type(color) == "table" then
        gate.Color = Color3.fromRGB(color[1] or 226, color[2] or 236, color[3] or 242)
    end
    if type(appearance.transparency) == "number" then
        gate.Transparency = appearance.transparency
    end
    if type(appearance.reflectance) == "number" then
        gate.Reflectance = appearance.reflectance
    end
end

local function decodeUnlocked(player)
    local result = {}
    local raw = player:GetAttribute("UnlockedAreasJson")
    if type(raw) ~= "string" or raw == "" then
        return result
    end
    local ok, values = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok or type(values) ~= "table" then
        return result
    end
    for _, areaId in ipairs(values) do
        result[tostring(areaId)] = true
    end
    return result
end

local function unlockFor(gate)
    local target =
        tostring(gate:GetAttribute("TargetAreaId") or gate:GetAttribute("TargetZoneId") or "")
    local zone = areasConfig.zones and areasConfig.zones[target]
    return zone and zone.unlock, target
end

local function wallFaces(gate)
    if gate.Size.X < gate.Size.Z then
        return { Enum.NormalId.Left, Enum.NormalId.Right }
    end
    return { Enum.NormalId.Front, Enum.NormalId.Back }
end

local function destroyFloatingPills(gate)
    local attachment = gate:FindFirstChild("ZoneTravelPromptAttachment")
    if attachment then
        local floating = attachment:FindFirstChild(PILL_NAME)
        if floating then
            floating:Destroy()
        end
    end
    local leftover = gate:FindFirstChild(PILL_NAME)
    if leftover and leftover:IsA("BillboardGui") then
        leftover:Destroy()
    end
end

local function ensureSurfacePill(gate, face)
    local name = PILL_NAME .. "_" .. face.Name
    local existing = gate:FindFirstChild(name)
    if existing and not existing:IsA("SurfaceGui") then
        existing:Destroy()
        existing = nil
    end
    if existing then
        return existing
    end

    local gui = Instance.new("SurfaceGui")
    gui.Name = name
    gui.Face = face
    gui.AlwaysOnTop = false
    gui.LightInfluence = 0
    gui.Active = true
    gui.ResetOnSpawn = false
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = promptLook.pixels_per_stud or 40
    gui.ZOffset = 0.05
    gui.Parent = gate

    local button = Instance.new("TextButton")
    button.Name = "Unlock"
    button.AnchorPoint = Vector2.new(0.5, 0.5)
    button.Position = UDim2.fromScale(0.5, 0.5)
    button.Size = UDim2.fromOffset(promptLook.width or 320, promptLook.height or 88)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.AutoButtonColor = true
    button.Parent = gui

    local key = promptLook.pill_key or "citrine"
    PanelChrome.pillPanel(button, key, 1)
    PanelChrome.pillBorder(button, key, 2, 0, 0.12)

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(0.86, 0.62)
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.fromScale(0.5, 0.5)
    label.Font = Enum.Font.GothamBlack
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(64, 46, 8)
    label.ZIndex = 5
    label.Parent = button

    button.Activated:Connect(function()
        local _, target = unlockFor(gate)
        if target ~= "" then
            Signals.UnlockZoneRequest:FireServer({ zoneId = target })
        end
    end)

    return gui
end

local function paintPill(gate, open)
    local stale = gate:FindFirstChild("HallGateLabel")
    if stale then
        stale:Destroy()
    end
    destroyFloatingPills(gate)

    local prompt = gate:FindFirstChild("ZoneTravelPrompt", true)
    if prompt and prompt:IsA("ProximityPrompt") then
        prompt.Style = Enum.ProximityPromptStyle.Custom
        prompt.Enabled = not open
        local unlock = unlockFor(gate)
        prompt.ActionText = HallOfWorldsLogic.gateButtonText(unlock)
    end

    if open then
        for _, child in ipairs(gate:GetChildren()) do
            if child.Name:sub(1, #PILL_NAME) == PILL_NAME then
                child:Destroy()
            end
        end
        return
    end

    local text = HallOfWorldsLogic.gateButtonText(unlockFor(gate))
    for _, face in ipairs(wallFaces(gate)) do
        local gui = ensureSurfacePill(gate, face)
        gui.Enabled = true
        local label = gui:FindFirstChild("Label", true)
        if label and label:IsA("TextLabel") then
            label.Text = text
        end
    end
end

local function setGateOpen(gate, open)
    if not gate:IsA("BasePart") then
        return
    end
    gate.LocalTransparencyModifier = open and 1 or 0
    gate.CanCollide = not open
    gate.CanTouch = not open
    paintPill(gate, open)
end

function HallRouteGates.start()
    if started then
        return
    end
    started = true

    local player = Players.LocalPlayer

    local function refresh()
        local unlocked = decodeUnlocked(player)
        for _, gate in ipairs(CollectionService:GetTagged("HallGate")) do
            if gate:IsA("BasePart") then
                applyAppearance(gate)
            end
            local target = gate:GetAttribute("TargetAreaId") or gate:GetAttribute("TargetZoneId")
            setGateOpen(gate, unlocked[tostring(target or "")] == true)
        end
    end

    player:GetAttributeChangedSignal("UnlockedAreasJson"):Connect(refresh)
    CollectionService:GetInstanceAddedSignal("HallGate"):Connect(function()
        task.defer(refresh)
    end)
    task.defer(refresh)
end

return HallRouteGates
