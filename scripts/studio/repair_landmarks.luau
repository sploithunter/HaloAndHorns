--[[
    Repairs imported landmarks without moving their authored map hooks.

    Run in Studio Edit mode after Rojo has synced `configs/landmarks.lua`. The script replaces
    only MeshPart visuals, preserving such children as NativeFX, AscensionAltarHost,
    LightEmit, and HeavenMissionDoor. Placement and size come from the existing authored visual
    bounds; asset identity comes exclusively from configuration.

    Safe to rerun: a healthy one-mesh landmark is audited and left untouched.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("landmarks"))

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

local function localVisualBounds(root, meshParts)
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

    return (minimum + maximum) * 0.5, maximum - minimum
end

local function removeEmptyImportedWrappers(root, candidates)
    for _, candidate in ipairs(candidates) do
        if
            candidate.Parent
            and candidate:IsDescendantOf(root)
            and #candidate:GetChildren() == 0
        then
            candidate:Destroy()
        end
    end
end

local function loadCanonicalMesh(asset)
    local container = InsertService:LoadAsset(tonumber(asset.model_asset_id))
    local mesh = container:FindFirstChildWhichIsA("MeshPart", true)
    assert(mesh, string.format("Model asset %s contains no MeshPart", asset.model_asset_id))
    mesh.Parent = nil
    container:Destroy()
    return mesh
end

local function detachFromImporter(root)
    if root:GetAttribute("RBX_ReimportId") == nil then
        return root
    end

    -- RBX_ReimportId is CoreScript-protected: even Edit-mode automation cannot clear it. Move the
    -- preserved children into a plain Model instead. This removes the importer contract itself,
    -- rather than hoping a future reimport will leave the repaired mesh alone.
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

    local visual = replacement:FindFirstChildWhichIsA("MeshPart", true)
    if visual then
        replacement.PrimaryPart = visual
    end
    root:Destroy()
    replacement.Name = originalName
    return replacement
end

local function repairOne(assetKey, asset, targetPath, fallbackCenter, fallbackSize)
    local root = resolvePath(targetPath)
    assert(root and root:IsA("Model"), string.format("Missing landmark model %s", targetPath))

    local meshParts = {}
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("MeshPart") then
            table.insert(meshParts, descendant)
        end
    end
    if
        #meshParts == 1
        and meshParts[1].MeshId == asset.mesh_id
        and meshParts[1].TextureID == asset.texture_id
        and root:GetAttribute("RBX_ReimportId") == nil
    then
        print(string.format("LANDMARK OK  %s (%s)", targetPath, assetKey))
        return false
    end

    local localCenter, targetSize
    if #meshParts > 0 then
        localCenter, targetSize = localVisualBounds(root, meshParts)
    else
        assert(
            fallbackCenter and fallbackSize,
            string.format("%s has no visual MeshParts or configured sibling", targetPath)
        )
        localCenter, targetSize = fallbackCenter, fallbackSize
    end
    local targetCFrame = root:GetPivot() * CFrame.new(localCenter)
    local wrappers = {}
    for _, meshPart in ipairs(meshParts) do
        local parent = meshPart.Parent
        meshPart:Destroy()
        while parent and parent ~= root do
            table.insert(wrappers, parent)
            parent = parent.Parent
        end
    end
    removeEmptyImportedWrappers(root, wrappers)

    -- MeshId is a protected property in some Studio execution contexts. Loading the uploaded
    -- Model asset is both supported and safer than trying to manufacture a MeshPart by ID.
    local mesh = loadCanonicalMesh(asset)
    mesh.Name = asset.mesh_name
    mesh.Anchored = true
    mesh.CanCollide = false
    mesh.CanTouch = false
    mesh.CanQuery = true
    mesh.CastShadow = true
    mesh.TextureID = asset.texture_id
    mesh.Size = targetSize
    mesh.CFrame = targetCFrame
    mesh:SetAttribute("CanonicalLandmark", assetKey)
    mesh:SetAttribute("ModelAssetId", asset.model_asset_id)
    mesh:SetAttribute("TriangleBudget", asset.triangle_budget)
    mesh.Parent = root

    -- Studio's 3D importer adds this link. Keeping it lets a later reimport silently restore the
    -- unsafe split mesh, which is exactly how this damage returned.
    root = detachFromImporter(root)
    root:SetAttribute("CanonicalLandmark", assetKey)
    root:SetAttribute("CanonicalMeshId", asset.mesh_id)
    root:SetAttribute("CanonicalSource", asset.source)

    print(
        string.format("LANDMARK FIX %s (%s, %d old meshes -> 1)", targetPath, assetKey, #meshParts)
    )
    return true
end

ChangeHistoryService:SetWaypoint("Before canonical landmark repair")

local repaired = 0
local audited = 0
for assetKey, asset in pairs(config) do
    if type(asset) == "table" and type(asset.targets) == "table" then
        local fallbackCenter, fallbackSize
        for _, targetPath in ipairs(asset.targets) do
            local root = resolvePath(targetPath)
            if root then
                local meshParts = {}
                for _, descendant in ipairs(root:GetDescendants()) do
                    if descendant:IsA("MeshPart") then
                        table.insert(meshParts, descendant)
                    end
                end
                if #meshParts > 0 then
                    fallbackCenter, fallbackSize = localVisualBounds(root, meshParts)
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
end

ChangeHistoryService:SetWaypoint("Canonical landmark repair")
print(string.format("Landmark audit complete: %d checked, %d repaired", audited, repaired))
