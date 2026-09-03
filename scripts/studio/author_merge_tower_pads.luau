-- Run in Roblox Studio Edit mode after the polished Merge realm map is present.
--
-- Adds two initial tower mounts outside deployed egg positions 1 and 9, plus a second pair one
-- equal depth interval behind them. The rear pair unlocks at its config-owned Rebirth rank. The
-- geometry deliberately uses an armored square silhouette instead of the circular/glowing egg
-- stand language. The pass is idempotent and replaces only GeneratedMap_MergeEggVoxel.TowerStations.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

assert(not RunService:IsRunning(), "Author Merge tower pads in Edit mode")

local MergeConfig = require(ReplicatedStorage.Configs:WaitForChild("merge_egg_prototype"))
local MergeTowerSlots = require(ReplicatedStorage.Shared.Game.MergeTowerSlots)
local towerConfig = assert(MergeConfig.team.edge_towers, "team.edge_towers is missing")
local padLayout = assert(towerConfig.pad_layout, "team.edge_towers.pad_layout is missing")

local map = assert(
    Workspace:FindFirstChild("GeneratedMap_MergeEggVoxel"),
    "Workspace.GeneratedMap_MergeEggVoxel is missing"
)
local hatcherStations = assert(map:FindFirstChild("HatcherStations"), "HatcherStations is missing")
local laneLines = assert(map:FindFirstChild("LaneLines"), "LaneLines is missing")

local PAD_FOOTPRINT = assert(tonumber(padLayout.footprint_studs), "pad footprint is missing")
local PAD_CLEARANCE =
    assert(tonumber(padLayout.lateral_clearance_studs), "pad lateral clearance is missing")
local INITIAL_DEPTH_INTERVALS =
    assert(tonumber(padLayout.initial_depth_intervals), "initial pad depth is missing")
local REAR_GAP_MULTIPLIER =
    assert(tonumber(padLayout.rear_gap_multiplier), "rear pad gap multiplier is missing")
local BASE_HEIGHT = 0.45
local TOP_HEIGHT = 0.18
local DETAIL_HEIGHT = 0.12

local HEAVEN_ACCENT = Color3.fromRGB(76, 213, 255)
local HELL_ACCENT = Color3.fromRGB(255, 91, 40)
local FOUNDATION_COLOR = Color3.fromRGB(28, 35, 48)
local TOP_COLOR = Color3.fromRGB(58, 70, 88)
local CORE_COLOR = Color3.fromRGB(35, 43, 57)
local HARDWARE_COLOR = Color3.fromRGB(137, 153, 174)

local function configurePart(part, name, size, cframe, color, material)
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = true
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Material = material
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    return part
end

local function addPart(parent, name, size, cframe, color, material)
    local part = Instance.new("Part")
    configurePart(part, name, size, cframe, color, material)
    part.Parent = parent
    return part
end

local function findSlot(station, slot)
    for _, descendant in ipairs(station:GetDescendants()) do
        if
            descendant:IsA("BasePart")
            and tonumber(descendant:GetAttribute("MergeEggPositionSlot")) == slot
        then
            return descendant
        end
    end
    return station:FindFirstChild(string.format("Pad_%02d", slot), true)
end

local function stampHook(instance, bayId, side, column, def)
    instance:SetAttribute("MergeTowerSlot", def.id)
    instance:SetAttribute("MergeTowerPadSlot", def.padSlot)
    instance:SetAttribute("MergeTowerPadRole", def.padRole)
    instance:SetAttribute("MergeTowerPadInitial", def.padSlot <= 2)
    instance:SetAttribute(
        "MergeTowerUnlockRebirthRank",
        MergeTowerSlots.requiredRebirthRank(def, towerConfig)
    )
    instance:SetAttribute("MergeEggBayId", bayId)
    instance:SetAttribute("MergeEggBaySide", string.lower(side))
    instance:SetAttribute("MergeEggBayColumn", column)
end

