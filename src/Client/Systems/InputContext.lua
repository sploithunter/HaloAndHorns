-- InputContext — live input/display state. Hybrid devices may change InputMode without changing
-- DisplayClass; a controller connected to a tablet must not turn the tablet into a television.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputPlatform = require(ReplicatedStorage.Shared.Game.InputPlatform)

local InputContext = {}
local player = Players.LocalPlayer
local started = false

local function viewport()
    local camera = Workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function preferredInput()
    local ok, value = pcall(function()
        return UserInputService.PreferredInput
    end)
    return ok and value or UserInputService:GetLastInputType()
end

local function refresh()
    local size = viewport()
    local gamepad = UserInputService.GamepadEnabled
    local mode = InputPlatform.inputMode(preferredInput(), {
        gamepad = gamepad,
        touch = UserInputService.TouchEnabled,
        keyboard = UserInputService.KeyboardEnabled,
    })
    local tenFoot = false
    pcall(function()
        tenFoot = GuiService:IsTenFootInterface()
    end)
    local display = InputPlatform.displayClass(tenFoot, size.X, size.Y, {
        touch = UserInputService.TouchEnabled,
        keyboard = UserInputService.KeyboardEnabled,
    })
    player:SetAttribute("InputMode", mode)
    player:SetAttribute("DisplayClass", display)
    player:SetAttribute("IsTenFootInterface", tenFoot)
    player:SetAttribute("ControllerConnected", gamepad)
    player:SetAttribute("ControllerGlyphSet", "xbox")
    pcall(function()
        GuiService.AutoSelectGuiEnabled = mode == InputPlatform.MODE.GAMEPAD
    end)
end

function InputContext.start()
    if started then
        return
    end
    started = true
    refresh()
    pcall(function()
        UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
    end)
    UserInputService.LastInputTypeChanged:Connect(refresh)
    UserInputService.GamepadConnected:Connect(refresh)
    UserInputService.GamepadDisconnected:Connect(refresh)
    local cameraConnection
    local function watchCamera(camera)
        if cameraConnection then
            cameraConnection:Disconnect()
        end
        cameraConnection = camera
                and camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
            or nil
        refresh()
    end
    watchCamera(Workspace.CurrentCamera)
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        watchCamera(Workspace.CurrentCamera)
    end)
end

function InputContext.isGamepad()
    return player:GetAttribute("InputMode") == InputPlatform.MODE.GAMEPAD
end

function InputContext.isTenFoot()
    return player:GetAttribute("DisplayClass") == InputPlatform.DISPLAY.TEN_FOOT
end

return InputContext
