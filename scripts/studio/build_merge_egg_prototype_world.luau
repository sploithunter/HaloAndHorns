-- Run in Roblox Studio Edit mode. Rebuilds only Workspace.Maps.MergeEggPrototype.
-- The result is one persistent authored Model: a continuous floor strip plus fixed walls.

local Workspace = game:GetService("Workspace")

local maps = Workspace:FindFirstChild("Maps")
if not maps then
    maps = Instance.new("Folder")
    maps.Name = "Maps"
    maps.Parent = Workspace
end

local previous = maps:FindFirstChild("MergeEggPrototype")
if previous then
    previous:Destroy()
end

local world = Instance.new("Model")
world.Name = "MergeEggPrototype"
world:SetAttribute("MapKind", "AuthoredPrototype")
world:SetAttribute("Phase", 5)
world:SetAttribute("UsesTileSystem", false)
world:SetAttribute("UsesTileStreaming", false)
-- Workspace streaming still exists globally. Treat the tiny venue as one atomic model so
-- the continuous floor and its walls arrive together; this is not a chunk/tile lifecycle.
world.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
world.Parent = maps

local ORIGIN = Vector3.new(-16000, 0, 0)

local function part(name, size, cframe, color, material, transparency)
    local value = Instance.new("Part")
    value.Name = name
    value.Anchored = true
    value.CanCollide = true
    value.CanTouch = false
    value.CanQuery = true
    value.Size = size
    value.CFrame = cframe
    value.Color = color
    value.Material = material
    value.Transparency = transparency or 0
    value.TopSurface = Enum.SurfaceType.Smooth
    value.BottomSurface = Enum.SurfaceType.Smooth
    value.Parent = world
    return value
end

local LAND = Color3.fromRGB(93, 125, 72)
local WALL = Color3.fromRGB(64, 71, 62)
local STONE = Color3.fromRGB(99, 108, 98)
local GOLD = Color3.fromRGB(245, 190, 72)
local BLUE = Color3.fromRGB(86, 180, 216)
local RED = Color3.fromRGB(197, 82, 72)
local BORDER = Color3.fromRGB(255, 126, 64)

-- Preserve the complete hatcher/objective end and remove the long empty approach half. The strip
-- now runs from Z -300 to Z 0, centered at -150.
local floor = part(
    "LandStrip",
    Vector3.new(96, 2, 300),
    CFrame.new(ORIGIN + Vector3.new(0, 0, -150)),
    LAND,
    Enum.Material.Ground
)
world.PrimaryPart = floor

part(
    "WestWall",
    Vector3.new(2, 14, 300),
    CFrame.new(ORIGIN + Vector3.new(-49, 7, -150)),
    WALL,
    Enum.Material.Slate
)
part(
    "EastWall",
    Vector3.new(2, 14, 300),
    CFrame.new(ORIGIN + Vector3.new(49, 7, -150)),
    WALL,
    Enum.Material.Slate
)
part(
    "NorthEndWall",
    Vector3.new(100, 14, 2),
    CFrame.new(ORIGIN + Vector3.new(0, 7, -301)),
    WALL,
    Enum.Material.Slate
)
part(
    "SouthEndWall",
    Vector3.new(100, 14, 2),
    CFrame.new(ORIGIN + Vector3.new(0, 7, 1)),
    WALL,
    Enum.Material.Slate
)

local function anchor(name, offset, lookAtOffset)
    local position = ORIGIN + offset
    local look = ORIGIN + (lookAtOffset or (offset + Vector3.new(0, 0, 1)))
    local value = part(
        name,
        Vector3.new(6, 1, 6),
        CFrame.lookAt(position, Vector3.new(look.X, position.Y, look.Z)),
        Color3.new(1, 1, 1),
        Enum.Material.SmoothPlastic,
        1
    )
    value.CanCollide = false
    return value
end

anchor("PlayerSpawn", Vector3.new(0, 2, -268), Vector3.new(0, 2, -220))
anchor("HatcherSpawn", Vector3.new(0, 2, -218), Vector3.new(0, 2, -170))
-- Every wave emerges from this temporary portal rather than appearing across the whole back edge.
-- Runtime hides the visual after the final queued enemy is out; the solid end wall remains behind
-- them as a drive-back surface.
local spawnArea = anchor("EnemySpawnArea", Vector3.new(0, 2, -5), Vector3.new(0, 2, -200))
spawnArea.Size = Vector3.new(24, 1, 4)

local portal = Instance.new("Model")
portal.Name = "EnemyPortalVisual"
portal:SetAttribute("RuntimeTransientVisual", true)
portal.Parent = world

local function portalPart(name, size, offset, color, transparency)
    local value =
        part(name, size, CFrame.new(ORIGIN + offset), color, Enum.Material.Neon, transparency)
    value.CanCollide = false
    value.CanTouch = false
    value:SetAttribute("PortalVisibleTransparency", transparency or 0)
    value.Parent = portal
    return value
end