local function buildPad(parent, bayId, side, column, def, center, floorTop, facing)
    local accent = side == "Heaven" and HEAVEN_ACCENT or HELL_ACCENT
    local model = Instance.new("Model")
    model.Name = (def.padSlot <= 2 and "InitialTowerPad_" or "RebirthTowerPad_") .. def.padRole
    stampHook(model, bayId, side, column, def)
    model:SetAttribute("MergeTowerPadFootprint", PAD_FOOTPRINT)
    model.Parent = parent

    local baseCFrame = CFrame.lookAt(
        Vector3.new(center.X, floorTop + BASE_HEIGHT * 0.5, center.Z),
        Vector3.new(center.X, floorTop + BASE_HEIGHT * 0.5, center.Z) + facing,
        Vector3.yAxis
    )
    local base = addPart(
        model,
        "Foundation",
        Vector3.new(PAD_FOOTPRINT, BASE_HEIGHT, PAD_FOOTPRINT),
        baseCFrame,
        FOUNDATION_COLOR,
        Enum.Material.Metal
    )
    base.CanCollide = true
    base.CanQuery = true
    stampHook(base, bayId, side, column, def)

    local topY = floorTop + BASE_HEIGHT
    addPart(
        model,
        "TopPlate",
        Vector3.new(PAD_FOOTPRINT - 0.65, TOP_HEIGHT, PAD_FOOTPRINT - 0.65),
        baseCFrame * CFrame.new(0, BASE_HEIGHT * 0.5 + TOP_HEIGHT * 0.5, 0),
        TOP_COLOR,
        Enum.Material.Metal
    )
    addPart(
        model,
        "MountingPlate",
        Vector3.new(5.35, DETAIL_HEIGHT, 5.35),
        baseCFrame * CFrame.new(0, BASE_HEIGHT * 0.5 + TOP_HEIGHT + DETAIL_HEIGHT * 0.5, 0),
        CORE_COLOR,
        Enum.Material.DiamondPlate
    )

    local accentY = BASE_HEIGHT * 0.5 + TOP_HEIGHT + DETAIL_HEIGHT * 0.5 + 0.015
    local edgeOffset = (PAD_FOOTPRINT - 1.0) * 0.5
    for _, spec in ipairs({
        { "AccentFront", Vector3.new(5.4, 0.08, 0.2), CFrame.new(0, accentY, -edgeOffset) },
        { "AccentBack", Vector3.new(5.4, 0.08, 0.2), CFrame.new(0, accentY, edgeOffset) },
        { "AccentLeft", Vector3.new(0.2, 0.08, 5.4), CFrame.new(-edgeOffset, accentY, 0) },
        { "AccentRight", Vector3.new(0.2, 0.08, 5.4), CFrame.new(edgeOffset, accentY, 0) },
    }) do
        addPart(model, spec[1], spec[2], baseCFrame * spec[3], accent, Enum.Material.Neon)
    end

    for index, localX in ipairs({ -1.65, 1.65 }) do
        addPart(
            model,
            string.format("MountRail_%02d", index),
            Vector3.new(0.38, 0.12, 5.25),
            baseCFrame * CFrame.new(localX, accentY + 0.055, 0),
            HARDWARE_COLOR,
            Enum.Material.Metal
        )
    end

    for index, corner in ipairs({
        Vector3.new(-3.35, accentY + 0.08, -3.35),
        Vector3.new(3.35, accentY + 0.08, -3.35),
        Vector3.new(-3.35, accentY + 0.08, 3.35),
        Vector3.new(3.35, accentY + 0.08, 3.35),
    }) do
        local bolt = addPart(
            model,
            string.format("CornerBolt_%02d", index),
            Vector3.new(0.34, 0.34, 0.34),
            baseCFrame * CFrame.new(corner),
            HARDWARE_COLOR,
            Enum.Material.Metal
        )
        bolt.Shape = Enum.PartType.Ball
    end

    local anchor = addPart(
        model,
        "TowerAnchor",
        Vector3.new(1, 0.1, 1),
        CFrame.lookAt(
            Vector3.new(center.X, topY + TOP_HEIGHT + DETAIL_HEIGHT + 0.05, center.Z),
            Vector3.new(center.X, topY + TOP_HEIGHT + DETAIL_HEIGHT + 0.05, center.Z) + facing,
            Vector3.yAxis
        ),
        accent,
        Enum.Material.SmoothPlastic
    )
    anchor.Transparency = 1
    anchor.CastShadow = false
    stampHook(anchor, bayId, side, column, def)
    anchor:SetAttribute("MergeTowerPadTopY", anchor.Position.Y)
    model.PrimaryPart = anchor
    return model
end

ChangeHistoryService:SetWaypoint("Before Merge tower pad authoring")

local old = map:FindFirstChild("TowerStations")
if old then
    old:Destroy()
end
local towerStations = Instance.new("Folder")
towerStations.Name = "TowerStations"
towerStations.Parent = map

