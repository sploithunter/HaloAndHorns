--[[
    Range catalog picker — starts a shared Pets/Powers draft and opens Inventory.

    Server fires GameEvent "range_picker". Inventory cards + PowerChoiceMenu are the
    two Range screens; Enter from either sends ChallengeRun_Start.
]]

local Players = game:GetService("Players")

local RangeLoadoutSession = require(script.Parent.RangeLoadoutSession)

local RangePicker = {}

local function openInventory(ctx)
    RangeLoadoutSession.begin(ctx)
    local menu = _G.MenuManager
    local panel = menu and menu.GetPanel and menu:GetPanel("Inventory")
    if not (panel and panel.BeginRangeCatalog) then
        return false
    end
    panel:BeginRangeCatalog(ctx)
    if panel.isVisible then
        RangeLoadoutSession.holdDoors()
        return true
    end
    -- X-close hides the frame but can leave currentPanelName == "Inventory".
    if menu.NotifyPanelHidden then
        menu:NotifyPanelHidden(panel)
    end
    local opened = false
    if menu.OpenInventoryPanel then
        opened = menu:OpenInventoryPanel() == true
    elseif menu.OpenPanel then
        opened = menu:OpenPanel("Inventory") == true
    end
    if opened then
        RangeLoadoutSession.holdDoors()
    end
    return opened
end

local function hookInventory(ctx)
    local menu = _G.MenuManager
    if not (menu and menu.OnPanelRegistered) then
        return false
    end
    menu:OnPanelRegistered("Inventory", function()
        if not openInventory(ctx) then
            RangeLoadoutSession.clear()
        end
    end)
    return true
end

local function openWhenReady(ctx)
    if openInventory(ctx) then
        return
    end
    if hookInventory(ctx) then
        return
    end
    -- MenuManager is assigned in the same beat as ClientUIReady. Inventory
    -- registers later; OnPanelRegistered is the open event, not a poll.
    local player = Players.LocalPlayer
    local conn
    local function tryHook()
        if hookInventory(ctx) and conn then
            conn:Disconnect()
            conn = nil
        end
    end
    conn = player:GetAttributeChangedSignal("ClientUIReady"):Connect(tryHook)
    tryHook()
end

function RangePicker.start()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Signals = require(ReplicatedStorage.Shared.Network.Signals)
    if Signals.GameEvent then
        Signals.GameEvent.OnClientEvent:Connect(function(name, ctx)
            if name ~= "range_picker" or type(ctx) ~= "table" then
                return
            end
            openWhenReady(ctx)
        end)
    end
    return RangePicker
end

return RangePicker
