--[[
    Range catalog picker — starts a shared Pets/Powers draft and opens Inventory.

    Server fires GameEvent "range_picker". Inventory cards + PowerChoiceMenu are the
    two Range screens; Enter from either sends ChallengeRun_Start.
]]

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

function RangePicker.start()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Signals = require(ReplicatedStorage.Shared.Network.Signals)
    if Signals.GameEvent then
        Signals.GameEvent.OnClientEvent:Connect(function(name, ctx)
            if name ~= "range_picker" or type(ctx) ~= "table" then
                return
            end
            if openInventory(ctx) then
                return
            end
            -- MenuManager boots after this system; retry once the overlay exists.
            task.defer(function()
                for _ = 1, 20 do
                    if openInventory(ctx) then
                        return
                    end
                    task.wait(0.1)
                end
                RangeLoadoutSession.clear()
            end)
        end)
    end
    return RangePicker
end

return RangePicker
