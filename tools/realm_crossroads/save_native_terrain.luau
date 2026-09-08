-- Wrap Studio's native serialized terrain/art export in a standalone place.
-- Input must come from SerializationService after the Edit bake; never regenerate terrain here.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local r = require("@lune/roblox")
local cfg = serde.decode("json", fs.readFile("configs/realm_crossroads_terrain.json"))
local places = require("../../configs/places")
local function new(class, name, parent)
    local i = r.Instance.new(class)
    i.Name = name
    if parent then
        i.Parent = parent
    end
    return i
end
local game = new("DataModel", "RealmCrossroads-R4-Terrain")
local world = new("Workspace", "Workspace", game)
world.FallenPartsDestroyHeight = cfg.voxel.bottom - 40
local player = new("StarterPlayer", "StarterPlayer", game)
player.CharacterWalkSpeed = places.roles.merge.walk_speed
local instances = r.deserializeModel(fs.readFile("output/realm_crossroads/native-r4-export.rbxm"))
for _, top in ipairs(instances) do
    if top.ClassName == "Terrain" then
        top.Parent = world
    else
        for _, item in ipairs(top:GetChildren()) do
            if item.ClassName == "Folder" then
                local parent = game
                if
                    item.Name == "StarterPlayerScripts"
                    or item.Name == "StarterCharacterScripts"
                then
                    parent = player
                end
                local service = new(item.Name, item.Name, parent)
                for _, child in ipairs(item:GetChildren()) do
                    child.Parent = service
                end
            else
                item.Parent = world
            end
        end
    end
end
local light = game:FindFirstChild("Lighting")
light.ClockTime = cfg.lighting.clock_time
light.Brightness = cfg.lighting.brightness
light.Ambient = r.Color3.fromRGB(unpack(cfg.lighting.ambient))
assert(world:FindFirstChild("Terrain"), "Missing native terrain")
assert(world:FindFirstChild(cfg.root), "Missing authored geometry")
game.ServerStorage.CrossroadsTerrainBake.Source = fs.readFile(cfg.bake_source)
local bragg = serde.decode("json", fs.readFile(cfg.bragg_source))
game.ServerStorage.CrossroadsBraggBake.Source = fs.readFile(bragg.bake_source)
game.ServerStorage.CrossroadsBraggConfig.Value = serde.encode("json", bragg)
local activities = serde.decode("json", fs.readFile(cfg.activities_source))
game.ServerStorage.CrossroadsActivityBake.Source = fs.readFile(activities.bake_source)
game.ServerStorage.CrossroadsActivityConfig.Value = serde.encode("json", activities)
local landscape = serde.decode("json", fs.readFile(cfg.landscape_source))
game.ServerStorage.CrossroadsLandscapeBake.Source = fs.readFile(landscape.bake_source)
game.ServerStorage.CrossroadsLandscapeConfig.Value = serde.encode("json", landscape)
fs.writeFile("output/realm_crossroads/RealmCrossroads-R4-Terrain.rbxl", r.serializePlace(game))
print("Saved baked R4 place from native Studio export: " .. #game:GetDescendants() .. " instances")
