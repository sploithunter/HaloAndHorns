-- Spawnable Merge tower model access. Authored maps own only TowerAnchor pads; cannon visuals are
-- cloned from ReplicatedStorage.Assets.Models.MergeCannons when a tower exists.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

function MergeTowerModels.Clone(role, tier, rootOverride)
    local normalizedRole = string.lower(tostring(role or ""))
    local resolvedTier = math.max(1, math.floor(tonumber(tier) or 1))
    local template = MergeTowerModels.GetTemplate(role, tier, rootOverride)
    if not template then
        return nil, "tower_template_missing"
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

function MergeTowerModels.Spawn(role, tier, pad, parent, rootOverride)
    local anchor = anchorPart(pad)
    if not anchor then
        return nil, "tower_anchor_missing"
    end
    local model, reason = MergeTowerModels.Clone(role, tier, rootOverride)
    if not model then
        return nil, reason
    end
    model.Parent = parent or pad.Parent
    model:PivotTo(anchor.CFrame)
    local boundsCFrame, boundsSize = model:GetBoundingBox()
    local bottomY = boundsCFrame.Position.Y - boundsSize.Y * 0.5
    model:PivotTo(model:GetPivot() + Vector3.new(0, anchor.Position.Y - bottomY, 0))
    model:SetAttribute("MergeTowerSpawned", true)
    model:SetAttribute("MergeTowerSpawnScale", 1)
    model:SetAttribute("MergeTowerPadSlot", pad:GetAttribute("MergeTowerPadSlot"))
    model:SetAttribute("MergeEggBayId", pad:GetAttribute("MergeEggBayId"))
    return model
end

return MergeTowerModels
