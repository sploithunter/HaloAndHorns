-- Spawnable Merge tower model access. Authored maps own only TowerAnchor pads; cannon visuals are
-- cloned from ReplicatedStorage.Assets.Models.MergeCannons when a tower exists.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MergeTierArt = require(script.Parent.MergeTierArt)

local MergeTowerModels = {}

local ROLE_NAMES = {
    heal = "Heal",
    rage = "Rage",
    debuff = "Debuff",
    gravity = "Gravity",
    repulsor = "Repulsor",
    nullifier = "Nullifier",
}

local function templatesRoot(rootOverride)
    if rootOverride then
        return rootOverride
    end
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local models = assets and assets:FindFirstChild("Models")
    return models and models:FindFirstChild("MergeCannons")
end

local function contentId(value)
    return string.match(tostring(value or ""), "(%d+)$") or ""
end

local function anchorPart(pad)
    if not pad then
        return nil
    end
    if pad:IsA("BasePart") then
        return pad
    end
    local named = pad:FindFirstChild("TowerAnchor", true)
    if named and named:IsA("BasePart") then
        return named
    end
    return pad:FindFirstChildWhichIsA("BasePart", true)
end

function MergeTowerModels.GetTemplate(role, tier, rootOverride)
    local roleName = ROLE_NAMES[string.lower(tostring(role or ""))]
    local resolvedTier = math.max(1, math.floor(tonumber(tier) or 1))
    local root = templatesRoot(rootOverride)
    local roleFolder = root and roleName and root:FindFirstChild(roleName)
    local template = roleFolder and roleFolder:FindFirstChild("Tier" .. tostring(resolvedTier))
    if template and template:IsA("Model") then
        return template
    end
    return nil
end

function MergeTowerModels.worldScale(scale)
    local resolved = tonumber(scale)
    if resolved == nil then
        return 1
    end
    return math.max(0.1, resolved)
end

function MergeTowerModels.entryWorldScale(tierArt, role, tier)
    local art = MergeTierArt.entry(tierArt, "cannon", role, tier)
    return MergeTowerModels.worldScale(art and art.worldScale)
end

function MergeTowerModels.MatchesTemplate(model, role, tier, rootOverride, tierArt, worldScale)
    if not (model and model:IsA("Model")) then
        return false
    end
    local expected = MergeTierArt.entry(tierArt, "cannon", role, tier)
    local template = MergeTowerModels.GetTemplate(role, tier, rootOverride)
    if not (expected and template) then
        return false
    end
    if math.abs(model:GetScale() - MergeTowerModels.worldScale(worldScale)) > 1e-3 then
        return false
    end
    if contentId(model:GetAttribute("RobloxModelAssetId")) ~= expected.modelAssetId then
        return false
    end
    if contentId(model:GetAttribute("RobloxMeshAssetId")) ~= expected.meshId then
        return false
    end
    if contentId(model:GetAttribute("RobloxTextureAssetId")) ~= expected.textureId then
        return false
    end
    local meshCount = 0
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("MeshPart") then
            meshCount += 1
            if
                contentId(descendant.MeshId) ~= expected.meshId
                or contentId(descendant.TextureID) ~= expected.textureId
            then
                return false
            end
        end
    end
    return meshCount == 1
end

function MergeTowerModels.Clone(role, tier, rootOverride, tierArt)
    local normalizedRole = string.lower(tostring(role or ""))
    local resolvedTier = math.max(1, math.floor(tonumber(tier) or 1))
    local template = MergeTowerModels.GetTemplate(role, tier, rootOverride)
    if not template then
        return nil, "tower_template_missing"
    end
    if
        not MergeTowerModels.MatchesTemplate(
            template,
            normalizedRole,
            resolvedTier,
            rootOverride,
            tierArt
        )
    then
        return nil, "tower_template_manifest_mismatch"
    end
    local clone = template:Clone()
    clone.Name = string.format("%sCannon_Tier%d", ROLE_NAMES[normalizedRole], resolvedTier)
    for _, descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            descendant.Massless = true
        end
    end
    return clone
end

function MergeTowerModels.Spawn(role, tier, pad, parent, rootOverride, tierArt)
    local anchor = anchorPart(pad)
    if not anchor then
        return nil, "tower_anchor_missing"
    end
    local model, reason = MergeTowerModels.Clone(role, tier, rootOverride, tierArt)
    if not model then
        return nil, reason
    end
    local worldScale = MergeTowerModels.entryWorldScale(tierArt, role, tier)
    if math.abs(worldScale - 1) > 1e-3 then
        model:ScaleTo(worldScale)
    end
    model.Parent = parent or pad.Parent
    model:PivotTo(anchor.CFrame)
    local boundsCFrame, boundsSize = model:GetBoundingBox()
    local bottomY = boundsCFrame.Position.Y - boundsSize.Y * 0.5
    model:PivotTo(model:GetPivot() + Vector3.new(0, anchor.Position.Y - bottomY, 0))
    model:SetAttribute("MergeTowerSpawned", true)
    model:SetAttribute("MergeTowerSpawnScale", worldScale)
    local art = MergeTierArt.entry(tierArt, "cannon", role, tier)
    model:SetAttribute("MergeTowerBarrelYawDegrees", tonumber(art and art.barrelYawDegrees) or 0)
    model:SetAttribute("MergeTowerSeatOffsetY", tonumber(art and art.seatOffsetY) or 0)
    model:SetAttribute("MergeTowerPadSlot", pad:GetAttribute("MergeTowerPadSlot"))
    model:SetAttribute("MergeEggBayId", pad:GetAttribute("MergeEggBayId"))
    return model
end

return MergeTowerModels
