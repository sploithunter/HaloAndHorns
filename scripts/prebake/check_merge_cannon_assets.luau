--!strict

-- Validate the checked-in Merge cannon prebake against the 24-entry proof manifest.
-- Usage: lune run scripts/prebake/check_merge_cannon_assets.luau [Models.rbxm]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local inputPath = process.args[1] or "assets/place/Models.rbxm"
local manifest = serde.decode("json", fs.readFile("scripts/merge_cannon_model_ids.json"))
local roots = roblox.deserializeModel(fs.readFile(inputPath))
assert(#roots == 1, "expected Models.rbxm to contain exactly one root")

local cannonRoot = assert(roots[1]:FindFirstChild("MergeCannons"), "MergeCannons folder missing")
assert(cannonRoot:GetAttribute("MergeTowerModelTierCount") == 4, "wrong model tier count")
assert(
    cannonRoot:GetAttribute("MergeTowerScaledCopyFallbackRemoved") == true,
    "scaled-copy fallback marker missing"
)

local templateCount = 0
local meshIds = {}
local textureIds = {}
for role, family in pairs(manifest.families) do
    local roleFolder =
        assert(cannonRoot:FindFirstChild(family.displayName), "missing family " .. role)
    for _, entry in ipairs(family.tiers) do
        local tier = entry.tier
        local model = assert(roleFolder:FindFirstChild("Tier" .. tostring(tier)), "missing tier")
        assert(model:IsA("Model"), "tier template must be a Model")
        assert(model:GetAttribute("MergeTowerRole") == role, "role attribute mismatch")
        assert(model:GetAttribute("MergeTowerTier") == tier, "tier attribute mismatch")
        assert(model:GetAttribute("MergeTowerSourceArtTier") == tier, "source art tier mismatch")
        assert(model:GetAttribute("MergeTowerTemplateScale") == 1, "template is scaled")
        assert(
            tostring(model:GetAttribute("RobloxModelAssetId")) == entry.roblox.modelAssetId,
            "Model asset id mismatch"
        )

        local visual = assert(model:FindFirstChild("Visual"), "Visual MeshPart missing")
        assert(visual:IsA("MeshPart"), "Visual must be a MeshPart")
        local embeddedMesh = tostring(model:GetAttribute("RobloxMeshAssetId"))
        local embeddedTexture = tostring(model:GetAttribute("RobloxTextureAssetId"))
        assert(embeddedMesh == entry.roblox.meshId, "Mesh id mismatch")
        assert(embeddedTexture == entry.roblox.textureId, "Texture id mismatch")
        assert(not meshIds[embeddedMesh], "duplicate Mesh id in prebake")
        assert(not textureIds[embeddedTexture], "duplicate Texture id in prebake")
        meshIds[embeddedMesh] = true
        textureIds[embeddedTexture] = true
        templateCount += 1
    end
end

assert(templateCount == 24, "expected 24 Merge cannon templates")
assert(#cannonRoot:GetChildren() == 6, "expected six Merge cannon families")
print(
    string.format("PASS %s: %d distinct four-tier Merge cannon templates", inputPath, templateCount)
)
