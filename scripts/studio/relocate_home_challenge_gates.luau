--[[
    Edit-mode migration for the Hall rollback.

    Moves the ORIGINAL Range and Training Ground fixtures into Homeworld; it never clones them.
    All attributes, tags, SurfaceGuis, lightning markers, and object references survive because
    each authored Instance is only reparented and pivoted. Safe to rerun after the move.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")

local maps = assert(workspace:FindFirstChild("Maps"), "Workspace.Maps is required")
local home = assert(maps:FindFirstChild("Home"), "Workspace.Maps.Home is required")
local hall = assert(maps:FindFirstChild("FuturePath"), "Workspace.Maps.FuturePath is required")
local destination = home:FindFirstChild("ChallengeBindings")
if not destination then
    destination = Instance.new("Folder")
    destination.Name = "ChallengeBindings"
    destination.Parent = home
end
destination:SetAttribute("AuthoredBy", "homeworld-restoration-2026-08-22")

local placements = {
    RangePad = Vector3.new(-300, 0.817, 60),
    RangePadGateVisual = Vector3.new(-300, 18.576, 60),
    RangeGuide = Vector3.new(-300, 18.867, 30),
    RangeLeaderboard = Vector3.new(-300, 18.867, 90),
    TrainingGroundPad = Vector3.new(-205, 1.358, 557),
    TrainingGroundPadGateVisual = Vector3.new(-205, 19.118, 557),
    TrainingGroundGuide = Vector3.new(-205, 19.407, 527),
    TrainingGroundLeaderboard = Vector3.new(-205, 19.407, 587),
}

local areaByName = {
    RangePad = "Lava",
    RangePadGateVisual = "Lava",
    RangePadTitle = "Lava",
    RangeGuide = "Lava",
    RangeLeaderboard = "Lava",
    TrainingGroundPad = "Desert",
    TrainingGroundPadGateVisual = "Desert",
    TrainingGroundPadTitle = "Desert",
    TrainingGroundGuide = "Desert",
    TrainingGroundLeaderboard = "Desert",
}

local expectedTags = {
    RangePad = "MissionDoor",
    TrainingGroundPad = "MissionDoor",
    RangePadGateVisual = "ArchLightning",
    TrainingGroundPadGateVisual = "ArchLightning",
    RangeLeaderboard = "LeaderboardBoard",
    TrainingGroundLeaderboard = "LeaderboardBoard",
}

local function findOriginal(name)
    return destination:FindFirstChild(name) or hall:FindFirstChild(name, true)
end

local function pivotToPosition(instance, position)
    local pivot = if instance:IsA("Model") then instance:GetPivot() else instance.CFrame
    local target = CFrame.new(position) * (pivot - pivot.Position)
    if instance:IsA("Model") then
        instance:PivotTo(target)
    elseif instance:IsA("BasePart") then
        instance.CFrame = target
    end
end

ChangeHistoryService:SetWaypoint("Before Homeworld challenge relocation")
local moved = {}
for name, areaId in pairs(areaByName) do
    local instance = assert(findOriginal(name), string.format("missing original %s", name))
    instance.Parent = destination
    instance:SetAttribute("HomeworldChallengeArea", areaId)
    local position = placements[name]
    if position then
        pivotToPosition(instance, position)
    end
    local expectedTag = expectedTags[name]
    if expectedTag then
        assert(CollectionService:HasTag(instance, expectedTag), name .. " lost tag " .. expectedTag)
    end
    table.insert(moved, instance:GetFullName())
end
table.sort(moved)

assert(destination.RangePad:GetAttribute("MissionId") == "range", "Range MissionId changed")
assert(
    destination.TrainingGroundPad:GetAttribute("MissionId") == "training_ground",
    "Training MissionId changed"
)
assert(
    destination.RangeLeaderboard:GetAttribute("BoardId") == "range_current",
    "Range BoardId changed"
)
assert(
    destination.TrainingGroundLeaderboard:GetAttribute("BoardId") == "training_ground_current",
    "Training BoardId changed"
)

ChangeHistoryService:SetWaypoint("Homeworld challenges relocated")
return { ok = true, parent = destination:GetFullName(), moved = moved }
