-- Test GUI for Economy System
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Get Signals (new networking system)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

-- Wait for Signals to initialize
task.wait(1)

if not Signals.PurchaseItem or not Signals.SellItem then
    warn("Economy signals not found! Check Signals configuration")
    return
end

-- Create test GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EconomyTestGUI"
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 350, 0, 700)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
frame.BorderSizePixel = 0
frame.Parent = screenGui

-- Add corner radius
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "Economy System Test"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = frame

-- Currency display
local currencyLabel = Instance.new("TextLabel")
currencyLabel.Size = UDim2.new(0.9, 0, 0, 25)
currencyLabel.Position = UDim2.new(0.05, 0, 0, 35)
currencyLabel.BackgroundTransparency = 1
currencyLabel.Text = "Coins: Loading... | Gems: Loading..."
currencyLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
currencyLabel.TextScaled = true
currencyLabel.Font = Enum.Font.Gotham
currencyLabel.Parent = frame

-- Scrolling frame for shop items
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(0.9, 0, 0, 400)
scrollFrame.Position = UDim2.new(0.05, 0, 0, 70)
scrollFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = frame

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 4)
scrollCorner.Parent = scrollFrame

-- Layout for shop items
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

-- Shop items data
local shopItems = {
    -- Basic items
    { id = "test_item", name = "Test Item", price = 50, currency = "coins" },
    { id = "health_potion", name = "Health Potion", price = 25, currency = "coins" },
    { id = "wooden_sword", name = "Wooden Sword", price = 100, currency = "coins" },
    { id = "iron_sword", name = "Iron Sword", price = 500, currency = "coins" },
    { id = "basic_pickaxe", name = "Basic Pickaxe", price = 200, currency = "coins" },

    -- Premium items
    { id = "premium_boost", name = "Premium XP Boost", price = 10, currency = "gems" },
    { id = "diamond_sword", name = "Diamond Sword", price = 25, currency = "gems" },

    -- Rate limiting effect items ⚡
    { id = "speed_potion", name = "⚡ Speed Potion", price = 5, currency = "gems" },
    { id = "trader_scroll", name = "📜 Trader Scroll", price = 150, currency = "coins" },
    { id = "vip_pass", name = "💎 VIP Pass", price = 100, currency = "gems" },

    -- Testing utilities 🧪
    { id = "alamantic_aluminum", name = "🧪 Alamantic Aluminum", price = 1, currency = "coins" },
}

-- Function to create purchase button
local function createPurchaseButton(item, index)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -10, 0, 40)
    button.BackgroundColor3 = Color3.fromRGB(0, 120, 180)
    button.Text = string.format("Buy %s (%d %s)", item.name, item.price, item.currency)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.Gotham
    button.TextScaled = true
    button.LayoutOrder = index
    button.Parent = scrollFrame

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 4)
    buttonCorner.Parent = button

    button.Activated:Connect(function()
        print(
            string.format("🛒 Purchasing %s for %d %s...", item.name, item.price, item.currency)
        )
        print("📊 Current coins before purchase:", player:GetAttribute("Coins") or "unknown")
        Signals.PurchaseItem:FireServer({
            itemId = item.id,
            cost = item.price,
            currency = item.currency,
        })
    end)

    return button
end

-- Create purchase buttons for each item
for i, item in ipairs(shopItems) do
    createPurchaseButton(item, i)
end

-- Update canvas size based on content
local function updateCanvasSize()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
end

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)
updateCanvasSize()

-- Control buttons section
local controlsFrame = Instance.new("Frame")
controlsFrame.Size = UDim2.new(0.9, 0, 0, 155)
controlsFrame.Position = UDim2.new(0.05, 0, 0, 480)
controlsFrame.BackgroundTransparency = 1
controlsFrame.Parent = frame

local controlsLayout = Instance.new("UIListLayout")
controlsLayout.Padding = UDim.new(0, 3)
controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
controlsLayout.Parent = controlsFrame

-- Comprehensive Test Button
local comprehensiveTestButton = Instance.new("TextButton")
comprehensiveTestButton.Size = UDim2.new(1, 0, 0, 30)
comprehensiveTestButton.BackgroundColor3 = Color3.fromRGB(34, 139, 34)
comprehensiveTestButton.Text = "🚀 RUN COMPREHENSIVE TEST"
comprehensiveTestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
comprehensiveTestButton.Font = Enum.Font.GothamBold
comprehensiveTestButton.TextScaled = true
comprehensiveTestButton.LayoutOrder = 0
comprehensiveTestButton.Parent = controlsFrame

