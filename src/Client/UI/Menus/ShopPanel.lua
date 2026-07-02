--[[
    ShopPanel - Professional Pet Simulator Style Shop
    
    Features:
    - Category-based shop layout
    - Featured items section
    - Professional visual design with gradients and shadows
    - Purchase animations and confirmations
    - Special offers and sales indicators
    - Currency requirement display
    - Responsive design with hover effects
    
    Usage:
    local ShopPanel = require(script.ShopPanel)
    local shop = ShopPanel.new()
    MenuManager:RegisterPanel("Shop", shop)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

-- Get shared modules
local Locations = require(ReplicatedStorage.Shared.Locations)
local CloseButton = require(script.Parent.Parent.Components.CloseButton)

-- Load Logger with wrapper
local LoggerWrapper
local loggerSuccess, loggerResult = pcall(function()
    return require(Locations.Logger)
end)

if loggerSuccess and loggerResult then
    LoggerWrapper = {
        new = function(name)
            return {
                info = function(self, ...)
                    loggerResult:Info("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                warn = function(self, ...)
                    loggerResult:Warn("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                error = function(self, ...)
                    loggerResult:Error("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                debug = function(self, ...)
                    loggerResult:Debug("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
            }
        end,
    }
else
    LoggerWrapper = {
        new = function(name)
            return {
                info = function(self, ...)
                    print("[" .. name .. "] INFO:", ...)
                end,
                warn = function(self, ...)
                    warn("[" .. name .. "] WARN:", ...)
                end,
                error = function(self, ...)
                    warn("[" .. name .. "] ERROR:", ...)
                end,
                debug = function(self, ...)
                    print("[" .. name .. "] DEBUG:", ...)
                end,
            }
        end,
    }
end

-- Load UI config
local uiConfig
local configSuccess, configResult = pcall(function()
    return Locations.getConfig("ui")
end)

if configSuccess and configResult then
    uiConfig = configResult
else
    -- Enhanced fallback config
    uiConfig = {
        active_theme = "dark",
        themes = {
            dark = {
                primary = {
                    background = Color3.fromRGB(25, 25, 30),
                    surface = Color3.fromRGB(35, 35, 45),
                    accent = Color3.fromRGB(46, 204, 113),
                },
                text = {
                    primary = Color3.fromRGB(255, 255, 255),
                    secondary = Color3.fromRGB(200, 200, 210),
                },
            },
        },
        helpers = {
            get_theme = function(config)
                return config.themes.dark
            end,
        },
    }
end

local ShopPanel = {}
ShopPanel.__index = ShopPanel

function ShopPanel.new()
    local self = setmetatable({}, ShopPanel)

    self.logger = LoggerWrapper.new("ShopPanel")

    -- Panel state
    self.isVisible = false
    self.frame = nil
    self.searchBox = nil
    self.itemsGrid = nil
    self.itemFrames = {}
    self.selectedCategory = "Featured"
    self.searchTerm = ""

    -- Sample shop data
    self.shopData = self:_generateShopData()

    -- Player currencies (would come from real data)
    self.playerCurrencies = {
        coins = 1250,
        gems = 89,
        robux = 25,
    }

    return self
end

function ShopPanel:Show(parent)
    if self.isVisible then
        return
    end

    self:_createUI(parent)
    self:_updateItemsDisplay()

    self.isVisible = true
    self.logger:info("Professional shop panel shown")
end

function ShopPanel:Hide()
    if not self.isVisible then
        return
    end

    if self.frame then
        self.frame:Destroy()
        self.frame = nil
    end

    self.itemFrames = {}
    self.isVisible = false
    self.logger:info("Shop panel hidden")
end

function ShopPanel:_createUI(parent)
    local theme = uiConfig.helpers.get_theme(uiConfig)

    -- Main panel frame
    self.frame = Instance.new("Frame")
    self.frame.Name = "ShopPanel"
    self.frame.Size = UDim2.new(0.85, 0, 0.9, 0)
    self.frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.frame.AnchorPoint = Vector2.new(0.5, 0.5)
    self.frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    self.frame.BorderSizePixel = 0
    self.frame.ZIndex = 100
    self.frame.Parent = parent

    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = self.frame

    -- Border glow
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(46, 204, 113)
    stroke.Thickness = 3
    stroke.Transparency = 0.3
    stroke.Parent = self.frame

    -- Background gradient
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 25)),
    })
    gradient.Rotation = 45
    gradient.Parent = self.frame

    -- Header section
    self:_createHeader()

    -- Left panel (categories)
    self:_createCategoriesPanel()

    -- Right panel (items)
    self:_createItemsPanel()

    -- Add entrance animation
    self:_animateEntrance()
end

function ShopPanel:_createHeader()
    local theme = uiConfig.helpers.get_theme(uiConfig)

    -- Header background
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 80)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    header.BorderSizePixel = 0
    header.ZIndex = 101
    header.Parent = self.frame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 20)
    headerCorner.Parent = header

    -- Header gradient
    local headerGradient = Instance.new("UIGradient")
    headerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(46, 204, 113)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(39, 174, 96)),
    })
    headerGradient.Rotation = 90
    headerGradient.Parent = header

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0, 300, 1, 0)
    title.Position = UDim2.new(0, 25, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🛒 Pet Shop"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 102
    title.Parent = header

    -- Currency display
    self:_createCurrencyDisplay(header)

    -- Close button
    -- THE standard close X (shared component; the old "✕" glyph tofu-boxed in Gotham)
    CloseButton.attach(header, {
        zindex = 102,
        onClick = function()
            self:Hide()
        end,
    })
end

function ShopPanel:_createCurrencyDisplay(parent)
    -- Currency container
    local currencyContainer = Instance.new("Frame")
    currencyContainer.Size = UDim2.new(0, 300, 0, 50)
    currencyContainer.Position = UDim2.new(1, -380, 0, 15)
    currencyContainer.BackgroundTransparency = 1
    currencyContainer.ZIndex = 102
    currencyContainer.Parent = parent

    -- Layout
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Parent = currencyContainer

    -- Currencies
    local currencies = {
        { type = "coins", icon = "💰", color = Color3.fromRGB(255, 215, 0) },
        { type = "gems", icon = "💎", color = Color3.fromRGB(138, 43, 226) },
        { type = "robux", icon = "🔶", color = Color3.fromRGB(0, 162, 255) },
    }

    for i, currency in ipairs(currencies) do
        self:_createCurrencyItem(currency, currencyContainer, i)
    end
end

function ShopPanel:_createCurrencyItem(currency, parent, layoutOrder)
    -- Currency frame
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 90, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    frame.BackgroundTransparency = 0.9
    frame.BorderSizePixel = 0
    frame.LayoutOrder = layoutOrder
    frame.ZIndex = 103
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    -- Icon
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 20, 0, 20)
    icon.Position = UDim2.new(0, 8, 0.5, -10)
    icon.BackgroundTransparency = 1
    icon.Text = currency.icon
    icon.TextColor3 = currency.color
    icon.TextScaled = true
    icon.Font = Enum.Font.GothamBold
    icon.ZIndex = 104
    icon.Parent = frame

    -- Amount
    local amount = Instance.new("TextLabel")
    amount.Size = UDim2.new(1, -35, 1, 0)
    amount.Position = UDim2.new(0, 32, 0, 0)
    amount.BackgroundTransparency = 1
    amount.Text = self:_formatNumber(self.playerCurrencies[currency.type] or 0)
    amount.TextColor3 = Color3.fromRGB(255, 255, 255)
    amount.TextScaled = true
    amount.Font = Enum.Font.GothamBold
    amount.TextXAlignment = Enum.TextXAlignment.Left
    amount.ZIndex = 104
    amount.Parent = frame
