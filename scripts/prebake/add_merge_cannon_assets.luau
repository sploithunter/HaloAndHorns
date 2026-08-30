--!strict

-- Add the six Merge cannon meshes to the Rojo-served Models.rbxm library. The uploaded Model ids
-- remain provenance; runtime clones these local templates and never depends on Workspace review
-- objects. Current art is Tier 2. Tier 1 deliberately reuses that mesh at a smaller authored size
-- until its distinct model pass is ready.
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
cannonRoot:SetAttribute("MergeTowerModelTierCount", manifest.tiering.modelTierCount)
cannonRoot:SetAttribute("MergeTowerCurrentArtTier", manifest.tiering.currentArtTier)
cannonRoot:SetAttribute("MergeTowerTier1Scale", manifest.tiering.tier1Scale)
cannonRoot.Parent = root

local roleOrder = { "heal", "rage", "debuff", "gravity", "repulsor", "nullifier" }
local tierSpecs = {
    { tier = 1, scale = manifest.tiering.tier1Scale },
    { tier = 2, scale = 1 },
}

local added = 0
for _, role in ipairs(roleOrder) do
    local entry = assert(manifest[role], "missing cannon manifest entry for " .. role)
    local size = assert(entry.canonicalTier2Size, "missing Tier 2 size for " .. role)

    local roleFolder = roblox.Instance.new("Folder")
    roleFolder.Name = string.upper(string.sub(role, 1, 1)) .. string.sub(role, 2)
    roleFolder:SetAttribute("MergeTowerRole", role)
    roleFolder:SetAttribute("RobloxModelAssetId", entry.modelAssetId)
    roleFolder.Parent = cannonRoot

    for _, tierSpec in ipairs(tierSpecs) do
        local model = roblox.Instance.new("Model")
        model.Name = "Tier" .. tostring(tierSpec.tier)
        model:SetAttribute("MergeTowerRole", role)
        model:SetAttribute("MergeTowerTier", tierSpec.tier)
        model:SetAttribute("MergeTowerSourceArtTier", manifest.tiering.currentArtTier)
        model:SetAttribute("MergeTowerTemplateScale", tierSpec.scale)
        model:SetAttribute("RobloxModelAssetId", entry.modelAssetId)
        model:SetAttribute("RobloxMeshAssetId", entry.meshId)
        model:SetAttribute("RobloxTextureAssetId", entry.textureId)
        model.Parent = roleFolder

        local visual = roblox.Instance.new("MeshPart")
        visual.Name = "Visual"
        visual.MeshId = "rbxassetid://" .. tostring(entry.meshId)
        visual.TextureID = "rbxassetid://" .. tostring(entry.textureId)
        visual.Size = roblox.Vector3.new(
            size[1] * tierSpec.scale,
            size[2] * tierSpec.scale,
            size[3] * tierSpec.scale
        )
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
