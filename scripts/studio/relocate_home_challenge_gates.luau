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
    RangePad = Vector3.new(-265.664, 0.817, 100.983),
    RangePadGateVisual = Vector3.new(-265.664, 18.576, 100.983),
    RangeGuide = Vector3.new(-295.659, 18.867, 101.507),
    RangeLeaderboard = Vector3.new(-235.668, 18.867, 100.46),
    TrainingGroundPad = Vector3.new(-24.201, 1.358, 412.186),
    TrainingGroundPadGateVisual = Vector3.new(-24.201, 19.118, 412.186),
    TrainingGroundGuide = Vector3.new(-54.196, 19.407, 412.709),
    TrainingGroundLeaderboard = Vector3.new(5.795, 19.407, 411.662),
}

-- Fallback rotations for a clean migration from the retired Hall. Once a fixture already lives in
-- ChallengeBindings its authored transform wins, so a designer can keep moving the visible set.
local placementYaw = {
    RangePad = 0,
    RangePadGateVisual = 91,
    RangeGuide = 1,
    RangeLeaderboard = 1,
    TrainingGroundPad = 0,
    TrainingGroundPadGateVisual = 91,
    TrainingGroundGuide = -179,
    TrainingGroundLeaderboard = -179,
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

local function pivotToPosition(instance, position, yaw)
    local pivot = if instance:IsA("Model") then instance:GetPivot() else instance.CFrame
    local rotation = if yaw then CFrame.Angles(0, math.rad(yaw), 0) else pivot - pivot.Position
    local target = CFrame.new(position) * rotation
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
    local needsInitialPlacement = instance.Parent ~= destination
    instance.Parent = destination
    instance:SetAttribute("HomeworldChallengeArea", areaId)
    local position = placements[name]
    if position and needsInitialPlacement then
        pivotToPosition(instance, position, placementYaw[name])
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

-- Invisible mission pads must follow the visible arches. This is intentionally derived every run:
-- a designer can move either fixture later without leaving its interaction pad at the old location.
local function seatPadUnderVisual(prefix)
    local pad = assert(destination:FindFirstChild(prefix .. "Pad"), prefix .. " pad missing")
    local visual = assert(
        destination:FindFirstChild(prefix .. "PadGateVisual"),
        prefix .. " gate visual missing"
    )
    local visualPosition = visual:GetPivot().Position
    pad.CFrame = CFrame.new(visualPosition.X, pad.Position.Y, visualPosition.Z)
end
seatPadUnderVisual("Range")
seatPadUnderVisual("TrainingGround")

-- The moved Training arch occupies an authored cactus spawn. Clear against the visible arch—not
-- the once-stale invisible pad—and destroy the source anchors so FloraService cannot respawn them.
local trainingPosition = destination.TrainingGroundPadGateVisual:GetPivot().Position
local removedCactusAnchors = {}
for _, anchor in ipairs(CollectionService:GetTagged("FloraAnchor")) do
    if
        anchor:IsA("BasePart")
        and anchor:IsDescendantOf(home)
        and anchor:GetAttribute("Kind") == "cactus"
        and (
            Vector3.new(
                anchor.Position.X - trainingPosition.X,
                0,
                anchor.Position.Z - trainingPosition.Z
            ).Magnitude < 24
        )
    then
        table.insert(removedCactusAnchors, anchor:GetFullName())
        anchor:Destroy()
    end
end
table.sort(removedCactusAnchors)

ChangeHistoryService:SetWaypoint("Homeworld challenges relocated")
return {
    ok = true,
    parent = destination:GetFullName(),
    moved = moved,
    removedCactusAnchors = removedCactusAnchors,
}