end

function ShopPanel:_createCategoriesPanel()
    -- Left panel for categories
    local categoriesPanel = Instance.new("Frame")
    categoriesPanel.Name = "CategoriesPanel"
    categoriesPanel.Size = UDim2.new(0, 200, 1, -90)
    categoriesPanel.Position = UDim2.new(0, 10, 0, 90)
    categoriesPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    categoriesPanel.BorderSizePixel = 0
    categoriesPanel.ZIndex = 101
    categoriesPanel.Parent = self.frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = categoriesPanel

    -- Categories list
    local categoriesScroll = Instance.new("ScrollingFrame")
    categoriesScroll.Size = UDim2.new(1, -10, 1, -10)
    categoriesScroll.Position = UDim2.new(0, 5, 0, 5)
    categoriesScroll.BackgroundTransparency = 1
    categoriesScroll.ScrollBarThickness = 4
    categoriesScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    categoriesScroll.ZIndex = 102
    categoriesScroll.Parent = categoriesPanel

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = categoriesScroll

    -- Categories
    local categories = {
        { name = "Featured", icon = "⭐", color = Color3.fromRGB(255, 215, 0) },
        { name = "Pets", icon = "🐾", color = Color3.fromRGB(52, 152, 219) },
        { name = "Eggs", icon = "🥚", color = Color3.fromRGB(155, 89, 182) },
        { name = "Boosts", icon = "⚡", color = Color3.fromRGB(46, 204, 113) },
        { name = "Tools", icon = "🔧", color = Color3.fromRGB(230, 126, 34) },
        { name = "Special", icon = "💎", color = Color3.fromRGB(231, 76, 60) },
    }

    for i, category in ipairs(categories) do
        self:_createCategoryButton(category, categoriesScroll, i)
    end

    -- Update canvas size
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        categoriesScroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)
end

