--!strict

-- Add the six four-tier Merge bulwark families to the Rojo-served Models.rbxm library.
-- Maps own only placement anchors; gameplay clones these local templates and never loads the
-- provenance Model assets at runtime.
--
-- Usage:
--   lune run scripts/prebake/add_merge_bulwark_assets.luau \
--     assets/place/Models.rbxm <output.rbxm>

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local inputPath = process.args[1]
local outputPath = process.args[2]
assert(inputPath and outputPath, "usage: add_merge_bulwark_assets.luau <Models.rbxm> <output.rbxm>")

local manifest = serde.decode("json", fs.readFile("scripts/merge_bulwark_model_ids.json"))
local roots = roblox.deserializeModel(fs.readFile(inputPath))
assert(#roots == 1, "expected Models.rbxm to contain exactly one root")
local root = roots[1]

local previous = root:FindFirstChild("MergeBulwarks")
if previous then
    previous:Destroy()
end

local bulwarkRoot = roblox.Instance.new("Folder")
bulwarkRoot.Name = "MergeBulwarks"
bulwarkRoot:SetAttribute("MergeBulwarkModelTierCount", manifest.modelTierCount)
bulwarkRoot:SetAttribute("MergeBulwarkTileReferenceLength", manifest.tileReferenceLength)
bulwarkRoot.Parent = root

local familyOrder = {
    "impaler_palisade",
    "concertina_line",
    "land_shark",
    "saw_blade",
    "grasping_hedge",
    "wardstone_barrier",
}

local function folderName(displayName: string): string
    return string.gsub(displayName, "%s+", "")
end

local added = 0
for _, familyId in ipairs(familyOrder) do
    local family = assert(manifest.families[familyId], "missing bulwark family " .. familyId)
    local familyFolder = roblox.Instance.new("Folder")
    familyFolder.Name = folderName(family.displayName)
    familyFolder:SetAttribute("MergeBulwarkFamily", familyId)
    if family.animationClass then
        familyFolder:SetAttribute("MergeBulwarkAnimationClass", family.animationClass)
    end
    familyFolder.Parent = bulwarkRoot

    for _, entry in ipairs(family.tiers) do
        local model = roblox.Instance.new("Model")
        model.Name = "Tier" .. tostring(entry.tier)
        model:SetAttribute("MergeBulwarkFamily", familyId)
        model:SetAttribute("MergeBulwarkTier", entry.tier)
        model:SetAttribute("MergeBulwarkTriangles", entry.triangles)
        model:SetAttribute("RobloxModelAssetId", entry.modelAssetId)
        model:SetAttribute("RobloxMeshAssetId", entry.meshId)
        model:SetAttribute("RobloxTextureAssetId", entry.textureId)
        if family.animationClass then
            model:SetAttribute("MergeBulwarkAnimationClass", family.animationClass)
        end
        model.Parent = familyFolder

        local visual = roblox.Instance.new("MeshPart")
        visual.Name = "Visual"
        visual.MeshId = "rbxassetid://" .. tostring(entry.meshId)
        visual.TextureID = "rbxassetid://" .. tostring(entry.textureId)
        visual.Size = roblox.Vector3.new(
            entry.canonicalSize[1],
            entry.canonicalSize[2],
            entry.canonicalSize[3]
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
print(string.format("wrote %s with %d spawnable Merge bulwark templates", outputPath, added))
