-- Read-only Edit-mode audit for the four Merge bulwark rows and four cannon pads per bay.
-- Run after author_merge_bulwark_anchors.luau and author_merge_tower_pads.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Audit Merge defense geometry in Edit mode")

local MergeConfig = require(ReplicatedStorage.Configs:WaitForChild("merge_egg_prototype"))
local MergeBulwarkSlots = require(ReplicatedStorage.Shared.Game.MergeBulwarkSlots)
local MergeTowerSlots = require(ReplicatedStorage.Shared.Game.MergeTowerSlots)
local map = assert(
    workspace:FindFirstChild("GeneratedMap_MergeEggVoxel"),
    "Workspace.GeneratedMap_MergeEggVoxel is missing"
)
local laneLines = assert(map:FindFirstChild("LaneLines"), "LaneLines is missing")
local towerStations = assert(map:FindFirstChild("TowerStations"), "TowerStations is missing")
local bulwarkConfig = assert(MergeConfig.team.edge_bulwarks, "team.edge_bulwarks is missing")
local towerConfig = assert(MergeConfig.team.edge_towers, "team.edge_towers is missing")
local lineLayout = assert(bulwarkConfig.line_layout, "edge_bulwarks.line_layout is missing")

local EPSILON = 1e-3
local EXPECTED_BAYS = 10
local EXPECTED_ANCHORS = 10

local function planar(value)
    return Vector3.new(value.X, 0, value.Z)
end

local function nearVector(actual, expected, label)
    assert(
        (planar(actual) - planar(expected)).Magnitude <= EPSILON,
        string.format(
            "%s differs by %.6f studs",
            label,
            (planar(actual) - planar(expected)).Magnitude
        )
    )
end

local function part(folder, name)
    local value = folder:FindFirstChild(name)
    assert(value and value:IsA("BasePart"), folder:GetFullName() .. "." .. name .. " is missing")
    return value
end