function ShopPanel:_createCategoryButton(category, parent, layoutOrder)
    local isSelected = (category.name == self.selectedCategory)

    -- Category button
    local button = Instance.new("TextButton")
    button.Name = category.name .. "Button"
    button.Size = UDim2.new(1, -10, 0, 50)
    button.BackgroundColor3 = isSelected and category.color or Color3.fromRGB(40, 40, 50)
    button.BorderSizePixel = 0
    button.Text = ""
    button.LayoutOrder = layoutOrder
    button.ZIndex = 103
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = button

    -- Button content
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -10, 1, -10)
    content.Position = UDim2.new(0, 5, 0, 5)
    content.BackgroundTransparency = 1
    content.ZIndex = 104
    content.Parent = button

    -- Icon
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 25, 0, 25)
    icon.Position = UDim2.new(0, 0, 0.5, -12)
    icon.BackgroundTransparency = 1
    icon.Text = category.icon
    icon.TextScaled = true
    icon.Font = Enum.Font.GothamBold
    icon.ZIndex = 105
    icon.Parent = content

    -- Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -35, 1, 0)
    nameLabel.Position = UDim2.new(0, 35, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = category.name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 105
    nameLabel.Parent = content

    -- Click handling
    button.Activated:Connect(function()
        self:_selectCategory(category.name)
    end)

    if not isSelected then
        self:_addButtonHoverEffect(button, Color3.fromRGB(40, 40, 50))
    end
end

function ShopPanel:_createItemsPanel()
    -- Right panel for items
    local itemsPanel = Instance.new("Frame")
    itemsPanel.Name = "ItemsPanel"
    itemsPanel.Size = UDim2.new(1, -230, 1, -90)
    itemsPanel.Position = UDim2.new(0, 220, 0, 90)
    itemsPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    itemsPanel.BorderSizePixel = 0
    itemsPanel.ZIndex = 101
    itemsPanel.Parent = self.frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = itemsPanel

    -- Items scroll frame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ItemsScroll"
    scrollFrame.Size = UDim2.new(1, -20, 1, -20)
    scrollFrame.Position = UDim2.new(0, 10, 0, 10)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(46, 204, 113)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.ZIndex = 102
    scrollFrame.Parent = itemsPanel

    -- Grid layout
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 160, 0, 200)
    gridLayout.CellPadding = UDim2.new(0, 15, 0, 15)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = scrollFrame

    -- Padding
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 15)
    padding.PaddingBottom = UDim.new(0, 15)
    padding.PaddingLeft = UDim.new(0, 15)
    padding.PaddingRight = UDim.new(0, 15)
    padding.Parent = scrollFrame

    -- Update canvas size when layout changes
    gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 30)
    end)

    self.itemsGrid = scrollFrame
