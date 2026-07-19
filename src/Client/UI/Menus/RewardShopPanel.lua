--[[
    RewardShopPanel — the unified Pet Shop.

    The default tab is the real Roblox game-pass catalog. Developer products
    appear automatically only after they have positive Marketplace IDs; the
    rating-safe earnable-currency RewardShop remains available on its own tab.
    All Robux prompts travel through MonetizationService via Signals, never
    directly from a card.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CloseButton = require(script.Parent.Parent.Components.CloseButton)
local MonetizationCatalog = require(ReplicatedStorage.Shared.Game.MonetizationCatalog)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local monetization = require(ReplicatedStorage.Configs:WaitForChild("monetization"))

local REMOTE_NAME = "GameAPICommand"

local COLORS = {
    panel = Color3.fromRGB(22, 24, 32),
    panelTop = Color3.fromRGB(39, 43, 58),
    header = Color3.fromRGB(34, 126, 171),
    headerDeep = Color3.fromRGB(24, 78, 128),
    tab = Color3.fromRGB(49, 54, 70),
    tabSelected = Color3.fromRGB(237, 167, 55),
    card = Color3.fromRGB(42, 45, 58),
    cardTop = Color3.fromRGB(57, 61, 78),
    cardStroke = Color3.fromRGB(91, 98, 121),
    buy = Color3.fromRGB(39, 177, 102),
    buyHover = Color3.fromRGB(32, 151, 86),
    disabled = Color3.fromRGB(77, 82, 98),
    owned = Color3.fromRGB(111, 82, 166),
    robux = Color3.fromRGB(83, 204, 132),
    reward = Color3.fromRGB(255, 214, 88),
    text = Color3.fromRGB(255, 255, 255),
    subtext = Color3.fromRGB(204, 210, 224),
    error = Color3.fromRGB(255, 125, 125),
    success = Color3.fromRGB(111, 231, 159),
}

local RewardShopPanel = {}
RewardShopPanel.__index = RewardShopPanel

local function round(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
end

local function constrain(label, maxSize, minSize)
    local constraint = Instance.new("UITextSizeConstraint")
    constraint.MaxTextSize = maxSize
    constraint.MinTextSize = minSize or 8
    constraint.Parent = label
end

local function summarize(bundle)
    local parts = {}
    for currency, amount in pairs((bundle and bundle.currencies) or {}) do
        parts[#parts + 1] = tostring(amount) .. " " .. tostring(currency)
    end
    for _, item in ipairs((bundle and bundle.items) or {}) do
        parts[#parts + 1] = tostring(item.qty or 1) .. "x " .. tostring(item.id)
    end
    for _, pet in ipairs((bundle and bundle.pets) or {}) do
        parts[#parts + 1] = "Pet: " .. tostring(pet.id)
    end
    for _, effect in ipairs((bundle and bundle.effects) or {}) do
        parts[#parts + 1] = tostring(effect.id)
    end
    for slot, amount in pairs((bundle and bundle.slots) or {}) do
        parts[#parts + 1] = "+" .. tostring(amount) .. " " .. tostring(slot)
    end
    if (bundle and bundle.experience or 0) > 0 then
        parts[#parts + 1] = tostring(bundle.experience) .. " XP"
    end
    return table.concat(parts, "\n")
end

local function costText(cost)
    local parts = {}
    for currency, amount in pairs((cost and cost.currencies) or {}) do
        parts[#parts + 1] = tostring(amount) .. " " .. tostring(currency)
    end
    return table.concat(parts, " + ")
end

function RewardShopPanel.new()
    local self = setmetatable({}, RewardShopPanel)
    self.isVisible = false
    self.frame = nil
    self.gridFrame = nil
    self.gridLayout = nil
    self.statusLabel = nil
    self.tabs = {}
    self.selectedTab = "passes"
    self.ownedPasses = {}
    self.livePasses = MonetizationCatalog.livePasses(monetization)
    self.liveProducts = MonetizationCatalog.liveProducts(monetization)
    self.connections = {
        Signals.OwnedPasses.OnClientEvent:Connect(function(snapshot)
            self.ownedPasses = MonetizationCatalog.ownedSet(snapshot)
            if self.isVisible and self.selectedTab == "passes" then
                self:_refresh()
            end
        end),
        Signals.PurchaseSuccess.OnClientEvent:Connect(function(data)
            if type(data) ~= "table" then
                return
            end
            if data.type == "gamepass" and type(data.id) == "string" then
                self.ownedPasses[data.id] = true
                Signals.GetOwnedPasses:FireServer()
            end
            self:_setStatus("Purchase complete — thank you!", false)
            if self.isVisible then
                self:_refresh()
            end
        end),
        Signals.PurchaseError.OnClientEvent:Connect(function(data)
            self:_setStatus(
                (type(data) == "table" and data.message) or "Purchase could not be started.",
                true
            )
            if self.isVisible then
                self:_refresh()
            end
        end),
    }
    return self
end

function RewardShopPanel:_callBus(name, args)
    local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
    if not remote then
        return nil
    end
    local ok, envelope = pcall(function()
        return remote:InvokeServer(name, args or {})
    end)
    if not ok or type(envelope) ~= "table" then
        return nil
    end
    return envelope.result
end

function RewardShopPanel:Show(parent)
    if self.isVisible then
        return
    end
    self:_createUI(parent)
    self.isVisible = true
    Signals.GetOwnedPasses:FireServer()
    self:_refresh()
end

function RewardShopPanel:Hide()
    if not self.isVisible then
        return
    end
    if self.frame then
        self.frame:Destroy()
    end
    self.frame = nil
    self.gridFrame = nil
    self.gridLayout = nil
    self.statusLabel = nil
    self.tabs = {}
    self.isVisible = false
end

function RewardShopPanel:IsVisible()
    return self.isVisible
end

function RewardShopPanel:GetFrame()
    return self.frame
end

function RewardShopPanel:Destroy()
    self:Hide()
    for _, connection in ipairs(self.connections) do
        connection:Disconnect()
    end
    self.connections = {}
end

function RewardShopPanel:_createUI(parent)
    local frame = Instance.new("Frame")
    frame.Name = "RewardShopPanel"
    frame.Size = UDim2.new(0.9, 0, 0.88, 0)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = COLORS.panel
    frame.BorderSizePixel = 0
    frame.ZIndex = 100
    frame.Parent = parent
    self.frame = frame
    round(frame, 20)

    local sizeLimit = Instance.new("UISizeConstraint")
    sizeLimit.MaxSize = Vector2.new(980, 720)
    sizeLimit.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.tabSelected
    stroke.Thickness = 3
    stroke.Transparency = 0.18
    stroke.Parent = frame

    local panelGradient = Instance.new("UIGradient")
    panelGradient.Color = ColorSequence.new(COLORS.panelTop, COLORS.panel)
    panelGradient.Rotation = 70
    panelGradient.Parent = frame

    self:_createHeader()
    self:_createTabs()
    self:_createGrid()
    self:_animateEntrance()
end

function RewardShopPanel:_createHeader()
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 74)
    header.BackgroundColor3 = COLORS.header
    header.BorderSizePixel = 0
    header.ZIndex = 101
    header.Parent = self.frame
    round(header, 20)

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new(COLORS.header, COLORS.headerDeep)
    gradient.Rotation = 90
    gradient.Parent = header

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -120, 0, 38)
    title.Position = UDim2.new(0, 22, 0, 7)
    title.BackgroundTransparency = 1
    title.Text = "PET SHOP"
    title.TextColor3 = COLORS.text
    title.TextScaled = true
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 102
    title.Parent = header
    constrain(title, 30, 12)

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -120, 0, 21)
    subtitle.Position = UDim2.new(0, 24, 0, 43)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Permanent perks and fair, deterministic rewards"
    subtitle.TextColor3 = COLORS.subtext
    subtitle.TextScaled = true
    subtitle.Font = Enum.Font.GothamMedium
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.ZIndex = 102
    subtitle.Parent = header
    constrain(subtitle, 14, 8)

    CloseButton.attach(header, {
        zindex = 103,
        onClick = function()
            self:Hide()
        end,
    })
end

function RewardShopPanel:_createTabs()
    local bar = Instance.new("Frame")
    bar.Name = "Tabs"
    bar.Size = UDim2.new(1, -24, 0, 46)
    bar.Position = UDim2.new(0, 12, 0, 82)
    bar.BackgroundTransparency = 1
    bar.ZIndex = 102
    bar.Parent = self.frame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.Parent = bar

    local definitions = {
        { id = "passes", text = "GAME PASSES" },
    }
    if #self.liveProducts > 0 then
        definitions[#definitions + 1] = { id = "products", text = "BOOSTS" }
    end
    definitions[#definitions + 1] = { id = "rewards", text = "EARNED OFFERS" }

    for order, definition in ipairs(definitions) do
        local button = Instance.new("TextButton")
        button.Name = "Tab_" .. definition.id
        button.Size = UDim2.new(0, 170, 0, 40)
        button.LayoutOrder = order
        button.BackgroundColor3 = COLORS.tab
        button.BorderSizePixel = 0
        button.Text = definition.text
        button.TextColor3 = COLORS.text
        button.TextScaled = true
        button.Font = Enum.Font.GothamBold
        button.ZIndex = 103
        button.Parent = bar
        round(button, 10)
        constrain(button, 15, 8)
        button.Activated:Connect(function()
            self:_selectTab(definition.id)
        end)
        self.tabs[definition.id] = button
    end

    self:_updateTabStyle()
end

function RewardShopPanel:_createGrid()
    local grid = Instance.new("ScrollingFrame")
    grid.Name = "ShopGrid"
    grid.Size = UDim2.new(1, -24, 1, -174)
    grid.Position = UDim2.new(0, 12, 0, 134)
    grid.BackgroundTransparency = 1
    grid.BorderSizePixel = 0
    grid.ScrollBarThickness = 6
    grid.ScrollBarImageColor3 = COLORS.tabSelected
    grid.CanvasSize = UDim2.new()
    grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
    grid.ZIndex = 101
    grid.Parent = self.frame
    self.gridFrame = grid

    local layout = Instance.new("UIGridLayout")
    layout.CellSize = UDim2.new(0, 240, 0, 306)
    layout.CellPadding = UDim2.new(0, 14, 0, 14)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = grid
    self.gridLayout = layout

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 12)
    padding.Parent = grid

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, -32, 0, 28)
    status.Position = UDim2.new(0, 16, 1, -34)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextColor3 = COLORS.success
    status.TextScaled = true
    status.Font = Enum.Font.GothamBold
    status.ZIndex = 104
    status.Parent = self.frame
    constrain(status, 14, 8)
    self.statusLabel = status
end

function RewardShopPanel:_setStatus(message, isError)
    if not self.statusLabel then
        return
    end
    self.statusLabel.Text = tostring(message or "")
    self.statusLabel.TextColor3 = isError and COLORS.error or COLORS.success
end

function RewardShopPanel:_updateTabStyle()
    for id, button in pairs(self.tabs) do
        local selected = id == self.selectedTab
        button.BackgroundColor3 = selected and COLORS.tabSelected or COLORS.tab
        button.TextColor3 = selected and Color3.fromRGB(35, 31, 24) or COLORS.text
    end
end

function RewardShopPanel:_selectTab(tab)
    self.selectedTab = tab
    self:_setStatus("", false)
    self:_updateTabStyle()
    self:_refresh()
end

function RewardShopPanel:_clearGrid()
    if not self.gridFrame then
        return
    end
    for _, child in ipairs(self.gridFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    self.gridFrame.CanvasPosition = Vector2.zero
end

function RewardShopPanel:_refresh()
    if not self.gridFrame then
        return
    end
    self:_clearGrid()
    if self.selectedTab == "passes" then
        for _, entry in ipairs(self.livePasses) do
            self:_createMarketplaceCard(entry)
        end
    elseif self.selectedTab == "products" then
        for _, entry in ipairs(self.liveProducts) do
            self:_createMarketplaceCard(entry)
        end
    else
        self:_createRewardCards()
    end
end

function RewardShopPanel:_createMarketplaceCard(entry)
    local item = entry.config
    local owned = entry.kind == "gamepass" and self.ownedPasses[entry.id] == true

    local card = Instance.new("Frame")
    card.Name = "Marketplace_" .. entry.id
    card.BackgroundColor3 = COLORS.card
    card.BorderSizePixel = 0
    card.LayoutOrder = entry.order
    card.ZIndex = 102
    card.Parent = self.gridFrame
    round(card, 14)

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new(COLORS.cardTop, COLORS.card)
    gradient.Rotation = 45
    gradient.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = owned and COLORS.owned or COLORS.cardStroke
    stroke.Thickness = owned and 3 or 1
    stroke.Transparency = owned and 0.1 or 0.3
    stroke.Parent = card

    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 92, 0, 23)
    badge.Position = UDim2.new(0, 8, 0, 8)
    badge.BackgroundColor3 = owned and COLORS.owned or COLORS.header
    badge.BorderSizePixel = 0
    badge.Text = owned and "OWNED" or (entry.kind == "gamepass" and "PERMANENT" or "CONSUMABLE")
    badge.TextColor3 = COLORS.text
    badge.TextScaled = true
    badge.Font = Enum.Font.GothamBold
    badge.ZIndex = 105
    badge.Parent = card
    round(badge, 7)
    constrain(badge, 12, 7)

    local iconBackground = Instance.new("Frame")
    iconBackground.Size = UDim2.new(0, 94, 0, 94)
    iconBackground.Position = UDim2.new(0.5, -47, 0, 31)
    iconBackground.BackgroundColor3 = COLORS.headerDeep
    iconBackground.BorderSizePixel = 0
    iconBackground.ZIndex = 103
    iconBackground.Parent = card
    round(iconBackground, 18)

    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1, -8, 1, -8)
    icon.Position = UDim2.new(0, 4, 0, 4)
    icon.BackgroundTransparency = 1
    icon.Image = item.icon or ""
    icon.ScaleType = Enum.ScaleType.Fit
    icon.ZIndex = 104
    icon.Parent = iconBackground
    round(icon, 14)

    if icon.Image == "" or icon.Image == "rbxassetid://0" then
        icon.Visible = false
        local fallback = Instance.new("TextLabel")
        fallback.Size = UDim2.fromScale(1, 1)
        fallback.BackgroundTransparency = 1
        fallback.Text = entry.kind == "gamepass" and "🎫" or "⚡"
        fallback.TextScaled = true
        fallback.Font = Enum.Font.GothamBold
        fallback.ZIndex = 104
        fallback.Parent = iconBackground
    end

    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, -16, 0, 29)
    name.Position = UDim2.new(0, 8, 0, 130)
    name.BackgroundTransparency = 1
    name.Text = item.name or entry.id
    name.TextColor3 = COLORS.text
    name.TextScaled = true
    name.Font = Enum.Font.GothamBold
    name.ZIndex = 103
    name.Parent = card
    constrain(name, 17, 9)

    local description = Instance.new("TextLabel")
    description.Size = UDim2.new(1, -20, 0, 66)
    description.Position = UDim2.new(0, 10, 0, 162)
    description.BackgroundTransparency = 1
    description.Text = item.description or ""
    description.TextColor3 = COLORS.subtext
    description.TextWrapped = true
    description.TextScaled = true
    description.Font = Enum.Font.GothamMedium
    description.ZIndex = 103
    description.Parent = card
    constrain(description, 14, 8)

    local price = Instance.new("TextLabel")
    price.Size = UDim2.new(1, -16, 0, 24)
    price.Position = UDim2.new(0, 8, 1, -70)
    price.BackgroundTransparency = 1
    price.Text = "R$ " .. tostring(item.price_robux or "?")
    price.TextColor3 = COLORS.robux
    price.TextScaled = true
    price.Font = Enum.Font.GothamBold
    price.ZIndex = 103
    price.Parent = card
    constrain(price, 16, 9)

    local buy = Instance.new("TextButton")
    buy.Name = "BuyButton"
    buy.Size = UDim2.new(1, -16, 0, 40)
    buy.Position = UDim2.new(0, 8, 1, -44)
    buy.BackgroundColor3 = owned and COLORS.owned or COLORS.buy
    buy.BorderSizePixel = 0
    buy.Text = owned and "Owned ✓" or "Buy"
    buy.TextColor3 = COLORS.text
    buy.TextScaled = true
    buy.Font = Enum.Font.GothamBold
    buy.AutoButtonColor = not owned
    buy.Active = not owned
    buy.ZIndex = 104
    buy.Parent = card
    round(buy, 10)
    constrain(buy, 16, 9)

    if not owned then
        buy.Activated:Connect(function()
            buy.Text = "Opening…"
            buy.Active = false
            self:_setStatus("Opening Roblox purchase confirmation…", false)
            Signals.InitiatePurchase:FireServer({
                productId = entry.id,
                productType = entry.kind,
            })
        end)
    end
end

function RewardShopPanel:_createRewardCards()
    local result = self:_callBus("shop.list", {})
    local offers = result and result.offers
    if type(offers) ~= "table" then
        self:_setStatus("Earned offers are temporarily unavailable.", true)
        return
    end
    table.sort(offers, function(a, b)
        return (a.name or a.id) < (b.name or b.id)
    end)
    for order, offer in ipairs(offers) do
        self:_createRewardCard(offer, order)
    end
end

function RewardShopPanel:_createRewardCard(offer, order)
    local card = Instance.new("Frame")
    card.Name = "Offer_" .. tostring(offer.id)
    card.BackgroundColor3 = COLORS.card
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.ZIndex = 102
    card.Parent = self.gridFrame
    round(card, 14)

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.cardStroke
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = card

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(1, -16, 0, 76)
    icon.Position = UDim2.new(0, 8, 0, 25)
    icon.BackgroundTransparency = 1
    icon.Text = "🎁"
    icon.TextScaled = true
    icon.Font = Enum.Font.GothamBold
    icon.ZIndex = 103
    icon.Parent = card

    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, -16, 0, 30)
    name.Position = UDim2.new(0, 8, 0, 104)
    name.BackgroundTransparency = 1
    name.Text = offer.name or offer.id
    name.TextColor3 = COLORS.text
    name.TextScaled = true
    name.Font = Enum.Font.GothamBold
    name.ZIndex = 103
    name.Parent = card
    constrain(name, 18, 9)

    local reward = Instance.new("TextLabel")
    reward.Size = UDim2.new(1, -20, 0, 70)
    reward.Position = UDim2.new(0, 10, 0, 139)
    reward.BackgroundTransparency = 1
    reward.Text = summarize(offer.reward)
    reward.TextColor3 = COLORS.reward
    reward.TextWrapped = true
    reward.TextScaled = true
    reward.Font = Enum.Font.GothamMedium
    reward.ZIndex = 103
    reward.Parent = card
    constrain(reward, 15, 8)

    local cost = Instance.new("TextLabel")
    cost.Size = UDim2.new(1, -16, 0, 24)
    cost.Position = UDim2.new(0, 8, 1, -70)
    cost.BackgroundTransparency = 1
    cost.Text = costText(offer.cost)
    cost.TextColor3 = COLORS.subtext
    cost.TextScaled = true
    cost.Font = Enum.Font.GothamBold
    cost.ZIndex = 103
    cost.Parent = card
    constrain(cost, 14, 8)

    local buy = Instance.new("TextButton")
    buy.Name = "BuyButton"
    buy.Size = UDim2.new(1, -16, 0, 40)
    buy.Position = UDim2.new(0, 8, 1, -44)
    buy.BorderSizePixel = 0
    buy.TextColor3 = COLORS.text
    buy.TextScaled = true
    buy.Font = Enum.Font.GothamBold
    buy.ZIndex = 103
    buy.Parent = card
    round(buy, 10)
    constrain(buy, 16, 9)

    local soldOut = offer.reason == "out_of_stock"
    if offer.purchasable then
        buy.Text = "Buy"
        buy.BackgroundColor3 = COLORS.buy
        buy.Activated:Connect(function()
            buy.Text = "…"
            buy.Active = false
            self:_callBus("shop.purchase", { offerId = offer.id })
            self:_refresh()
        end)
    elseif soldOut then
        buy.Text = (offer.limit == 1) and "Owned ✓" or "Sold out"
        buy.BackgroundColor3 = COLORS.owned
        buy.AutoButtonColor = false
        buy.Active = false
    else
        buy.Text = "Can't afford"
        buy.BackgroundColor3 = COLORS.disabled
        buy.AutoButtonColor = false
        buy.Active = false
    end
end

function RewardShopPanel:_animateEntrance()
    if not self.frame then
        return
    end
    local finalSize = self.frame.Size
    self.frame.Size = UDim2.new(0.78, 0, 0.76, 0)
    TweenService:Create(
        self.frame,
        TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = finalSize }
    ):Play()
end

return RewardShopPanel
