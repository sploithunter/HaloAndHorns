-- Deterministic presentation audit for every Merge bulwark family/tier across every authored bay.
-- Run in the SERVER command bar in Play mode after Models.rbxm and the permanent Merge map load.
-- Static defenses must fill ten uniformly scaled cells without crossing the side walls. Land Sharks
-- are a three-hazard submerged patrol, not a tiled wall. Saw rigs additionally have strict depth and
-- height limits so an accidentally deck-sized import cannot pass this audit again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

assert(RunService:IsStudio(), "Merge bulwark fit automation is Studio-only")

local MergeBulwarkModels = require(ReplicatedStorage.Shared.Game.MergeBulwarkModels)
local map = assert(
    workspace:FindFirstChild("GeneratedMap_MergeEggVoxel"),
    "Workspace.GeneratedMap_MergeEggVoxel is missing"
)
local stations = assert(map:FindFirstChild("BulwarkStations"), "BulwarkStations is missing")

local FAMILIES = {
    "impaler_palisade",
    "concertina_line",
    "land_shark",
    "saw_blade",
    "grasping_hedge",
    "wardstone_barrier",
}
local EXPECTED_BAYS = 10
local EXPECTED_TILES = 10
local EXPECTED_TILE_LENGTH = 9.4
local EXPECTED_SCALE = 0.94
local TOLERANCE = 0.05
local LAND_SHARK_COUNT = 3
local SAW_MAX_DEPTH = 6
local SAW_MAX_HEIGHT = 6
local LAND_SHARK_FIN_EXPOSURE = 1

local function near(actual, expected, tolerance, label)
    assert(
        math.abs(actual - expected) <= tolerance,
        string.format("%s: expected %.4f, got %.4f", label, expected, actual)
    )
end