end

function ShopPanel:_generateShopData()
    local items = {}

    -- Featured items
    table.insert(items, {
        id = "featured_mega_pet",
        name = "Mega Rainbow Dragon",
        icon = "🐲",
        category = "Featured",
        price = 500,
        currency = "gems",
        originalPrice = 750,
        discount = 33,
        rarity = "Mythical",
        color = Color3.fromRGB(255, 0, 255),
        description = "Ultimate legendary pet!",
    })

    table.insert(items, {
        id = "featured_boost_pack",
        name = "Ultimate Boost Pack",
        icon = "⚡",
        category = "Featured",
        price = 199,
        currency = "robux",
        discount = 50,
        originalPrice = 399,
        rarity = "Special",
        color = Color3.fromRGB(255, 215, 0),
        description = "3x Speed, 2x Luck, Double Coins",
    })

    -- Regular pets
    local petIcons =
        { "🐶", "🐱", "🐼", "🦊", "🐯", "🐸", "🐷", "🐨", "🐵", "🦁" }
    local rarities = {
        { name = "Common", color = Color3.fromRGB(150, 150, 150), priceRange = { 50, 150 } },
        { name = "Uncommon", color = Color3.fromRGB(30, 255, 0), priceRange = { 100, 300 } },
        { name = "Rare", color = Color3.fromRGB(0, 112, 255), priceRange = { 200, 500 } },
        { name = "Epic", color = Color3.fromRGB(163, 53, 238), priceRange = { 400, 800 } },
        { name = "Legendary", color = Color3.fromRGB(255, 128, 0), priceRange = { 600, 1200 } },
    }

    for i = 1, 30 do
        local rarity = rarities[math.random(1, #rarities)]
        local price = math.random(rarity.priceRange[1], rarity.priceRange[2])

        table.insert(items, {
            id = "pet_" .. i,
            name = "Pet " .. i,
            icon = petIcons[math.random(1, #petIcons)],
            category = "Pets",
            price = price,
            currency = math.random() > 0.7 and "gems" or "coins",
            rarity = rarity.name,
            color = rarity.color,
            description = "A wonderful " .. rarity.name:lower() .. " pet!",
        })
    end

    -- Eggs
    for i = 1, 8 do
        table.insert(items, {
            id = "egg_" .. i,
            name = "Mystery Egg " .. i,
            icon = "🥚",
            category = "Eggs",
            price = math.random(100, 500),
            currency = "coins",
            rarity = "Mystery",
            color = Color3.fromRGB(255, 255, 100),
            description = "Contains a random pet!",
        })
    end

    return items
end

function ShopPanel:_updateItemsDisplay()
    -- Clear existing items
    for _, frame in pairs(self.itemFrames) do
        frame:Destroy()
    end
    self.itemFrames = {}

    -- Filter items
    local filteredItems = {}
    for _, item in ipairs(self.shopData) do
        local matchesCategory = (item.category == self.selectedCategory)

        if matchesCategory then
            table.insert(filteredItems, item)
        end
    end

    -- Create item frames
    for i, item in ipairs(filteredItems) do
        self:_createShopItem(item, i)
    end
end

function ShopPanel:_createShopItem(item, layoutOrder)
    -- Item frame
    local itemFrame = Instance.new("Frame")
    itemFrame.Name = item.id
    itemFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    itemFrame.BorderSizePixel = 0
    itemFrame.LayoutOrder = layoutOrder
    itemFrame.ZIndex = 103
    itemFrame.Parent = self.itemsGrid

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = itemFrame

    -- Rarity border
    local stroke = Instance.new("UIStroke")
    stroke.Color = item.color
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = itemFrame

    -- Background gradient
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 55, 65)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 45, 55)),
    })
    gradient.Rotation = 45
    gradient.Parent = itemFrame

    -- Discount badge (if applicable)
    if item.discount then
        local discountBadge = Instance.new("Frame")
        discountBadge.Size = UDim2.new(0, 50, 0, 25)
        discountBadge.Position = UDim2.new(1, -5, 0, 5)
        discountBadge.AnchorPoint = Vector2.new(1, 0)
        discountBadge.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
        discountBadge.BorderSizePixel = 0
        discountBadge.ZIndex = 105
        discountBadge.Parent = itemFrame

        local badgeCorner = Instance.new("UICorner")
        badgeCorner.CornerRadius = UDim.new(0, 8)
        badgeCorner.Parent = discountBadge

        local discountText = Instance.new("TextLabel")
        discountText.Size = UDim2.new(1, 0, 1, 0)
        discountText.BackgroundTransparency = 1
        discountText.Text = "-" .. item.discount .. "%"
        discountText.TextColor3 = Color3.fromRGB(255, 255, 255)
        discountText.TextScaled = true
        discountText.Font = Enum.Font.GothamBold
        discountText.ZIndex = 106
        discountText.Parent = discountBadge
    end

    -- Item icon background
    local iconBG = Instance.new("Frame")
    iconBG.Size = UDim2.new(0, 80, 0, 80)
    iconBG.Position = UDim2.new(0.5, -40, 0, 15)
    iconBG.BackgroundColor3 = item.color
    iconBG.BackgroundTransparency = 0.8
    iconBG.BorderSizePixel = 0
    iconBG.ZIndex = 104
    iconBG.Parent = itemFrame

    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 40)
    iconCorner.Parent = iconBG

    -- Item icon
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 50, 0, 50)
    icon.Position = UDim2.new(0.5, -25, 0.5, -25)
    icon.BackgroundTransparency = 1
    icon.Text = item.icon
    icon.TextScaled = true
    icon.Font = Enum.Font.GothamBold
    icon.ZIndex = 105
    icon.Parent = iconBG

    -- Item name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -10, 0, 25)
    nameLabel.Position = UDim2.new(0, 5, 0, 100)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = item.name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.ZIndex = 104
    nameLabel.Parent = itemFrame

    -- Description
    local description = Instance.new("TextLabel")
    description.Size = UDim2.new(1, -10, 0, 20)
    description.Position = UDim2.new(0, 5, 0, 125)
    description.BackgroundTransparency = 1
    description.Text = item.description
    description.TextColor3 = Color3.fromRGB(200, 200, 210)
    description.TextScaled = true
    description.Font = Enum.Font.Gotham
    description.TextWrapped = true
    description.ZIndex = 104
    description.Parent = itemFrame

    -- Price section
    local priceFrame = Instance.new("Frame")
    priceFrame.Size = UDim2.new(1, -10, 0, 25)
    priceFrame.Position = UDim2.new(0, 5, 0, 150)
    priceFrame.BackgroundTransparency = 1
    priceFrame.ZIndex = 104
    priceFrame.Parent = itemFrame

    -- Currency icon
    local currencyIcon = item.currency == "robux" and "🔶"
        or (item.currency == "gems" and "💎" or "💰")

    local priceLabel = Instance.new("TextLabel")
    priceLabel.Size = UDim2.new(1, 0, 1, 0)
    priceLabel.BackgroundTransparency = 1
    priceLabel.Text = currencyIcon .. " " .. self:_formatNumber(item.price)
    priceLabel.TextColor3 = item.currency == "robux" and Color3.fromRGB(0, 162, 255)
        or (item.currency == "gems" and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(255, 215, 0))
    priceLabel.TextScaled = true
    priceLabel.Font = Enum.Font.GothamBold
    priceLabel.ZIndex = 105
    priceLabel.Parent = priceFrame

    -- Original price (if discounted)
    if item.originalPrice then
        local originalPrice = Instance.new("TextLabel")
        originalPrice.Size = UDim2.new(1, 0, 0, 15)
        originalPrice.Position = UDim2.new(0, 0, 0, -18)
        originalPrice.BackgroundTransparency = 1
        originalPrice.Text = currencyIcon .. " " .. self:_formatNumber(item.originalPrice)
        originalPrice.TextColor3 = Color3.fromRGB(150, 150, 150)
        originalPrice.TextScaled = true
        originalPrice.Font = Enum.Font.Gotham
        originalPrice.ZIndex = 105
        originalPrice.Parent = priceFrame

        -- Create strikethrough line effect
        local strikethrough = Instance.new("Frame")
        strikethrough.Size = UDim2.new(0.8, 0, 0, 1)
        strikethrough.Position = UDim2.new(0.1, 0, 0.5, 0)
        strikethrough.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
        strikethrough.BorderSizePixel = 0
        strikethrough.ZIndex = 106
        strikethrough.Parent = originalPrice
    end

    -- Buy button
    local buyButton = Instance.new("TextButton")
    buyButton.Size = UDim2.new(1, -10, 0, 20)
    buyButton.Position = UDim2.new(0, 5, 1, -25)
    buyButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    buyButton.BorderSizePixel = 0
    buyButton.Text = "BUY NOW"
    buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    buyButton.TextScaled = true
    buyButton.Font = Enum.Font.GothamBold
    buyButton.ZIndex = 104
    buyButton.Parent = itemFrame

    local buyCorner = Instance.new("UICorner")
    buyCorner.CornerRadius = UDim.new(0, 10)
    buyCorner.Parent = buyButton

    -- Buy button click
    buyButton.Activated:Connect(function()
        self:_purchaseItem(item)
    end)

    -- Check if player can afford
    local canAfford = self.playerCurrencies[item.currency] >= item.price
    if not canAfford then
        buyButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        buyButton.Text = "NOT ENOUGH " .. item.currency:upper()
    end

    -- Hover effects
    self:_addItemHoverEffect(itemFrame)
    if canAfford then
        self:_addButtonHoverEffect(buyButton, Color3.fromRGB(46, 204, 113))
    end

    -- Store reference
    table.insert(self.itemFrames, itemFrame)
