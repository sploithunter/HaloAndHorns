--!strict

-- Build a cacheable one-MeshPart model for ReplicatedStorage.PlaceAssets.
-- Usage: lune run scripts/prebake/build_mesh_place_asset.luau \
--   <output.rbxm> <asset-name> <mesh-id> <texture-id> <size-x> <size-y> <size-z>

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local outputPath = process.args[1]
local assetName = process.args[2]
local meshId = process.args[3]
local textureId = process.args[4]
local sizeX = tonumber(process.args[5])
local sizeY = tonumber(process.args[6])
local sizeZ = tonumber(process.args[7])

if
    not outputPath
    or not assetName
    or not meshId
    or not textureId
    or not sizeX
    or not sizeY
    or not sizeZ
then
    print("usage: build_mesh_place_asset.luau <output> <name> <mesh-id> <texture-id> <x> <y> <z>")
    process.exit(1)
end

local model = roblox.Instance.new("Model")
model.Name = assetName

local mesh = roblox.Instance.new("MeshPart")
mesh.Name = "hall_egg_stand"
mesh.MeshId = "rbxassetid://" .. meshId
mesh.TextureID = "rbxassetid://" .. textureId
mesh.Size = roblox.Vector3.new(sizeX, sizeY, sizeZ)
mesh.Anchored = true
mesh.CanCollide = false
mesh.CanTouch = false
mesh.Parent = model

fs.writeFile(outputPath, roblox.serializeModel({ model }))
print("wrote " .. outputPath)
