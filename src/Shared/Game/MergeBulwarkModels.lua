-- Spawnable Merge bulwark model access. Authored maps own only placement anchors; visuals are
-- cloned from ReplicatedStorage.Assets.Models.MergeBulwarks when a defense exists.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MergeBulwarkModels = {}

local FAMILY_NAMES = {
    impaler_palisade = "ImpalerPalisade",
    concertina_line = "ConcertinaLine",
    land_shark = "LandShark",
    saw_blade = "SawBlade",
    grasping_hedge = "GraspingHedge",
    wardstone_barrier = "WardstoneBarrier",
}

local function templatesRoot(rootOverride)
    if rootOverride then
        return rootOverride
    end
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local models = assets and assets:FindFirstChild("Models")
    return models and models:FindFirstChild("MergeBulwarks")
end

local function resolveAnchor(anchor)
    if typeof(anchor) == "CFrame" then
        return anchor
    end
    if anchor and anchor:IsA("BasePart") then
        return anchor.CFrame
    end
    if anchor then
        local named = anchor:FindFirstChild("BulwarkAnchor", true)
        if named and named:IsA("BasePart") then
            return named.CFrame
        end
    end
    return nil
end

function MergeBulwarkModels.GetTemplate(family, tier, rootOverride)
    local familyName = FAMILY_NAMES[string.lower(tostring(family or ""))]
    local resolvedTier = math.clamp(math.floor(tonumber(tier) or 1), 1, 4)
    local root = templatesRoot(rootOverride)
    local familyFolder = root and familyName and root:FindFirstChild(familyName)
    local template = familyFolder and familyFolder:FindFirstChild("Tier" .. tostring(resolvedTier))
    if template and template:IsA("Model") then
        return template
    end
    return nil
end

function MergeBulwarkModels.Clone(family, tier, rootOverride)
    local normalizedFamily = string.lower(tostring(family or ""))
    local resolvedTier = math.clamp(math.floor(tonumber(tier) or 1), 1, 4)
    local template = MergeBulwarkModels.GetTemplate(normalizedFamily, resolvedTier, rootOverride)
    if not template then
        return nil, "bulwark_template_missing"
    end
    local clone = template:Clone()
    clone.Name = string.format("%s_Tier%d", FAMILY_NAMES[normalizedFamily], resolvedTier)
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

function MergeBulwarkModels.Spawn(family, tier, anchor, parent, rootOverride)
    local target = resolveAnchor(anchor)
    if not target then
        return nil, "bulwark_anchor_missing"
    end
    local model, reason = MergeBulwarkModels.Clone(family, tier, rootOverride)
    if not model then
        return nil, reason
    end
    model.Parent = parent or workspace
    model:PivotTo(target)
    local boundsCFrame, boundsSize = model:GetBoundingBox()
    local bottomY = boundsCFrame.Position.Y - boundsSize.Y * 0.5
    model:PivotTo(model:GetPivot() + Vector3.new(0, target.Position.Y - bottomY, 0))
    model:SetAttribute("MergeBulwarkSpawned", true)
    return model
end

return MergeBulwarkModels
