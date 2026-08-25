--!strict

-- Add the uploaded Layer 3 environment meshes to the prebaked Models.rbxm bundle.
-- The registry remains the source of truth for Roblox ids; this script only supplies
-- the import-time natural bounds and runtime category for each completed asset.
--
-- Usage:
--   lune run scripts/prebake/add_layer3_environment_assets.luau \
--     assets/place/Models.rbxm <output.rbxm>

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local inputPath = process.args[1]
local outputPath = process.args[2]
assert(
    inputPath and outputPath,
    "usage: lune run add_layer3_environment_assets.luau <Models.rbxm> <output.rbxm>"
)

type AssetSpec = {
    category: string,
    size: { number },
}

local specs: { [string]: AssetSpec } = {
    abyss_orchid = { category = "Flora", size = { 1.957032, 2, 1.015624 } },
    blood_reed = { category = "Flora", size = { 2, 1.953124, 1.371094 } },
    bloomstone_shelf = { category = "Flora", size = { 2, 1.390340, 1.870864 } },
    bloomwing_butterfly = { category = "AmbientFauna", size = { 2, 2, 0.4482 } },
    celestial_bellgrass = { category = "Flora", size = { 2, 1.8817, 1.2578 } },
    crimson_watcher_bloom = { category = "Flora", size = { 1.5113, 2, 0.8006 } },
    dreadspire_faultstone = { category = "Flora", size = { 2, 1.480462, 1.928590 } },
    dreadspire_razorstone = { category = "Flora", size = { 2, 1.187199, 1.987182 } },
    dreadspire_ribbon_grass = { category = "Flora", size = { 2, 1.0508, 2 } },
    dreadspire_thorn_cactus = { category = "Flora", size = { 1.976900, 2, 1.277448 } },
    dreadspire_watch_shrine = { category = "Landmarks", size = { 1.609298, 1.936256, 2 } },
    -- Trees need a larger canonical height than raw Roblox model uploads (which
    -- normalize to ~2 studs). FloraService intentionally clamps ScaleTo at 5x;
    -- a 12-stud canonical tree can therefore honor the copied 28-60 stud anchors.
    dreadthorn_tree = { category = "Flora", size = { 12.2339, 12, 7.7004 } },
    dreadwing_beetle = { category = "AmbientFauna", size = { 1.6562, 0.9082, 2 } },
    ember_thorn_cluster = { category = "Flora", size = { 2, 1.914166, 0.998046 } },
    emerald_ribbon_shrub = { category = "Flora", size = { 1.9688, 2, 2 } },
    empyrean_bloom_cactus = { category = "Flora", size = { 1.949218, 2, 1.308594 } },
    empyrean_hibiscus = { category = "Flora", size = { 1.738282, 2, 1.324218 } },
    empyrean_bloom_shrine = { category = "Landmarks", size = { 2, 1.9330, 1.6014 } },
    gloom_pitcher = { category = "Flora", size = { 1.7461, 2, 1.6562 } },
    halo_fern = { category = "Flora", size = { 2, 2, 1.0625 } },
    ironroot_crawler = { category = "Flora", size = { 2, 0.6895, 2 } },
    jade_lantern_bloom = { category = "Flora", size = { 2, 1.987070, 1.400068 } },
    living_root_pavilion = { category = "Landmarks", size = { 2, 1.953124, 1.949218 } },
    lumen_moss_cushion = { category = "Flora", size = { 1.9888, 0.8470, 2 } },
    luminous_canopy_tree = { category = "Flora", size = { 12.0235, 12, 11.7182 } },
    moonpetal_bush = { category = "Flora", size = { 2, 1.8047, 1.2422 } },
    obsidian_gatehouse = { category = "Landmarks", size = { 2, 1.618400, 0.985958 } },
    obsidian_hornback_lizard = { category = "AmbientFauna", size = { 1.4297, 1.0547, 2 } },
    obsidian_spike_plant = { category = "Flora", size = { 2, 1.303326, 1.984344 } },
    pearlback_snail = { category = "AmbientFauna", size = { 1.0278, 1.1371, 2 } },
    pearlroot_anemone = { category = "Flora", size = { 1.9805, 2, 1.8242 } },
    pearlroot_boulder = { category = "Flora", size = { 2, 1.484376, 2 } },
    petal_spire = { category = "Flora", size = { 1.183594, 2, 1.136718 } },
    razorleaf_fan = { category = "Flora", size = { 2, 1.2187, 2 } },
    rootlight_vine = { category = "Flora", size = { 1.907812, 2, 1.497590 } },
    violet_bramble = { category = "Flora", size = { 1.990174, 1.976920, 2 } },
    violet_hook_bloom = { category = "Flora", size = { 1.8984, 2, 1.2656 } },
    wingleaf_reed = { category = "Flora", size = { 1.6672, 2, 0.4613 } },
}

local registry = serde.decode("json", fs.readFile("scripts/layer3_prop_assets.json"))
local roots = roblox.deserializeModel(fs.readFile(inputPath))
assert(#roots == 1, "expected Models.rbxm to contain exactly one root")
local root = roots[1]

local categories: { [string]: any } = {}
for _, categoryName in ipairs({ "Flora", "AmbientFauna", "Landmarks" }) do
    local category = root:FindFirstChild(categoryName)
    if not category then
        category = roblox.Instance.new("Folder")
        category.Name = categoryName
        category.Parent = root
    end
    categories[categoryName] = category
end

local added = 0
for name, spec in pairs(specs) do
    local entry = registry.assets[name]
    assert(entry, "missing registry entry for " .. name)

    local category = categories[spec.category]
    local previous = category:FindFirstChild(name)
    if previous then
        previous:Destroy()
    end

    local model = roblox.Instance.new("Model")
    model.Name = name
    model:SetAttribute("Layer3Realm", entry.realm)
    model:SetAttribute("RobloxModelAssetId", entry.model_asset)
    model.Parent = category

    local mesh = roblox.Instance.new("MeshPart")
    mesh.Name = "Visual"
    mesh.MeshId = entry.mesh_id
    mesh.TextureID = entry.texture_image
    mesh.Size = roblox.Vector3.new(spec.size[1], spec.size[2], spec.size[3])
    mesh.Anchored = true
    mesh.CanCollide = spec.category == "Landmarks"
    mesh.CanTouch = false
    mesh.CanQuery = spec.category == "Landmarks"
    mesh.Parent = model

    added += 1
end

fs.writeFile(outputPath, roblox.serializeModel(roots))
print(string.format("wrote %s with %d Layer 3 environment assets", outputPath, added))
