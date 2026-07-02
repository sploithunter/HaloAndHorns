--[[
    RewardShopPanel — the client UI for the reward spine's Shop gate (Phase 9).

    Mirrors the ShopPanel/QuestPanel/DailyPanel contract (.new / Show / Hide /
    GetFrame / IsVisible / Destroy) so MenuManager opens it from the "Shop"
    side-menu button. Renders offer cards (name, reward, cost, -% tag, Buy /
    Owned / Can't afford). Live data via the GameAPICommand bus bridge:
    `shop.list` (offers + affordability + limits) and `shop.purchase`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CloseButton = require(script.Parent.Parent.Components.CloseButton)

local REMOTE_NAME = "GameAPICommand"

local COLORS = {
    panel = Color3.fromRGB(20, 20, 25),
    panelGradientTop = Color3.fromRGB(30, 30, 40),
    header = Color3.fromRGB(56, 161, 178),
    headerGradient = Color3.fromRGB(43, 134, 148),
    card = Color3.fromRGB(40, 42, 52),
    cardStroke = Color3.fromRGB(70, 74, 88),
    buy = Color3.fromRGB(46, 204, 113),
    buyHover = Color3.fromRGB(39, 174, 96),
    disabled = Color3.fromRGB(70, 74, 88),
    owned = Color3.fromRGB(90, 96, 110),
    sale = Color3.fromRGB(243, 156, 18),
    close = Color3.fromRGB(231, 76, 60),
    text = Color3.fromRGB(255, 255, 255),
    subtext = Color3.fromRGB(200, 205, 215),
    gold = Color3.fromRGB(255, 215, 0),
}

local RewardShopPanel = {}
RewardShopPanel.__index = RewardShopPanel

function RewardShopPanel.new()
    local self = setmetatable({}, RewardShopPanel)
    self.isVisible = false
    self.frame = nil
    self.gridFrame = nil
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
    self:_refresh()
end

function RewardShopPanel:Hide()
    if not self.isVisible then
        return
    end
    if self.frame then
        self.frame:Destroy()
        self.frame = nil
    end
    self.gridFrame = nil
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
end

function RewardShopPanel:_createUI(parent)
    local frame = Instance.new("Frame")
    frame.Name = "RewardShopPanel"
    frame.Size = UDim2.new(0.72, 0, 0.82, 0)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = COLORS.panel
    frame.BorderSizePixel = 0
    frame.ZIndex = 100
    frame.Parent = parent
    self.frame = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.header
    stroke.Thickness = 3
    stroke.Transparency = 0.3
    stroke.Parent = frame

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.panelGradientTop),
        ColorSequenceKeypoint.new(1, COLORS.panel),
    })
    gradient.Rotation = 45
    gradient.Parent = frame

    self:_createHeader()

    local grid = Instance.new("ScrollingFrame")
    grid.Name = "ShopGrid"
    grid.Size = UDim2.new(1, -24, 1, -96)
    grid.Position = UDim2.new(0, 12, 0, 88)
    grid.BackgroundTransparency = 1
    grid.BorderSizePixel = 0
    grid.ScrollBarThickness = 6
    grid.CanvasSize = UDim2.new(0, 0, 0, 0)
    grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
    grid.ZIndex = 101
    grid.Parent = frame
    self.gridFrame = grid

    local layout = Instance.new("UIGridLayout")
    layout.CellSize = UDim2.new(0, 220, 0, 240)
    layout.CellPadding = UDim2.new(0, 14, 0, 14)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = grid

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = grid

    self:_animateEntrance()
end

