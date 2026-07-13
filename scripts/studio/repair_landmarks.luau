--[[
    Audits/repairs imported landmark scenes without moving authored map hooks.

    Run in Studio Edit mode after Rojo sync. The configured Model asset supplies four protected
    MeshIds through InsertService; the script never writes MeshId directly. It preserves placement,
    native effects, interaction hosts, mission doors, attributes, and CollectionService tags.

    Safe to rerun: healthy four-part scenes are audited and left untouched.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(
    ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"):WaitForChild("LandmarkAssets")
)

local function resolvePath(path)
    local current = game
    for segment in string.gmatch(path, "[^%.]+") do
        if segment ~= "game" then
            current = current:FindFirstChild(segment)
            if not current then
                return nil
            end
        end
    end
    return current
end

local function meshPartsOf(root)
    local parts = {}
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("MeshPart") then
            table.insert(parts, descendant)
        end
    end
    return parts
end

local function localVisualBounds(root, meshParts)
    -- A previously canonicalized single-mesh fallback already owns the exact authored oriented
    -- box. Using corner math against Model.WorldPivot can swap its Y/Z extents after the imported
    -- root has been replaced, so preserve the part's own CFrame/Size directly.
    if #meshParts == 1 then
        return root:GetPivot():ToObjectSpace(meshParts[1].CFrame), meshParts[1].Size
    end

    local pivot = root:GetPivot()
    local minimum = Vector3.new(math.huge, math.huge, math.huge)
    local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)

    for _, part in ipairs(meshParts) do
        local half = part.Size * 0.5
        for x = -1, 1, 2 do
            for y = -1, 1, 2 do
                for z = -1, 1, 2 do
                    local worldCorner = part.CFrame:PointToWorldSpace(
                        Vector3.new(x * half.X, y * half.Y, z * half.Z)
                    )
                    local corner = pivot:PointToObjectSpace(worldCorner)
                    minimum = Vector3.new(
                        math.min(minimum.X, corner.X),
                        math.min(minimum.Y, corner.Y),
                        math.min(minimum.Z, corner.Z)
                    )
                    maximum = Vector3.new(
                        math.max(maximum.X, corner.X),
                        math.max(maximum.Y, corner.Y),
                        math.max(maximum.Z, corner.Z)
                    )
                end
            end
        end
    end

    return CFrame.new((minimum + maximum) * 0.5), maximum - minimum
end

local function hasExpectedMeshes(parts, asset)
    if #parts ~= asset.scene_parts or #parts ~= #asset.mesh_ids then
        return false
    end
    local expected = {}
    for _, meshId in ipairs(asset.mesh_ids) do
        expected[meshId] = true
    end
    for _, part in ipairs(parts) do
        if not expected[part.MeshId] then
            return false
        end
        local surface = part:FindFirstChildWhichIsA("SurfaceAppearance")
        if
            not surface
            or surface.ColorMap ~= asset.surface.color_map
            or surface.NormalMap ~= asset.surface.normal_map
            or surface.RoughnessMap ~= asset.surface.roughness_map
            or surface.MetalnessMap ~= asset.surface.metalness_map
        then
            return false
        end
    end
    return true
end

local COLLISION_FIDELITY = {
    Default = Enum.CollisionFidelity.Default,
    Hull = Enum.CollisionFidelity.Hull,
    Box = Enum.CollisionFidelity.Box,
    PreciseConvexDecomposition = Enum.CollisionFidelity.PreciseConvexDecomposition,
}

local function applyCollision(part, collision)
    collision = collision or {}
    local fidelity = COLLISION_FIDELITY[collision.fidelity or "Default"]
    assert(fidelity, "Unknown landmark collision fidelity " .. tostring(collision.fidelity))
    part.CanCollide = collision.can_collide == true
    part.CanTouch = false
    part.CanQuery = true
    part.CollisionFidelity = fidelity
end

local function hasExpectedCollision(parts, asset)
    local collision = asset.collision or {}
    local fidelity = COLLISION_FIDELITY[collision.fidelity or "Default"]
    if not fidelity then
        return false
    end
    for _, part in ipairs(parts) do
        if
            part.CanCollide ~= (collision.can_collide == true)
            or part.CanTouch ~= false
            or part.CanQuery ~= true
            or part.CollisionFidelity ~= fidelity
        then
            return false
        end
    end
    return true
end

local function removeVisuals(root, parts)
    local wrappers = {}
    for _, part in ipairs(parts) do
        local parent = part.Parent
        part:Destroy()
        while parent and parent ~= root do
            table.insert(wrappers, parent)
            parent = parent.Parent
        end
    end
    for _, wrapper in ipairs(wrappers) do
        if wrapper.Parent and wrapper:IsDescendantOf(root) and #wrapper:GetChildren() == 0 then
            wrapper:Destroy()
        end
    end
end

local function applySurface(part, maps)
    part.TextureID = ""
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("SurfaceAppearance") then
            child:Destroy()
        end
    end
    local surface = Instance.new("SurfaceAppearance")
    surface.ColorMap = maps.color_map
    surface.NormalMap = maps.normal_map
    surface.RoughnessMap = maps.roughness_map
    surface.MetalnessMap = maps.metalness_map
    surface.Parent = part
end

local function loadScene(asset, targetCFrame, targetSize)
    local scene = InsertService:LoadAsset(tonumber(asset.model_asset_id))
    local parts = meshPartsOf(scene)
    assert(
        #parts == asset.scene_parts,
        string.format(
            "Model asset %s returned %d/%d MeshParts",
            asset.model_asset_id,
            #parts,
            asset.scene_parts
        )
    )

    local _, sourceSize = scene:GetBoundingBox()
    local scale = targetSize.X / sourceSize.X
    scene:ScaleTo(scale)
    local sourceCFrame, scaledSize = scene:GetBoundingBox()

    local tolerance = 0.02
    assert(
        math.abs(scaledSize.Y - targetSize.Y) / targetSize.Y <= tolerance
            and math.abs(scaledSize.Z - targetSize.Z) / targetSize.Z <= tolerance,
        string.format(
            "Landmark aspect mismatch after scaling: got %s, expected %s",
            tostring(scaledSize),
            tostring(targetSize)
        )
    )

    local transform = targetCFrame * sourceCFrame:Inverse()
    for _, part in ipairs(parts) do
        part.CFrame = transform * part.CFrame
        part.Anchored = true
        applyCollision(part, asset.collision)
        part.CastShadow = true
        applySurface(part, asset.surface)
    end
    return scene, parts
end

local function detachFromImporter(root)
    if root:GetAttribute("RBX_ReimportId") == nil then
        return root
    end

    -- The importer attribute is CoreScript-protected. Rehouse preserved children in a plain Model
    -- so a future reimport cannot silently restore unsafe source geometry.
    local originalName = root.Name
    local replacement = Instance.new("Model")
    replacement.Name = originalName .. "__Canonical"
    replacement.Parent = root.Parent
    for attribute, value in pairs(root:GetAttributes()) do
        if attribute ~= "RBX_ReimportId" then
            replacement:SetAttribute(attribute, value)
        end
    end
    for _, tag in ipairs(CollectionService:GetTags(root)) do
        CollectionService:AddTag(replacement, tag)
    end
    for _, child in ipairs(root:GetChildren()) do
        child.Parent = replacement
    end
    root:Destroy()
    replacement.Name = originalName
    return replacement
end

local function repairOne(assetKey, asset, targetPath, fallbackCenter, fallbackSize)
    local root = resolvePath(targetPath)
    assert(root and root:IsA("Model"), string.format("Missing landmark model %s", targetPath))
    local oldParts = meshPartsOf(root)

    if hasExpectedMeshes(oldParts, asset) and root:GetAttribute("RBX_ReimportId") == nil then
        if hasExpectedCollision(oldParts, asset) then
            print(string.format("LANDMARK OK  %s (%s, %d parts)", targetPath, assetKey, #oldParts))
            return false
        end
        for _, part in ipairs(oldParts) do
            applyCollision(part, asset.collision)
        end
        print(
            string.format(
                "LANDMARK COLLISION FIX %s (%s, %d parts)",
                targetPath,
                assetKey,
                #oldParts
            )
        )
        return true
    end

    local localBounds, targetSize
    if #oldParts > 0 then
        localBounds, targetSize = localVisualBounds(root, oldParts)
    else
        assert(
            fallbackCenter and fallbackSize,
            string.format("%s has no visual MeshParts or configured sibling", targetPath)
        )
        localBounds, targetSize = fallbackCenter, fallbackSize
    end
    local targetCFrame = root:GetPivot() * localBounds

    local scene, newParts = loadScene(asset, targetCFrame, targetSize)
    removeVisuals(root, oldParts)
    for _, part in ipairs(newParts) do
        part:SetAttribute("CanonicalLandmark", assetKey)
        part:SetAttribute("ModelAssetId", asset.model_asset_id)
        part:SetAttribute("TriangleBudget", asset.triangle_budget_per_part)
        part.Parent = root
    end
    scene:Destroy()

    root = detachFromImporter(root)
    root.PrimaryPart = newParts[1]
    root:SetAttribute("CanonicalLandmark", assetKey)
    root:SetAttribute("CanonicalModelAssetId", asset.model_asset_id)
    root:SetAttribute("CanonicalSource", asset.source)
    root:SetAttribute("SceneParts", asset.scene_parts)

    print(
        string.format(
            "LANDMARK FIX %s (%s, %d old -> %d canonical parts)",
            targetPath,
            assetKey,
            #oldParts,
            #newParts
        )
    )
    return true
end

ChangeHistoryService:SetWaypoint("Before canonical landmark repair")

local repaired = 0
local audited = 0
for assetKey, asset in pairs(config.assets) do
    local fallbackCenter, fallbackSize
    for _, targetPath in ipairs(asset.targets) do
        local root = resolvePath(targetPath)
        if root then
            local parts = meshPartsOf(root)
            if #parts > 0 then
                fallbackCenter, fallbackSize = localVisualBounds(root, parts)
                break
            end
        end
    end
    for _, targetPath in ipairs(asset.targets) do
        audited += 1
        if repairOne(assetKey, asset, targetPath, fallbackCenter, fallbackSize) then
            repaired += 1
        end
    end
end

ChangeHistoryService:SetWaypoint("Canonical landmark repair")
print(string.format("Landmark audit complete: %d checked, %d repaired", audited, repaired))