local comprehensiveCorner = Instance.new("UICorner")
comprehensiveCorner.CornerRadius = UDim.new(0, 4)
comprehensiveCorner.Parent = comprehensiveTestButton

-- Monetization Test Button
local monetizationTestButton = Instance.new("TextButton")
monetizationTestButton.Size = UDim2.new(1, 0, 0, 25)
monetizationTestButton.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
monetizationTestButton.Text = "💎 TEST MONETIZATION SYSTEM"
monetizationTestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
monetizationTestButton.Font = Enum.Font.GothamBold
monetizationTestButton.TextScaled = true
monetizationTestButton.LayoutOrder = 0.5
monetizationTestButton.Parent = controlsFrame

local monetizationCorner = Instance.new("UICorner")
monetizationCorner.CornerRadius = UDim.new(0, 4)
monetizationCorner.Parent = monetizationTestButton

comprehensiveTestButton.Activated:Connect(function()
    print("🚀 ===== COMPREHENSIVE ECONOMY TEST STARTING =====")

    -- Test sequence with delays to see each step
    local function runTestSequence()
        -- Step 1: Get initial state
        print("📊 Step 1: Getting initial state...")
        -- economyBridge:Fire("server", "GetPlayerDebugInfo", {}) -- TODO: Replace with appropriate Signal
        task.wait(1)

        -- Step 2: Purchase with coins
        print("💰 Step 2: Purchasing test_item with coins...")
        Signals.PurchaseItem:FireServer({
            itemId = "test_item",
            cost = 50,
            currency = "coins",
        })
        task.wait(1)

        -- Step 3: Purchase with gems
        print("💎 Step 3: Purchasing premium_boost with gems...")
        Signals.PurchaseItem:FireServer({
            itemId = "premium_boost",
            cost = 10,
            currency = "gems",
        })
        task.wait(1)

        -- Step 4: Sell an item
        print("💸 Step 4: Selling test_item...")
        Signals.SellItem:FireServer({
            itemId = "test_item",
            quantity = 1,
        })
        task.wait(1)

        -- Step 5: Try purchasing with insufficient funds
        print("❌ Step 5: Testing insufficient funds (diamond_sword = 25 gems)...")
        Signals.PurchaseItem:FireServer({
            itemId = "diamond_sword",
            cost = 25,
            currency = "gems",
        })
        task.wait(1)

        -- Step 5.5: Try purchasing with insufficient level (crystal_staff requires level 10)
        print(
            "❌ Step 5.5: Testing insufficient level (crystal_staff requires level 10, player is level 1)..."
        )
        Signals.PurchaseItem:FireServer({
            itemId = "crystal_staff",
            cost = 5,
            currency = "crystals",
        })
        task.wait(1)

        -- Step 6: Get final state and summary
        print("📊 Step 6: Getting final state...")
        -- economyBridge:Fire("server", "GetPlayerDebugInfo", {}) -- TODO: Replace with appropriate Signal
        task.wait(1)

        -- Step 7: Test monetization system
        print("💎 Step 7: Testing monetization system...")
        local Locations = require(ReplicatedStorage.Shared.Locations)
        local monetizationBridge = Locations.getBridge("Monetization")
        if monetizationBridge then
            print("   - Testing product info retrieval...")
            monetizationBridge:Fire("server", "GetProductInfo", { productId = "small_gems" })
            task.wait(0.5)

            print("   - Testing game pass ownership...")
            monetizationBridge:Fire("server", "GetOwnedPasses", {})
            task.wait(0.5)

            print("   - Testing test purchase (free in Studio)...")
            monetizationBridge:Fire("server", "InitiatePurchase", {
                productType = "product",
                configId = "small_gems",
            })
            task.wait(1)
        else
            print("   ⚠️ Monetization bridge not available")
        end

        -- Step 8: Test configuration validation
        print("⚙️ Step 8: Testing configuration validation...")
        local monetizationStatus = Locations.getConfigLoader():GetMonetizationStatus()
        print(
            "   - Monetization status:",
            monetizationStatus.hasFirstPurchaseBonus and "✅" or "❌"
        )
        print(
            "   - Test mode:",
            monetizationStatus.testModeEnabled and "✅ Enabled" or "❌ Disabled"
        )
        print("   - Products configured:", monetizationStatus.productCount)
        print("   - Game passes configured:", monetizationStatus.passCount)

        print("🏁 ===== COMPREHENSIVE TEST COMPLETED =====")
        print("✅ Check the logs above to verify all systems worked correctly!")
        print("📋 EXPECTED RESULTS:")
        print("   ✅ Steps 1-4: All purchases and sells should succeed")
        print("   ❌ Step 5: diamond_sword should fail (insufficient gems)")
        print("   ❌ Step 5.5: crystal_staff should fail (insufficient level)")
        print("   ✅ Step 7: Monetization system should respond to requests")
        print("   ✅ Step 8: Configuration should show valid monetization setup")
    end

    task.spawn(runTestSequence)
end)

