-- Replace copied generic houses and place the completed Layer 3 landmark props.
--
-- Safe to rerun. Replaced authored houses are moved to ServerStorage rather than
-- destroyed, and every generated landmark is rebuilt from its group-owned model.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

local SPECS = {
    {
        layer = "Heaven_3",
        name = "EmpyreanBloomShrine",
        modelAsset = 100662494836813,
        center = Vector3.new(-408.728, 0, 237.950),
        bottomY = 5997.238,
        height = 24.824,
        yaw = -1.832596,
        replaceHouse = true,
    },
    {
        layer = "Heaven_3",
        name = "LivingRootPavilion",
        modelAsset = 86910500091958,
        center = Vector3.new(-130, 0, 330),
        bottomY = 6001.158,
        height = 18,
        yaw = math.rad(35),
        replaceHouse = false,
    },
    {
        layer = "Hell_3",
        name = "DreadspireWatchShrine",
        modelAsset = 116087475469526,
        center = Vector3.new(-408.728, 0, 237.950),
        bottomY = -6002.764,
        height = 24.825,
        yaw = -1.832596,
        replaceHouse = true,
    },
    {
        layer = "Hell_3",
        name = "ObsidianGatehouse",
        modelAsset = 104018506045014,
        center = Vector3.new(-372.749, 0, 79.778),
        bottomY = -6000.991,
        height = 24.825,
        yaw = -1.832596,
        replaceHouse = true,
    },
}

local maps = workspace:FindFirstChild("Maps")
assert(maps, "Workspace.Maps missing")

local backupRoot = ServerStorage:FindFirstChild("Layer3LandmarkOriginals")
if not backupRoot then
    backupRoot = Instance.new("Folder")
    backupRoot.Name = "Layer3LandmarkOriginals"
    backupRoot.Parent = ServerStorage
end

local function nearestGenericHouse(layer, position)
    local best
    local bestDistance = math.huge
    for _, child in ipairs(layer:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("House roof") then
            local center = select(1, child:GetBoundingBox()).Position
            local distance = (Vector3.new(center.X, 0, center.Z) - position).Magnitude
            if distance < bestDistance then
                best = child
                bestDistance = distance
            end
        end
    end
    if bestDistance > 4 then
        return nil
    end
    return best
end

local function backupHouse(layer, spec)
    if not spec.replaceHouse then
        return false
    end
    local realmBackup = backupRoot:FindFirstChild(layer.Name)
    if not realmBackup then
        realmBackup = Instance.new("Folder")
        realmBackup.Name = layer.Name
        realmBackup.Parent = backupRoot
    end
    if realmBackup:FindFirstChild(spec.name) then
        return false
    end
    local original = nearestGenericHouse(layer, spec.center)
    assert(original, ("generic house missing near %s/%s"):format(layer.Name, spec.name))
    original.Name = spec.name
    original:SetAttribute("Layer3ReplacedOriginal", true)
    original.Parent = realmBackup
    return true
end

local function loadVisual(spec)
    local container = InsertService:LoadAsset(spec.modelAsset)
    local source = container:FindFirstChildWhichIsA("MeshPart", true)
    assert(source, ("model %d has no MeshPart"):format(spec.modelAsset))
    local visual = source:Clone()
    container:Destroy()

    local factor = spec.height / visual.Size.Y
    visual.Size *= factor
    visual.Name = "Visual"
    visual.CFrame = CFrame.new(spec.center.X, spec.bottomY + visual.Size.Y / 2, spec.center.Z)
        * CFrame.Angles(0, spec.yaw, 0)
    visual.Color = Color3.new(1, 1, 1)
    visual.Anchored = true
    visual.CanCollide = true
    visual.CanTouch = false
    visual.CanQuery = true
    visual.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
    return visual
end

ChangeHistoryService:SetWaypoint("Before Layer 3 landmark placement")
local report = {}
for _, spec in ipairs(SPECS) do
    local layer = maps:FindFirstChild(spec.layer)
    assert(layer, spec.layer .. " missing")
    local landmarks = layer:FindFirstChild("Layer3Landmarks")
    if not landmarks then
        landmarks = Instance.new("Folder")
        landmarks.Name = "Layer3Landmarks"
        landmarks.Parent = layer
    end

    local backedUp = backupHouse(layer, spec)
    local previous = landmarks:FindFirstChild(spec.name)
    if previous then
        previous:Destroy()
    end

    local model = Instance.new("Model")
    model.Name = spec.name
    model:SetAttribute("Layer3Landmark", true)
    model:SetAttribute("RobloxModelAssetId", tostring(spec.modelAsset))
    model:SetAttribute("ReplacesGenericHouse", spec.replaceHouse)
    local visual = loadVisual(spec)
    visual.Parent = model
    model.Parent = landmarks

    table.insert(
        report,
        ("%s/%s size=%.1f,%.1f,%.1f backed_up=%s"):format(
            spec.layer,
            spec.name,
            visual.Size.X,
            visual.Size.Y,
            visual.Size.Z,
            tostring(backedUp)
        )
    )
end
ChangeHistoryService:SetWaypoint("After Layer 3 landmark placement")
return table.concat(report, "\n")
