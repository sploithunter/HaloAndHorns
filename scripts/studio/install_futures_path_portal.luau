-- Clone one authored realm Return-to-Base gate into Home for Future's Path.
-- Run in EDIT mode. Repeatable: replaces only Workspace.Maps.Home.Portal_FuturesPath.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local maps = Workspace:FindFirstChild("Maps")
assert(maps, "Workspace.Maps is missing")
local home = maps:FindFirstChild("Home")
assert(home, "Workspace.Maps.Home is missing")

local candidates = {
    { folder = "Heaven_1", yOffset = 2000 },
    { folder = "Hell_1", yOffset = -2000 },
    { folder = "Heaven_2", yOffset = 4000 },
    { folder = "Hell_2", yOffset = -4000 },
}

local source
local sourceOffset
for _, candidate in ipairs(candidates) do
    local layer = maps:FindFirstChild(candidate.folder)
    local portal = layer and layer:FindFirstChild("Portal_Home", true)
    if portal and (portal:IsA("Model") or portal:IsA("BasePart")) then
        source = portal
        sourceOffset = candidate.yOffset
        break
    end
end
assert(source, "No authored Portal_Home found in Heaven/Hell layers")

local old = home:FindFirstChild("Portal_FuturesPath")
if old then
    old:Destroy()
end

local clone = source:Clone()
clone.Name = "Portal_FuturesPath"
clone.Parent = home

-- Place it at the equivalent Home-layer position. Jason can nudge this authored fixture after
-- inspection; rerunning the script always returns to the deterministic source-relative position.
local sourcePivot = source:IsA("Model") and source:GetPivot() or source.CFrame
local homePivot = sourcePivot - Vector3.new(0, sourceOffset, 0)
if clone:IsA("Model") then
    clone:PivotTo(homePivot)
else
    clone.CFrame = homePivot
end

for _, inst in ipairs(clone:GetDescendants()) do
    if inst:IsA("BasePart") then
        inst.Anchored = true
        inst:SetAttribute("RealmPortalBound", nil)
        inst:SetAttribute("FuturePathBound", nil)
    elseif inst:IsA("ProximityPrompt") then
        inst:Destroy()
    elseif inst.Name == "RealmPortalLockBadge" or inst.Name == "RealmPortalInfoBadge" then
        inst:Destroy()
    end
end
if clone:IsA("BasePart") then
    clone.Anchored = true
end
clone:SetAttribute("RealmPortalBound", nil)
clone:SetAttribute("FuturePathBound", nil)
clone:SetAttribute("DestinationPurpose", "future_path_entry")
clone:SetAttribute("RequiredLevel", 2)
CollectionService:AddTag(clone, "FuturePathPortal")

print(
    ("[FuturePath] cloned %s -> %s at %s"):format(
        source:GetFullName(),
        clone:GetFullName(),
        tostring(homePivot.Position)
    )
)
return clone:GetFullName()
