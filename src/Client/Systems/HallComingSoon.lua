--[[
    HallComingSoon

    Frozen closer walls. Not HallGates — they never unlock. A citrine
    SurfaceGui on each thin face reads "Coming Soon".
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
local PanelChrome = require(script.Parent.Parent.UI.Components.PanelChrome)

local HallComingSoon = {}
local started = false
local hallConfig = ConfigLoader:LoadConfig("hall_of_worlds") or {}
local appearance = hallConfig.gate_appearance or {}
local coming = hallConfig.coming_soon or {}
local LABEL_PREFIX = "HallComingSoonLabel"

local function applyAppearance(wall)
    local material = Enum.Material[appearance.material or "Ice"]
    if material then
        wall.Material = material
    end
    local color = appearance.color
    if type(color) == "table" then
        wall.Color = Color3.fromRGB(color[1] or 226, color[2] or 236, color[3] or 242)
    end
    if type(appearance.transparency) == "number" then
        wall.Transparency = appearance.transparency
    end
    if type(appearance.reflectance) == "number" then
        wall.Reflectance = appearance.reflectance
    end
end

local function wallFaces(wall)
    if wall.Size.X < wall.Size.Z then
        return { Enum.NormalId.Left, Enum.NormalId.Right }
    end
    return { Enum.NormalId.Front, Enum.NormalId.Back }
end

local function ensureLabel(wall, face)
    local name = LABEL_PREFIX .. "_" .. face.Name
    local existing = wall:FindFirstChild(name)
    if existing and not existing:IsA("SurfaceGui") then
        existing:Destroy()
        existing = nil
    end
    if existing then
        existing:Destroy()
    end

    local gui = Instance.new("SurfaceGui")
    gui.Name = name
    gui.Face = face
    gui.AlwaysOnTop = false
    gui.LightInfluence = 0
    gui.Active = false
    gui.ResetOnSpawn = false
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = coming.pixels_per_stud or 40
    gui.ZOffset = 0.05
    gui.Parent = wall

    local holder = Instance.new("Frame")
    holder.Name = "Card"
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.fromScale(0.5, 0.5)
    holder.Size = UDim2.fromOffset(coming.width or 420, coming.height or 110)
    holder.BackgroundTransparency = 1
    holder.Parent = gui

    PanelChrome.pillPanel(holder, "citrine", 1)
    PanelChrome.pillBorder(holder, "citrine", 2, 0, 0.12)

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(0.86, 0.62)
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.fromScale(0.5, 0.5)
    label.Font = Enum.Font.GothamBlack
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(64, 46, 8)
    label.Text = coming.text or "Coming Soon"
    label.ZIndex = 5
    label.Parent = holder

    return gui
end

local function paint(wall)
    if not wall:IsA("BasePart") then
        return
    end
    applyAppearance(wall)
    wall.CanCollide = true
    wall.CanTouch = false
    for _, face in ipairs(wallFaces(wall)) do
        ensureLabel(wall, face)
    end
end

function HallComingSoon.start()
    if started then
        return
    end
    started = true

    local function refresh()
        for _, wall in ipairs(CollectionService:GetTagged("HallComingSoon")) do
            paint(wall)
        end
    end

    CollectionService:GetInstanceAddedSignal("HallComingSoon"):Connect(function(wall)
        paint(wall)
    end)
    task.defer(refresh)
end

return HallComingSoon