function RewardShopPanel:_createHeader()
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 72)
    header.BackgroundColor3 = COLORS.header
    header.BorderSizePixel = 0
    header.ZIndex = 101
    header.Parent = self.frame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 20)
    headerCorner.Parent = header

    local headerGradient = Instance.new("UIGradient")
    headerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.header),
        ColorSequenceKeypoint.new(1, COLORS.headerGradient),
    })
    headerGradient.Rotation = 90
    headerGradient.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -160, 1, 0)
    title.Position = UDim2.new(0, 24, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🛒 Shop"
    title.TextColor3 = COLORS.text
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 102
    title.Parent = header
    local titleConstraint = Instance.new("UITextSizeConstraint")
    titleConstraint.MaxTextSize = 30
    titleConstraint.Parent = title

    -- THE standard close X (shared component; the old "✕" glyph tofu-boxed in Gotham)
    CloseButton.attach(header, {
        zindex = 102,
        onClick = function()
            self:Hide()
        end,
    })
end

local function summarize(bundle)
    local parts = {}
    for currency, amount in pairs((bundle and bundle.currencies) or {}) do
        table.insert(parts, amount .. " " .. currency)
    end
    for _, item in ipairs((bundle and bundle.items) or {}) do
        table.insert(parts, (item.qty or 1) .. "x " .. tostring(item.id))
    end
    for _, pet in ipairs((bundle and bundle.pets) or {}) do
        table.insert(parts, "pet: " .. tostring(pet.id))
    end
    for _, eff in ipairs((bundle and bundle.effects) or {}) do
        table.insert(parts, tostring(eff.id))
    end
    for slot, amount in pairs((bundle and bundle.slots) or {}) do
        table.insert(parts, "+" .. amount .. " " .. slot)
    end
    if (bundle and bundle.experience or 0) > 0 then
        table.insert(parts, bundle.experience .. " XP")
    end
    return table.concat(parts, "\n")
end

local function costText(cost)
    local parts = {}
    for currency, amount in pairs((cost and cost.currencies) or {}) do
        table.insert(parts, amount .. " " .. currency)
    end
    return table.concat(parts, " + ")
end

function RewardShopPanel:_refresh()
    if not self.gridFrame then
        return
    end
    for _, ch in ipairs(self.gridFrame:GetChildren()) do
        if ch:IsA("Frame") then
            ch:Destroy()
        end
    end

    local result = self:_callBus("shop.list", {})
    local offers = result and result.offers
    if type(offers) ~= "table" then
        return
    end
    table.sort(offers, function(a, b)
        return (a.name or a.id) < (b.name or b.id)
    end)
    for i, offer in ipairs(offers) do
        self:_createOfferCard(offer, i)
    end
end

function RewardShopPanel:_createOfferCard(offer, order)
    local card = Instance.new("Frame")
    card.Name = "Offer_" .. tostring(offer.id)
    card.BackgroundColor3 = COLORS.card
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.ZIndex = 102
    card.Parent = self.gridFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.cardStroke
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    stroke.Parent = card

    -- Name
    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, -16, 0, 26)
    name.Position = UDim2.new(0, 8, 0, 10)
    name.BackgroundTransparency = 1
    name.Text = offer.name or offer.id
    name.TextColor3 = COLORS.text
    name.TextScaled = true
    name.Font = Enum.Font.GothamBold
    name.ZIndex = 103
    name.Parent = card
    local nameConstraint = Instance.new("UITextSizeConstraint")
    nameConstraint.MaxTextSize = 18
    nameConstraint.Parent = name

    -- Reward summary
    local reward = Instance.new("TextLabel")
    reward.Size = UDim2.new(1, -16, 0, 96)
    reward.Position = UDim2.new(0, 8, 0, 42)
    reward.BackgroundTransparency = 1
    reward.Text = summarize(offer.reward)
    reward.TextColor3 = COLORS.gold
    reward.TextWrapped = true
    reward.TextScaled = true
    reward.Font = Enum.Font.GothamMedium
    reward.ZIndex = 103
    reward.Parent = card
    local rewardConstraint = Instance.new("UITextSizeConstraint")
    rewardConstraint.MaxTextSize = 15
    rewardConstraint.Parent = reward

    -- Cost line
    local cost = Instance.new("TextLabel")
    cost.Size = UDim2.new(1, -16, 0, 22)
    cost.Position = UDim2.new(0, 8, 1, -78)
    cost.BackgroundTransparency = 1
    cost.Text = "Cost: " .. costText(offer.cost)
    cost.TextColor3 = COLORS.subtext
    cost.TextScaled = true
    cost.Font = Enum.Font.Gotham
    cost.ZIndex = 103
    cost.Parent = card
    local costConstraint = Instance.new("UITextSizeConstraint")
    costConstraint.MaxTextSize = 14
    costConstraint.Parent = cost

    -- Sale tag
    if offer.discountPercent and offer.discountPercent > 0 then
        local sale = Instance.new("TextLabel")
        sale.Size = UDim2.new(0, 56, 0, 24)
        sale.Position = UDim2.new(1, -64, 0, 8)
        sale.BackgroundColor3 = COLORS.sale
        sale.Text = "-" .. offer.discountPercent .. "%"
        sale.TextColor3 = COLORS.text
        sale.TextScaled = true
        sale.Font = Enum.Font.GothamBold
        sale.ZIndex = 104
        sale.Parent = card
        local saleCorner = Instance.new("UICorner")
        saleCorner.CornerRadius = UDim.new(0, 8)
        saleCorner.Parent = sale
        local saleConstraint = Instance.new("UITextSizeConstraint")
        saleConstraint.MaxTextSize = 14
        saleConstraint.Parent = sale
    end

    -- Buy button
    local buy = Instance.new("TextButton")
    buy.Name = "BuyButton"
    buy.Size = UDim2.new(1, -16, 0, 44)
    buy.Position = UDim2.new(0, 8, 1, -52)
    buy.BorderSizePixel = 0
    buy.TextColor3 = COLORS.text
    buy.TextScaled = true
    buy.Font = Enum.Font.GothamBold
    buy.ZIndex = 103
    buy.Parent = card
    local buyCorner = Instance.new("UICorner")
    buyCorner.CornerRadius = UDim.new(0, 10)
    buyCorner.Parent = buy
    local buyConstraint = Instance.new("UITextSizeConstraint")
    buyConstraint.MaxTextSize = 16
    buyConstraint.Parent = buy

    local soldOut = offer.reason == "out_of_stock"
    if offer.purchasable then
        buy.Text = "Buy"
        buy.BackgroundColor3 = COLORS.buy
        buy.AutoButtonColor = true
        buy.Active = true
        buy.Activated:Connect(function()
            self:_purchase(offer.id, buy)
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

function RewardShopPanel:_purchase(offerId, button)
    if button then
        button.Text = "…"
        button.Active = false
    end
    self:_callBus("shop.purchase", { offerId = offerId })
    -- Refresh so affordability, limits, and the Owned/Sold-out state re-render.
    self:_refresh()
end

function RewardShopPanel:_animateEntrance()
    if not self.frame then
        return
    end
    self.frame.Size = UDim2.new(0.62, 0, 0.72, 0)
    TweenService:Create(
        self.frame,
        TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0.72, 0, 0.82, 0) }
    ):Play()
end

return RewardShopPanel