end

function ShopPanel:_selectCategory(categoryName)
    self.selectedCategory = categoryName

    -- Update category buttons visual state
    local categoriesPanel = self.frame:FindFirstChild("CategoriesPanel")
    if categoriesPanel then
        local categoriesScroll = categoriesPanel:FindFirstChild("ScrollingFrame")
        if categoriesScroll then
            for _, button in ipairs(categoriesScroll:GetChildren()) do
                if button:IsA("TextButton") then
                    local isSelected = button.Name:find(categoryName)
                    -- Find the category data to get color
                    local categories = {
                        Featured = Color3.fromRGB(255, 215, 0),
                        Pets = Color3.fromRGB(52, 152, 219),
                        Eggs = Color3.fromRGB(155, 89, 182),
                        Boosts = Color3.fromRGB(46, 204, 113),
                        Tools = Color3.fromRGB(230, 126, 34),
                        Special = Color3.fromRGB(231, 76, 60),
                    }

                    button.BackgroundColor3 = isSelected
                            and (categories[categoryName] or Color3.fromRGB(52, 152, 219))
                        or Color3.fromRGB(40, 40, 50)
                end
            end
        end
    end

    -- Update items display
    self:_updateItemsDisplay()
end

function ShopPanel:_purchaseItem(item)
    self.logger:info("Attempting to purchase:", item.name, "for", item.price, item.currency)

    -- Check if player can afford
    if self.playerCurrencies[item.currency] < item.price then
        self.logger:warn("Cannot afford item")
        return
    end

    -- Simulate purchase (in real game, this would call server)
    self.playerCurrencies[item.currency] = self.playerCurrencies[item.currency] - item.price

    -- Update currency display
    self:_updateCurrencyDisplay()

    -- Show purchase animation/confirmation
    self:_showPurchaseConfirmation(item)
