-- The Halo and Horns place legitimately uses the SpawnZone tag for farming and combat bounds.
-- RobloxGenerateMap also consumes that tag, but draws an animated dotted boundary around it.
-- If that project's Rojo server is connected to this place by mistake, remove its exact client
-- roots before StarterPlayerScripts can run them. Do not remove or alter SpawnZone itself.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local FOREIGN_CLIENT_ROOT = "GenMapClient"
local FOREIGN_EFFECT_ROOT = "GenMapClientFX"

local function removeForeignArtifact(instance: Instance)
    warn(
        ("[ForeignArtifactGuard] Removed foreign map-generator artifact %s"):format(
            instance:GetFullName()
        )
    )
    instance:Destroy()
end

local function removeNamedChild(parent: Instance, childName: string)
    local child = parent:FindFirstChild(childName)
    if child then
        removeForeignArtifact(child)
    end
end

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerScripts = localPlayer:WaitForChild("PlayerScripts")

removeNamedChild(playerScripts, FOREIGN_CLIENT_ROOT)
playerScripts.ChildAdded:Connect(function(child)
    if child.Name == FOREIGN_CLIENT_ROOT then
        task.defer(function()
            if child.Parent == playerScripts then
                removeForeignArtifact(child)
            end
        end)
    end
end)

removeNamedChild(Workspace, FOREIGN_EFFECT_ROOT)
Workspace.ChildAdded:Connect(function(child)
    if child.Name == FOREIGN_EFFECT_ROOT then
        task.defer(function()
            if child.Parent == Workspace then
                removeForeignArtifact(child)
            end
        end)
    end
end)

script:SetAttribute("Ready", true)
