--[[
    CombatTutorialDoorButtons — SurfaceGui hits on the frost door.

    Lesson (SET HEAL FIRST / ENTER) continues the room. Leave asks to
    confirm, then exits. No camera Billboard; both plates are SurfaceGuis.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local TAG = "CombatTutorialDoorAction"
local CombatTutorialDoorButtons = {}
local started = false
local bound = setmetatable({}, { __mode = "k" })

local function bind(button)
    if bound[button] or not button:IsA("GuiButton") then
        return
    end
    bound[button] = true
    button.Activated:Connect(function()
        local action = button:GetAttribute("DoorAction")
        if type(action) ~= "string" or action == "" then
            return
        end
        Signals.CombatTutorialDoorAction:FireServer(action)
    end)
end

function CombatTutorialDoorButtons.start()
    if started then
        return
    end
    started = true
    for _, button in ipairs(CollectionService:GetTagged(TAG)) do
        bind(button)
    end
    CollectionService:GetInstanceAddedSignal(TAG):Connect(bind)
end

return CombatTutorialDoorButtons