end

function ShopPanel:_updateCurrencyDisplay()
    -- Find and update currency displays in header
    local header = self.frame:FindFirstChild("Header")
    if header then
        -- This would update the currency display
        -- In a real implementation, you'd update the actual currency labels
    end
end

function ShopPanel:_showPurchaseConfirmation(item)
    -- Create a simple confirmation popup
    local confirmation = Instance.new("Frame")
    confirmation.Size = UDim2.new(0, 300, 0, 150)
    confirmation.Position = UDim2.new(0.5, -150, 0.5, -75)
    confirmation.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    confirmation.BorderSizePixel = 0
    confirmation.ZIndex = 200
    confirmation.Parent = self.frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = confirmation

    local message = Instance.new("TextLabel")
    message.Size = UDim2.new(1, -20, 1, 0)
    message.Position = UDim2.new(0, 10, 0, 0)
    message.BackgroundTransparency = 1
    message.Text = "✅ Purchase Successful!\n" .. item.name .. " added to inventory!"
    message.TextColor3 = Color3.fromRGB(255, 255, 255)
    message.TextScaled = true
    message.Font = Enum.Font.GothamBold
    message.TextWrapped = true
    message.ZIndex = 201
    message.Parent = confirmation

    -- Auto-remove after 2 seconds
    game:GetService("Debris"):AddItem(confirmation, 2)
