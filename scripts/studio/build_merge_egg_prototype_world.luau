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
world:SetAttribute("Phase", 6)
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

local function wallButton(name, size, cframe, color, title, subtitle)
    local value = part(name, size, cframe, color, Enum.Material.Neon)
    value.CanCollide = false

    local surface = Instance.new("SurfaceGui")
    surface.Name = name .. "Surface"
    surface.Face = Enum.NormalId.Front
    surface.CanvasSize = Vector2.new(720, 280)
    surface.LightInfluence = 0
    surface.Parent = value

    local heading = Instance.new("TextLabel")
    heading.BackgroundTransparency = 1
    heading.Position = UDim2.fromScale(0.04, 0.08)
    heading.Size = UDim2.fromScale(0.92, 0.52)
    heading.Font = Enum.Font.GothamBlack
    heading.Text = title
    heading.TextColor3 = Color3.new(1, 1, 1)
    heading.TextScaled = true
    heading.Parent = surface

    local detail = Instance.new("TextLabel")
    detail.BackgroundTransparency = 1
    detail.Position = UDim2.fromScale(0.04, 0.62)
    detail.Size = UDim2.fromScale(0.92, 0.24)
    detail.Font = Enum.Font.GothamBold
    detail.Text = subtitle
    detail.TextColor3 = Color3.fromRGB(28, 35, 45)
    detail.TextScaled = true
    detail.Parent = surface
    return value
end

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
local hatcherSpawn = anchor("HatcherSpawn", Vector3.new(0, 2, -218), Vector3.new(0, 2, -170))
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

-- This is deliberately separate from the BulwarkLine. Crossing the yellow line opens an enemy to
-- every reserve team; crossing this red line is the actual breach telemetry boundary. The gap to
-- EnemyFinishLine is the current no-windup prototype window before an installed hatcher egg is hit.
local breachLine = part(
    "BreachLine",
    Vector3.new(84, 0.25, 2),
    CFrame.new(ORIGIN + Vector3.new(0, 1.16, -205)),
    RED,
    Enum.Material.Neon,
    0.05
)
breachLine.CanCollide = false

local breachGroundLabel = part(
    "BreachGroundLabel",
    Vector3.new(62, 0.08, 8),
    CFrame.new(ORIGIN + Vector3.new(0, 1.09, -199)),
    Color3.fromRGB(24, 30, 43),
    Enum.Material.SmoothPlastic,
    1
)
breachGroundLabel.CanCollide = false

local breachLabel = Instance.new("SurfaceGui")
breachLabel.Name = "BreachGroundSurface"
breachLabel.Face = Enum.NormalId.Top
breachLabel.CanvasSize = Vector2.new(160, 1240)
breachLabel.LightInfluence = 0
breachLabel.ZOffset = 1
breachLabel.Parent = breachGroundLabel

local breachText = Instance.new("TextLabel")
breachText.AnchorPoint = Vector2.new(0.5, 0.5)
breachText.Position = UDim2.fromScale(0.5, 0.5)
breachText.Size = UDim2.fromOffset(1180, 150)
breachText.Rotation = -90
breachText.BackgroundTransparency = 1
breachText.BorderSizePixel = 0
breachText.Font = Enum.Font.GothamBold
breachText.Text = "BREACH  •  EGGS EXPOSED"
breachText.TextColor3 = RED
breachText.TextStrokeColor3 = Color3.fromRGB(24, 30, 43)
breachText.TextStrokeTransparency = 0.15
breachText.TextSize = 75
breachText.TextWrapped = false
breachText.Parent = breachLabel

part(
    "StartPlatform",
    Vector3.new(84, 1, 72),
    CFrame.new(ORIGIN + Vector3.new(0, 1.5, -250)),
    STONE,
    Enum.Material.Cobblestone
)

-- The physical lane always has nine positions. Only the four initially owned positions are
-- visible/queryable; purchases reveal the center first, then fill symmetrically toward the edges.
local deploymentPads = Instance.new("Model")
deploymentPads.Name = "MergeEggDeploymentPads"
deploymentPads:SetAttribute("MergeEggDeploymentPadCount", 9)
deploymentPads.Parent = world
local initialTeamsBySlot = { [2] = 1, [4] = 2, [6] = 3, [8] = 4 }
for slot = 1, 9 do
    local teamId = initialTeamsBySlot[slot]
    local x = (slot - 5) * 8
    local pad = part(
        string.format("DeploymentPad%02d", slot),
        Vector3.new(6.6, 0.12, 6.6),
        hatcherSpawn.CFrame * CFrame.new(x, 0.06, 3),
        Color3.fromRGB(82, 145, 190),
        Enum.Material.Neon,
        teamId and 0.3 or 1
    )
    pad.CanCollide = false
    pad.CanTouch = false
    pad.CanQuery = teamId ~= nil
    pad:SetAttribute("MergeEggDeploymentPad", true)
    pad:SetAttribute("MergeEggPositionSlot", slot)
    pad:SetAttribute("MergeEggDeploymentTeamId", teamId)
    pad:SetAttribute("MergeEggDeploymentAvailable", teamId ~= nil)
    pad:SetAttribute("MergeEggDeploymentOccupied", false)
    pad:SetAttribute("MergeEggDeploymentTier", 0)
    pad.Parent = deploymentPads
