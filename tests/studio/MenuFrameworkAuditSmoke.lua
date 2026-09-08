-- Native client geometry + dispatch audit. Admin actions are replaced with spies;
-- settings apply/save is disabled, so fixtures cannot mutate player data.
local Smoke = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local function settle()
    for _ = 1, 4 do
        RunService.RenderStepped:Wait()
    end
end

local function inside(child, parent)
    local p, s = child.AbsolutePosition - parent.AbsolutePosition, child.AbsoluteSize
    assert(
        p.X >= -1
            and p.Y >= -1
            and p.X + s.X <= parent.AbsoluteSize.X + 1
            and p.Y + s.Y <= parent.AbsoluteSize.Y + 1,
        child:GetFullName() .. " escapes " .. parent.Name
    )
end

function Smoke.show(kind, size)
    assert(RunService:IsStudio() and RunService:IsClient(), "Audit assertion at 26")
    local player = Players.LocalPlayer
    local menus = player.PlayerScripts.Client.UI.Menus
    local panel = require(kind == "admin" and menus.AdminPanel or menus.SettingsPanel).new()
    if kind == "settings" then
        panel._applyAudioSettings = function() end
    end
    panel.isCreatorPassTester = false -- No on-open creator-status remote.
    local gui = Instance.new("ScreenGui")
    gui.Name = "MenuFrameworkAuditSmoke"
    gui.DisplayOrder = 250
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
    gui.Parent = player.PlayerGui
    local viewport = Instance.new("Frame")
    viewport.Name = "FixtureViewport"
    viewport.BackgroundTransparency = 1
    viewport.Size = size and UDim2.fromOffset(size.X, size.Y) or UDim2.fromScale(1, 1)
    viewport.Parent = gui
    settle()
    panel:Show(viewport)
    settle()
    local fixture = { panel = panel, gui = gui, viewport = viewport }
    function fixture:destroy()
        self.panel:Destroy()
        self.gui:Destroy()
    end
    return fixture
end

