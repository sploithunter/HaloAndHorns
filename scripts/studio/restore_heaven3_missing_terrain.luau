-- Restore the Heaven 3 terrain section omitted when the authored Layer 2 map was duplicated.
--
-- Safe to rerun: PasteRegion keeps existing Heaven 3 voxels and adds only non-empty source cells.
-- The bounds were found by comparing corresponding Heaven 2/3 voxel occupancy in 100-stud tiles.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local terrain = workspace.Terrain

local RESOLUTION = 4
local LAYER_OFFSET_VOXELS = Vector3int16.new(0, 500, 0) -- +2,000 studs at 4 studs/voxel
local SOURCE_MIN = Vector3int16.new(-105, 985, -30) -- (-420, 3940, -120)
local SOURCE_MAX = Vector3int16.new(25, 1030, 55) -- (100, 4120, 220)

local function countFilled(region: Region3): number
    local materials, occupancy = terrain:ReadVoxels(region:ExpandToGrid(RESOLUTION), RESOLUTION)
    local filled = 0
    for x = 1, #materials do
        for y = 1, #materials[x] do
            for z = 1, #materials[x][y] do
                if materials[x][y][z] ~= Enum.Material.Air and occupancy[x][y][z] > 0.01 then
                    filled += 1
                end
            end
        end
    end
    return filled
end

local targetMin = SOURCE_MIN + LAYER_OFFSET_VOXELS
local targetMax = SOURCE_MAX + LAYER_OFFSET_VOXELS
local targetRegion = Region3.new(
    Vector3.new(targetMin.X, targetMin.Y, targetMin.Z) * RESOLUTION,
    Vector3.new(targetMax.X, targetMax.Y, targetMax.Z) * RESOLUTION
)
local before = countFilled(targetRegion)

ChangeHistoryService:SetWaypoint("Before Heaven 3 terrain repair")
local source = terrain:CopyRegion(Region3int16.new(SOURCE_MIN, SOURCE_MAX))
terrain:PasteRegion(source, targetMin, false)
ChangeHistoryService:SetWaypoint("After Heaven 3 terrain repair")

local after = countFilled(targetRegion)
assert(after >= before, "Heaven 3 terrain voxel count decreased unexpectedly")
return ("Heaven 3 terrain restored: %d -> %d filled voxels (+%d)"):format(
    before,
    after,
    after - before
)
