-- Edit-mode stamp: parent/clone the wooden gate signs and add SurfaceGuis.
-- Run from Studio MCP execute_luau (paste or load). Does not snap user pivots.

local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local surface = require(game:GetService("ReplicatedStorage").Configs.leaderboards).surface

-- The release rollback moved the complete authored fixtures into Homeworld. Never recreate the
-- retired Hall copies if this historical one-time placement script is run again.
local maps = workspace:FindFirstChild("Maps")
local homeBindings = maps
    and maps:FindFirstChild("Home")
    and maps.Home:FindFirstChild("ChallengeBindings")
if
    homeBindings
    and homeBindings:FindFirstChild("RangeLeaderboard")
    and homeBindings:FindFirstChild("TrainingGroundLeaderboard")
then
    return {
        ok = true,
        already_relocated = true,
        parent = homeBindings:GetFullName(),
    }
end

local function pickScreen(model)
    local best, bestThin
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            local thin = math.min(part.Size.X, part.Size.Y, part.Size.Z)
            if not bestThin or thin < bestThin then
                best, bestThin = part, thin
            end
        end
    end
    if best then
        best.Name = "Screen"
    end
    return best
end

local function makeSurface(screen, title, body)
    for _, old in ipairs(screen:GetChildren()) do
        if old:IsA("BillboardGui") or old:IsA("SurfaceGui") then
            old:Destroy()
        end
    end
    local gui = Instance.new("SurfaceGui")
    gui.Name = "LeaderboardSurface"
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(surface.canvas[1], surface.canvas[2])
    gui.LightInfluence = 0
    gui.Brightness = 2
    gui.AlwaysOnTop = false
    gui.Parent = screen

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.Size = UDim2.fromScale(1, 1)
    root.BackgroundColor3 = Color3.fromRGB(17, 19, 27)
    root.BorderSizePixel = 0
    root.Parent = gui

    local header = Instance.new("TextLabel")
    header.Name = "Title"
    header.BackgroundTransparency = 1
    header.Position = UDim2.fromOffset(20, 18)
    header.Size = UDim2.new(1, -40, 0, 48)
    header.Font = Enum.Font[surface.title_font]
    header.Text = title
    header.TextColor3 = Color3.fromRGB(244, 246, 255)
    header.TextScaled = true
    header.Parent = root

    local text = Instance.new("TextLabel")
    text.Name = "Body"
    text.BackgroundTransparency = 1
    text.Position = UDim2.fromOffset(24, 78)
    text.Size = UDim2.new(1, -48, 1, -100)
    text.Font = Enum.Font[surface.body_font]
    text.Text = body
    text.TextColor3 = Color3.fromRGB(208, 215, 232)
    text.TextWrapped = true
    text.TextYAlignment = Enum.TextYAlignment.Top
    text.TextSize = 22
    text.Parent = root
    return gui
end

local function configure(model, name, parent, attrs, tags, title, body)
    model.Name = name
    model.Parent = parent
    for key, value in pairs(attrs) do
        model:SetAttribute(key, value)
    end
    for _, tag in ipairs(tags) do
        CollectionService:AddTag(model, tag)
    end
    local screen = pickScreen(model)
    if screen then
        makeSurface(screen, title, body)
    end
    local pivot = model:GetPivot()
    return {
        name = name,
        path = model:GetFullName(),
        pos = { x = pivot.X, y = pivot.Y, z = pivot.Z },
    }
end

local existing = {}
for _, inst in ipairs(workspace:GetChildren()) do
    if inst.Name == "Leaderboard" and inst:IsA("Model") then
        table.insert(existing, inst)
    end
end
if #existing ~= 2 then
    return { ok = false, reason = "expected 2 Workspace.Leaderboard models", count = #existing }
end
table.sort(existing, function(a, b)
    return a:GetPivot().Z < b:GetPivot().Z
end)

local south = existing[1]
local north = existing[2]
local tile04 = workspace.Maps.FuturePath.Tiles.Tile04_corner
local tile07 = workspace.Maps.FuturePath.Tiles.Tile07_corner
local tgGate = workspace.Maps.FuturePath.HallRuntimeBindings.TrainingGroundPadGateVisual
local rangeGate = workspace.Maps.FuturePath.HallRuntimeBindings.RangePadGateVisual
local tgPivot = tgGate:GetPivot()
local rangePivot = rangeGate:GetPivot()

local function copyBesideRange(src)
    local clone = src:Clone()
    local rel = tgPivot:ToObjectSpace(src:GetPivot())
    local dest = rangePivot * rel
    clone:PivotTo(CFrame.new(dest.X, src:GetPivot().Y, dest.Z) * (dest - dest.Position))
    return clone
end

ChangeHistoryService:SetWaypoint("Challenge gate boards")

local rangeGuide = copyBesideRange(south)
local rangeBoard = copyBesideRange(north)

local placed = {
    configure(
        south,
        "TrainingGroundGuide",
        tile07,
        {
            GuideMode = "training_ground",
            GuiKind = "Surface",
        },
        { "ChallengeGuide" },
        "Training Ground",
        table.concat({
            "Your own pets and powers.",
            "Teams are allowed.",
            "Easier rooms than The Range.",
            "Best room in the last 48 hours ranks the board.",
        }, "\n\n")
    ),
    configure(
        north,
        "TrainingGroundLeaderboard",
        tile07,
        {
            BoardId = "training_ground_current",
            GuiKind = "Surface",
        },
        { "LeaderboardBoard" },
        "Training Ground",
        table.concat({
            "GLOBAL TOP 10",
            "Best room in the last 48 hours.",
            "Ranks fill when players finish a run.",
        }, "\n\n")
    ),
    configure(
        rangeGuide,
        "RangeGuide",
        tile04,
        {
            GuideMode = "range",
            GuiKind = "Surface",
        },
        { "ChallengeGuide" },
        "The Range",
        table.concat({
            "Solo catalog run. Leave your team at the door.",
            "Everyone fights at level 50.",
            "Pick an origin kit and a loaned squad.",
            "Best room in the last 48 hours ranks the board.",
        }, "\n\n")
    ),
    configure(
        rangeBoard,
        "RangeLeaderboard",
        tile04,
        {
            BoardId = "range_current",
            GuiKind = "Surface",
        },
        { "LeaderboardBoard" },
        "The Range",
        table.concat({
            "GLOBAL TOP 10",
            "Best room in the last 48 hours.",
            "Ranks fill when players finish a run.",
        }, "\n\n")
    ),
}

ChangeHistoryService:SetWaypoint("Challenge gate boards placed")
return { ok = true, placed = placed }