function Smoke.run()
    local report = { geometry = {}, adminActions = 0 }
    for _, size in
        {
            Vector2.new(852, 393),
            Vector2.new(667, 375),
            Vector2.new(568, 320),
            Vector2.new(393, 852),
            Vector2.new(1440, 900),
        }
    do
        for _, kind in { "settings", "admin" } do
            local f = Smoke.show(kind, size)
            local panel = f.panel
            inside(panel.frame, f.viewport)
            inside(panel.frame.CloseButton, panel.frame)
            assert(
                panel.frame.CloseButton.AbsoluteSize.X >= 44
                    and panel.frame.CloseButton.AbsoluteSize.Y >= 44,
                "Close control below touch size"
            )
            assert(panel.scrollFrame.AbsoluteSize.Y > 40, "No room for menu content")
            inside(panel.scrollFrame, panel.frame)
            for _, child in panel.frame:GetDescendants() do
                if child:IsA("GuiButton") then
                    assert(
                        child.AbsoluteSize.Y >= 43.9,
                        child:GetFullName() .. " is too short to touch"
                    )
                    assert(
                        child.AbsoluteSize.X >= 43.9,
                        child:GetFullName() .. " is too narrow to touch"
                    )
                end
            end
            if kind == "settings" then
                local ordered = {}
                for _, row in panel.scrollFrame:GetChildren() do
                    if row:IsA("GuiObject") then
                        assert(not ordered[row.LayoutOrder], "Overlapping Settings layout orders")
                        ordered[row.LayoutOrder] = row
                    end
                end
                for _, name in
                    {
                        "Performance ModeSetting",
                        "Reduced MotionSetting",
                        "UI ScaleSetting",
                        "InventoryDisplay",
                        "EggPreviewDisplay",
                    }
                do
                    assert(
                        not panel.scrollFrame:FindFirstChild(name),
                        "Unsupported setting exposed: " .. name
                    )
                end
                assert(
                    panel.scrollFrame:FindFirstChild("Voices VolumeSetting"),
                    "Audit assertion at 112"
                )
            else
                inside(panel.body.PlayerSelector, panel.body)
                inside(panel.body.Filters, panel.body)
                inside(panel.body.AdminResult, panel.body)
                assert(
                    panel.body.AdminResult.AbsolutePosition.Y
                            + panel.body.AdminResult.AbsoluteSize.Y
                        <= panel.scrollFrame.AbsolutePosition.Y + 1,
                    "Admin result covers actions"
                )
                local categories = require(ReplicatedStorage.Configs.admin_menu).category_order
                for index in ipairs(categories) do
                    panel.categoryIndex = index
                    panel:_createTestCategories()
                    settle()
                    assert(#panel.scrollFrame:GetChildren() > 2, "Empty category")
                end
                panel.searchQuery = "no-such-action-xyz"
                panel:_createTestCategories()
                assert(panel.scrollFrame:FindFirstChild("NoMatches"), "Audit assertion at 132")
            end
            panel.scrollFrame.CanvasPosition = Vector2.new(
                0,
                math.max(
                    0,
                    panel.scrollFrame.AbsoluteCanvasSize.Y - panel.scrollFrame.AbsoluteWindowSize.Y
                )
            )
            settle()
            table.insert(report.geometry, {
                kind = kind,
                width = size.X,
                height = size.Y,
                contentHeight = panel.scrollFrame.AbsoluteSize.Y,
            })
            f:destroy()
        end
    end
    local Admin = require(Players.LocalPlayer.PlayerScripts.Client.UI.Menus.AdminPanel)
    local catalog = require(ReplicatedStorage.Configs.admin_menu)
    for _, categoryId in catalog.category_order do
        for _, action in catalog.categories[categoryId].tests do
            local calls = {}
            local fake = {
                logger = { info = function() end, warn = function() end, error = function() end },
            }
            for method, value in pairs(Admin) do
                if type(value) == "function" and method ~= "_executeTestAction" then
                    fake[method] = function(...)
                        table.insert(calls, { method = method, args = { ... } })
                    end
                end
            end
            Admin._executeTestAction(fake, action.action, action.name)
            assert(
                #calls == 1 and calls[1].method ~= "_showAdminResult",
                "Unrouted Admin action: " .. action.action
            )
            report.adminActions += 1
        end
    end
    local Manager = require(Players.LocalPlayer.PlayerScripts.Client.UI.MenuManager)
    local hidden = false
    local good = {
        Hide = function()
            hidden = true
        end,
    }
    local fakeManager = setmetatable({
        panels = {},
        currentPanel = good,
        currentPanelName = "good",
        logger = { error = function() end, warn = function() end },
        isTransitioning = false,
    }, { __index = Manager })
    assert(
        fakeManager:OpenPanel("unknown") == false and not hidden,
        "Unknown menu closed the current menu"
    )
    fakeManager.currentPanel = nil
    local partial = Instance.new("Frame")
    partial.Parent = Players.LocalPlayer.PlayerGui
    fakeManager.panels.broken = {
        Show = function()
            error("intentional fixture failure")
        end,
        Hide = function()
            error("intentional cleanup failure")
        end,
        GetFrame = function()
            return partial
        end,
    }
    assert(fakeManager:OpenPanel("broken") == false, "Audit assertion at 206")
    assert(not fakeManager.isTransitioning and partial.Parent == nil, "Audit assertion at 207")
    report.failedShowRecovers = true

    local targetPanel = setmetatable({ targetPlayerLabel = {} }, { __index = Admin })
    local targets = { Players.LocalPlayer }
    for index = 1, 7 do
        table.insert(targets, { UserId = -index, Name = "Audit Player " .. index })
    end
    targetPanel._refreshPlayerList = function(self)
        self.playerList = targets
    end
    for index = 2, 8 do
        targetPanel:_showPlayerDropdown()
        assert(
            targetPanel.selectedTargetPlayerId == targets[index].UserId,
            "Audit assertion at 220"
        )
        assert(
            targetPanel:_getAdminActionData({}).targetPlayerId == targets[index].UserId,
            "Audit assertion at 221"
        )
    end
    targetPanel:_showPlayerDropdown()
    assert(targetPanel.selectedTargetPlayerId == nil, "Audit assertion at 224")
    report.eightPlayerTargetCycle = true
    local parsed = setmetatable({ logger = { info = function() end } }, { __index = Admin })
    assert(parsed:_parseAmount("+1M") == 1000000, "Audit assertion at 227")
    assert(parsed:_parseAmount("-500K") == -500000, "Audit assertion at 228")
    assert(parsed:_parseAmount("1e999") == nil, "Audit assertion at 229")

    local Inventory = require(Players.LocalPlayer.PlayerScripts.Client.UI.Menus.InventoryPanel)
    local options = {}
    Inventory._addConfiguredAction({}, options, {
        action = "delete",
        text = "Delete %d",
        quantities = { 1, 5, "all" },
        color = { 255, 255, 255 },
    }, { count = 3 })
    assert(
        #options == 2 and options[2].quantity == 3 and options[2].text == "Delete All (3)",
        "Audit assertion at 239"
    )
    local egg = {}
    local hatched
    Inventory._hatchEgg({
        _hatchEggItem = function(_, item)
            hatched = item
        end,
    }, egg)
    assert(hatched == egg, "Audit assertion at 247")
    report.inventoryAllAndHatchRouting = true
    report.unknownPanelPreservesCurrent = true
    return report
end

return Smoke