monetizationTestButton.Activated:Connect(function()
    print("💎 ===== MONETIZATION SYSTEM TEST STARTING =====")

    local function runMonetizationTest()
        -- Test 1: Configuration validation
        print("⚙️ Test 1: Configuration validation...")
        local Locations = require(ReplicatedStorage.Shared.Locations)
        local monetizationStatus = Locations.getConfigLoader():GetMonetizationStatus()
        print("   ✅ Products configured:", monetizationStatus.productCount)
        print("   ✅ Game passes configured:", monetizationStatus.passCount)
        print("   ✅ Test mode:", monetizationStatus.testModeEnabled and "Enabled" or "Disabled")
        print(
            "   ✅ Premium benefits:",
            monetizationStatus.hasPremiumBenefits and "Available" or "Not configured"
        )
        task.wait(1)

        -- Test 2: ProductIdMapper functionality
        print("🔧 Test 2: ProductIdMapper functionality...")
        local success, productIdMapper = pcall(function()
            return require(Locations.ProductIdMapper)
        end)

        if success and productIdMapper then
            print("   ✅ ProductIdMapper loaded")
            print("   ✅ Test mode:", productIdMapper:IsTestMode() and "Enabled" or "Disabled")

            -- Test product config
            local productConfig = productIdMapper:GetProductConfig("small_gems")
            if productConfig then
                print(
                    "   ✅ Product config available:",
                    productConfig.name,
                    "-",
                    productConfig.price_robux,
                    "R$"
                )
            end

            -- Test game pass config
            local passConfig = productIdMapper:GetPassConfig("vip_pass")
            if passConfig then
                print(
                    "   ✅ Game pass config available:",
                    passConfig.name,
                    "-",
                    passConfig.price_robux,
                    "R$"
                )
            end
        else
            print("   ❌ ProductIdMapper not available")
        end
        task.wait(1)

        -- Test 3: Network bridge functionality
        print("🌐 Test 3: Network bridge functionality...")
        local monetizationBridge = Locations.getBridge("Monetization")
        if monetizationBridge then
            print("   ✅ Monetization bridge available")

            print("   📡 Testing product info request...")
            monetizationBridge:Fire("server", "GetProductInfo", { productId = "small_gems" })
            task.wait(0.5)

            print("   📡 Testing game pass ownership request...")
            monetizationBridge:Fire("server", "GetOwnedPasses", {})
            task.wait(0.5)

            if productIdMapper and productIdMapper:IsTestMode() then
                print("   💰 Testing purchase in test mode (should be free)...")
                monetizationBridge:Fire("server", "InitiatePurchase", {
                    productType = "product",
                    configId = "small_gems",
                })
                task.wait(1)
            else
                print("   ⚠️ Skipping purchase test (not in test mode)")
            end
        else
            print("   ❌ Monetization bridge not available")
        end
        task.wait(1)

        -- Test 4: Check for monetization services (if main server loaded)
        print("🔧 Test 4: Server services check...")
        local moduleLoaderSuccess, moduleLoader = pcall(function()
            local ml = require(Locations.ModuleLoader)
            return ml:Get("Logger") and ml -- Only return if Logger is available (indicating services are loaded)
        end)

        if moduleLoaderSuccess and moduleLoader then
            print("   ✅ Server services are loaded")

            local monetizationServiceSuccess = pcall(function()
                return moduleLoader:Get("MonetizationService")
            end)

            if monetizationServiceSuccess then
                print("   ✅ MonetizationService accessible")
            else
                print("   ⚠️ MonetizationService not accessible yet")
            end
        else
            print("   ⚠️ Server services not fully loaded yet")
        end

        print("💎 ===== MONETIZATION TEST COMPLETED =====")
        print("✅ All available monetization features tested!")
        print("📋 Check above for any ❌ failures or ⚠️ warnings")
        print("💡 In test mode, purchases should be free in Studio")
    end

    task.spawn(runMonetizationTest)
end)

