-- Spawnable Merge bulwark model access. Authored maps own only placement anchors; visuals are
-- cloned server-side from ServerStorage.Assets.Models.MergeBulwarks when a defense exists.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MergeTierArt = require(script.Parent.MergeTierArt)
local ModelTemplateStore = require(ReplicatedStorage.Shared.Utils.ModelTemplateStore)

local MergeBulwarkModels = {}

local FAMILY_NAMES = {
    impaler_palisade = "ImpalerPalisade",
    concertina_line = "ConcertinaLine",
    land_shark = "LandShark",
    saw_blade = "SawBlade",
    grasping_hedge = "GraspingHedge",
    wardstone_barrier = "WardstoneBarrier",
}

-- Authored BulwarkAnchor parts point along the lane-width axis (local Z). Most source meshes were
-- authored lengthwise on X; Land Shark is the one catalog family already authored lengthwise on Z.
-- Keeping this correction here lets every map expose one consistent anchor contract.
local LONG_AXIS = {
    land_shark = "Z",
}

local TILE_REFERENCE_LENGTH = 10
local SCALE_EPSILON = 0.001

local function templatesRoot(rootOverride)
    if rootOverride then
        return rootOverride
    end
    local models = ModelTemplateStore.root()
    return models and models:FindFirstChild("MergeBulwarks")
end

local function contentId(value)
    return string.match(tostring(value or ""), "(%d+)$") or ""
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

function MergeBulwarkModels.MatchesTemplate(model, family, tier, rootOverride, tierArt)
    if not (model and model:IsA("Model")) then
        return false
    end
    local normalizedFamily = string.lower(tostring(family or ""))
    local expected = MergeTierArt.entry(tierArt, "bulwark", normalizedFamily, tier)
    local template = MergeBulwarkModels.GetTemplate(normalizedFamily, tier, rootOverride)
    if not (expected and template) then
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
    local matched = false
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("MeshPart") then
            if normalizedFamily == "saw_blade" then
                if descendant.MeshSize.Magnitude < 0.01 then
                    return false
                end
            elseif
                contentId(descendant.MeshId) ~= expected.meshId
                or contentId(descendant.TextureID) ~= expected.textureId
            then
                return false
            end
            matched = true
        end
    end
    if normalizedFamily == "saw_blade" then
        return matched and model:GetAttribute("MergeBulwarkPrebakedPlacement") == true
    end
    return matched
end

function MergeBulwarkModels.Clone(family, tier, rootOverride, tierArt)
    local normalizedFamily = string.lower(tostring(family or ""))
    local resolvedTier = math.clamp(math.floor(tonumber(tier) or 1), 1, 4)
    local template = MergeBulwarkModels.GetTemplate(normalizedFamily, resolvedTier, rootOverride)
    if not template then
        return nil, "bulwark_template_missing"
    end
    if
        not MergeBulwarkModels.MatchesTemplate(
            template,
            normalizedFamily,
            resolvedTier,
            rootOverride,
            tierArt
        )
    then
        return nil, "bulwark_template_manifest_mismatch"
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
    for _, descendant in ipairs(clone:GetDescendants()) do
        if
            descendant:IsA("BasePart")
            and descendant:GetAttribute("MergeBulwarkAuthoredSize") == nil
        then
            descendant:SetAttribute("MergeBulwarkAuthoredSize", descendant.Size)
        end
    end
    return clone
end

local function tileSizeScale(model, placementScale)
    local source = tonumber(model:GetAttribute("MergeBulwarkSourceUniformScale")) or 1
    local placement = tonumber(placementScale)
        or tonumber(model:GetAttribute("MergeBulwarkSpawnScale"))
        or 1
    return source * math.max(0.01, placement)
end

local function restoreTileSizes(model, placementScale)
    local sizeScale = tileSizeScale(model, placementScale)
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            local authored = descendant:GetAttribute("MergeBulwarkAuthoredSize")
            if typeof(authored) == "Vector3" then
                descendant.Size = authored * sizeScale
            end
        end
    end
end

