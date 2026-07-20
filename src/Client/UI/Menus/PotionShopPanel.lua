--[[
    PotionShopPanel — the authored potion tents' buy/sell surface.

    Uses the shared game window language (PanelChrome shell, area-themed pill rings,
    standard close control) and renders only server-provided catalog/state. Every action
    returns through PotionShopService; the client never mutates gems or inventory.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PanelChrome = require(script.Parent.Parent.Components.PanelChrome)
local PetBadge = require(script.Parent.Parent.PetBadge)
local PowerIcons = require(ReplicatedStorage.Configs:WaitForChild("power_icons"))

local REMOTE_NAME = "GameAPICommand"
local COLORS = {
    row = Color3.fromRGB(38, 40, 50),
    rowAlt = Color3.fromRGB(44, 42, 54),
    text = Color3.fromRGB(255, 255, 255),
    subtext = Color3.fromRGB(202, 207, 218),
    dim = Color3.fromRGB(150, 157, 171),
    gem = Color3.fromRGB(130, 220, 255),
    buy = Color3.fromRGB(42, 176, 102),
    sell = Color3.fromRGB(133, 86, 190),
    disabled = Color3.fromRGB(72, 74, 84),
    error = Color3.fromRGB(242, 105, 105),
    success = Color3.fromRGB(116, 235, 155),
}

local REASONS = {
    shop_out_of_range = "Move closer to the potion tent.",
    insufficient_funds = "You do not have enough gems.",
    none_to_sell = "You do not own that potion.",
    not_sold = "That potion is not sold here.",
    not_bought = "That potion cannot be sold here.",
    invalid_quantity = "Choose 1, 10, or 100.",
    insufficient_inventory = "You do not own enough of that potion.",
    no_price = "That potion is not available to buy.",
    no_value = "That potion has no resale value.",
    debit_failed = "The gem payment did not complete.",
    grant_failed = "The potion could not be delivered; your gems were refunded.",
    rollback_failed = "The transaction needs attention. No further action was taken.",
    credit_failed_items_restored = "The sale failed; your potion was restored.",
    remove_failed = "The potion could not be removed from inventory.",
    service_unavailable = "The potion shop is temporarily unavailable.",
}

local PotionShopPanel = {}
PotionShopPanel.__index = PotionShopPanel

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 12)
    corner.Parent = parent
end

local function pillify(button)
    addCorner(button, 999)
    PanelChrome.pillBorder(button, PanelChrome.areaPill(), (button.ZIndex or 1) + 3, 0, 0.18)
    return button
end

local function textLabel(parent, options)
    local label = Instance.new("TextLabel")
    label.Name = options.name or "Label"
    label.Size = options.size
    label.Position = options.position or UDim2.new()
    label.AnchorPoint = options.anchor or Vector2.zero
    label.BackgroundTransparency = 1
    label.Text = options.text or ""
    label.TextColor3 = options.color or COLORS.text
    label.TextSize = options.textSize or 16
    label.Font = options.font or Enum.Font.Gotham
    label.TextXAlignment = options.xAlign or Enum.TextXAlignment.Left
    label.TextYAlignment = options.yAlign or Enum.TextYAlignment.Center
    label.TextWrapped = options.wrapped == true
    label.ZIndex = options.zindex or 103
    label.Parent = parent
    return label
end

local function actionButton(parent, name, text, position, color, enabled, size)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = size or UDim2.new(0, 86, 0, 36)
    button.Position = position
    button.AnchorPoint = Vector2.zero
    button.BackgroundColor3 = enabled and color or COLORS.disabled
    button.BorderSizePixel = 0
    button.AutoButtonColor = enabled
    button.Active = enabled
    button.Text = text
    button.TextColor3 = enabled and COLORS.text or COLORS.dim
    button.TextSize = 12
    button.Font = Enum.Font.GothamBold
    button.ZIndex = 106
    button.Parent = parent
    pillify(button)
    return button
end

function PotionShopPanel.new()
    return setmetatable({
        isVisible = false,
        frame = nil,
        list = nil,
        balanceLabel = nil,
        priceLabel = nil,
        statusLabel = nil,
        rows = {},
        busy = {},
        context = nil,
    }, PotionShopPanel)
end

function PotionShopPanel:_callBus(name, args)
    local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
        or ReplicatedStorage:WaitForChild(REMOTE_NAME, 5)
    if not remote then
        return nil
    end
    local ok, envelope = pcall(function()
        return remote:InvokeServer(name, args or {})
    end)
    if not ok or type(envelope) ~= "table" then
        return nil
    end
    return envelope.result or envelope
end

function PotionShopPanel:SetShopContext(context)
    self.context = context
end

function PotionShopPanel:Show(parent)
    if self.isVisible then
        self:_refresh()
        return
    end
    self:_createUI(parent)
    self.isVisible = true
    self:_refresh()
end

function PotionShopPanel:Hide()
    if self.frame then
        self.frame:Destroy()
    end
    self.frame = nil
    self.list = nil
    self.balanceLabel = nil
    self.priceLabel = nil
    self.statusLabel = nil
    self.rows = {}
    self.busy = {}
    self.isVisible = false
end

function PotionShopPanel:IsVisible()
    return self.isVisible
end

function PotionShopPanel:GetFrame()
    return self.frame
end

function PotionShopPanel:Destroy()
    self:Hide()
end

function PotionShopPanel:_createUI(parent)
    local shell = PanelChrome.build(parent, {
        name = "PotionShopPanel",
        title = "🧪 Potion Shop",
        size = UDim2.new(0.68, 0, 0.78, 0),
        onClose = function()
            self:Hide()
        end,
    })
    self.frame = shell.frame

    self.balanceLabel = textLabel(shell.header, {
        name = "Balance",
        size = UDim2.new(0, 180, 0.7, 0),
        position = UDim2.new(1, -84, 0.5, 0),
        anchor = Vector2.new(1, 0.5),
        text = "💎 —",
        color = COLORS.gem,
        textSize = 22,
        font = Enum.Font.GothamBold,
        xAlign = Enum.TextXAlignment.Right,
        zindex = 103,
    })

    local toolbar = Instance.new("Frame")
    toolbar.Name = "ShopSummary"
    toolbar.Size = UDim2.new(1, -34, 0.12, 0)
    toolbar.Position = UDim2.new(0.5, 0, 0.125, 0)
    toolbar.AnchorPoint = Vector2.new(0.5, 0)
    toolbar.BackgroundColor3 = Color3.fromRGB(29, 31, 39)
    toolbar.BorderSizePixel = 0
    toolbar.ZIndex = 102
    toolbar.Parent = self.frame
    addCorner(toolbar, 12)
    PanelChrome.pillBorder(toolbar, shell.areaKey, 104, 0, 0.08)

    self.priceLabel = textLabel(toolbar, {
        name = "Prices",
        size = UDim2.new(0.44, -16, 1, 0),
        position = UDim2.new(0, 18, 0, 0),
        text = "Buy  💎 5     •     Sell  💎 2",
        color = COLORS.text,
        textSize = 18,
        font = Enum.Font.GothamBold,
    })
    self.statusLabel = textLabel(toolbar, {
        name = "Status",
        size = UDim2.new(0.54, -20, 1, 0),
        position = UDim2.new(0.46, 0, 0, 0),
        text = "Choose a potion.",
        color = COLORS.subtext,
        textSize = 15,
        xAlign = Enum.TextXAlignment.Right,
    })

    self.list = PanelChrome.scrollPane(self.frame, {
        name = "PotionList",
        size = UDim2.new(1, 0, 0.72, 0),
        position = UDim2.new(0.5, 0, 0.26, 0),
        padding = 10,
        inset = 18,
    })
end

function PotionShopPanel:_setStatus(text, isError)
    if not self.statusLabel then
        return
    end
    self.statusLabel.Text = text
    self.statusLabel.TextColor3 = isError and COLORS.error or COLORS.success
end

function PotionShopPanel:_clearRows()
    for _, row in ipairs(self.rows) do
        row:Destroy()
    end
    self.rows = {}
end

function PotionShopPanel:_discFor(offer)
    local badge = offer.badge
    if badge and PowerIcons.discFor then
        return PowerIcons.discFor(badge.element, badge.symbol)
    end
    local potionBadge = PetBadge.forPotion(offer.meter)
    if potionBadge and PowerIcons.discFor then
        return PowerIcons.discFor(potionBadge.element, potionBadge.symbol)
    end
    return nil
end

function PotionShopPanel:_renderOffer(offer, index)
    local row = PanelChrome.entryRow(self.list, {
        name = offer.id .. "Row",
        height = 142,
        layoutOrder = index,
        bg = index % 2 == 0 and COLORS.rowAlt or COLORS.row,
        key = PanelChrome.areaPill(),
        bleed = 1,
        sliceScale = 0.08,
        zindex = 102,
    })
    self.rows[#self.rows + 1] = row

    local iconHolder = Instance.new("Frame")
    iconHolder.Name = "Icon"
    iconHolder.Size = UDim2.new(0, 82, 0, 82)
    iconHolder.Position = UDim2.new(0, 18, 0.5, 0)
    iconHolder.AnchorPoint = Vector2.new(0, 0.5)
    iconHolder.BackgroundColor3 = Color3.fromRGB(25, 26, 33)
    iconHolder.BorderSizePixel = 0
    iconHolder.ZIndex = 103
    iconHolder.Parent = row
    addCorner(iconHolder, 18)

    local disc = self:_discFor(offer)
    if disc then
        local image = Instance.new("ImageLabel")
        image.Name = "PotionDisc"
        image.Size = UDim2.new(1, -8, 1, -8)
        image.Position = UDim2.fromScale(0.5, 0.5)
        image.AnchorPoint = Vector2.new(0.5, 0.5)
        image.BackgroundTransparency = 1
        image.Image = disc
        image.ScaleType = Enum.ScaleType.Fit
        image.ZIndex = 104
        image.Parent = iconHolder
    else
        textLabel(iconHolder, {
            name = "FallbackIcon",
            size = UDim2.fromScale(1, 1),
            text = offer.icon or "🧪",
            textSize = 38,
            xAlign = Enum.TextXAlignment.Center,
            zindex = 104,
        })
    end

    textLabel(row, {
        name = "PotionName",
        size = UDim2.new(1, -490, 0, 28),
        position = UDim2.new(0, 116, 0, 15),
        text = offer.name,
        textSize = 20,
        font = Enum.Font.GothamBold,
    })
    textLabel(row, {
        name = "PotionType",
        size = UDim2.new(1, -490, 0, 20),
        position = UDim2.new(0, 116, 0, 43),
        text = offer.type or "Potion",
        color = COLORS.gem,
        textSize = 13,
        font = Enum.Font.GothamBold,
    })
    textLabel(row, {
        name = "Description",
        size = UDim2.new(1, -490, 0, 54),
        position = UDim2.new(0, 116, 0, 65),
        text = offer.summary or "",
        color = COLORS.subtext,
        textSize = 13,
        wrapped = true,
        yAlign = Enum.TextYAlignment.Top,
    })
    textLabel(row, {
        name = "Owned",
        size = UDim2.new(0, 340, 0, 24),
        position = UDim2.new(1, -358, 0, 10),
        text = "Owned: " .. tostring(offer.owned or 0),
        color = COLORS.text,
        textSize = 15,
        font = Enum.Font.GothamBold,
        xAlign = Enum.TextXAlignment.Center,
    })

    local controls = Instance.new("Frame")
    controls.Name = "QuantityControls"
    controls.Size = UDim2.new(0, 340, 0, 82)
    controls.Position = UDim2.new(1, -358, 0, 43)
    controls.BackgroundTransparency = 1
    controls.ZIndex = 103
    controls.Parent = row

    textLabel(controls, {
        name = "BuyLabel",
        size = UDim2.new(0, 42, 0, 36),
        text = "BUY",
        color = COLORS.success,
        textSize = 12,
        font = Enum.Font.GothamBold,
        xAlign = Enum.TextXAlignment.Center,
    })
    textLabel(controls, {
        name = "SellLabel",
        size = UDim2.new(0, 42, 0, 36),
        position = UDim2.new(0, 0, 0, 44),
        text = "SELL",
        color = Color3.fromRGB(205, 166, 255),
        textSize = 12,
        font = Enum.Font.GothamBold,
        xAlign = Enum.TextXAlignment.Center,
    })

    local owned = tonumber(offer.owned) or 0
    local balance = tonumber(self.balance) or 0
    for buttonIndex, quantity in ipairs({ 1, 10, 100 }) do
        local x = 48 + (buttonIndex - 1) * 96
        local buyTotal = (tonumber(offer.buyPrice) or 0) * quantity
        local sellTotal = (tonumber(offer.sellPrice) or 0) * quantity
        local buyEnabled = balance >= buyTotal and buyTotal > 0
        local sellEnabled = owned >= quantity and sellTotal > 0
        local buy = actionButton(
            controls,
            "Buy" .. quantity,
            string.format("%d · 💎%d", quantity, buyTotal),
            UDim2.new(0, x, 0, 0),
            COLORS.buy,
            buyEnabled
        )
        local sell = actionButton(
            controls,
            "Sell" .. quantity,
            string.format("%d · 💎%d", quantity, sellTotal),
            UDim2.new(0, x, 0, 44),
            COLORS.sell,
            sellEnabled
        )
        if buyEnabled then
            buy.Activated:Connect(function()
                self:_transact("potion.shop.buy", offer, quantity)
            end)
        end
        if sellEnabled then
            sell.Activated:Connect(function()
                self:_transact("potion.shop.sell", offer, quantity)
            end)
        end
    end
end

function PotionShopPanel:_render(catalog)
    self:_clearRows()
    self.balance = tonumber(catalog.balance) or 0
    if self.balanceLabel then
        self.balanceLabel.Text = "💎 " .. tostring(catalog.balance or 0)
    end
    if self.priceLabel then
        self.priceLabel.Text = string.format(
            "Buy  💎 %d     •     Sell  💎 %d",
            tonumber(catalog.buyPrice) or 0,
            tonumber(catalog.sellPrice) or 0
        )
    end
    for index, offer in ipairs(catalog.offers or {}) do
        self:_renderOffer(offer, index)
    end
    if #(catalog.offers or {}) == 0 then
        self:_setStatus("The shop has no stock right now.", true)
    end
end

function PotionShopPanel:_refresh()
    task.spawn(function()
        local result = self:_callBus("potion.shop.catalog", {})
        if not self.isVisible then
            return
        end
        if not (result and result.ok) then
            local reason = result and result.reason
            self:_setStatus(REASONS[reason] or "Could not load the potion shop.", true)
            return
        end
        self:_render(result)
        self:_setStatus("Choose a potion.", false)
    end)
end

function PotionShopPanel:_transact(command, offer, quantity)
    if self.busy[offer.id] then
        return
    end
    self.busy[offer.id] = true
    self:_setStatus(command:find("%.buy$") and "Buying…" or "Selling…", false)
    task.spawn(function()
        local result = self:_callBus(command, { potionId = offer.id, quantity = quantity })
        self.busy[offer.id] = nil
        if not self.isVisible then
            return
        end
        if result and result.ok then
            local verb = command:find("%.buy$") and "Bought " or "Sold "
            self:_setStatus(string.format("%s%d %s.", verb, quantity, tostring(offer.name)), false)
            self:_refresh()
            return
        end
        local reason = result and result.reason
        self:_setStatus(REASONS[reason] or ("Transaction failed: " .. tostring(reason)), true)
    end)
end

return PotionShopPanel