portalPart(
    "PortalCore",
    Vector3.new(25, 12, 0.6),
    Vector3.new(0, 7, -1.1),
    Color3.fromRGB(116, 56, 255),
    0.22
)
portalPart(
    "PortalLeft",
    Vector3.new(3, 16, 2),
    Vector3.new(-14, 8, -0.8),
    Color3.fromRGB(66, 24, 145),
    0.05
)
portalPart(
    "PortalRight",
    Vector3.new(3, 16, 2),
    Vector3.new(14, 8, -0.8),
    Color3.fromRGB(66, 24, 145),
    0.05
)
portalPart(
    "PortalCrown",
    Vector3.new(31, 3, 2),
    Vector3.new(0, 15, -0.8),
    Color3.fromRGB(66, 24, 145),
    0.05
)

local portalCore = portal:FindFirstChild("PortalCore")
local portalLight = Instance.new("PointLight")
portalLight.Name = "PortalLight"
portalLight.Color = Color3.fromRGB(158, 91, 255)
portalLight.Brightness = 4
portalLight.Range = 34
portalLight.Parent = portalCore

local portalParticles = Instance.new("ParticleEmitter")
portalParticles.Name = "PortalParticles"
portalParticles.Color =
    ColorSequence.new(Color3.fromRGB(210, 170, 255), Color3.fromRGB(83, 35, 190))
portalParticles.LightEmission = 1
portalParticles.Lifetime = NumberRange.new(0.5, 1.1)
portalParticles.Rate = 34
portalParticles.Speed = NumberRange.new(0.5, 2)
portalParticles.SpreadAngle = Vector2.new(180, 180)
portalParticles.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.7),
    NumberSequenceKeypoint.new(0.5, 1.7),
    NumberSequenceKeypoint.new(1, 0),
})
portalParticles.Parent = portalCore

local finishLine = part(
    "EnemyFinishLine",
    Vector3.new(84, 0.3, 4),
    CFrame.new(ORIGIN + Vector3.new(0, 1.2, -255)),
    BORDER,
    Enum.Material.Neon
)
finishLine.CanCollide = false

-- The reserve-engagement boundary is visible and authoritative: runtime projects enemy movement
-- across this exact plane toward EnemyFinishLine. It sits 43 studs in front of HatcherSpawn so a
-- large enemy has a readable emergency zone before it can overlap a captain.
local bulwarkLine = part(
    "BulwarkLine",
    Vector3.new(84, 0.25, 2),
    CFrame.new(ORIGIN + Vector3.new(0, 1.15, -175)),
    GOLD,
    Enum.Material.Neon,
    0.1
)
bulwarkLine.CanCollide = false

local bulwarkGroundLabel = part(
    "BulwarkGroundLabel",
    Vector3.new(62, 0.08, 8),
    CFrame.new(ORIGIN + Vector3.new(0, 1.08, -181)),
    Color3.fromRGB(24, 30, 43),
    Enum.Material.SmoothPlastic,
    1
)
bulwarkGroundLabel.CanCollide = false

local bulwarkLabel = Instance.new("SurfaceGui")
bulwarkLabel.Name = "BulwarkGroundSurface"
bulwarkLabel.Face = Enum.NormalId.Top
bulwarkLabel.CanvasSize = Vector2.new(160, 1240)
bulwarkLabel.LightInfluence = 0
bulwarkLabel.ZOffset = 1
bulwarkLabel.Parent = bulwarkGroundLabel

local bulwarkText = Instance.new("TextLabel")
bulwarkText.AnchorPoint = Vector2.new(0.5, 0.5)
bulwarkText.Position = UDim2.fromScale(0.5, 0.5)
bulwarkText.Size = UDim2.fromOffset(1180, 150)
bulwarkText.Rotation = -90
bulwarkText.BackgroundTransparency = 1
bulwarkText.BorderSizePixel = 0
bulwarkText.Font = Enum.Font.GothamBold
bulwarkText.Text = "BULWARK  •  ALL TEAMS ENGAGE"
bulwarkText.TextColor3 = GOLD
bulwarkText.TextStrokeColor3 = Color3.fromRGB(24, 30, 43)
bulwarkText.TextStrokeTransparency = 0.15
bulwarkText.TextScaled = false
bulwarkText.TextSize = 75
bulwarkText.TextWrapped = false
bulwarkText.Parent = bulwarkLabel

part(
    "StartPlatform",
    Vector3.new(84, 1, 72),
    CFrame.new(ORIGIN + Vector3.new(0, 1.5, -250)),
    STONE,
    Enum.Material.Cobblestone
)
local hatcher = part(
    "HatcherControl",
    Vector3.new(12, 3, 12),
    CFrame.new(ORIGIN + Vector3.new(0, 3, -230)),
    GOLD,
    Enum.Material.Neon
)
hatcher.Shape = Enum.PartType.Cylinder
hatcher.CFrame *= CFrame.Angles(0, 0, math.pi / 2)

part(
    "ExitControl",
    Vector3.new(10, 5, 10),
    CFrame.new(ORIGIN + Vector3.new(-30, 4, -275)),
    BLUE,
    Enum.Material.Neon
)
part(
    "ResetControl",
    Vector3.new(10, 5, 10),
    CFrame.new(ORIGIN + Vector3.new(30, 4, -275)),
    RED,
    Enum.Material.Neon
)

local bounds = anchor("ArenaBounds", Vector3.new(0, 8, -150))
bounds.Size = Vector3.new(92, 16, 298)

print("[MergeEggPrototype] authored Workspace.Maps.MergeEggPrototype")
