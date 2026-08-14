-- Run once in Studio Edit mode. Geometry remains Studio-authored; runtime code only binds the
-- LeaderboardBoard tag + BoardId attribute and paints the live SurfaceGui.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local FOLDER_NAME = "OriginLeaderboards"
local TAG = "LeaderboardBoard"

local definitions = {
    {
        area = "Grass",
        boardId = "most_dragons",
        title = "MOST DRAGONS",
        accent = Color3.fromRGB(83, 214, 105),
        direction = Vector3.new(1, 0, 1),
    },
    {
        area = "Desert",
        boardId = "crystal_crusher",
        title = "CRYSTAL CRUSHER",
        accent = Color3.fromRGB(255, 191, 57),
        direction = Vector3.new(1, 0, -1),
    },
    {
        area = "Lava",
        boardId = "enemies_defeated",
        title = "ENEMIES DEFEATED",
        accent = Color3.fromRGB(255, 77, 55),
        direction = Vector3.new(-1, 0, -1),
    },
    {
        area = "Ice",
        boardId = "team_power",
        title = "TEAM POWER",
        accent = Color3.fromRGB(78, 190, 255),
        direction = Vector3.new(-1, 0, 1),
    },
}

local function findArea(name)
    local maps = Workspace:FindFirstChild("Maps")
    local home = maps and maps:FindFirstChild("Home")
    return home and home:FindFirstChild(name) or Workspace:FindFirstChild(name, true)
end

local function bounds(instance)
    if instance:IsA("Model") then
        return instance:GetBoundingBox()
    elseif instance:IsA("BasePart") then
        return instance.CFrame, instance.Size
    end
    local first = instance:FindFirstChildWhichIsA("BasePart", true)
    if first then
        return first.CFrame, first.Size
    end
    return CFrame.new(), Vector3.new(80, 2, 80)
end

local function part(parent, name, size, cframe, material, color)
    local item = Instance.new("Part")
    item.Name = name
    item.Size = size
    item.CFrame = cframe
    item.Anchored = true
    item.CanCollide = true
    item.Material = material
    item.Color = color
    item.Parent = parent
    return item
end

local function preview(screen, definition)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "LeaderboardSurface"
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(900, 620)
    gui.LightInfluence = 0
    gui.Parent = screen
    local root = Instance.new("Frame")
    root.Size = UDim2.fromScale(1, 1)
    root.BackgroundColor3 = Color3.fromRGB(17, 19, 27)
    root.BorderSizePixel = 0
    root.Parent = gui
    local stroke = Instance.new("UIStroke")
    stroke.Color = definition.accent
    stroke.Thickness = 8
    stroke.Parent = root
    local title = Instance.new("TextLabel")
    title.BackgroundColor3 = definition.accent
    title.Size = UDim2.new(1, 0, 0, 105)
    title.BorderSizePixel = 0
    title.Font = Enum.Font.GothamBlack
    title.Text = definition.title
    title.TextColor3 = Color3.fromRGB(15, 18, 24)
    title.TextSize = 42
    title.Parent = root
    for index = 1, 10 do
        local row = Instance.new("TextLabel")
        row.BackgroundColor3 = if index % 2 == 0
            then Color3.fromRGB(33, 36, 49)
            else Color3.fromRGB(26, 29, 40)
        row.BorderSizePixel = 0
        row.Position = UDim2.fromOffset(25, 118 + (index - 1) * 45)
        row.Size = UDim2.new(1, -50, 0, 40)
        row.Font = Enum.Font.GothamBold
        row.Text =
            string.format("%d    Player name                                      —", index)
        row.TextColor3 = Color3.fromRGB(230, 234, 244)
        row.TextSize = 21
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Parent = root
    end
end

local old = Workspace:FindFirstChild(FOLDER_NAME)
if old then
    old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = FOLDER_NAME
folder.Parent = Workspace

for _, definition in ipairs(definitions) do
    local area = findArea(definition.area)
    assert(area, "Could not locate Home area: " .. definition.area)
    local areaCFrame, areaSize = bounds(area)
    local flat = definition.direction.Unit
    local localOffset = Vector3.new(flat.X * areaSize.X * 0.32, 0, flat.Z * areaSize.Z * 0.32)
    local ground = areaCFrame.Position + areaCFrame:VectorToWorldSpace(localOffset)
    local position = Vector3.new(ground.X, areaCFrame.Position.Y + areaSize.Y * 0.5 + 8, ground.Z)
    local target = Vector3.new(areaCFrame.Position.X, position.Y, areaCFrame.Position.Z)
    local face = CFrame.lookAt(position, target)

    local model = Instance.new("Model")
    model.Name = definition.area .. "Leaderboard"
    model:SetAttribute("BoardId", definition.boardId)
    model:SetAttribute("AreaId", definition.area)
    model.Parent = folder
    CollectionService:AddTag(model, TAG)

    local screen = part(
        model,
        "Screen",
        Vector3.new(18, 12, 0.6),
        face,
        Enum.Material.SmoothPlastic,
        Color3.fromRGB(18, 20, 29)
    )
    part(
        model,
        "TopTrim",
        Vector3.new(18.8, 0.45, 1),
        face * CFrame.new(0, 6.15, 0),
        Enum.Material.Neon,
        definition.accent
    )
    part(
        model,
        "BottomTrim",
        Vector3.new(18.8, 0.45, 1),
        face * CFrame.new(0, -6.15, 0),
        Enum.Material.Neon,
        definition.accent
    )
    part(
        model,
        "LeftTrim",
        Vector3.new(0.45, 12, 1),
        face * CFrame.new(-9.2, 0, 0),
        Enum.Material.Neon,
        definition.accent
    )
    part(
        model,
        "RightTrim",
        Vector3.new(0.45, 12, 1),
        face * CFrame.new(9.2, 0, 0),
        Enum.Material.Neon,
        definition.accent
    )
    part(
        model,
        "LeftPost",
        Vector3.new(0.8, 7.5, 0.8),
        face * CFrame.new(-7.5, -9.7, 0.2),
        Enum.Material.Metal,
        Color3.fromRGB(36, 39, 49)
    )
    part(
        model,
        "RightPost",
        Vector3.new(0.8, 7.5, 0.8),
        face * CFrame.new(7.5, -9.7, 0.2),
        Enum.Material.Metal,
        Color3.fromRGB(36, 39, 49)
    )
    part(
        model,
        "Base",
        Vector3.new(18, 0.75, 3),
        face * CFrame.new(0, -13.5, 0.6),
        Enum.Material.Metal,
        Color3.fromRGB(27, 30, 39)
    )
    model.PrimaryPart = screen
    preview(screen, definition)
end

print("Installed four tagged origin leaderboard boards under Workspace." .. FOLDER_NAME)