-- Get Shop Items Button
local shopButton = Instance.new("TextButton")
shopButton.Size = UDim2.new(1, 0, 0, 25)
shopButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
shopButton.Text = "Refresh Shop Items"
shopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
shopButton.Font = Enum.Font.Gotham
shopButton.TextScaled = true
shopButton.LayoutOrder = 1
shopButton.Parent = controlsFrame

local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 4)
shopCorner.Parent = shopButton

shopButton.Activated:Connect(function()
    print("🏪 Requesting shop items...")
    -- economyBridge:Fire("server", "GetShopItems", {}) -- TODO: Replace with appropriate Signal
end)

-- Sell Test Item Button
local sellButton = Instance.new("TextButton")
sellButton.Size = UDim2.new(1, 0, 0, 25)
sellButton.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
sellButton.Text = "Sell Test Item"
sellButton.TextColor3 = Color3.fromRGB(255, 255, 255)
sellButton.Font = Enum.Font.Gotham
sellButton.TextScaled = true
sellButton.LayoutOrder = 2
sellButton.Parent = controlsFrame

local sellCorner = Instance.new("UICorner")
sellCorner.CornerRadius = UDim.new(0, 4)
sellCorner.Parent = sellButton

sellButton.Activated:Connect(function()
    print("💰 Testing item sell...")
    print("📊 Current coins before sell:", player:GetAttribute("Coins") or "unknown")
    Signals.SellItem:FireServer({
        itemId = "test_item",
        quantity = 1,
    })
end)

-- Debug button
local debugButton = Instance.new("TextButton")
debugButton.Size = UDim2.new(1, 0, 0, 15)
debugButton.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
debugButton.Text = "Debug: Print Current Data"
debugButton.TextColor3 = Color3.fromRGB(255, 255, 255)
debugButton.TextScaled = true
debugButton.Font = Enum.Font.Gotham
debugButton.LayoutOrder = 3
debugButton.Parent = controlsFrame

local debugCorner = Instance.new("UICorner")
debugCorner.CornerRadius = UDim.new(0, 4)
debugCorner.Parent = debugButton

debugButton.Activated:Connect(function()
    print("🔍 DEBUG INFO:")
    print("   Coins:", player:GetAttribute("Coins") or "not set")
    print("   Gems:", player:GetAttribute("Gems") or "not set")
    print("   Level:", player:GetAttribute("Level") or "not set")
    print("   Data Loaded:", player:GetAttribute("DataLoaded") or "not set")
    print("   Signals Available:", Signals.PurchaseItem ~= nil)

    -- Request inventory info from server
    -- economyBridge:Fire("server", "GetPlayerDebugInfo", {}) -- TODO: Replace with appropriate Signal
end)

-- Rate Limiting Test Button
local rateLimitButton = Instance.new("TextButton")
rateLimitButton.Size = UDim2.new(1, 0, 0, 25)
rateLimitButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
rateLimitButton.Text = "Test Rate Limiting"
rateLimitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rateLimitButton.TextScaled = true
rateLimitButton.Font = Enum.Font.Gotham
rateLimitButton.LayoutOrder = 4
rateLimitButton.Parent = controlsFrame

local rateLimitCorner = Instance.new("UICorner")
rateLimitCorner.CornerRadius = UDim.new(0, 4)
rateLimitCorner.Parent = rateLimitButton

