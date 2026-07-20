--[[
    RetentionContext — one-shot client environment report for the raw launch dataset.

    Roblox's native Analytics dashboard already knows platform. The durable event store also needs
    the environment attached to an inspectable player session, so this sends a strictly whitelisted
    snapshot through the existing GameAPI command boundary. No device identifier is collected.
]]

local GuiService = game:GetService("GuiService")
local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")
local Workspace = game:GetService("Workspace")

local RetentionContext = {}

local function deviceClass()
    if GuiService:IsTenFootInterface() then
        return "console"
    elseif VRService.VREnabled then
        return "vr"
    elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        return "touch"
    elseif UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
        return "desktop"
    elseif UserInputService.GamepadEnabled then
        return "gamepad"
    end
    return "unknown"
end

local function viewport()
    local camera = Workspace.CurrentCamera
    local size = camera and camera.ViewportSize
    return {
        width = size and math.floor(size.X) or 0,
        height = size and math.floor(size.Y) or 0,
    }
end

function RetentionContext.start()
    task.spawn(function()
        local remote = ReplicatedStorage:WaitForChild("GameAPICommand", 20)
        if not remote then
            return
        end
        pcall(function()
            remote:InvokeServer("retention.context", {
                deviceClass = deviceClass(),
                locale = LocalizationService.RobloxLocaleId,
                systemLocale = LocalizationService.SystemLocaleId,
                viewport = viewport(),
                touch = UserInputService.TouchEnabled,
                keyboard = UserInputService.KeyboardEnabled,
                mouse = UserInputService.MouseEnabled,
                gamepad = UserInputService.GamepadEnabled,
                vr = VRService.VREnabled,
                tenFoot = GuiService:IsTenFootInterface(),
            })
        end)
    end)
end

return RetentionContext
