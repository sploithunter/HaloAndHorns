-- Remove the copied visible flora exemplars from Heaven 3 and Hell 3 while
-- preserving their tagged FloraAnchor parts. FloraService owns every runtime
-- spawn; keeping the old linked visual causes replacements to overlap it.
--
-- Safe scope: only destroys Models referenced by a direct ObjectValue named
-- FloraSpawn under a Layer 3 FloraAnchor. Unlinked map geometry is untouched.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")

local layers = {
    workspace.Maps:FindFirstChild("Heaven_3"),
    workspace.Maps:FindFirstChild("Hell_3"),
}

ChangeHistoryService:SetWaypoint("Before Layer 3 authored flora cleanup")
local report = {}
for _, layer in ipairs(layers) do
    assert(layer, "Layer 3 map missing")
    local removed = 0
    local byKind = {}
    local seen = {}
    for _, anchor in ipairs(CollectionService:GetTagged("FloraAnchor")) do
        if anchor:IsA("BasePart") and anchor:IsDescendantOf(layer) then
            local reference = anchor:FindFirstChild("FloraSpawn")
            local visual = reference and reference:IsA("ObjectValue") and reference.Value
            if
                visual
                and visual:IsA("Model")
                and visual:IsDescendantOf(layer)
                and not seen[visual]
            then
                seen[visual] = true
                local kind = tostring(anchor:GetAttribute("Kind") or "unknown")
                byKind[kind] = (byKind[kind] or 0) + 1
                visual:Destroy()
                removed += 1
            end
        end
    end
    table.insert(report, ("%s removed=%d"):format(layer.Name, removed))
    local kinds = {}
    for kind in pairs(byKind) do
        table.insert(kinds, kind)
    end
    table.sort(kinds)
    for _, kind in ipairs(kinds) do
        table.insert(report, ("  %s=%d"):format(kind, byKind[kind]))
    end
end
ChangeHistoryService:SetWaypoint("After Layer 3 authored flora cleanup")
return table.concat(report, "\n")
