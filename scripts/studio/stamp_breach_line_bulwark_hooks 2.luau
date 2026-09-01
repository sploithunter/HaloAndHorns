-- Runtime/Edit stamp: Breach Line placement hooks + Manage prompts.
-- Does not touch BulwarkLine, BreachLine, or existing gold-line stations.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local Progression = require(ReplicatedStorage.Shared.Game.MergeBulwarkProgression)
local Slots = require(ReplicatedStorage.Shared.Game.MergeBulwarkSlots)

local TILE_COUNT = 10
local WALL_INSET = 1
local CANONICAL_TILE_LENGTH = 10

local map = assert(Workspace:FindFirstChild("GeneratedMap_MergeEggVoxel"), "map missing")
local laneLines = assert(map:FindFirstChild("LaneLines"), "LaneLines missing")
local playFields = assert(map:FindFirstChild("PlayFields"), "PlayFields missing")
local portableBays = Workspace:FindFirstChild("Maps")
    and Workspace.Maps:FindFirstChild("MergeEggRealm")
    and Workspace.Maps.MergeEggRealm:FindFirstChild("Bays")

local def = Slots.get("egg")
local old = map:FindFirstChild(def.stationsFolder)
if old then
    old:Destroy()
end
local stations = Instance.new("Folder")
stations.Name = def.stationsFolder
stations.Parent = map

local function stamp(instance, bayId, side, column, index, tileLength)
    instance:SetAttribute("MergeEggBayId", bayId)
    instance:SetAttribute("MergeEggBaySide", string.lower(side))
    instance:SetAttribute("MergeEggBayColumn", column)
    instance:SetAttribute("MergeBulwarkTileIndex", index)
    instance:SetAttribute("MergeBulwarkTileCount", TILE_COUNT)
    instance:SetAttribute("MergeBulwarkTileLength", tileLength)
    instance:SetAttribute("MergeBulwarkScale", tileLength / CANONICAL_TILE_LENGTH)
    instance:SetAttribute("MergeBulwarkWallInset", WALL_INSET)
    instance:SetAttribute("MergeBulwarkSlot", def.id)
end

local authored = 0
local heavenAnchors
for _, lines in ipairs(laneLines:GetChildren()) do
    local side, columnText = string.match(lines.Name, "^(Heaven)_(%d+)_Lines$")
    if not side then
        side, columnText = string.match(lines.Name, "^(Hell)_(%d+)_Lines$")
    end
    local column = tonumber(columnText)
    local lineName = Slots.stripLineName(def)
    local line = lineName and lines:FindFirstChild(lineName)
    local field = side
        and column
        and playFields:FindFirstChild(string.format("%s_%02d", side, column))
    if side and column and line and line:IsA("BasePart") and field and field:IsA("BasePart") then
        local longIsX = line.Size.X >= line.Size.Z
        local markerLength = longIsX and line.Size.X or line.Size.Z
        local usableLength = markerLength - WALL_INSET * 2
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
        bayFolder.Parent = stations
        local anchors = {}
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
            anchor.Parent = bayFolder
            anchors[index] = anchor
            authored += 1
        end
        if bayId == "heaven_01" then
            heavenAnchors = anchors
        end
    end
end

local function openBreachMenu(who, world)
    local owned = {}
    local laneFamily = world and world:GetAttribute("MergeBulwarkFamily")
    local laneTier = tonumber(world and world:GetAttribute("MergeBulwarkTier")) or 0
    local eggFamily = world and (world:GetAttribute("MergeEggBulwarkFamily") or world:GetAttribute("MergeBulwark_egg_Family"))
    local eggTier = tonumber(world and (world:GetAttribute("MergeEggBulwarkTier") or world:GetAttribute("MergeBulwark_egg_Tier"))) or 0
    if type(laneFamily) == "string" and laneFamily ~= "" then
        owned[laneFamily] = math.max(1, laneTier)
    end
    if type(eggFamily) == "string" and eggFamily ~= "" then
        owned[eggFamily] = math.max(1, eggTier)
    end
    Signals.MergeEggPrototypeBoardResult:FireClient(who, {
        ok = true,
        action = "open_bulwark_menu",
        value = {
            slot = "egg",
            family = type(eggFamily) == "string" and eggFamily ~= "" and eggFamily or nil,
            tier = eggTier,
            owned = owned,
            installed = type(eggFamily) == "string" and eggFamily ~= "",
            maximumTier = 4,
            families = Progression.familiesForSlot("egg"),
            unlocked = true,
            unlockWave = 1,
            productionUnlockWave = 20,
            tutorialIntermissionWave = 20,
            playtestUnlock = true,
            currentWave = math.max(1, math.floor(tonumber(who:GetAttribute("CombatMusicCue") and 7) or 7)),
            actionCost = 1,
            currency = "hall_coins",
            wallet = math.max(0, math.floor(tonumber(who:GetAttribute("Hall_coins")) or 0)),
        },
    })
end

local hostCount = 0
local nearest = math.huge
local player = Players:GetPlayers()[1]
local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
local bay = portableBays and portableBays:FindFirstChild("MergeBay_heaven_01")
local folder = bay and bay:FindFirstChild("MergeEggBulwarks")
if folder and heavenAnchors then
    local midIndex = math.max(1, math.ceil(#heavenAnchors * 0.5))
    local ends = { heavenAnchors[1], heavenAnchors[midIndex], heavenAnchors[#heavenAnchors] }
    local suffixes = { "EggLeft", "EggMid", "EggRight" }
    for i, anchor in ipairs(ends) do
        local existing = folder:FindFirstChild("MergeEggBulwarkMenuHost_" .. suffixes[i])
        if existing then
            existing:Destroy()
        end
        local host = Instance.new("Part")
        host.Name = "MergeEggBulwarkMenuHost_" .. suffixes[i]
        host.Size = Vector3.new(2, 4, 2)
        host.CFrame = anchor.CFrame * CFrame.new(0, 2, 0)
        host.Anchored = true
        host.CanCollide = false
        host.CanTouch = false
        host.CanQuery = false
        host.Transparency = 1
        host:SetAttribute("MergeBulwarkSlot", "egg")
        host.Parent = folder
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "MergeEggBulwarkMenuPrompt"
        prompt.ActionText = "Manage"
        prompt.ObjectText = "Bulwark"
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 22
        prompt.RequiresLineOfSight = false
        prompt.Parent = host
        prompt.Triggered:Connect(function(who)
            openBreachMenu(who, bay)
        end)
        hostCount += 1
        if root then
            nearest = math.min(nearest, (root.Position - host.Position).Magnitude)
        end
    end
end

return {
    authored = authored,
    hosts = hostCount,
    nearest = nearest,
    laneStationsIntact = map:FindFirstChild("BulwarkStations") ~= nil,
}
