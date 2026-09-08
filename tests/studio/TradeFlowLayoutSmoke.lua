-- Native client trade/gift UI fixture. Requests and all inventory-changing commands are stubbed.
-- show("request" | "trade" | "gift", optional viewport) leaves an interactive fixture.
-- run() verifies geometry and state updates; destroy() removes every test surface.
local Smoke = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local function settle()
    for _ = 1, 4 do
        RunService.RenderStepped:Wait()
    end
end

function Smoke.show(mode, size)
    assert(RunService:IsStudio() and RunService:IsClient(), "Run in Studio Client")
    local player = Players.LocalPlayer
    local TradePanel = require(player.PlayerScripts.Client.UI.Menus.TradePanel)
    local panel = TradePanel.new()
    local fixture =
        { panel = panel, calls = {}, pets = {}, enhancements = {}, eggs = {}, nextOfferId = 0 }
    for i = 1, 30 do
        fixture.pets[i] =
            { uid = "fixture_pet_" .. i, id = "bunny", variant = "basic", level = i, quantity = 1 }
    end
    fixture.pets[1].quantity = 3 -- Keep offered and remaining stack copies distinct.
    fixture.enhancements[1] = {
        uid = "fixture_enhancement",
        id = "damage",
        category = "enhancements",
        type = "damage",
        level = 1,
        origins = {},
    }
    fixture.eggs[1] = {
        uid = "fixture_egg",
        id = "tester_egg",
        category = "eggs",
        name = "Test Egg",
        variant = "basic",
    }
    local state = {
        you = { items = {}, confirmed = false },
        them = { name = "Mobile Partner", items = { fixture.pets[30] }, confirmed = false },
    }
    fixture.state = state
    local gui = Instance.new("ScreenGui")
    gui.Name = "TradeFlowLayoutSmoke"
    gui.DisplayOrder = 200
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = player.PlayerGui
    local viewport = Instance.new("Frame")
    viewport.Name = "Viewport"
    viewport.BackgroundTransparency = 1
    viewport.Size = size and UDim2.fromOffset(size.X, size.Y) or UDim2.fromScale(1, 1)
    viewport.Parent = gui
    fixture.viewport = viewport
    panel._ensureLiveGui = function()
        return viewport
    end
    local function available(bucket)
        local result = {}
        for _, item in ipairs(bucket) do
            local offered = 0
            for _, descriptor in ipairs(state.you.items) do
                if descriptor.recordKey == item.uid then
                    offered += 1
                end
            end
            local remaining = (item.quantity or 1) - offered
            if remaining > 0 then
                local copy = table.clone(item)
                copy.quantity = remaining
                table.insert(result, copy)
            end
        end
        return result
    end
    panel._callBus = function(_, command, args)
        table.insert(fixture.calls, { command = command, args = args })
        if command == "trade.myPets" or command == "gift.myPets" then
            return {
                ok = true,
                pets = available(fixture.pets),
                targetUserId = -8,
                targetName = "Mobile Partner",
                preferenceLabel = "Any",
            }
        elseif command == "trade.myEnhancements" then
            return { ok = true, enhancements = available(fixture.enhancements) }
        elseif command == "trade.myEggs" then
            return { ok = true, eggs = available(fixture.eggs) }
        elseif command == "trade.respond" then
            if args.accept then
                panel:_onEvent({ type = "opened", state = state })
            end
        elseif
            command == "trade.add"
            or command == "trade.addEnhancement"
            or command == "trade.addEgg"
        then
            for _, bucket in ipairs({ fixture.pets, fixture.enhancements, fixture.eggs }) do
                for _, item in ipairs(bucket) do
                    if item.uid == args.uid then
                        fixture.nextOfferId += 1
                        local descriptor = table.clone(item)
                        descriptor.recordKey = item.uid
                        descriptor.uid = "escrow_" .. fixture.nextOfferId
                        descriptor.record = table.clone(item)
                        descriptor.quantity = 1
                        descriptor.record.quantity = 1
                        table.insert(state.you.items, descriptor)
                    end
                end
            end
            state.you.confirmed = false
            panel:_onEvent({ type = "updated", state = state })
        elseif command == "trade.remove" then
            for index, item in ipairs(state.you.items) do
                if item.uid == args.uid then
                    table.remove(state.you.items, index)
                    break
                end
            end
            state.you.confirmed = false
            panel:_onEvent({ type = "updated", state = state })
        elseif command == "trade.setGems" then
            for index = #state.you.items, 1, -1 do
                if state.you.items[index].category == "currencies" then
                    table.remove(state.you.items, index)
                end
            end
            table.insert(
                state.you.items,
                { uid = "gems", category = "currencies", id = "gems", amount = args.amount }
            )
            state.you.confirmed = false
            panel:_onEvent({ type = "updated", state = state })
        elseif command == "trade.confirm" then
            state.you.confirmed = true
            panel:_onEvent({ type = "updated", state = state })
        elseif command == "trade.cancel" then
            panel:_onEvent({ type = "cancelled" })
        end
        return { ok = true }
    end
    fixture.destroy = function()
        panel:_closeWindow()
        panel:_closeRequestPopup()
        panel:_closeGiftPicker()
        panel:Destroy()
        gui:Destroy()
    end
    if mode == "gift" then
        panel:_openGiftPicker({ userId = -8, name = "Mobile Partner" })
    elseif mode == "request" then
        panel:_onEvent({ type = "request", fromUserId = -8, fromName = "Mobile Partner" })
    else
        panel:_onEvent({ type = "opened", state = state })
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