rateLimitButton.Activated:Connect(function()
    task.spawn(function()
        print("🚨 ===== RATE LIMITING TEST START =====")

        -- Test 1: Rapid fire purchases (should trigger rate limiting)
        print("⚡ Test 1: Rapid fire purchases (should hit rate limits)...")
        for i = 1, 10 do
            print(string.format("  🔥 Rapid purchase #%d", i))
            Signals.PurchaseItem:FireServer({
                itemId = "test_item",
                cost = 50,
                currency = "coins",
            })
            task.wait(0.05) -- Very fast - 20 requests per second
        end
        task.wait(2)

        -- Test 2: Purchase and use a speed potion
        print("🧪 Test 2: Buying and using speed potion...")
        Signals.PurchaseItem:FireServer({
            itemId = "speed_potion",
            cost = 5,
            currency = "gems",
        })
        task.wait(1)

        print("  💊 Using speed potion (should apply rate boost)...")
        -- economyBridge:Fire("server", "UseItem", -- TODO: Replace with appropriate Signal {itemId = "speed_potion"})
        task.wait(2)

        -- Test 3: Rapid purchases WITH speed boost active
        print("⚡ Test 3: Rapid purchases WITH speed boost...")
        for i = 1, 10 do
            print(string.format("  ⚡ Boosted purchase #%d", i))
            Signals.PurchaseItem:FireServer({
                itemId = "test_item",
                cost = 50,
                currency = "coins",
            })
            task.wait(0.05)
        end
        task.wait(2)

        -- Test 4: Check final state
        print("📊 Test 4: Getting final state...")
        -- economyBridge:Fire("server", "GetPlayerDebugInfo", {}) -- TODO: Replace with appropriate Signal

        print("🏁 ===== RATE LIMITING TEST COMPLETE =====")
        print("📋 EXPECTED RESULTS:")
        print("   ❌ Test 1: Some purchases should be blocked (rate limited)")
        print("   ✅ Test 2: Speed potion should be purchased and used")
        print("   ✅ Test 3: More purchases should succeed (rate boost active)")
    end)
end)

-- Effect Stacking Test Button
local effectButton = Instance.new("TextButton")
effectButton.Size = UDim2.new(1, 0, 0, 25)
effectButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
effectButton.Text = "Test Effect Stacking"
effectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
effectButton.TextScaled = true
effectButton.Font = Enum.Font.Gotham
effectButton.LayoutOrder = 5
effectButton.Parent = controlsFrame

local effectCorner = Instance.new("UICorner")
effectCorner.CornerRadius = UDim.new(0, 4)
effectCorner.Parent = effectButton

effectButton.Activated:Connect(function()
    task.spawn(function()
        print("🔗 ===== EFFECT STACKING TEST START =====")

        -- Test 1: Buy multiple DIFFERENT effect items
        print("🛒 Test 1: Buying different effect items...")

        print("  💊 Buying speed potion...")
        Signals.PurchaseItem:FireServer({
            itemId = "speed_potion",
            cost = 5,
            currency = "gems",
        })
        task.wait(1)

        print("  📜 Buying trader scroll...")
        Signals.PurchaseItem:FireServer({
            itemId = "trader_scroll",
            cost = 150,
            currency = "coins",
        })
        task.wait(1)

        print("  💎 Buying VIP pass...")
        Signals.PurchaseItem:FireServer({
            itemId = "vip_pass",
            cost = 100,
            currency = "gems",
        })
        task.wait(1)

        print("  💊 Buying extra speed potion...")
        Signals.PurchaseItem:FireServer({
            itemId = "speed_potion",
            cost = 5,
            currency = "gems",
        })
        task.wait(2)

        -- Test 2: Use different effects (should test stacking limits)
        print("⚡ Test 2: Using different effects (testing stacking)...")

        print("  🧪 Using speed potion (effect #1)...")
        -- economyBridge:Fire("server", "UseItem", -- TODO: Replace with appropriate Signal {itemId = "speed_potion"})
        task.wait(1)

        print("  📜 Using trader scroll (effect #2)...")
        -- economyBridge:Fire("server", "UseItem", -- TODO: Replace with appropriate Signal {itemId = "trader_scroll"})
        task.wait(1)

        print("  💎 Using VIP pass (effect #3)...")
        -- economyBridge:Fire("server", "UseItem", -- TODO: Replace with appropriate Signal {itemId = "vip_pass"})
        task.wait(1)

        print("  💊 Using 4th speed potion (should be rejected - stacking limit)...")
        -- economyBridge:Fire("server", "UseItem", -- TODO: Replace with appropriate Signal {itemId = "speed_potion"})
        task.wait(2)

        -- Test 3: Try to add 5th effect (should be rejected)
        print("📜 Test 3: Attempting 5th effect (should fail)...")
        print("  🧪 Trying to use another speed potion...")
        -- economyBridge:Fire("server", "UseItem", -- TODO: Replace with appropriate Signal {itemId = "speed_potion"})
        task.wait(2)

        -- Test 4: Rapid purchases with mixed effects
        print("🚀 Test 4: Rapid purchases with mixed effects active...")
        for i = 1, 8 do
            print(string.format("  🎯 Multi-effect purchase #%d", i))
            Signals.PurchaseItem:FireServer({
                itemId = "test_item",
                cost = 50,
                currency = "coins",
            })
            task.wait(0.1)
        end

        print("🏁 ===== EFFECT STACKING TEST COMPLETE =====")
        print("📋 EXPECTED RESULTS:")
        print("   ✅ First 3 different effects should stack (speed, trader, VIP)")
        print("   ❌ 4th effect should be rejected (stacking limit of 3)")
        print("   ❌ 5th effect should be rejected (stacking limit)")
        print("   ✅ Mixed effect purchases should succeed with boosted rates")
    end)
end)