local authored = 0
local firstBay
for _, station in ipairs(hatcherStations:GetChildren()) do
    local side, columnText = string.match(station.Name, "^(Heaven)_(%d+)_Hatchers$")
    if not side then
        side, columnText = string.match(station.Name, "^(Hell)_(%d+)_Hatchers$")
    end
    local column = tonumber(columnText)
    if side and column then
        local slotOne = findSlot(station, 1)
        local slotNine = findSlot(station, 9)
        local lines = laneLines:FindFirstChild(string.format("%s_%02d_Lines", side, column))
        local breachLine = lines
            and lines:FindFirstChild(tostring(MergeConfig.world.breach_line or "BreachLine"))
        if slotOne and slotNine and breachLine and breachLine:IsA("BasePart") then
            local rowDelta = Vector3.new(
                slotNine.Position.X - slotOne.Position.X,
                0,
                slotNine.Position.Z - slotOne.Position.Z
            )
            assert(rowDelta.Magnitude > 0.01, station:GetFullName() .. " has coincident slot hooks")
            local rowDirection = rowDelta.Unit
            local floorTop = math.min(
                slotOne.Position.Y - slotOne.Size.Y * 0.5,
                slotNine.Position.Y - slotNine.Size.Y * 0.5
            )
            local centerOffset = slotOne.Size.Z * 0.5 + PAD_FOOTPRINT * 0.5 + PAD_CLEARANCE
            if math.abs(rowDirection.X) > math.abs(rowDirection.Z) then
                centerOffset = slotOne.Size.X * 0.5 + PAD_FOOTPRINT * 0.5 + PAD_CLEARANCE
            end
            local facing = side == "Heaven" and Vector3.new(1, 0, 0) or Vector3.new(-1, 0, 0)
            -- One pad-width behind the egg-row depth so the chassis is not on
            -- top of the red-line Bulwark Engineer. March axis stays the egg
            -- stand X, then steps back a full footprint toward the player.
            local initialDepth = -facing * PAD_FOOTPRINT * INITIAL_DEPTH_INTERVALS
            local initialLeftCenter = slotOne.Position - rowDirection * centerOffset + initialDepth
            local initialRightCenter = slotNine.Position
                + rowDirection * centerOffset
                + initialDepth
            local redToInitialDistance = math.abs(
                Vector3.new(
                    initialLeftCenter.X - breachLine.Position.X,
                    0,
                    initialLeftCenter.Z - breachLine.Position.Z
                ):Dot(facing)
            )
            assert(
                redToInitialDistance > PAD_FOOTPRINT,
                station:GetFullName() .. " initial tower pad is not behind BreachLine"
            )
            local rearGap = -facing * redToInitialDistance * REAR_GAP_MULTIPLIER
            local bayId = string.format("%s_%02d", string.lower(side), column)
            local bayFolder = Instance.new("Folder")
            bayFolder.Name = string.format("%s_%02d_TowerPads", side, column)
            bayFolder:SetAttribute("MergeEggBayId", bayId)
            bayFolder:SetAttribute("MergeEggBaySide", string.lower(side))
            bayFolder:SetAttribute("MergeEggBayColumn", column)
            bayFolder.Parent = towerStations

            buildPad(
                bayFolder,
                bayId,
                side,
                column,
                assert(MergeTowerSlots.get("left")),
                initialLeftCenter,
                floorTop,
                facing
            )
            buildPad(
                bayFolder,
                bayId,
                side,
                column,
                assert(MergeTowerSlots.get("right")),
                initialRightCenter,
                floorTop,
                facing
            )
            buildPad(
                bayFolder,
                bayId,
                side,
                column,
                assert(MergeTowerSlots.get("rear_left")),
                initialLeftCenter + rearGap,
                floorTop,
                facing
            )
            buildPad(
                bayFolder,
                bayId,
                side,
                column,
                assert(MergeTowerSlots.get("rear_right")),
                initialRightCenter + rearGap,
                floorTop,
                facing
            )
            authored += 4
            if bayId == "heaven_01" then
                firstBay = bayFolder
            end
        end
    end
end

map:SetAttribute("MergeTowerPadsPerBay", 4)
map:SetAttribute("MergeTowerPadCount", authored)
Selection:Set(firstBay and { firstBay } or { towerStations })
ChangeHistoryService:SetWaypoint("Author Merge tower pads")

print(string.format("[MergeTowerPads] authored %d tower pads", authored))