local function touch(button)
    assert(
        button.AbsoluteSize.X >= 44 and button.AbsoluteSize.Y >= 44,
        button.Name .. " touch target too small"
    )
end

function Smoke.run()
    local results = {}
    for _, size in ipairs({
        Vector2.new(733, 313),
        Vector2.new(690, 337),
        Vector2.new(667, 295),
        Vector2.new(1280, 720),
    }) do
        local f = Smoke.show("request", size)
        local ok, err = pcall(function()
            local p = f.panel
            assert(inside(p.requestPopup, f.viewport), "Request popup clipped")
            touch(p.requestPopup.Accept)
            touch(p.requestPopup.Decline)
            p:_callBus("trade.respond", { accept = true, fromUserId = -8 })
            p:_closeRequestPopup()
            settle()
            local win = p.window
            assert(inside(win, f.viewport), "Trade window clipped")
            assert(inside(win.CloseButton, win), "Trade close button escapes the window")
            assert(inside(win.CloseButton, f.viewport), "Trade close button clipped by safe area")
            local view = p._tradeView
            touch(view.confirm)
            touch(win.Body.Actions.CancelTrade)
            for _, col in ipairs({ view.source, view.theirs }) do
                assert(inside(col.frame, win), "Trade column clipped")
                assert(
                    col.frame.AbsolutePosition.Y + col.frame.AbsoluteSize.Y
                        <= win.Body.Actions.AbsolutePosition.Y,
                    "Columns overlap actions"
                )
                local grid = col.frame.Content.TradeItems
                assert(
                    grid.AbsoluteSize.Y >= 65 and grid.AbsoluteSize.X >= 65,
                    "Cannot see a complete item card"
                )
                assert(inside(grid, col.frame), "Item grid escapes column")
            end
            local source = view.source.frame.Content
            touch(source.CategorySelector)
            touch(source.GemBar.SetGems)
            touch(source.GemBar.GemAmount)
            source.CategorySelector.Categories.Visible = true
            settle()
            for _, tab in pairs(view.source.tabs) do
                touch(tab.button)
                assert(
                    inside(tab.button, view.source.frame),
                    "Category option escapes source column"
                )
            end
            source.CategorySelector.Categories.Visible = false
            local grid = source.TradeItems
            grid.CanvasPosition = Vector2.new(0, grid.AbsoluteCanvasSize.Y)
            settle()
            local last
            for _, item in ipairs(grid:GetChildren()) do
                if item:IsA("Frame") and (not last or item.LayoutOrder > last.LayoutOrder) then
                    last = item
                end
            end
            assert(last and inside(last, grid), "Last inventory item cannot scroll into view")
            p:_callBus("trade.add", { uid = f.pets[1].uid })
            p:_callBus("trade.setGems", { amount = 123 })
            settle()
            local offeredCard
            for _, card in ipairs(grid:GetChildren()) do
                if
                    card:IsA("Frame")
                    and card:FindFirstChild("OfferHighlight")
                    and card.OfferHighlight.Visible
                then
                    offeredCard = card
                end
            end
            assert(
                offeredCard and offeredCard.LayoutOrder == 1,
                "Offered pet is not highlighted at the top"
            )
            local partialStack
            for _, card in ipairs(grid:GetChildren()) do
                if card:IsA("Frame") and not card.OfferHighlight.Visible then
                    local quantity = card:FindFirstChild("QtyLabel")
                    if quantity and quantity.Visible and quantity.Text == "×2" then
                        partialStack = card
                    end
                end
            end
            assert(partialStack, "Offering one stack copy hides the two remaining copies")
            local escrowUid = f.state.you.items[1].uid
            p._sourceTab = "eggs"
            p:_renderWindow(f.state)
            settle()
            assert(
                offeredCard.Parent and offeredCard.OfferHighlight.Visible,
                "Changing categories hides the offer"
            )
            p:_callBus("trade.addEgg", { uid = f.eggs[1].uid })
            settle()
            local highlights = 0
            for _, card in ipairs(grid:GetChildren()) do
                if card:IsA("Frame") and card.OfferHighlight.Visible then
                    highlights += 1
                    assert(card.LayoutOrder <= 2, "Mixed-category offers are not first")
                end
            end
            assert(highlights == 2, "Mixed-category offers lost a highlight")
            p:_callBus("trade.remove", { uid = f.state.you.items[#f.state.you.items].uid })
            p:_callBus("trade.remove", { uid = escrowUid })
            p:_callBus("trade.confirm", {})
            assert(p.window == win, "State update replaced the trade window")
            assert(
                #f.state.you.items == 1 and f.state.you.items[1].amount == 123,
                "Offer did not update"
            )
            assert(
                not view.confirm.Active and view.confirmLabel.Text:find("Confirmed", 1, true),
                "Confirmation waiting state missing"
            )
            p:_callBus("trade.cancel", {})
            assert(not p.window, "Cancel does not close trade")
            p:_openGiftPicker({ userId = -8, name = "Mobile Partner" })
            settle()
            assert(inside(p.giftWindow, f.viewport), "Gift picker clipped")
            local giftGrid = p._giftView.frame.Content.TradeItems
            assert(giftGrid.AbsoluteSize.Y >= 65, "Gift picker cannot show a whole pet")
            giftGrid.CanvasPosition = Vector2.new(0, giftGrid.AbsoluteCanvasSize.Y)
            settle()
            p:_confirmGift({ userId = -8, name = "Mobile Partner" }, f.pets[1])
            settle()
            local confirm = f.viewport.GiftConfirmation
            assert(inside(confirm, f.viewport), "Gift confirmation clipped")
            touch(confirm.ConfirmGift)
            touch(confirm.CancelGift)
            assert(
                inside(confirm.ConfirmGift, confirm) and inside(confirm.CancelGift, confirm),
                "Gift actions clipped"
            )
        end)
        f.destroy()
        assert(ok, tostring(size) .. ": " .. tostring(err))
        table.insert(results, { viewport = tostring(size), passed = true })
    end
    return results
end

return Smoke