-- Function to update currency display
local function updateCurrencyDisplay()
    local coins = player:GetAttribute("Coins") or 0
    local gems = player:GetAttribute("Gems") or 0
    local crystals = player:GetAttribute("Crystals") or 0
    currencyLabel.Text =
        string.format("💰 Coins: %d | 💎 Gems: %d | 🔮 Crystals: %d", coins, gems, crystals)
end

-- Update currency display when attributes change
player:GetAttributeChangedSignal("Coins"):Connect(updateCurrencyDisplay)
player:GetAttributeChangedSignal("Gems"):Connect(updateCurrencyDisplay)
player:GetAttributeChangedSignal("Crystals"):Connect(updateCurrencyDisplay)

-- Initial currency display update
task.spawn(function()
    task.wait(2) -- Wait for data to potentially load
    updateCurrencyDisplay()
end)

-- Global Effects Test Buttons
local globalEffectsLabel = Instance.new("TextLabel")
globalEffectsLabel.Size = UDim2.new(1, 0, 0, 25)
globalEffectsLabel.BackgroundTransparency = 1
globalEffectsLabel.Text = "=== Global Effects Testing ==="
globalEffectsLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
globalEffectsLabel.TextScaled = true
globalEffectsLabel.Font = Enum.Font.GothamBold
globalEffectsLabel.LayoutOrder = 6
globalEffectsLabel.Parent = controlsFrame

-- XP Weekend Button
local xpWeekendButton = Instance.new("TextButton")
xpWeekendButton.Size = UDim2.new(1, 0, 0, 25)
xpWeekendButton.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
xpWeekendButton.Text = "🎉 Start XP Weekend (48h)"
xpWeekendButton.TextColor3 = Color3.fromRGB(255, 255, 255)
xpWeekendButton.TextScaled = true
xpWeekendButton.Font = Enum.Font.Gotham
xpWeekendButton.LayoutOrder = 7
xpWeekendButton.Parent = controlsFrame

local xpCorner = Instance.new("UICorner")
xpCorner.CornerRadius = UDim.new(0, 4)
xpCorner.Parent = xpWeekendButton

-- Speed Hour Button
local speedHourButton = Instance.new("TextButton")
speedHourButton.Size = UDim2.new(1, 0, 0, 25)
speedHourButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
speedHourButton.Text = "⚡ Start Speed Hour (1h)"
speedHourButton.TextColor3 = Color3.fromRGB(255, 255, 255)
speedHourButton.TextScaled = true
speedHourButton.Font = Enum.Font.Gotham
speedHourButton.LayoutOrder = 8
speedHourButton.Parent = controlsFrame

local speedCorner = Instance.new("UICorner")
speedCorner.CornerRadius = UDim.new(0, 4)
speedCorner.Parent = speedHourButton

