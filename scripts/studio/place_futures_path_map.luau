-- Place the baked Future's Path map in its reserved world-space.
-- Run in EDIT mode after importing maps/futures_path/manifest.json with RobloxGenerateMap.
-- Repeatable: the saved WorldOffset* attributes make subsequent runs apply only the delta.

local Workspace = game:GetService("Workspace")

local TARGET_OFFSET = Vector3.new(-24000, 0, 0)

local maps = Workspace:FindFirstChild("Maps")
assert(maps, "Workspace.Maps is missing")
local root = maps:FindFirstChild("FuturePath")
assert(root, "Workspace.Maps.FuturePath is missing; import the baked manifest first")

local previousOffset = Vector3.new(
    tonumber(root:GetAttribute("WorldOffsetX")) or 0,
    tonumber(root:GetAttribute("WorldOffsetY")) or 0,
    tonumber(root:GetAttribute("WorldOffsetZ")) or 0
)
local delta = TARGET_OFFSET - previousOffset

if delta.Magnitude > 0.001 then
    -- Move only top-level authored assemblies. Their descendants travel with them, preventing
    -- double translation of parts nested under tile models.
    for _, child in ipairs(root:GetChildren()) do
        if child:IsA("Model") then
            child:PivotTo(child:GetPivot() + delta)
        elseif child:IsA("BasePart") then
            child.CFrame += delta
        end
    end
end

for _, inst in ipairs(root:GetDescendants()) do
    if inst:IsA("BasePart") then
        inst.Anchored = true
    end
end

root:SetAttribute("WorldOffsetX", TARGET_OFFSET.X)
root:SetAttribute("WorldOffsetY", TARGET_OFFSET.Y)
root:SetAttribute("WorldOffsetZ", TARGET_OFFSET.Z)
root:SetAttribute("BakedMap", true)

print(
    ("[FuturePath] placed %s at offset %s (delta %s)"):format(
        root:GetFullName(),
        tostring(TARGET_OFFSET),
        tostring(delta)
    )
)
return root:GetFullName()
