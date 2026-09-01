--!strict

-- Add all 24 Merge cannon meshes to the Rojo-served Models.rbxm library. The uploaded Model ids
-- remain provenance; runtime clones these local templates and never depends on Workspace review
-- objects. Every gameplay tier has its own Mesh and Texture asset at a uniform template scale.
--
-- Usage:
--   lune run scripts/prebake/add_merge_cannon_assets.luau \
--     assets/place/Models.rbxm <output.rbxm>

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local inputPath = process.args[1]
local outputPath = process.args[2]
assert(inputPath and outputPath, "usage: add_merge_cannon_assets.luau <Models.rbxm> <output.rbxm>")

local manifest = serde.decode("json", fs.readFile("scripts/merge_cannon_model_ids.json"))
local roots = roblox.deserializeModel(fs.readFile(inputPath))
assert(#roots == 1, "expected Models.rbxm to contain exactly one root")
local root = roots[1]

local previous = root:FindFirstChild("MergeCannons")
if previous then
    previous:Destroy()
end

local cannonRoot = roblox.Instance.new("Folder")
cannonRoot.Name = "MergeCannons"
cannonRoot:SetAttribute("MergeTowerModelTierCount", manifest.runtimeContract.modelTierCount)
cannonRoot:SetAttribute("MergeTowerScaledCopyFallbackRemoved", true)
cannonRoot.Parent = root

local roleOrder = { "heal", "rage", "debuff", "gravity", "repulsor", "nullifier" }

local added = 0
for _, role in ipairs(roleOrder) do
    local family = assert(manifest.families[role], "missing cannon manifest family for " .. role)

    local roleFolder = roblox.Instance.new("Folder")
    roleFolder.Name = family.displayName
    roleFolder:SetAttribute("MergeTowerRole", role)
    roleFolder.Parent = cannonRoot

    for _, entry in ipairs(family.tiers) do
        local tier = assert(entry.tier, "missing tier number for " .. role)
        local robloxEntry = assert(entry.roblox, "missing Roblox ids for " .. role)
        local size = assert(robloxEntry.canonicalSize, "missing canonical size for " .. role)
        local model = roblox.Instance.new("Model")
        model.Name = "Tier" .. tostring(tier)
        model:SetAttribute("MergeTowerRole", role)
        model:SetAttribute("MergeTowerTier", tier)
        model:SetAttribute("MergeTowerSourceArtTier", tier)
        model:SetAttribute("MergeTowerTemplateScale", 1)
        model:SetAttribute("RobloxModelAssetId", robloxEntry.modelAssetId)
        model:SetAttribute("RobloxMeshAssetId", robloxEntry.meshId)
        model:SetAttribute("RobloxTextureAssetId", robloxEntry.textureId)
        model.Parent = roleFolder

        local visual = roblox.Instance.new("MeshPart")
        visual.Name = "Visual"
        visual.MeshId = "rbxassetid://" .. tostring(robloxEntry.meshId)
        visual.TextureID = "rbxassetid://" .. tostring(robloxEntry.textureId)
        visual.Size = roblox.Vector3.new(size[1], size[2], size[3])
        visual.Anchored = true
        visual.CanCollide = false
        visual.CanTouch = false
        visual.CanQuery = false
        visual.CastShadow = true
        visual.Massless = true
        visual.Parent = model
        model.PrimaryPart = visual
        added += 1
    end
end

fs.writeFile(outputPath, roblox.serializeModel(roots))
print(string.format("wrote %s with %d spawnable Merge cannon templates", outputPath, added))
