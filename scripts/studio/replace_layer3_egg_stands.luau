--[[
    Replace the copied Layer 2 visuals inside the eight existing Layer 3 egg stands.

    Studio owns the fixtures. This pass preserves each area-named Model, its attributes/tags,
    and the existing UIanchor Instance. Only the direct visible BaseParts are replaced. The new
    realm mesh is fitted to the old footprint and floor, then UIanchor is moved vertically so a
    standard 3.5x, 2-stud source egg rests in the stand cup after the configured +0.5 placement
    offset.

    Safe to rerun: placement metadata is saved on the fixture and Layer3StandVisual is replaced
    in place. Run in Edit mode, inspect, then Save to Roblox.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local Workspace = game:GetService("Workspace")

local SPECS = {
    Heaven_3 = {
        modelAsset = 107235026268961,
        meshAsset = "rbxassetid://103416941338986",
        textureAsset = "rbxassetid://124952214941560",
        style = "heaven3",
    },
    Hell_3 = {
        modelAsset = 123190461137250,
        meshAsset = "rbxassetid://127005495897025",
        textureAsset = "rbxassetid://103193080758066",
        style = "hell3",
    },
}

local AREA_NAMES = { "Lava", "Ice", "Grass", "Desert" }
local VISUAL_NAME = "Layer3StandVisual"
local FOOTPRINT_FILL = 0.96
local EGG_SOURCE_HEIGHT = 2
local EGG_SCALE = 3.5
local EGG_PLACEMENT_OFFSET_Y = 0.5

local function aabb(parts)
    local min = Vector3.new(math.huge, math.huge, math.huge)
    local max = Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, part in ipairs(parts) do
        local half = part.Size * 0.5
        for sx = -1, 1, 2 do
            for sy = -1, 1, 2 do
                for sz = -1, 1, 2 do
                    local point = part.CFrame:PointToWorldSpace(
                        Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
                    )
                    min = Vector3.new(
                        math.min(min.X, point.X),
                        math.min(min.Y, point.Y),
                        math.min(min.Z, point.Z)
                    )
                    max = Vector3.new(
                        math.max(max.X, point.X),
                        math.max(max.Y, point.Y),
                        math.max(max.Z, point.Z)
                    )
                end
            end
        end
    end
    return min, max
end

local function directVisualParts(stand)
    local parts = {}
    for _, child in ipairs(stand:GetChildren()) do
        if child:IsA("BasePart") and child.Name ~= "UIanchor" then
            table.insert(parts, child)
        end
    end
    return parts
end

local function sourceMesh(spec)
    local container = InsertService:LoadAsset(spec.modelAsset)
    local mesh = container:FindFirstChildWhichIsA("MeshPart", true)
    assert(mesh, ("model %d has no MeshPart"):format(spec.modelAsset))
    local clone = mesh:Clone()
    container:Destroy()
    return clone
end

local function originalPlacement(stand, oldParts)
    local footprint = tonumber(stand:GetAttribute("Layer3StandFootprint"))
    local bottomY = tonumber(stand:GetAttribute("Layer3StandBottomY"))
    local centerX = tonumber(stand:GetAttribute("Layer3StandCenterX"))
    local centerZ = tonumber(stand:GetAttribute("Layer3StandCenterZ"))
    local yaw = tonumber(stand:GetAttribute("Layer3StandYawRadians"))
    if footprint and bottomY and centerX and centerZ and yaw then
        return footprint, bottomY, centerX, centerZ, yaw
    end

    assert(#oldParts >= 1, stand:GetFullName() .. " has no visible parts to measure")
    local min, max = aabb(oldParts)
    local anchor = stand:FindFirstChild("UIanchor")
    assert(anchor and anchor:IsA("BasePart"), stand:GetFullName() .. " has no BasePart UIanchor")
    local _, anchorYaw = anchor.CFrame:ToEulerAnglesYXZ()
    footprint = math.min(max.X - min.X, max.Z - min.Z) * FOOTPRINT_FILL
    bottomY = min.Y
    centerX = anchor.Position.X
    centerZ = anchor.Position.Z
    yaw = anchorYaw
    stand:SetAttribute("Layer3StandFootprint", footprint)
    stand:SetAttribute("Layer3StandBottomY", bottomY)
    stand:SetAttribute("Layer3StandCenterX", centerX)
    stand:SetAttribute("Layer3StandCenterZ", centerZ)
    stand:SetAttribute("Layer3StandYawRadians", yaw)
    return footprint, bottomY, centerX, centerZ, yaw
end

local function replaceStand(stand, spec, template)
    local oldParts = directVisualParts(stand)
    local footprint, bottomY, centerX, centerZ, yaw = originalPlacement(stand, oldParts)
    local anchor = stand:FindFirstChild("UIanchor")
    assert(anchor and anchor:IsA("BasePart"), stand:GetFullName() .. " lost UIanchor")

    local visual = template:Clone()
    visual.Name = VISUAL_NAME
    local natural = visual.Size
    local scale = footprint / math.max(natural.X, natural.Z)
    visual.Size = natural * scale
    local centerY = bottomY + visual.Size.Y * 0.5
    visual.CFrame = CFrame.new(centerX, centerY, centerZ) * CFrame.Angles(0, yaw, 0)
    visual.TextureID = spec.textureAsset
    visual.Color = Color3.new(1, 1, 1)
    visual.Anchored = true
    visual.CanCollide = true
    visual.CanTouch = true
    visual.CanQuery = true
    visual.CastShadow = true
    visual:SetAttribute("SourceModelAsset", tostring(spec.modelAsset))
    visual:SetAttribute("SourceMeshAsset", spec.meshAsset)
    visual:SetAttribute("SourceTextureAsset", spec.textureAsset)
    visual:SetAttribute("RealmStyle", spec.style)

    -- Parent the replacement before deleting the old assembly so a failed clone never empties a
    -- fixture. On reruns, oldParts includes the prior Layer3StandVisual and replaces it cleanly.
    visual.Parent = stand
    for _, part in ipairs(oldParts) do
        part:Destroy()
    end

    local visualTop = centerY + visual.Size.Y * 0.5
    local eggHalfHeight = EGG_SOURCE_HEIGHT * EGG_SCALE * 0.5
    local anchorY = visualTop + eggHalfHeight - EGG_PLACEMENT_OFFSET_Y
    anchor.CFrame = CFrame.new(centerX, anchorY, centerZ) * CFrame.Angles(0, yaw, 0)
    stand:SetAttribute("Layer3StandStyle", spec.style)
    stand:SetAttribute("Layer3StandModelAsset", tostring(spec.modelAsset))
    stand:SetAttribute("Layer3StandMeshAsset", spec.meshAsset)
    stand:SetAttribute("Layer3StandTextureAsset", spec.textureAsset)

    return {
        oldParts = #oldParts,
        footprint = footprint,
        visualHeight = visual.Size.Y,
        bottomY = bottomY,
        topY = visualTop,
        anchorY = anchorY,
        tags = #CollectionService:GetTags(stand),
    }
end

local maps = Workspace:FindFirstChild("Maps")
assert(maps, "Workspace.Maps missing")
ChangeHistoryService:SetWaypoint("Before Layer 3 egg stand replacement")

local reports = {}
for layerName, spec in pairs(SPECS) do
    local layer = maps:FindFirstChild(layerName)
    local hatchers = layer and layer:FindFirstChild("EggHatchers")
    assert(hatchers, ("Workspace.Maps.%s.EggHatchers missing"):format(layerName))
    local template = sourceMesh(spec)
    for _, area in ipairs(AREA_NAMES) do
        local stand = hatchers:FindFirstChild(area)
        assert(stand and stand:IsA("Model"), ("%s.%s stand missing"):format(layerName, area))
        local report = replaceStand(stand, spec, template)
        table.insert(
            reports,
            ("%s.%s old=%d footprint=%.2f height=%.2f bottom=%.2f top=%.2f anchor=%.2f tags=%d"):format(
                layerName,
                area,
                report.oldParts,
                report.footprint,
                report.visualHeight,
                report.bottomY,
                report.topY,
                report.anchorY,
                report.tags
            )
        )
    end
    template:Destroy()
end

ChangeHistoryService:SetWaypoint("After Layer 3 egg stand replacement")
table.sort(reports)
return table.concat(reports, "\n")
