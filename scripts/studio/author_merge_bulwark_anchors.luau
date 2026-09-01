-- Run in Roblox Studio Edit mode after the polished Merge realm map is present.
--
-- Authors invisible placement anchors across every cataloged install slot whose
-- source line already exists. Never create, rename, or destroy BulwarkLine or
-- BreachLine — those two parts are combat planes (pets open / eggs become
-- attackable). Extra walls are install hooks only. Mid and front stay dark
-- until their helper lines are authored.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

assert(not RunService:IsRunning(), "Author Merge bulwark anchors in Edit mode")

local MergeBulwarkSlots = require(ReplicatedStorage.Shared.Game.MergeBulwarkSlots)

local map = assert(
    Workspace:FindFirstChild("GeneratedMap_MergeEggVoxel"),
    "Workspace.GeneratedMap_MergeEggVoxel is missing"
)
local laneLines = assert(map:FindFirstChild("LaneLines"), "LaneLines is missing")
local playFields = assert(map:FindFirstChild("PlayFields"), "PlayFields is missing")
local portableBays = Workspace:FindFirstChild("Maps")
    and Workspace.Maps:FindFirstChild("MergeEggRealm")
    and Workspace.Maps.MergeEggRealm:FindFirstChild("Bays")

local TILE_COUNT = 10
local WALL_INSET = 1
local CANONICAL_TILE_LENGTH = 10

local function stamp(instance, bayId, side, column, index, tileLength)
    instance:SetAttribute("MergeEggBayId", bayId)
    instance:SetAttribute("MergeEggBaySide", string.lower(side))
    instance:SetAttribute("MergeEggBayColumn", column)
    instance:SetAttribute("MergeBulwarkTileIndex", index)
    instance:SetAttribute("MergeBulwarkTileCount", TILE_COUNT)
    instance:SetAttribute("MergeBulwarkTileLength", tileLength)
    instance:SetAttribute("MergeBulwarkScale", tileLength / CANONICAL_TILE_LENGTH)
    instance:SetAttribute("MergeBulwarkWallInset", WALL_INSET)
end

ChangeHistoryService:SetWaypoint("Before Merge bulwark anchor authoring")

local authored = 0
local firstBay
for _, def in ipairs(MergeBulwarkSlots.all()) do
    local old = map:FindFirstChild(def.stationsFolder)
    if old then
        old:Destroy()
    end
    local stations = Instance.new("Folder")
    stations.Name = def.stationsFolder
    stations.Parent = map

    for _, lines in ipairs(laneLines:GetChildren()) do
        local side, columnText = string.match(lines.Name, "^(Heaven)_(%d+)_Lines$")
        if not side then
            side, columnText = string.match(lines.Name, "^(Hell)_(%d+)_Lines$")
        end
        local column = tonumber(columnText)
        local lineName = MergeBulwarkSlots.stripLineName(def)
        local line = lineName and lines:FindFirstChild(lineName)
        local field = side
            and column
            and playFields:FindFirstChild(string.format("%s_%02d", side, column))
        if side and column and line and line:IsA("BasePart") and field and field:IsA("BasePart") then
            local longIsX = line.Size.X >= line.Size.Z
            local markerLength = longIsX and line.Size.X or line.Size.Z
            local usableLength = markerLength - WALL_INSET * 2
            assert(usableLength > 0, lines:GetFullName() .. " " .. def.lineDefault .. " is too short")
            local tileLength = usableLength / TILE_COUNT
            local direction = longIsX and line.CFrame.RightVector or line.CFrame.LookVector
            local bayId = string.format("%s_%02d", string.lower(side), column)
            local portableBay = portableBays and portableBays:FindFirstChild("MergeBay_" .. bayId)
            local landStrip = portableBay and portableBay:FindFirstChild("LandStrip")
            local floorTop = landStrip and landStrip.Position.Y + landStrip.Size.Y * 0.5
                or field.Position.Y + field.Size.Y * 0.5

            local bayFolder = Instance.new("Folder")
            bayFolder.Name = string.format(def.bayFolderFormat, side, column)
            stamp(bayFolder, bayId, side, column, 0, tileLength)
            bayFolder:SetAttribute("MergeBulwarkSlot", def.id)
            bayFolder:SetAttribute("MergeBulwarkMarkerLength", markerLength)
            bayFolder:SetAttribute("MergeBulwarkUsableLength", usableLength)
            bayFolder.Parent = stations

            for index = 1, TILE_COUNT do
                local offset = -usableLength * 0.5 + tileLength * (index - 0.5)
                local center = line.Position + direction * offset
                local anchor = Instance.new("Part")
                anchor.Name = string.format(def.anchorNameFormat, index)
                anchor.Anchored = true
                anchor.CanCollide = false
                anchor.CanTouch = false
                anchor.CanQuery = false
                anchor.CastShadow = false
                anchor.Transparency = 1
                anchor.Size = Vector3.new(0.5, 0.1, 0.5)
                anchor.CFrame = CFrame.lookAt(
                    Vector3.new(center.X, floorTop, center.Z),
                    Vector3.new(center.X, floorTop, center.Z) + direction,
                    Vector3.yAxis
                )
                stamp(anchor, bayId, side, column, index, tileLength)
                anchor:SetAttribute("MergeBulwarkSlot", def.id)
                anchor.Parent = bayFolder
                authored += 1
            end

            if def.required == true and bayId == "heaven_01" then
                firstBay = bayFolder
            end
        end
    end
end

map:SetAttribute("MergeBulwarkTilesPerBay", TILE_COUNT)
map:SetAttribute("MergeBulwarkWallInset", WALL_INSET)
map:SetAttribute("MergeBulwarkAnchorCount", authored)
Selection:Set(firstBay and { firstBay } or { map:FindFirstChild("BulwarkStations") })
ChangeHistoryService:SetWaypoint("Author Merge bulwark anchors")

print(string.format("[MergeBulwarkAnchors] authored %d anchors across %d slots", authored, #MergeBulwarkSlots.all()))