end

-- Helper functions
function ShopPanel:_formatNumber(number)
    if number >= 1000000 then
        return string.format("%.1fM", number / 1000000)
    elseif number >= 1000 then
        return string.format("%.1fK", number / 1000)
    else
        return tostring(number)
    end
end

function ShopPanel:_addButtonHoverEffect(button, originalColor)
    button.MouseEnter:Connect(function()
        local tween = TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundColor3 = Color3.new(
                math.min(1, originalColor.R + 0.1),
                math.min(1, originalColor.G + 0.1),
                math.min(1, originalColor.B + 0.1)
            ),
        })
        tween:Play()
    end)

    button.MouseLeave:Connect(function()
        local tween = TweenService:Create(
            button,
            TweenInfo.new(0.15, Enum.EasingStyle.Quad),
            { BackgroundColor3 = originalColor }
        )
        tween:Play()
    end)
end

function ShopPanel:_addItemHoverEffect(itemFrame)
    local originalSize = itemFrame.Size
    local stroke = itemFrame:FindFirstChild("UIStroke")

    itemFrame.MouseEnter:Connect(function()
        local sizeTween =
            TweenService:Create(itemFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                Size = UDim2.new(
                    originalSize.X.Scale,
                    originalSize.X.Offset + 5,
                    originalSize.Y.Scale,
                    originalSize.Y.Offset + 5
                ),
            })
        sizeTween:Play()

        if stroke then
            local strokeTween = TweenService:Create(
                stroke,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad),
                { Transparency = 0, Thickness = 3 }
            )
            strokeTween:Play()
        end
    end)

    itemFrame.MouseLeave:Connect(function()
        local sizeTween = TweenService:Create(
            itemFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad),
            { Size = originalSize }
        )
        sizeTween:Play()

        if stroke then
            local strokeTween = TweenService:Create(
                stroke,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad),
                { Transparency = 0.3, Thickness = 2 }
            )
            strokeTween:Play()
        end
    end)
end

function ShopPanel:_animateEntrance()
    -- Start slightly off-screen and transparent
    self.frame.Position = UDim2.new(0.5, 0, 0.5, 50)
    self.frame.BackgroundTransparency = 1

    -- Animate to final position
    local tween = TweenService:Create(
        self.frame,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {
            Position = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundTransparency = 0,
        }
    )
    tween:Play()
end

-- Public interface methods
function ShopPanel:IsVisible()
    return self.isVisible
end

function ShopPanel:GetFrame()
    return self.frame
end

function ShopPanel:UpdateCurrencies(newCurrencies)
    if newCurrencies then
        for currency, amount in pairs(newCurrencies) do
            if self.playerCurrencies[currency] then
                self.playerCurrencies[currency] = amount
            end
        end
        self:_updateCurrencyDisplay()
    end
end

function ShopPanel:Destroy()
    self:Hide()
    self.logger:info("Professional shop panel destroyed")
end

return ShopPanel