-- Luck Boost Button
local luckBoostButton = Instance.new("TextButton")
luckBoostButton.Size = UDim2.new(1, 0, 0, 25)
luckBoostButton.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
luckBoostButton.Text = "🍀 Start Luck Boost (2h)"
luckBoostButton.TextColor3 = Color3.fromRGB(255, 255, 255)
luckBoostButton.TextScaled = true
luckBoostButton.Font = Enum.Font.Gotham
luckBoostButton.LayoutOrder = 9
luckBoostButton.Parent = controlsFrame

local luckCorner = Instance.new("UICorner")
luckCorner.CornerRadius = UDim.new(0, 4)
luckCorner.Parent = luckBoostButton

-- Clear Global Effects Button
local clearGlobalButton = Instance.new("TextButton")
clearGlobalButton.Size = UDim2.new(1, 0, 0, 25)
clearGlobalButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
clearGlobalButton.Text = "🧹 Clear All Global Effects"
clearGlobalButton.TextColor3 = Color3.fromRGB(255, 255, 255)
clearGlobalButton.TextScaled = true
clearGlobalButton.Font = Enum.Font.Gotham
clearGlobalButton.LayoutOrder = 10
clearGlobalButton.Parent = controlsFrame

local clearCorner = Instance.new("UICorner")
clearCorner.CornerRadius = UDim.new(0, 4)
clearCorner.Parent = clearGlobalButton

-- Global effect button handlers (purchase and use admin items)
xpWeekendButton.Activated:Connect(function()
    print("🎉 Purchasing and using XP Weekend Activator...")
    Signals.PurchaseItem:FireServer({
        itemId = "admin_xp_weekend",
        cost = 1,
        currency = "gems",
    })
    task.wait(0.5)
    -- economyBridge:Fire("server", "UseItem", -- TODO: Replace with appropriate Signal {itemId = "admin_xp_weekend"})
end)

speedHourButton.Activated:Connect(function()
    print("⚡ Purchasing and using Speed Hour Activator...")
    Signals.PurchaseItem:FireServer({
        itemId = "admin_speed_hour",
        cost = 1,
        currency = "gems",
    })
    task.wait(0.5)
    -- economyBridge:Fire("server", "UseItem", -- TODO: Replace with appropriate Signal {itemId = "admin_speed_hour"})
end)

luckBoostButton.Activated:Connect(function()
    print("🍀 Purchasing and using Luck Boost Activator...")
    Signals.PurchaseItem:FireServer({
        itemId = "admin_luck_boost",
        cost = 1,
        currency = "gems",
    })
    task.wait(0.5)
    -- economyBridge:Fire("server", "UseItem", -- TODO: Replace with appropriate Signal {itemId = "admin_luck_boost"})
end)

clearGlobalButton.Activated:Connect(function()
    print("🧹 Purchasing and using Global Effects Clearer...")
    Signals.PurchaseItem:FireServer({
        itemId = "admin_clear_global",
        cost = 1,
        currency = "coins",
    })
    task.wait(0.5)
    -- economyBridge:Fire("server", "UseItem", -- TODO: Replace with appropriate Signal {itemId = "admin_clear_global"})
end)

-- Alamantic Aluminum Test Button
local aluminumButton = Instance.new("TextButton")
aluminumButton.Size = UDim2.new(1, 0, 0, 25)
aluminumButton.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
aluminumButton.Text = "🧪 Use Alamantic Aluminum (Clear Player Effects)"
aluminumButton.TextColor3 = Color3.fromRGB(0, 0, 0)
aluminumButton.TextScaled = true
aluminumButton.Font = Enum.Font.Gotham
aluminumButton.LayoutOrder = 11
aluminumButton.Parent = controlsFrame

local aluminumCorner = Instance.new("UICorner")
aluminumCorner.CornerRadius = UDim.new(0, 4)
aluminumCorner.Parent = aluminumButton

aluminumButton.Activated:Connect(function()
    print("🧪 Purchasing and using Alamantic Aluminum...")
    Signals.PurchaseItem:FireServer({
        itemId = "alamantic_aluminum",
        cost = 1,
        currency = "coins",
    })
    task.wait(0.5)
    -- economyBridge:Fire("server", "UseItem", -- TODO: Replace with appropriate Signal {itemId = "alamantic_aluminum"})
end)

print("💰 Enhanced Economy Test GUI loaded!")

return {
    UpdateStatus = function(text)
        -- Could add a status label if needed
        print("Status:", text)
    end,
}
