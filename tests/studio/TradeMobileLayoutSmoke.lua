-- Client-only rendered layout regression. All commands are stubbed: no invitations, gifts, or
-- saved preferences are sent. run() covers short landscape, narrow portrait, and desktop sizes.
-- show() leaves an interactive fixture for Studio's device emulator; call fixture.destroy() after.
local Smoke = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local function settle()
    for _ = 1, 4 do
        RunService.RenderStepped:Wait()
    end
end

function Smoke.show(size)
    assert(RunService:IsStudio() and RunService:IsClient(), "Run in Studio Client")
    local player = Players.LocalPlayer
    local TradePanel = require(player.PlayerScripts.Client.UI.Menus.TradePanel)
    local fixture = { count = 8, calls = {} }
    local panel = TradePanel.new()
    fixture.panel = panel
    panel._callBus = function(_, command, args)
        table.insert(fixture.calls, { command = command, args = args })
        local rows = {}
        for i = 1, fixture.count do
            rows[i] = {
                userId = -i,
                name = "Mobile Player " .. i,
                privacy = "Everyone",
                giftsEnabled = i ~= 3,
                giftPreferenceLabel = i == 3 and "Off" or "Any",
                busy = i == 2,
            }
        end
        return { ok = true, players = rows, mode = args.mode }
    end
    -- Gift selection is outside this player-picker test; intercept before any real inventory read.
    panel._openGiftPicker = function(_, target)
        fixture.giftTarget = target.userId
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "TradeMobileLayoutSmoke"
    gui.DisplayOrder = 200
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = player.PlayerGui
    local parent = gui
    if size then
        parent = Instance.new("Frame")
        parent.Name = "TestViewport"
        parent.Size = UDim2.fromOffset(size.X, size.Y)
        parent.BackgroundTransparency = 1
        parent.Parent = gui
    end
    panel:Show(parent)
    fixture.destroy = function()
        panel:Destroy()
        gui:Destroy()
    end
    settle()
    return fixture
end

local function inside(child, parent)
    local p, s = child.AbsolutePosition, child.AbsoluteSize
    local pp, ps = parent.AbsolutePosition, parent.AbsoluteSize
    return p.X >= pp.X - 1
        and p.Y >= pp.Y - 1
        and p.X + s.X <= pp.X + ps.X + 1
        and p.Y + s.Y <= pp.Y + ps.Y + 1
end

function Smoke.run()
    local results = {}
    for _, size in ipairs({
        Vector2.new(690, 337),
        Vector2.new(667, 295),
        Vector2.new(320, 568),
        Vector2.new(393, 772),
        Vector2.new(1280, 720),
    }) do
        local fixture = Smoke.show(size)
        local ok, result = pcall(function()
            local panel = fixture.panel
            local frame = panel.frame
            local nav = frame.Body.Navigation
            local pages = frame.Body.Pages
            local list = panel.playerList
            assert(inside(nav, frame) and inside(pages, frame), "Chrome exceeds panel")
            assert(
                nav.AbsolutePosition.Y + nav.AbsoluteSize.Y <= pages.AbsolutePosition.Y,
                "Navigation overlaps players"
            )
            assert(list.AbsoluteSize.Y >= 112, "Cannot see even one complete player row")
            assert(list.AbsoluteCanvasSize.Y > list.AbsoluteSize.Y, "Eight-player list must scroll")
            for _, button in ipairs(nav:GetChildren()) do
                if button:IsA("TextButton") then
                    assert(
                        button.AbsoluteSize.Y >= 44 and button.AbsoluteSize.X >= 44,
                        "Navigation touch target too small"
                    )
                end
            end
            for _, row in ipairs(list:GetChildren()) do
                if row:IsA("Frame") then
                    for _, name in ipairs({ "Request", "GiveGift" }) do
                        local button = row[name]
                        assert(
                            button.AbsoluteSize.Y >= 44 and button.AbsoluteSize.X >= 44,
                            "Player action too small"
                        )
                        assert(inside(button, row), "Player action extends outside its row")
                    end
                    assert(
                        row.Request.AbsolutePosition.X + row.Request.AbsoluteSize.X
                            < row.GiveGift.AbsolutePosition.X,
                        "Player actions overlap"
                    )
                end
            end
            assert(not list["Player_-2"].Request.Active, "Busy player allows requests")
            assert(not list["Player_-3"].GiveGift.Active, "Disabled gifts allow sending")
            list.CanvasPosition = Vector2.new(0, list.AbsoluteCanvasSize.Y)
            settle()
            assert(
                inside(list["Player_-8"].GiveGift, list),
                "Last player's action cannot scroll into view"
            )
            local preferences = pages.Preferences
            list.Visible = false
            preferences.Visible = true
            settle()
            for _, group in ipairs({ panel.privacyButtons, panel.giftPrivacyButtons }) do
                for _, button in pairs(group) do
                    assert(
                        button.AbsoluteSize.Y >= 44 and button.AbsoluteSize.X >= 44,
                        "Preference touch target too small"
                    )
                end
            end
            preferences.CanvasPosition = Vector2.new(0, preferences.AbsoluteCanvasSize.Y)
            settle()
            assert(
                inside(panel.giftPrivacyButtons.off, preferences),
                "Last gift preference cannot scroll into view"
            )
            fixture.count = 0
            panel:_refreshPlayers()
            panel:_refreshPlayers()
            local emptyCount = 0
            for _, child in ipairs(list:GetChildren()) do
                if child:IsA("GuiObject") then
                    emptyCount += 1
                end
            end
            assert(emptyCount == 1, "Refresh stacks empty-state labels")
            fixture.count = 8
            panel:_refreshPlayers()
            assert(list:FindFirstChild("Player_-8"), "Refresh does not restore player rows")
            return {
                viewport = tostring(size),
                playerListHeight = list.AbsoluteSize.Y,
                passed = true,
            }
        end)
        fixture.destroy()
        assert(ok, tostring(size) .. ": " .. tostring(result))
        table.insert(results, result)
    end
    return results
end

return Smoke
