-- ConsoleActionRouter — one semantic controller contract for gameplay surfaces.
-- Menus retain Roblox selection navigation; gameplay bindings are active only outside a modal.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local EggInteractionService = require(ReplicatedStorage.Shared.Services.EggInteractionService)

local ConsoleActionRouter = {}
local started = false
local PRIORITY = Enum.ContextActionPriority.High.Value

local function menuOpen()
    local manager = _G.MenuManager
    return (manager and manager.GetCurrentPanelName and manager:GetCurrentPanelName() ~= nil)
        or GuiService.MenuIsOpen
end

local function onBegin(callback)
    return function(_, inputState)
        if inputState ~= Enum.UserInputState.Begin or menuOpen() then
            return Enum.ContextActionResult.Pass
        end
        callback()
        return Enum.ContextActionResult.Sink
    end
end

local function openPanel(name)
    local manager = _G.MenuManager
    if manager and manager.TogglePanel then
        manager:TogglePanel(name, "fade_in")
    end
end

local function hotbarCall(method)
    local controller = _G.HotbarController
    if controller and type(controller[method]) == "function" then
        controller[method](controller)
    end
end

function ConsoleActionRouter.start()
    if started then
        return
    end
    started = true

    ContextActionService:BindActionAtPriority("Console_Back", function(_, inputState)
        if inputState ~= Enum.UserInputState.Begin then
            return Enum.ContextActionResult.Pass
        end
        local manager = _G.MenuManager
        if manager and manager.GetCurrentPanelName and manager:GetCurrentPanelName() then
            manager:CloseCurrentPanel()
            return Enum.ContextActionResult.Sink
        end
        return Enum.ContextActionResult.Pass
    end, false, PRIORITY, Enum.KeyCode.ButtonB)

    ContextActionService:BindActionAtPriority(
        "Console_PreviousPower",
        onBegin(function()
            local controller = _G.HotbarController
            if controller then
                controller:StepSelection(-1)
            end
        end),
        false,
        PRIORITY,
        Enum.KeyCode.ButtonL1
    )
    ContextActionService:BindActionAtPriority(
        "Console_NextPower",
        onBegin(function()
            local controller = _G.HotbarController
            if controller then
                controller:StepSelection(1)
            end
        end),
        false,
        PRIORITY,
        Enum.KeyCode.ButtonR1
    )
    ContextActionService:BindActionAtPriority(
        "Console_CastPower",
        onBegin(function()
            hotbarCall("ActivateSelection")
        end),
        false,
        PRIORITY,
        Enum.KeyCode.ButtonR2
    )
    ContextActionService:BindActionAtPriority(
        "Console_ToggleAutocast",
        onBegin(function()
            hotbarCall("ToggleSelectionAutocast")
        end),
        false,
        PRIORITY,
        Enum.KeyCode.ButtonL2
    )
    ContextActionService:BindActionAtPriority(
        "Console_CycleFarm",
        onBegin(function()
            hotbarCall("CycleFarm")
        end),
        false,
        PRIORITY,
        Enum.KeyCode.ButtonY
    )
    ContextActionService:BindActionAtPriority(
        "Console_OpenPets",
        onBegin(function()
            openPanel("Inventory")
        end),
        false,
        PRIORITY,
        Enum.KeyCode.DPadLeft
    )
    ContextActionService:BindActionAtPriority(
        "Console_OpenPowers",
        onBegin(function()
            openPanel("PowerChoice")
        end),
        false,
        PRIORITY,
        Enum.KeyCode.DPadRight
    )
    ContextActionService:BindActionAtPriority(
        "Console_OpenQuests",
        onBegin(function()
            openPanel("Quest")
        end),
        false,
        PRIORITY,
        Enum.KeyCode.DPadUp
    )
    ContextActionService:BindActionAtPriority(
        "Console_OpenMenu",
        onBegin(function()
            openPanel("Settings")
        end),
        false,
        PRIORITY,
        Enum.KeyCode.DPadDown
    )

    -- Do not sink X: native ProximityPrompts also own it. Hatch only when Roblox did not consume it.
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.KeyCode == Enum.KeyCode.ButtonX and not gameProcessed and not menuOpen() then
            EggInteractionService:OnEKeyPressed()
        end
    end)
end

return ConsoleActionRouter
