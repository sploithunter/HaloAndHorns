-- Spawnable Merge bulwark model access. Authored maps own only placement anchors; visuals are
-- cloned from ReplicatedStorage.Assets.Models.MergeBulwarks when a defense exists.

local AssetService = game:GetService("AssetService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MergeTierArt = require(script.Parent.MergeTierArt)

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

-- Split/repaired saw MeshIds are 200-stud Roblox assets (cm FBX). Studio QA previews shrink them
-- with Model.Scale 0.04 / 0.05 to the 8–10 stud tile. The lune assembler copied those tile Sizes
-- onto new MeshParts at scale 1 and cannot bake MeshSize, so the renderer draws the 200-stud
-- native mesh. Recreate each MeshPart through AssetService so Size is authoritative again.
local TILE_REFERENCE_LENGTH = 10
local SAW_BLADE_IMPORT_SCALE = 0.04

local function templatesRoot(rootOverride)
    if rootOverride then
        return rootOverride
    end
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local models = assets and assets:FindFirstChild("Models")
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
    if normalizedFamily == "saw_blade" then
        return true
    end
    local matched = false
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("MeshPart") then
            if
                contentId(descendant.MeshId) ~= expected.meshId
                or contentId(descendant.TextureID) ~= expected.textureId
            then
                return false
            end
            matched = true
        end
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

local function bakeMeshPart(part)
    if not (part:IsA("MeshPart") and part.MeshId ~= "") then
        return part
    end
    if part.MeshSize.Magnitude >= 0.01 then
        return part
    end
    local ok, baked = pcall(function()
        -- selene: allow(undefined_variable)
        return AssetService:CreateMeshPartAsync(Content.fromUri(part.MeshId))
    end)
    if not (ok and baked) then
        return part
    end
    local desiredSize = part.Size
    baked.Name = part.Name
    baked.Size = desiredSize
    baked.CFrame = part.CFrame
    baked.Anchored = part.Anchored
    baked.CanCollide = part.CanCollide
    baked.CanTouch = part.CanTouch
    baked.CanQuery = part.CanQuery
    baked.Massless = part.Massless
    baked.CastShadow = part.CastShadow
    baked.Material = part.Material
    baked.Color = part.Color
    baked.Reflectance = part.Reflectance
    baked.Transparency = part.Transparency
    baked.TextureID = part.TextureID
    for name, value in pairs(part:GetAttributes()) do
        baked:SetAttribute(name, value)
    end
    for _, child in ipairs(part:GetChildren()) do
        child.Parent = baked
    end
    local parent = part.Parent
    local model = part:FindFirstAncestorOfClass("Model")
    if model and model.PrimaryPart == part then
        model.PrimaryPart = baked
    end
    baked.Parent = parent
    part:Destroy()
    return baked
end

function MergeBulwarkModels.ApplySawBladeImportScale(model, placementScale)
    if not model then
        return model
    end
    if tostring(model:GetAttribute("MergeBulwarkFamily") or "") ~= "saw_blade" then
        return model
    end
    local pending = false
    for _, descendant in ipairs(model:GetDescendants()) do
        if
            descendant:IsA("MeshPart")
            and descendant.MeshId ~= ""
            and descendant.MeshSize.Magnitude < 0.01
        then
            bakeMeshPart(descendant)
            pending = true
        end
    end
    -- If CreateMeshPartAsync is unavailable, fall back to the Studio-accepted 0.04 shrink.
    local stillNative = false
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("MeshPart") and descendant.MeshSize.Magnitude < 0.01 then
            stillNative = true
            break
        end
    end
    if stillNative and model:GetAttribute("MergeBulwarkImportScaled") ~= true and model.Parent then
        local current = model:GetScale()
        if current > 0 then
            model:ScaleTo(current * SAW_BLADE_IMPORT_SCALE)
        end
        restoreTileSizes(model, placementScale)
        model:SetAttribute("MergeBulwarkImportScaled", true)
    elseif pending then
        restoreTileSizes(model, placementScale)
        model:SetAttribute("MergeBulwarkMeshesBaked", true)
    end
    if model.Parent then
        return MergeBulwarkModels.FitToTile(model, placementScale)
    end
    return model
end

local function refitWhenMeshesLoad(model, placementScale)
    task.defer(function()
        local meshes = {}
        for _, descendant in ipairs(model:GetDescendants()) do
            if descendant:IsA("MeshPart") and descendant.MeshId ~= "" then
                table.insert(meshes, descendant)
            end
        end
        if #meshes > 0 then
            pcall(function()
                ContentProvider:PreloadAsync(meshes)
            end)
        end
        if model.Parent then
            MergeBulwarkModels.FitToTile(model, placementScale)
        end
    end)
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
    if nativePackage or (scale and scale > 0) then
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
    if normalizedFamily == "saw_blade" then
        MergeBulwarkModels.ApplySawBladeImportScale(model, placementScale)
        refitWhenMeshesLoad(model, placementScale)
    else
        MergeBulwarkModels.FitToTile(model, placementScale)
    end
    return model
end

return MergeBulwarkModels