local function configColor(row, path)
    assert(type(row) == "table" and #row >= 3, path .. " is missing")
    return Color3.fromRGB(
        assert(tonumber(row[1]), path .. "[1] must be numeric"),
        assert(tonumber(row[2]), path .. "[2] must be numeric"),
        assert(tonumber(row[3]), path .. "[3] must be numeric")
    )
end

local function assertLineAppearance(line, colorKey, transparencyKey, label)
    local expected = configColor(lineLayout[colorKey], "edge_bulwarks.line_layout." .. colorKey)
    assert(line.Color == expected, label .. " has the wrong configured color")
    assert(line.Material == Enum.Material.Neon, label .. " must use Neon")
    assert(
        math.abs(
            line.Transparency
                - assert(
                    tonumber(lineLayout[transparencyKey]),
                    "edge_bulwarks.line_layout." .. transparencyKey .. " is missing"
                )
        ) <= EPSILON,
        label .. " has the wrong transparency"
    )
end

local lineBays = 0
for _, lines in ipairs(laneLines:GetChildren()) do
    local side, columnText = string.match(lines.Name, "^(Heaven)_(%d+)_Lines$")
    if not side then
        side, columnText = string.match(lines.Name, "^(Hell)_(%d+)_Lines$")
    end
    local column = tonumber(columnText)
    if side and column then
        local yellow = part(lines, tostring(MergeConfig.world.bulwark_line or "BulwarkLine"))
        local red = part(lines, tostring(MergeConfig.world.breach_line or "BreachLine"))
        local orange = part(lines, assert(MergeBulwarkSlots.get("mid")).lineDefault)
        local green = part(lines, assert(MergeBulwarkSlots.get("front")).lineDefault)
        assertLineAppearance(green, "front_color", "front_transparency", lines.Name .. " green")
        assertLineAppearance(yellow, "lane_color", "lane_transparency", lines.Name .. " yellow")
        assertLineAppearance(orange, "mid_color", "mid_transparency", lines.Name .. " orange")
        assertLineAppearance(red, "egg_color", "egg_transparency", lines.Name .. " red")
        nearVector(
            orange.Position,
            red.Position:Lerp(yellow.Position, 0.5),
            lines.Name .. " orange"
        )
        nearVector(
            green.Position - yellow.Position,
            yellow.Position - orange.Position,
            lines.Name .. " green interval"
        )
        assert(orange:GetAttribute("MergeBulwarkSlot") == "mid", "orange slot tag is wrong")
        assert(green:GetAttribute("MergeBulwarkSlot") == "front", "green slot tag is wrong")
        assert(
            orange:GetAttribute("MergeBulwarkUnlockRebirthRank")
                == MergeBulwarkSlots.requiredRebirthRank("mid", bulwarkConfig),
            "orange Rebirth gate is wrong"
        )
        assert(
            green:GetAttribute("MergeBulwarkUnlockRebirthRank")
                == MergeBulwarkSlots.requiredRebirthRank("front", bulwarkConfig),
            "green Rebirth gate is wrong"
        )
        for _, def in ipairs(MergeBulwarkSlots.all()) do
            local stations = assert(map:FindFirstChild(def.stationsFolder))
            local bay =
                assert(stations:FindFirstChild(string.format(def.bayFolderFormat, side, column)))
            local count = 0
            for _, anchor in ipairs(bay:GetChildren()) do
                if anchor:IsA("BasePart") and string.match(anchor.Name, def.anchorNamePattern) then
                    count += 1
                end
            end
            assert(
                count == EXPECTED_ANCHORS,
                string.format(
                    "%s %s expected %d anchors, found %d",
                    lines.Name,
                    def.id,
                    EXPECTED_ANCHORS,
                    count
                )
            )
        end
        lineBays += 1
    end
end
assert(
    lineBays == EXPECTED_BAYS,
    string.format("Expected %d line bays, found %d", EXPECTED_BAYS, lineBays)
)

local towerBays = 0
for _, bay in ipairs(towerStations:GetChildren()) do
    if bay:IsA("Folder") and string.match(bay.Name, "_TowerPads$") then
        local bySlot = {}
        for _, pad in ipairs(bay:GetChildren()) do
            if pad:IsA("Model") then
                bySlot[MergeTowerSlots.fromPad(pad)] = pad
            end
        end
        for _, slot in ipairs(MergeTowerSlots.ids()) do
            assert(bySlot[slot], bay.Name .. " is missing cannon slot " .. slot)
            assert(
                bySlot[slot]:GetAttribute("MergeTowerUnlockRebirthRank")
                    == MergeTowerSlots.requiredRebirthRank(slot, towerConfig),
                bay.Name .. " has the wrong Rebirth gate for " .. slot
            )
        end
        local side, columnText = string.match(bay.Name, "^(Heaven)_(%d+)_TowerPads$")
        if not side then
            side, columnText = string.match(bay.Name, "^(Hell)_(%d+)_TowerPads$")
        end
        local column = assert(tonumber(columnText), bay.Name .. " has no bay column")
        local lines = assert(laneLines:FindFirstChild(string.format("%s_%02d_Lines", side, column)))
        local red = part(lines, tostring(MergeConfig.world.breach_line or "BreachLine"))
        local initialCenter = (bySlot.left:GetPivot().Position + bySlot.right:GetPivot().Position)
            * 0.5
        local rearCenter = (
            bySlot.rear_left:GetPivot().Position + bySlot.rear_right:GetPivot().Position
        ) * 0.5
        local redToInitial = planar(initialCenter - red.Position).Magnitude
        local initialToRear = planar(rearCenter - initialCenter).Magnitude
        assert(
            math.abs(redToInitial - initialToRear) <= EPSILON,
            string.format(
                "%s rear gap %.6f does not repeat red-to-initial gap %.6f",
                bay.Name,
                initialToRear,
                redToInitial
            )
        )
        towerBays += 1
    end
end
assert(
    towerBays == EXPECTED_BAYS,
    string.format("Expected %d tower bays, found %d", EXPECTED_BAYS, towerBays)
)

print("[MergeDefenseSlotGeometry] PASS", {
    bays = EXPECTED_BAYS,
    bulwarkRowsPerBay = #MergeBulwarkSlots.ids(),
    cannonPadsPerBay = #MergeTowerSlots.ids(),
    orangeRebirthRank = MergeBulwarkSlots.requiredRebirthRank("mid", bulwarkConfig),
    rearCannonRebirthRank = MergeTowerSlots.requiredRebirthRank("rear_left", towerConfig),
    greenRebirthRank = MergeBulwarkSlots.requiredRebirthRank("front", bulwarkConfig),
})

return true
