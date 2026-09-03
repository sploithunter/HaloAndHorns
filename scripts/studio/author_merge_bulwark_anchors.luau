-- Run in Roblox Studio Edit mode after the polished Merge realm map is present.
--
-- Authors the orange/mid and green/front placement lines, then stamps invisible
-- placement anchors across all four rows. Never create, rename, or destroy
-- BulwarkLine or BreachLine — those two parts remain the only combat planes
-- (pets open / eggs become attackable). Orange and green are install hooks only.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

assert(not RunService:IsRunning(), "Author Merge bulwark anchors in Edit mode")

local MergeBulwarkSlots = require(ReplicatedStorage.Shared.Game.MergeBulwarkSlots)
local MergeConfig = require(ReplicatedStorage.Configs:WaitForChild("merge_egg_prototype"))
local bulwarkConfig = assert(MergeConfig.team.edge_bulwarks, "team.edge_bulwarks is missing")
local lineLayout = assert(bulwarkConfig.line_layout, "edge_bulwarks.line_layout is missing")

local map = assert(
    Workspace:FindFirstChild("GeneratedMap_MergeEggVoxel"),
    "Workspace.GeneratedMap_MergeEggVoxel is missing"
)
local laneLines = assert(map:FindFirstChild("LaneLines"), "LaneLines is missing")
local playFields = assert(map:FindFirstChild("PlayFields"), "PlayFields is missing")
local portableBays = Workspace:FindFirstChild("Maps")
    and Workspace.Maps:FindFirstChild("MergeEggRealm")
    and Workspace.Maps.MergeEggRealm:FindFirstChild("Bays")

local TILE_COUNT = assert(tonumber(bulwarkConfig.tile_count), "edge_bulwarks.tile_count is missing")
local WALL_INSET =
    assert(tonumber(bulwarkConfig.wall_inset_studs), "edge_bulwarks.wall_inset_studs is missing")
local CANONICAL_TILE_LENGTH = assert(
    tonumber(bulwarkConfig.canonical_tile_length_studs),
    "edge_bulwarks.canonical_tile_length_studs is missing"
)
local INTERVAL_FRACTION =
    assert(tonumber(lineLayout.interval_fraction), "bulwark interval fraction is missing")
assert(math.abs(INTERVAL_FRACTION - 0.5) < 1e-6, "orange line must be the exact midpoint")

local function configColor(row, path)
    assert(type(row) == "table" and #row >= 3, path .. " is missing")
    return Color3.fromRGB(
        assert(tonumber(row[1]), path .. "[1] must be numeric"),
        assert(tonumber(row[2]), path .. "[2] must be numeric"),
        assert(tonumber(row[3]), path .. "[3] must be numeric")
    )
end

local function configureHelperLine(lines, def, template, position, color)
    local line = lines:FindFirstChild(def.lineDefault)
    if not (line and line:IsA("BasePart")) then
        if line then
            line:Destroy()
        end
        line = Instance.new("Part")
        line.Name = def.lineDefault
        line.Parent = lines
    end
    line.Anchored = true
    line.CanCollide = false
    line.CanTouch = false
    line.CanQuery = false
    line.CastShadow = false
    line.Size = template.Size
    line.CFrame = CFrame.new(position) * template.CFrame.Rotation
    line.Color = color
    line.Material = Enum.Material.Neon
    line.Transparency =
        assert(tonumber(lineLayout.transparency), "bulwark line transparency is missing")
    line.TopSurface = Enum.SurfaceType.Smooth
    line.BottomSurface = Enum.SurfaceType.Smooth
    line:SetAttribute("MergeBulwarkPlacementLine", true)
    line:SetAttribute("MergeBulwarkSlot", def.id)
    line:SetAttribute(
        "MergeBulwarkUnlockRebirthRank",
        MergeBulwarkSlots.requiredRebirthRank(def, bulwarkConfig)
    )
    return line
end

local helperLines = 0
for _, lines in ipairs(laneLines:GetChildren()) do
    local bulwark = lines:FindFirstChild(tostring(MergeConfig.world.bulwark_line or "BulwarkLine"))
    local breach = lines:FindFirstChild(tostring(MergeConfig.world.breach_line or "BreachLine"))
    if bulwark and bulwark:IsA("BasePart") and breach and breach:IsA("BasePart") then
        local midDef = assert(MergeBulwarkSlots.get("mid"))
        local frontDef = assert(MergeBulwarkSlots.get("front"))
        local midPosition = breach.Position:Lerp(bulwark.Position, INTERVAL_FRACTION)
        local interval = bulwark.Position - midPosition
        configureHelperLine(
            lines,
            midDef,
            bulwark,
            midPosition,
            configColor(lineLayout.mid_color, "edge_bulwarks.line_layout.mid_color")
        )
        configureHelperLine(
            lines,
            frontDef,
            bulwark,
            bulwark.Position + interval,
            configColor(lineLayout.front_color, "edge_bulwarks.line_layout.front_color")
        )
        helperLines += 2
    end
end

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
        if
            side
            and column
            and line
            and line:IsA("BasePart")
            and field
            and field:IsA("BasePart")
        then
            local longIsX = line.Size.X >= line.Size.Z
            local markerLength = longIsX and line.Size.X or line.Size.Z
            local usableLength = markerLength - WALL_INSET * 2
            assert(
                usableLength > 0,
                lines:GetFullName() .. " " .. tostring(lineName or def.id) .. " is too short"
            )
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
            bayFolder:SetAttribute(
                "MergeBulwarkUnlockRebirthRank",
                MergeBulwarkSlots.requiredRebirthRank(def, bulwarkConfig)
            )
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
                anchor:SetAttribute(
                    "MergeBulwarkUnlockRebirthRank",
                    MergeBulwarkSlots.requiredRebirthRank(def, bulwarkConfig)
                )
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

print(
    string.format(
        "[MergeBulwarkAnchors] authored %d helper lines and %d anchors across %d slots",
        helperLines,
        authored,
        #MergeBulwarkSlots.all()
    )
)
