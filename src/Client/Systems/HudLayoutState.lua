-- HudLayoutState — persisted Auto / Compact / Classic HUD preference.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local HudLayout = require(ReplicatedStorage.Shared.Game.HudLayout)

local HudLayoutState = {}
local player = Players.LocalPlayer
local started = false

local function viewport()
    local camera = Workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function refreshResolved()
    local size = viewport()
    local preference = HudLayout.normalize(player:GetAttribute("HudLayoutPreference"))
    player:SetAttribute("HudLayoutPreference", preference)
    player:SetAttribute(
        "HudLayoutResolved",
        HudLayout.resolve(
            preference,
            size.X,
            size.Y,
            UserInputService.TouchEnabled,
            UserInputService.KeyboardEnabled
        )
    )
end

local function callBus(name, args)
    local remote = ReplicatedStorage:WaitForChild("GameAPICommand")
    local ok, envelope = pcall(function()
        return remote:InvokeServer(name, args or {})
    end)
    if ok and type(envelope) == "table" then
        return envelope.result
    end
    return nil
end

function HudLayoutState.start()
    if started then
        return
    end
    started = true
    if player:GetAttribute("HudLayoutPreference") == nil then
        player:SetAttribute("HudLayoutPreference", "auto")
    end
    refreshResolved()

    player:GetAttributeChangedSignal("HudLayoutPreference"):Connect(refreshResolved)
    local cameraConnection
    local function watchCamera(camera)
        if cameraConnection then
            cameraConnection:Disconnect()
            cameraConnection = nil
        end
        if camera then
            cameraConnection =
                camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshResolved)
        end
        refreshResolved()
    end
    watchCamera(Workspace.CurrentCamera)
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        watchCamera(Workspace.CurrentCamera)
    end)

    task.spawn(function()
        local result = callBus("settings.get")
        if result and result.ok then
            player:SetAttribute("HudLayoutPreference", HudLayout.normalize(result.hudLayout))
        end
    end)
end

function HudLayoutState.getPreference()
    return HudLayout.normalize(player:GetAttribute("HudLayoutPreference"))
end

function HudLayoutState.isCompact()
    return player:GetAttribute("HudLayoutResolved") == "compact"
end

function HudLayoutState.setPreference(mode)
    mode = HudLayout.normalize(mode)
    player:SetAttribute("HudLayoutPreference", mode)
    task.spawn(function()
        callBus("settings.set", { hudLayout = mode })
    end)
end

return HudLayoutState
