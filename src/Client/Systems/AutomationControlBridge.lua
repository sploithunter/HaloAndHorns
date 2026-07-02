--[[
    AutomationControlBridge (Studio-only client system)

    Closes gap G6: during automated NavigateTo, the player's default control
    module re-issues Move(0,0) every frame and fights the server's Humanoid:MoveTo,
    stalling the character. This bridge lets the server temporarily disable the
    local player's controls (and re-enable them after) via the AutomationControl
    RemoteEvent that AutomationService owns.

    Self-contained: started from init.client.lua only under RunService:IsStudio().
    Does nothing if the remote isn't present (i.e. AutomationService not active).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAME = "AutomationControl"

local AutomationControlBridge = {}

function AutomationControlBridge.start()
    if not RunService:IsStudio() then
        return -- never active outside Studio
    end

    local player = Players.LocalPlayer
    if not player then
        return
    end

    local remote = ReplicatedStorage:WaitForChild(REMOTE_NAME, 10)
    if not remote or not remote:IsA("RemoteEvent") then
        return -- AutomationService not running; nothing to bridge
    end

    local function setControlsEnabled(enabled)
        local playerScripts = player:FindFirstChild("PlayerScripts")
        local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
        if not playerModule then
            return
        end
        local ok, controls = pcall(function()
            return require(playerModule):GetControls()
        end)
        if not ok or not controls then
            return
        end
        if enabled then
            controls:Enable()
        else
            controls:Disable()
        end
    end

    remote.OnClientEvent:Connect(function(enabled)
        setControlsEnabled(enabled and true or false)
    end)
end

return AutomationControlBridge