function MergeBulwarkModels.FitToTile(model, placementScale)
    if not (model and model.Parent) then
        return model
    end
    placementScale = tonumber(placementScale)
        or tonumber(model:GetAttribute("MergeBulwarkSpawnScale"))
        or 1
    local target = TILE_REFERENCE_LENGTH * math.max(0.01, placementScale)
    local _, size = model:GetBoundingBox()
    local longest = math.max(size.X, size.Y, size.Z)
    if longest > target * 1.25 then
        model:ScaleTo(model:GetScale() * (target / longest))
        restoreTileSizes(model, placementScale)
    end
    local groundY = tonumber(model:GetAttribute("MergeBulwarkGroundY"))
    if groundY then
        local boundsCFrame, boundsSize = model:GetBoundingBox()
        local bottomY = boundsCFrame.Position.Y - boundsSize.Y * 0.5
        model:PivotTo(model:GetPivot() + Vector3.new(0, groundY - bottomY, 0))
    end
    return model
end

function MergeBulwarkModels.Spawn(
    family,
    tier,
    anchor,
    parent,
    rootOverride,
    scaleOverride,
    tierArt
)
    local target = resolveAnchor(anchor)
    if not target then
        return nil, "bulwark_anchor_missing"
    end
    local model, reason = MergeBulwarkModels.Clone(family, tier, rootOverride, tierArt)
    if not model then
        return nil, reason
    end
    local scale = tonumber(scaleOverride)
    if scale == nil and anchor and typeof(anchor) == "Instance" then
        scale = tonumber(anchor:GetAttribute("MergeBulwarkScale"))
    end
    local nativePackage = model:GetAttribute("MergeBulwarkNativePackage") == true
    -- The uploaded package uses a 90-degree PrimaryPart PivotOffset as import metadata. Preserve
    -- its origin, but normalize that rotation before applying our map anchor orientation. Carrying
    -- the import rotation into PivotTo turns the otherwise-correct mesh onto its side.
    if nativePackage and model.PrimaryPart then
        model.PrimaryPart.PivotOffset = CFrame.new(model.PrimaryPart.PivotOffset.Position)
    end
    local normalizedFamily = string.lower(tostring(family or ""))
    local sourceUniformScale = tonumber(model:GetAttribute("MergeBulwarkSourceUniformScale")) or 1
    local placementScale = if scale and scale > 0 then scale else 1
    local uniform = sourceUniformScale * placementScale
    if normalizedFamily == "saw_blade" then
        local bakedScale = tonumber(model:GetAttribute("MergeBulwarkBakedPlacementScale"))
        if model:GetAttribute("MergeBulwarkPrebakedPlacement") ~= true or bakedScale == nil then
            model:Destroy()
            return nil, "bulwark_template_not_prebaked"
        end
        if math.abs(placementScale - bakedScale) > SCALE_EPSILON then
            model:Destroy()
            return nil, "bulwark_baked_scale_mismatch"
        end
    elseif nativePackage or (scale and scale > 0) then
        model:ScaleTo(uniform)
    end
    model.Parent = parent or workspace
    if LONG_AXIS[normalizedFamily] ~= "Z" then
        target *= CFrame.Angles(0, math.rad(90), 0)
    end
    model:PivotTo(target)
    local boundsCFrame, boundsSize = model:GetBoundingBox()
    local bottomY = boundsCFrame.Position.Y - boundsSize.Y * 0.5
    model:PivotTo(model:GetPivot() + Vector3.new(0, target.Position.Y - bottomY, 0))
    model:SetAttribute("MergeBulwarkSpawned", true)
    model:SetAttribute("MergeBulwarkFamily", normalizedFamily)
    model:SetAttribute("MergeBulwarkTier", math.clamp(math.floor(tonumber(tier) or 1), 1, 4))
    model:SetAttribute("MergeBulwarkSpawnScale", placementScale)
    model:SetAttribute("MergeBulwarkGroundY", target.Position.Y)
    if normalizedFamily ~= "saw_blade" then
        MergeBulwarkModels.FitToTile(model, placementScale)
    end
    return model
end

return MergeBulwarkModels