end

-- Literal 4x4 merge board. Empty cells stay neutral. Runtime mirrors the server-owned crafted
-- inventory into `Eggs` and places a small six-color tier sign only beneath occupied eggs; matching
-- colors identify a valid merge pair.
local board = Instance.new("Model")
board.Name = "MergeBoard"
board:SetAttribute("MergeEggBoardLayoutVersion", 2)
board:SetAttribute("Rows", 4)
board:SetAttribute("Columns", 4)
board.Parent = world

-- StartPlatform spans Z -286..-214; the board is 29.8 studs deep, so -271.1 makes its rear edge
-- meet the pedestal's rear edge exactly.
local boardCenter = CFrame.new(ORIGIN + Vector3.new(0, 2.02, -271.1))
local boardSlotSize = 6.6
local boardSlotGap = 0.6
local boardSpacing = boardSlotSize + boardSlotGap
local boardBase = part(
    "Base",
    Vector3.new(4 * boardSpacing + 1, 0.14, 4 * boardSpacing + 1),
    boardCenter,
    Color3.fromRGB(32, 38, 48),
    Enum.Material.Slate,
    0.08
)
boardBase.CanCollide = false
boardBase.CanQuery = false
boardBase.Parent = board
board.PrimaryPart = boardBase

local boardSlots = Instance.new("Folder")
boardSlots.Name = "Slots"
boardSlots.Parent = board
for row = 1, 4 do
    for column = 1, 4 do
        local index = (row - 1) * 4 + column
        local x = (column - 2.5) * boardSpacing
        local z = (row - 2.5) * boardSpacing
        local slot = part(
            string.format("Slot%02d", index),
            Vector3.new(boardSlotSize, 0.12, boardSlotSize),
            boardCenter * CFrame.new(x, 0.13, z),
            Color3.fromRGB(45, 52, 64),
            Enum.Material.Slate,
            0.08
        )
        slot.CanCollide = false
        slot.CanQuery = false
        slot:SetAttribute("MergeEggSlotIndex", index)
        slot.Parent = boardSlots
    end
end
local boardSigns = Instance.new("Folder")
boardSigns.Name = "EggSigns"
boardSigns.Parent = board
local boardEggs = Instance.new("Folder")
boardEggs.Name = "Eggs"
boardEggs.Parent = board

-- Single-click convenience between the manual 4x4 board and the frontline egg positions. Runtime
-- replaces this blank host with an interactive top-facing SurfaceGui.
local equipBestControl = part(
    "EquipBestControl",
    Vector3.new(7, 0.16, 12),
    CFrame.new(ORIGIN + Vector3.new(0, 2.13, -252.2)) * CFrame.Angles(0, math.rad(90), 0),
    Color3.fromRGB(75, 190, 105),
    Enum.Material.Neon,
    0.04
)
equipBestControl.CanCollide = false
equipBestControl.CanTouch = false
equipBestControl:SetAttribute("MergeEggEquipBestControl", true)

local hatcher = part(
    "HatcherControl",
    Vector3.new(12, 3, 12),
    CFrame.new(ORIGIN + Vector3.new(-38, 3, -230)),
    GOLD,
    Enum.Material.Neon
)
hatcher.Shape = Enum.PartType.Cylinder
hatcher.CFrame *= CFrame.Angles(0, 0, math.pi / 2)

-- The first timing probe keeps the board deliberately literal and small: buy only base Earth
-- Eggs on the rear wall, carry the abstract session inventory to a separate side-wall station,
-- merge two equal tiers per press, then place the result at a captain.
local legacyCreateControl = wallButton(
    "EggCreateControl",
    Vector3.new(22, 8, 1),
    CFrame.lookAt(ORIGIN + Vector3.new(-20, 6, -299.4), ORIGIN + Vector3.new(-20, 6, -260)),
    Color3.fromRGB(104, 205, 94),
    "CREATE EARTH EGG",
    "100 WAYCOINS"
)
legacyCreateControl.Transparency = 1
legacyCreateControl.CanQuery = false
legacyCreateControl.EggCreateControlSurface.Enabled = false
local legacyBaseUpgradeControl = wallButton(
    "EggBaseUpgradeControl",
    Vector3.new(22, 8, 1),
    CFrame.lookAt(ORIGIN + Vector3.new(20, 6, -299.4), ORIGIN + Vector3.new(20, 6, -260)),
    Color3.fromRGB(238, 158, 58),
    "UPGRADE BASE EGG",
    "GRASS → ICE • 1,000 WAYCOINS"
)
legacyBaseUpgradeControl.Transparency = 1
legacyBaseUpgradeControl.CanQuery = false
legacyBaseUpgradeControl.EggBaseUpgradeControlSurface.Enabled = false
wallButton(
    "EggMergeControl",
    Vector3.new(38, 18, 1),
    CFrame.lookAt(ORIGIN + Vector3.new(-48.4, 12, -250), ORIGIN + Vector3.new(-10, 12, -250)),
    Color3.fromRGB(35, 42, 58),
    "MANAGEMENT",
    "COMBAT • HATCHERS • EGGS"
)

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
