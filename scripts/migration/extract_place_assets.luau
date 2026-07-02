--[[ Extract ReplicatedStorage.PlaceAssets/* from a downloaded .rbxl into per-model
.rbxm files (repo-resident models — the Rojo-managed asset source of truth).
    lune run scripts/migration/extract_place_assets.luau -- <place.rbxl> <out_dir>
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local placePath = process.args[1]
local outDir = process.args[2]
assert(placePath and outDir, "usage: lune run extract_place_assets.luau -- <place.rbxl> <out_dir>")

local game = roblox.deserializePlace(fs.readFile(placePath))
local rs = game:GetService("ReplicatedStorage")
local folder = rs:FindFirstChild("PlaceAssets")
assert(folder, "no ReplicatedStorage.PlaceAssets in the place file")

local n = 0
for _, child in ipairs(folder:GetChildren()) do
    local bytes = roblox.serializeModel({ child })
    fs.writeFile(`{outDir}/{child.Name}.rbxm`, bytes)
    n += 1
end
print(`extracted {n} models to {outDir}`)
