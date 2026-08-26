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
world:SetAttribute("Phase", 1)
world:SetAttribute("UsesTileSystem", false)
world:SetAttribute("UsesTileStreaming", false)
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

local floor =
    part("LandStrip", Vector3.new(96, 2, 600), CFrame.new(ORIGIN), LAND, Enum.Material.Ground)
world.PrimaryPart = floor

part(
    "WestWall",
    Vector3.new(2, 14, 600),
    CFrame.new(ORIGIN + Vector3.new(-49, 7, 0)),
    WALL,
    Enum.Material.Slate
)
part(
    "EastWall",
    Vector3.new(2, 14, 600),
    CFrame.new(ORIGIN + Vector3.new(49, 7, 0)),
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
    CFrame.new(ORIGIN + Vector3.new(0, 7, 301)),
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
anchor("FriendlyRally", Vector3.new(0, 2, -205), Vector3.new(0, 2, -170))
anchor("BattleCenter", Vector3.new(0, 2, -70), Vector3.new(0, 2, 0))
anchor("EnemySpawnA", Vector3.new(0, 2, -165), Vector3.new(0, 2, -220))
anchor("EnemySpawnB", Vector3.new(0, 2, -75), Vector3.new(0, 2, -165))
anchor("EnemySpawnC", Vector3.new(0, 2, 15), Vector3.new(0, 2, -75))

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

local bounds = anchor("ArenaBounds", Vector3.new(0, 8, 0))
bounds.Size = Vector3.new(92, 16, 592)

print("[MergeEggPrototype] authored Workspace.Maps.MergeEggPrototype")
