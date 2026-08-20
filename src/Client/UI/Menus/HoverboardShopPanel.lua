--[[
    HoverboardShopPanel — Kade's shack catalog.

    Server owns stock, prices, and equipped state. The client renders Kade's
    story plus keyed board images, then sends buy/equip commands.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PanelChrome = require(script.Parent.Parent.Components.PanelChrome)
local Pill = require(script.Parent.Parent.Pill)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local REMOTE_NAME = "GameAPICommand"
local COLORS = {
    text = Color3.fromRGB(255, 255, 255),
    subtext = Color3.fromRGB(202, 207, 218),
    buy = Color3.fromRGB(42, 176, 102),
    equip = Color3.fromRGB(70, 130, 210),
    equipped = Color3.fromRGB(116, 235, 155),
    owned = Color3.fromRGB(186, 168, 255),
    disabled = Color3.fromRGB(72, 74, 84),
    error = Color3.fromRGB(242, 105, 105),
    gems = Color3.fromRGB(130, 220, 255),
    robux = Color3.fromRGB(0, 176, 111),
}

local REASONS = {
    shop_out_of_range = "Move closer to Kade.",
    insufficient_gems = "You need more gems.",
    already_owned = "You already own that board.",
    not_owned = "Grab that board first.",
    invalid_skin = "That board is not in the shop.",
    debit_failed = "The gem payment did not complete.",
    robux_unwired = "That Robux board is not listed yet.",
    service_unavailable = "The hoverboard shop is temporarily unavailable.",
}

local HoverboardShopPanel = {}
HoverboardShopPanel.__index = HoverboardShopPanel

local function textLabel(parent, options)
    local label = Instance.new("TextLabel")
    label.Name = options.name or "Label"
    label.Size = options.size
    label.Position = options.position or UDim2.new()
    label.AnchorPoint = options.anchor or Vector2.zero
    label.BackgroundTransparency = 1
    label.Text = options.text or ""
    label.TextColor3 = options.color or COLORS.text
    label.TextSize = options.textSize or 20
    label.Font = options.font or Enum.Font.Gotham
    label.TextWrapped = options.wrapped == true
    label.TextXAlignment = options.xAlign or Enum.TextXAlignment.Left
    label.TextYAlignment = options.yAlign or Enum.TextYAlignment.Center
    label.ZIndex = options.zindex or 103
    if options.layoutOrder then
        label.LayoutOrder = options.layoutOrder
    end
    if options.autoY then
        label.AutomaticSize = Enum.AutomaticSize.Y
    end
    if options.scaled then
        label.TextScaled = true
        local constraint = Instance.new("UITextSizeConstraint")
        constraint.MinTextSize = options.minText or 16
        constraint.MaxTextSize = options.maxText or 28
        constraint.Parent = label
    end
    label.Parent = parent
    return label
end

local function storyText(story)
    if type(story) ~= "table" then
        return ""
    end
    local lines = {}
    if type(story.lines) == "table" then
        for _, line in ipairs(story.lines) do
            if type(line) == "string" and line ~= "" then
                table.insert(lines, line)
            end
        end
    end
    return table.concat(lines, "\n")
end

local function priceLabel(offer)
    if offer.equipped then
        return "EQUIPPED", COLORS.equipped
    end
    if offer.owned then
        return "OWNED", COLORS.owned
    end
    if offer.kind == "robux" then
        -- Config R$ is dashboard baseline only. Live text comes from
        -- MarketplaceService:GetProductInfo (regional / managed pricing).
        if offer.on_sale then
            return "ON SALE", COLORS.robux
        end
        return "Robux", COLORS.robux
    end
    if offer.kind == "gems" then
        return string.format("%s Gems", tostring(offer.price or 0)), COLORS.gems
    end
    return "Free", COLORS.equipped
end

function HoverboardShopPanel.new()
    local self = setmetatable({
        frame = nil,
        rows = {},
        statusLabel = nil,
        balanceLabel = nil,
        storyLabel = nil,
        list = nil,
        grid = nil,
        gridLayout = nil,
        story = nil,
        _robuxPrices = {},
    }, HoverboardShopPanel)
    self._purchaseConn = Signals.PurchaseSuccess.OnClientEvent:Connect(function(data)
        if not self:IsVisible() then
            return
        end
        if
            type(data) == "table"
            and type(data.rewards) == "table"
            and data.rewards.hoverboard_skin
        then
            self:_setStatus("Board's yours. Hop on.", false)
            self:_refresh()
        end
    end)
    return self
end

function HoverboardShopPanel:_callBus(name, args)
    local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
    if not remote then
        return { ok = false, reason = "service_unavailable" }
    end
    local ok, envelope = pcall(function()
        return remote:InvokeServer(name, args or {})
    end)
    if not ok or type(envelope) ~= "table" then
        return { ok = false, reason = "service_unavailable" }
    end
    if envelope.ok == false then
        return { ok = false, reason = envelope.code or "service_unavailable" }
    end
    return envelope.result or envelope
end

function HoverboardShopPanel:SetShopContext(context)
    if type(context) == "table" and type(context.story) == "table" then
        self.story = context.story
    end
end

function HoverboardShopPanel:Show(parent)
    if not self.frame then
        self:_createUI(parent)
    end
    self.frame.Visible = true
    self:_refresh()
end

function HoverboardShopPanel:Hide()
    -- Destroy the frame so MenuOverlay ChildRemoved clears the dim scrim.
    if self.frame then
        self.frame:Destroy()
    end
    self.frame = nil
    self.list = nil
    self.grid = nil
    self.gridLayout = nil
    self.statusLabel = nil
    self.balanceLabel = nil
    self.storyLabel = nil
    self.rows = {}
end

function HoverboardShopPanel:IsVisible()
    return self.frame ~= nil and self.frame.Visible == true
end

function HoverboardShopPanel:GetFrame()
    return self.frame
end

function HoverboardShopPanel:Destroy()
    if self._purchaseConn then
        self._purchaseConn:Disconnect()
        self._purchaseConn = nil
    end
    self:Hide()
end

function HoverboardShopPanel:_close()
    local menuManager = _G.MenuManager
    if
        menuManager
        and menuManager.GetCurrentPanelName
        and menuManager:GetCurrentPanelName() == "HoverboardShop"
    then
        menuManager:CloseCurrentPanel()
        return
    end
    self:Hide()
end

function HoverboardShopPanel:_createUI(parent)
    local shell = PanelChrome.build(parent, {
        name = "HoverboardShopPanel",
        title = "🛹 Kade's Boards",
        size = UDim2.new(0.72, 0, 0.78, 0),
        onClose = function()
            self:_close()
        end,
    })
    self.frame = shell.frame
    self.balanceLabel = textLabel(shell.header, {
        name = "Balance",
        -- Right inset clears the close X inside the header capsule.
        size = UDim2.new(0.28, 0, 0.7, 0),
        position = UDim2.new(0.86, 0, 0.5, 0),
        anchor = Vector2.new(1, 0.5),
        text = "Gems —",
        color = COLORS.gems,
        font = Enum.Font.GothamBold,
        xAlign = Enum.TextXAlignment.Right,
        scaled = true,
        minText = 14,
        maxText = 22,
    })
    -- Story, status, and the board grid share one scroll so phones do not
    -- get a tall empty story box with a one-row catalog strip underneath.
    self.list = PanelChrome.scrollPane(self.frame, {
        name = "BoardList",
        size = UDim2.new(1, 0, 0.86, 0),
        position = UDim2.new(0.5, 0, 0.12, 0),
        padding = 8,
        inset = 12,
    })
    self.storyLabel = textLabel(self.list, {
        name = "Story",
        size = UDim2.new(1, 0, 0, 0),
        text = storyText(self.story),
        color = COLORS.subtext,
        textSize = 16,
        font = Enum.Font.GothamMedium,
        wrapped = true,
        yAlign = Enum.TextYAlignment.Top,
        autoY = true,
        layoutOrder = 0,
    })
    self.statusLabel = textLabel(self.list, {
        name = "Status",
        size = UDim2.new(1, 0, 0, 28),
        text = "Take a free board. Fancy ones cost gems or Robux.",
        color = COLORS.subtext,
        font = Enum.Font.GothamBold,
        scaled = true,
        minText = 14,
        maxText = 18,
        layoutOrder = 1,
    })
    self.grid = Instance.new("Frame")
    self.grid.Name = "BoardGrid"
    self.grid.BackgroundTransparency = 1
    self.grid.Size = UDim2.new(1, 0, 0, 0)
    self.grid.AutomaticSize = Enum.AutomaticSize.Y
    self.grid.LayoutOrder = 2
    self.grid.ZIndex = 102
    self.grid.Parent = self.list
    local layout = Instance.new("UIGridLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.CellPadding = UDim2.fromOffset(8, 8)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.Parent = self.grid
    self.gridLayout = layout
    self.grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:_layoutGrid()
    end)
    self:_layoutGrid()
end

function HoverboardShopPanel:_layoutGrid()
    if not (self.grid and self.gridLayout) then
        return
    end
    local width = self.grid.AbsoluteSize.X
    if width < 8 then
        return
    end
    local columns = 2
    if width >= 720 then
        columns = 4
    elseif width >= 480 then
        columns = 3
    end
    local pad = 8
    local cellW = math.max(88, math.floor((width - pad * (columns - 1)) / columns))
    -- Slightly taller than square so the name, tender, and action fit under the icon.
    local cellH = math.floor(cellW * 1.22)
    self.gridLayout.CellSize = UDim2.fromOffset(cellW, cellH)
    self.gridLayout.FillDirectionMaxCells = columns
end

function HoverboardShopPanel:_setStatus(text, isError)
    if self.statusLabel then
        self.statusLabel.Text = text
        self.statusLabel.TextColor3 = isError and COLORS.error or COLORS.equipped
    end
end

function HoverboardShopPanel:_clearRows()
    for _, row in ipairs(self.rows) do
        row:Destroy()
    end
    self.rows = {}
end

function HoverboardShopPanel:_fillRobuxPrice(label, offer)
    local robloxId = tonumber(offer.roblox_product_id) or 0
    if robloxId <= 0 or not label then
        return
    end
    self._robuxPrices = self._robuxPrices or {}
    local cached = self._robuxPrices[robloxId]
    if cached then
        label.Text = cached
        return
    end
    task.spawn(function()
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfo(robloxId, Enum.InfoType.Product)
        end)
        local price = ok and type(info) == "table" and tonumber(info.PriceInRobux)
        local text
        if price and price > 0 then
            if offer.on_sale then
                text = string.format("ON SALE  R$ %d", price)
            else
                text = string.format("R$ %d", price)
            end
        else
            text = offer.on_sale and "ON SALE  See Roblox" or "See Roblox price"
        end
        self._robuxPrices[robloxId] = text
        if label.Parent then
            label.Text = text
        end
    end)
end

function HoverboardShopPanel:_actionFor(offer)
    if offer.equipped then
        return "Equipped", COLORS.disabled, false
    end
    if offer.owned then
        return "Equip", COLORS.equip, true
    end
    if offer.kind == "robux" then
        if offer.on_sale then
            return "Sale", COLORS.robux, true
        end
        return "Robux", COLORS.robux, true
    end
    if offer.kind == "free" then
        return "Take", COLORS.buy, true
    end
    return "Buy", COLORS.buy, true
end

function HoverboardShopPanel:_render(catalog)
    self:_clearRows()
    if type(catalog.story) == "table" then
        self.story = catalog.story
    end
    if self.storyLabel then
        self.storyLabel.Text = storyText(self.story)
    end
    self.balanceLabel.Text = string.format("Gems  %s", tostring(catalog.gems or 0))
    local offers = catalog.offers
    if type(offers) ~= "table" or #offers == 0 then
        self:_setStatus("Kade has no boards in stock.", true)
        return
    end
    self:_layoutGrid()
    local host = self.grid or self.list
    for index, offer in ipairs(offers) do
        local card = PanelChrome.entryRow(host, {
            name = offer.id,
            height = 160,
            layoutOrder = index,
            bg = Color3.fromRGB(38, 40, 50),
            corner = 10,
        })
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.fromScale(0.72, 0.48)
        icon.Position = UDim2.new(0.5, 0, 0.04, 0)
        icon.AnchorPoint = Vector2.new(0.5, 0)
        icon.BackgroundTransparency = 1
        icon.Image = offer.icon or ""
        icon.ScaleType = Enum.ScaleType.Fit
        icon.ZIndex = 103
        icon.Parent = card
        local aspect = Instance.new("UIAspectRatioConstraint")
        aspect.AspectRatio = 1
        aspect.Parent = icon
        textLabel(card, {
            name = "Name",
            size = UDim2.new(0.9, 0, 0.16, 0),
            position = UDim2.new(0.05, 0, 0.52, 0),
            text = offer.display_name,
            font = Enum.Font.GothamBold,
            xAlign = Enum.TextXAlignment.Center,
            scaled = true,
            minText = 12,
            maxText = 18,
        })
        local priceText, priceColor = priceLabel(offer)
        local priceNode = textLabel(card, {
            name = "Price",
            size = UDim2.new(0.9, 0, 0.12, 0),
            position = UDim2.new(0.05, 0, 0.66, 0),
            text = priceText,
            color = priceColor,
            xAlign = Enum.TextXAlignment.Center,
            scaled = true,
            minText = 11,
            maxText = 15,
        })
        if offer.kind == "robux" and not offer.owned then
            self:_fillRobuxPrice(priceNode, offer)
        end
        local actionText, actionColor, enabled = self:_actionFor(offer)
        local button, buttonLabel = Pill.button({
            parent = card,
            name = "Action",
            color = actionColor,
            size = UDim2.new(0.86, 0, 0.16, 0),
            position = UDim2.new(0.5, 0, 0.92, 0),
            anchorPoint = Vector2.new(0.5, 1),
            text = actionText,
            textSize = 14,
            zIndex = 106,
        })
        buttonLabel.TextScaled = true
        local buttonSize = Instance.new("UITextSizeConstraint")
        buttonSize.MinTextSize = 11
        buttonSize.MaxTextSize = 16
        buttonSize.Parent = buttonLabel
        button.Active = enabled
        button.AutoButtonColor = enabled
        if offer.owned then
            button.Activated:Connect(function()
                if offer.equipped then
                    return
                end
                self:_act("hoverboard.shop.equip", offer.id)
            end)
        elseif enabled then
            button.Activated:Connect(function()
                self:_act("hoverboard.shop.buy", offer.id)
            end)
        end
        table.insert(self.rows, card)
    end
end

function HoverboardShopPanel:_refresh()
    local result = self:_callBus("hoverboard.shop.catalog", {})
    if not result or result.ok ~= true then
        self:_setStatus(REASONS[result and result.reason] or "Could not load the shop.", true)
        return
    end
    self:_setStatus("Take a free board. Fancy ones cost gems or Robux.", false)
    self:_render(result)
end

function HoverboardShopPanel:_act(command, skinId)
    local result = self:_callBus(command, { skinId = skinId })
    if not result or result.ok ~= true then
        self:_setStatus(REASONS[result and result.reason] or "That did not work.", true)
        return
    end
    if result.pending_robux == true then
        self:_setStatus("Roblox will ask you to pay.", false)
        self:_render(result)
        return
    end
    local verb = command == "hoverboard.shop.buy" and "It's yours." or "Equipped."
    self:_setStatus(verb, false)
    self:_render(result)
end

return HoverboardShopPanel
