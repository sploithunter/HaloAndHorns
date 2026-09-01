--!strict

-- Add the six four-tier Merge bulwark families to the Rojo-served Models.rbxm library.
-- Maps own only placement anchors; gameplay clones these local templates and never loads the
-- provenance Model assets at runtime. The native Roblox Model snapshots are intentional: rebuilding
-- only a MeshPart from MeshId/TextureId loses the imported package pivot and internal orientation.
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
local nativeRoot = "assets/source/props/merge_bulwarks/roblox_originals"
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
        local nativePath = entry.approvedNativeSource
            or string.format("%s/%s/tier%d/model.rbxm", nativeRoot, familyId, entry.tier)
        assert(fs.isFile(nativePath), "missing native Roblox bulwark snapshot " .. nativePath)
        local nativeRoots = roblox.deserializeModel(fs.readFile(nativePath))
        assert(#nativeRoots == 1, "expected one root in " .. nativePath)
        local model = nativeRoots[1]
        assert(model:IsA("Model"), "expected Model root in " .. nativePath)
        model.Name = "Tier" .. tostring(entry.tier)
        model:SetAttribute("MergeBulwarkFamily", familyId)
        model:SetAttribute("MergeBulwarkTier", entry.tier)
        model:SetAttribute("MergeBulwarkTriangles", entry.triangles)
        model:SetAttribute("RobloxModelAssetId", entry.modelAssetId)
        model:SetAttribute("RobloxMeshAssetId", entry.meshId)
        model:SetAttribute("RobloxTextureAssetId", entry.textureId)
        model:SetAttribute("MergeBulwarkNativePackage", true)
        model:SetAttribute(
            "MergeBulwarkSourceUniformScale",
            manifest.tileReferenceLength
                / math.max(entry.rawRobloxSize[1], entry.rawRobloxSize[2], entry.rawRobloxSize[3])
        )
        if family.animationClass then
            model:SetAttribute("MergeBulwarkAnimationClass", family.animationClass)
        end
        if entry.speedDegrees then
            model:SetAttribute("SawBladeSpeedDegrees", entry.speedDegrees)
            model:SetAttribute("PreviewSpeedDegrees", entry.speedDegrees)
        end
        if entry.robloxRotationAxis then
            model:SetAttribute("RotationAxis", entry.robloxRotationAxis)
        end
        if entry.idleSoundKey then
            model:SetAttribute("MergeBulwarkIdleSoundKey", entry.idleSoundKey)
        end
        if entry.impactSoundKey then
            model:SetAttribute("MergeBulwarkImpactSoundKey", entry.impactSoundKey)
        end
        -- Keep the lossless PackageLink in the source snapshot, but detach the runtime template so
        -- Studio cannot update the served library behind the prebake's back.
        for _, descendant in ipairs(model:GetDescendants()) do
            if descendant:IsA("PackageLink") then
                descendant:Destroy()
            end
        end
        model.Parent = familyFolder
        added += 1
    end
end

fs.writeFile(outputPath, roblox.serializeModel(roots))
print(string.format("wrote %s with %d spawnable Merge bulwark templates", outputPath, added))
