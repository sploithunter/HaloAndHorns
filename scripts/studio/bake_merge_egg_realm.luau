-- Run in Roblox Studio Edit mode after `build_merge_egg_prototype_world.luau`.
--
-- Bakes the complete 5x2 Merge Defense blockout into Workspace.Maps.MergeEggRealm. The pass is
-- idempotent: after the first bake, the configured primary bay can be used as the next source.
-- Runtime never calls this script or the Bake method.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

assert(not game:GetService("RunService"):IsRunning(), "Bake the Merge Egg realm in Edit mode")

local config =
    require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("merge_egg_prototype"))
local MergeEggRealmBuilder =
    require(ServerScriptService.Server.Services:WaitForChild("MergeEggRealmBuilder"))
local realmConfig = assert(config.realm_layout, "merge_egg_prototype.realm_layout is missing")
local maps = assert(
    Workspace:FindFirstChild(tostring((config.world or {}).maps_root or "Maps")),
    "Workspace.Maps is missing"
)

local sourceName = tostring(realmConfig.source_model_name or "MergeEggPrototype")
local source = maps:FindFirstChild(sourceName)
if not (source and source:IsA("Model")) then
    local existingRoot = maps:FindFirstChild(tostring(realmConfig.root_name or "MergeEggRealm"))
    local primaryId = tostring(realmConfig.primary_bay_id or "heaven_03")
    if existingRoot then
        for _, descendant in ipairs(existingRoot:GetDescendants()) do
            if
                descendant:IsA("Model")
                and descendant:GetAttribute("MergeEggBayId") == primaryId
            then
                source = descendant
                break
            end
        end
    end
end
assert(source and source:IsA("Model"), "No Merge Egg source bay is available to bake")

ChangeHistoryService:SetWaypoint("Before Merge Egg realm bake")
local builder = MergeEggRealmBuilder.new(realmConfig)
local root, baysOrReason = builder:Bake(source)
assert(root, "Merge Egg realm bake failed: " .. tostring(baysOrReason))
Selection:Set({ root })
ChangeHistoryService:SetWaypoint("Bake permanent Merge Egg realm")

local center, size = root:GetBoundingBox()
print(
    string.format(
        "[MergeEggRealmBake] authored %d bays at %s; bounds %.1f x %.1f x %.1f centered at %s",
        tonumber(root:GetAttribute("MergeEggBayCount")) or 0,
        root:GetFullName(),
        size.X,
        size.Y,
        size.Z,
        tostring(center.Position)
    )
)