local function corners(part)
    local half = part.Size * 0.5
    local result = {}
    for _, x in ipairs({ -1, 1 }) do
        for _, y in ipairs({ -1, 1 }) do
            for _, z in ipairs({ -1, 1 }) do
                result[#result + 1] =
                    part.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
            end
        end
    end
    return result
end

local function projectionBounds(model, axis)
    local minimum = math.huge
    local maximum = -math.huge
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            assert(descendant.Anchored, descendant:GetFullName() .. " is not anchored")
            assert(not descendant.CanCollide, descendant:GetFullName() .. " can collide")
            for _, point in ipairs(corners(descendant)) do
                local projection = point:Dot(axis)
                minimum = math.min(minimum, projection)
                maximum = math.max(maximum, projection)
            end
        end
    end
    assert(minimum < math.huge, model:GetFullName() .. " has no BaseParts")
    return minimum, maximum
end

local bayFolders = {}
for _, folder in ipairs(stations:GetChildren()) do
    if folder:IsA("Folder") and string.match(folder.Name, "_BulwarkAnchors$") then
        bayFolders[#bayFolders + 1] = folder
    end
end
table.sort(bayFolders, function(a, b)
    return a.Name < b.Name
end)
assert(#bayFolders == EXPECTED_BAYS, string.format("Expected 10 bays, found %d", #bayFolders))

local variantsChecked = 0
local placementsChecked = 0
for _, bayFolder in ipairs(bayFolders) do
    local anchors = {}
    for _, anchor in ipairs(bayFolder:GetChildren()) do
        if anchor:IsA("BasePart") and string.match(anchor.Name, "^BulwarkAnchor_%d+$") then
            anchors[#anchors + 1] = anchor
        end
    end
    table.sort(anchors, function(a, b)
        return (tonumber(a:GetAttribute("MergeBulwarkTileIndex")) or 0)
            < (tonumber(b:GetAttribute("MergeBulwarkTileIndex")) or 0)
    end)
    assert(
        #anchors == EXPECTED_TILES,
        string.format("%s expected 10 anchors, found %d", bayFolder.Name, #anchors)
    )
    local axis = (anchors[#anchors].Position - anchors[1].Position).Unit
    local laneAxis = Vector3.yAxis:Cross(axis)
    if laneAxis.Magnitude < 0.001 then
        laneAxis = Vector3.zAxis
    else
        laneAxis = laneAxis.Unit
    end
    for index, anchor in ipairs(anchors) do
        near(
            tonumber(anchor:GetAttribute("MergeBulwarkTileLength")) or 0,
            EXPECTED_TILE_LENGTH,
            0.001,
            bayFolder.Name .. " tile length"
        )
        near(
            tonumber(anchor:GetAttribute("MergeBulwarkScale")) or 0,
            EXPECTED_SCALE,
            0.001,
            bayFolder.Name .. " uniform scale"
        )
        if index > 1 then
            near(
                (anchor.Position - anchors[index - 1].Position).Magnitude,
                EXPECTED_TILE_LENGTH,
                0.001,
                bayFolder.Name .. " anchor spacing"
            )
        end
    end

    local expectedMinimum = anchors[1].Position:Dot(axis) - EXPECTED_TILE_LENGTH * 0.5
    local expectedMaximum = anchors[#anchors].Position:Dot(axis) + EXPECTED_TILE_LENGTH * 0.5
    local scratch = Instance.new("Folder")
    scratch.Name = "MergeBulwarkFitAudit_" .. bayFolder.Name
    scratch.Parent = workspace

    for _, family in ipairs(FAMILIES) do
        for tier = 1, 4 do
            local stripMinimum = math.huge
            local stripMaximum = -math.huge
            local spawned = {}
            local presentationAnchors = anchors
            if family == "land_shark" then
                presentationAnchors = {}
                for patrolIndex = 1, LAND_SHARK_COUNT do
                    local anchorIndex = math.clamp(
                        math.floor((patrolIndex * (#anchors + 1)) / (LAND_SHARK_COUNT + 1) + 0.5),
                        1,
                        #anchors
                    )
                    presentationAnchors[#presentationAnchors + 1] = anchors[anchorIndex]
                end
            end
            for _, anchor in ipairs(presentationAnchors) do
                local model, reason = MergeBulwarkModels.Spawn(family, tier, anchor, scratch)
                assert(
                    model,
                    string.format("%s Tier %d failed to spawn: %s", family, tier, tostring(reason))
                )
                spawned[#spawned + 1] = model
                near(
                    tonumber(model:GetAttribute("MergeBulwarkSpawnScale")) or 0,
                    EXPECTED_SCALE,
                    0.001,
                    string.format("%s Tier %d spawn scale", family, tier)
                )
                if family == "land_shark" then
                    model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(90), 0))
                    local _, sourceSize = model:GetBoundingBox()
                    model:PivotTo(
                        model:GetPivot() - Vector3.new(0, sourceSize.Y - LAND_SHARK_FIN_EXPOSURE, 0)
                    )
                end
                local tileMinimum, tileMaximum = projectionBounds(model, axis)
                assert(
                    tileMaximum - tileMinimum <= EXPECTED_TILE_LENGTH + TOLERANCE,
                    string.format(
                        "%s Tier %d tile exceeds its %.1f-stud cell (%.4f)",
                        family,
                        tier,
                        EXPECTED_TILE_LENGTH,
                        tileMaximum - tileMinimum
                    )
                )
                local laneMinimum, laneMaximum = projectionBounds(model, laneAxis)
                local bottom, top = projectionBounds(model, Vector3.yAxis)
                if family == "land_shark" then
                    local exposed = top - anchor.Position.Y
                    assert(
                        bottom < anchor.Position.Y
                            and math.abs(exposed - LAND_SHARK_FIN_EXPOSURE) <= TOLERANCE,
                        string.format(
                            "%s Tier %d must be submerged with only its fin exposed (bottom %.2f, exposed %.2f)",
                            family,
                            tier,
                            bottom - anchor.Position.Y,
                            exposed
                        )
                    )
                elseif family == "saw_blade" then
                    assert(
                        laneMaximum - laneMinimum <= SAW_MAX_DEPTH,
                        string.format(
                            "%s Tier %d is %.2f studs deep; maximum is %.2f",
                            family,
                            tier,
                            laneMaximum - laneMinimum,
                            SAW_MAX_DEPTH
                        )
                    )
                    assert(
                        top - bottom <= SAW_MAX_HEIGHT,
                        string.format(
                            "%s Tier %d is %.2f studs tall; maximum is %.2f",
                            family,
                            tier,
                            top - bottom,
                            SAW_MAX_HEIGHT
                        )
                    )
                end
                stripMinimum = math.min(stripMinimum, tileMinimum)
                stripMaximum = math.max(stripMaximum, tileMaximum)
                placementsChecked += 1
            end
            assert(
                #spawned == (if family == "land_shark" then LAND_SHARK_COUNT else EXPECTED_TILES),
                string.format("%s Tier %d presentation count is wrong", family, tier)
            )
            if family ~= "land_shark" then
                near(
                    stripMinimum,
                    expectedMinimum,
                    TOLERANCE,
                    string.format("%s %s Tier %d left inset", bayFolder.Name, family, tier)
                )
                near(
                    stripMaximum,
                    expectedMaximum,
                    TOLERANCE,
                    string.format("%s %s Tier %d right inset", bayFolder.Name, family, tier)
                )
            end
            for _, model in ipairs(spawned) do
                model:Destroy()
            end
            variantsChecked += 1
        end
    end
    scratch:Destroy()
end

print("[MergeBulwarkFit] PASS", {
    bays = #bayFolders,
    variants = variantsChecked,
    placements = placementsChecked,
    stripLength = EXPECTED_TILE_LENGTH * EXPECTED_TILES,
    landSharksPerBay = LAND_SHARK_COUNT,
    sawMaxDepth = SAW_MAX_DEPTH,
    sawMaxHeight = SAW_MAX_HEIGHT,
})

return true
