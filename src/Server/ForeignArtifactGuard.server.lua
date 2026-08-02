-- Exact-name quarantine for artifacts inserted by the separate RobloxGenerateMap Rojo project.
-- Halo and Horns owns similarly named tags such as SpawnZone, so this guard intentionally removes
-- only the foreign project's top-level roots and never scans tags or authored world geometry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local foreignRoots = {
    { parent = ReplicatedStorage, name = "GenMap" },
    { parent = ServerScriptService, name = "GenMapBoot" },
    { parent = StarterPlayer.StarterPlayerScripts, name = "GenMapClient" },
}

local function removeForeignArtifact(instance: Instance)
    warn(
        ("[ForeignArtifactGuard] Removed foreign map-generator artifact %s"):format(
            instance:GetFullName()
        )
    )
    instance:Destroy()
end

for _, root in foreignRoots do
    local existing = root.parent:FindFirstChild(root.name)
    if existing then
        removeForeignArtifact(existing)
    end

    root.parent.ChildAdded:Connect(function(child)
        if child.Name == root.name then
            task.defer(function()
                if child.Parent == root.parent then
                    removeForeignArtifact(child)
                end
            end)
        end
    end)
end
