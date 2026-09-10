-- Creates a new local seed place. Terrain is baked once in Studio Edit, then saved.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local r = require("@lune/roblox")
local cfg = serde.decode("json", fs.readFile("configs/realm_crossroads_terrain.json"))
local appearance = serde.decode("json", fs.readFile(cfg.appearance_source))
local study = serde.decode("json", fs.readFile(cfg.gate_source))
local places = require("../../configs/places")
cfg.walk_speed = places.roles.merge.walk_speed
cfg.palette = appearance.palette
cfg.faces = appearance.avatars
cfg.study = study
local function new(class, name, parent)
    local i = r.Instance.new(class)
    i.Name = name
    if parent then
        i.Parent = parent
    end
    return i
end
local game = new("DataModel", "RealmCrossroads-R4-Terrain")
local workspace = new("Workspace", "Workspace", game)
workspace.FallenPartsDestroyHeight = cfg.voxel.bottom - 40
local storage = new("ServerStorage", "ServerStorage", game)
local data = new("StringValue", "CrossroadsTerrainConfig", storage)
data.Value = serde.encode("json", cfg)
local bake = new("ModuleScript", "CrossroadsTerrainBake", storage)
bake.Source = fs.readFile(cfg.bake_source)
local crests = serde.decode("json", fs.readFile(cfg.crest_source))
local crestData = new("StringValue", "CrossroadsCrestConfig", storage)
crestData.Value = serde.encode("json", crests)
local glyphData = new("StringValue", "CrossroadsGlyphConfig", storage)
glyphData.Value = fs.readFile(crests.glyph_source)
local crestBake = new("ModuleScript", "CrossroadsCrestBake", storage)
crestBake.Source = fs.readFile(crests.source)
local bragg = serde.decode("json", fs.readFile(cfg.bragg_source))
local braggData = new("StringValue", "CrossroadsBraggConfig", storage)
braggData.Value = serde.encode("json", bragg)
local braggBake = new("ModuleScript", "CrossroadsBraggBake", storage)
braggBake.Source = fs.readFile(bragg.bake_source)
local activities = serde.decode("json", fs.readFile(cfg.activities_source))
local activityData = new("StringValue", "CrossroadsActivityConfig", storage)
activityData.Value = serde.encode("json", activities)
local activityBake = new("ModuleScript", "CrossroadsActivityBake", storage)
activityBake.Source = fs.readFile(activities.bake_source)
new("Folder", "CrossroadsActivityAssets", storage)
local landscape = serde.decode("json", fs.readFile(cfg.landscape_source))
local landscapeData = new("StringValue", "CrossroadsLandscapeConfig", storage)
landscapeData.Value = serde.encode("json", landscape)
local landscapeBake = new("ModuleScript", "CrossroadsLandscapeBake", storage)
landscapeBake.Source = fs.readFile(landscape.bake_source)
new("Folder", "CrossroadsLandscapeAssets", storage)
local marker = new("Part", "RunEditBakeFirst", workspace)
marker.Anchored = true
marker.Size = r.Vector3.new(10, 1, 10)
local player = new("StarterPlayer", "StarterPlayer", game)
player.CharacterWalkSpeed = cfg.walk_speed
fs.writeDir("output/realm_crossroads")
fs.writeFile("output/realm_crossroads/RealmCrossroads-R4-Terrain.rbxl", r.serializePlace(game))
print(
    "Created seed. In Studio Edit: require CrossroadsTerrainBake, then CrossroadsCrestBake, then CrossroadsBraggBake, then CrossroadsActivityBake, then CrossroadsLandscapeBake."
)
