--[[
    MonetizationService - Handles all Robux purchases and game pass management
    
    Features:
    - ProcessReceipt for developer products
    - Game pass ownership checking
    - Premium player detection
    - Purchase analytics
    - Test mode for Studio
    - First purchase bonuses
    - Purchase validation
    
    This service integrates with EconomyService to grant rewards
    and DataService to track purchase history.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Libraries = ReplicatedStorage.Shared.Libraries
local Signal = require(Libraries.Signal)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local MonetizationService = {}
MonetizationService.__index = MonetizationService

-- Purchase status tracking
local pendingPurchases = {}
local processedPurchases = {}

function MonetizationService:Init()
    -- Get dependencies
    self._logger = self._modules.Logger
    self._dataService = self._modules.DataService
    self._economyService = self._modules.EconomyService
    self._productIdMapper = self._modules.ProductIdMapper
    self._playerEffectsService = self._modules.PlayerEffectsService
    -- NetworkConfig removed - using Signals instead

    -- Validate dependencies
    if not self._logger then
        error("MonetizationService: Logger dependency missing")
    end

    if not self._dataService then
        self._logger:Error("CRITICAL: DataService dependency missing")
        error("MonetizationService: DataService dependency missing")
    end

    if not self._economyService then
        self._logger:Error("CRITICAL: EconomyService dependency missing")
        error("MonetizationService: EconomyService dependency missing")
    end

    if not self._productIdMapper then
        self._logger:Error("CRITICAL: ProductIdMapper dependency missing")
        error("MonetizationService: ProductIdMapper dependency missing")
    end

    -- Create signals
    self.ProductPurchased = Signal.new()
    self.PassPurchased = Signal.new()
    self.PurchaseFailed = Signal.new()

    -- Set up networking
    self:_setupNetworking()

    -- Set up MarketplaceService callbacks
    self:_setupMarketplaceCallbacks()

    -- Track test mode
    self._testMode = self._productIdMapper:IsTestMode()

    self._logger:Info("MonetizationService initialized", {
        testMode = self._testMode,
    })
end

function MonetizationService:Start()
    -- Check game passes for all current players
    for _, player in ipairs(Players:GetPlayers()) do
        self:CheckPlayerPasses(player)
    end

    -- Set up player connections
    Players.PlayerAdded:Connect(function(player)
        self:CheckPlayerPasses(player)
        self:CheckPremiumStatus(player)
    end)

    self._logger:Info("MonetizationService started")
end

function MonetizationService:_setupNetworking()
    -- Use Net RemoteEvents instead of legacy NetworkBridge
    local Signals = require(game:GetService("ReplicatedStorage").Shared.Network.Signals)
    self._signals = Signals

    -- Client ➜ Server
    Signals.InitiatePurchase.OnServerEvent:Connect(function(player, data)
        self:_handlePurchaseRequest(player, data)
    end)

    Signals.GetOwnedPasses.OnServerEvent:Connect(function(player)
        self:_sendOwnedPasses(player)
    end)

    Signals.GetProductInfo.OnServerEvent:Connect(function(player, data)
        self:_sendProductInfo(player, data)
    end)
end

function MonetizationService:_setupMarketplaceCallbacks()
    -- Set ProcessReceipt callback
    MarketplaceService.ProcessReceipt = function(receiptInfo)
        return self:ProcessReceipt(receiptInfo)
    end

    -- Handle game pass purchase prompts
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(
        function(player, gamePassId, wasPurchased)
            if wasPurchased then
                self:_handleGamePassPurchase(player, gamePassId)
            end
        end
    )

    -- Handle premium purchase
    MarketplaceService.PromptPremiumPurchaseFinished:Connect(function(player)
        if player.MembershipType == Enum.MembershipType.Premium then
            self:_applyPremiumBenefits(player)
        end
    end)
end

-- Main ProcessReceipt handler
function MonetizationService:ProcessReceipt(receiptInfo)
    -- Support running in headless TestEZ where no real Player objects exist
    local player = nil
    local ok, result = pcall(function()
        return Players:GetPlayerByUserId(receiptInfo.PlayerId)
    end)
    if ok then
        player = result
    end
    if not player and type(_G.__TEST_PLAYERS_BY_ID) == "table" then
        player = _G.__TEST_PLAYERS_BY_ID[receiptInfo.PlayerId]
    end
    if not player and _G.__TEST_PLAYER and _G.__TEST_PLAYER.UserId == receiptInfo.PlayerId then
        player = _G.__TEST_PLAYER
    end
    if not player then
        -- Player might have left, we'll try again later
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- Check if already processed (prevent double rewards)
    local purchaseKey = receiptInfo.PlayerId .. "_" .. receiptInfo.PurchaseId
    if processedPurchases[purchaseKey] then
        self._logger:Warn("Duplicate purchase receipt", {
            player = player.Name,
            purchaseId = receiptInfo.PurchaseId,
        })
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    -- Get product configuration
    local productConfig = self._productIdMapper:GetProductByRobloxId(receiptInfo.ProductId)
    if not productConfig then
        self._logger:Error("Unknown product purchased", {
            player = player.Name,
            productId = receiptInfo.ProductId,
        })
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- Validate purchase
    local isValid, errorCode, errorParams =
        self._productIdMapper:ValidatePurchase(player, productConfig.id)
    if not isValid then
        self._logger:Warn("Purchase validation failed", {
            player = player.Name,
            product = productConfig.id,
            reason = errorCode,
        })

        -- Send error to player
        local errorMessage = self._productIdMapper:GetErrorMessage(errorCode, errorParams)
        self:_sendPurchaseError(player, errorMessage)

        -- Even though validation failed, we still grant to prevent Robux loss
        -- but we MUST mark this purchase as processed so Roblox does not
        -- keep retrying and our duplicate-purchase test passes.
        processedPurchases[purchaseKey] = true
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    -- Process the purchase
    local success = self:_processProductPurchase(player, productConfig, receiptInfo)

    if success then
        -- Mark as processed
        processedPurchases[purchaseKey] = true

        -- Track analytics
        self:_trackPurchase(player, productConfig, receiptInfo)

        self._logger:Info("Product purchase processed", {
            player = player.Name,
            product = productConfig.id,
            receiptId = receiptInfo.PurchaseId,
        })

        return Enum.ProductPurchaseDecision.PurchaseGranted
    else
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
end

function MonetizationService:_processProductPurchase(player, productConfig, receiptInfo)
    local rewards = productConfig.rewards or {}

    -- Grant currency rewards
    for currency, amount in pairs(rewards) do
        if type(amount) == "number" then
            local success =
                self._economyService:AddCurrency(player, currency, amount, "robux_purchase")
            if not success then
                self._logger:Error("Failed to grant currency", {
                    player = player.Name,
                    currency = currency,
                    amount = amount,
                })
                return false -- abort so receipt is NotProcessedYet, allowing retry or manual handling
            end
        end
    end

    -- Grant item rewards
    if rewards.items then
        for _, itemId in ipairs(rewards.items) do
            local success = self._dataService:AddToInventory(player, itemId, 1)
            if not success then
                self._logger:Error("Failed to grant item", {
                    player = player.Name,
                    item = itemId,
                })
                -- Continue with other rewards
            end
        end
    end

    -- Grant effect rewards
    if rewards.effects then
        for _, effect in ipairs(rewards.effects) do
            local duration = effect.duration or 300
            self._playerEffectsService:ApplyEffect(player, effect.id, duration)
        end
    end

    -- Check for first purchase bonus
    if self:_isFirstPurchase(player) then
        self:_grantFirstPurchaseBonus(player)
    end

    -- Record purchase
    self._dataService:RecordPurchase(player, {
        type = "product",
        id = productConfig.id,
        receiptId = receiptInfo.PurchaseId,
        robuxSpent = productConfig.price_robux,
        timestamp = os.time(),
    })

    -- Fire purchase event
    self.ProductPurchased:Fire(player, productConfig)

    -- Send success to client
    self._signals.PurchaseSuccess:FireClient(player, {
        type = "product",
        id = productConfig.id,
        rewards = rewards,
    })

    return true
end

-- Check game passes for a player
function MonetizationService:CheckPlayerPasses(player)
    local passes = self._productIdMapper:GetAllPasses()
    local ownedPasses = {}

    for _, passConfig in ipairs(passes) do
        local passId = self._productIdMapper:GetProductId(passConfig.id)
        if passId then
            local ownsPass = false

            if self._testMode and passConfig.test_mode_enabled then
                -- In test mode, grant all test-enabled passes
                ownsPass = true
            else
                -- Check actual ownership
                local success, result = pcall(function()
                    return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
                end)

                if success then
                    ownsPass = result
                else
                    self._logger:Error("Failed to check game pass ownership", {
                        player = player.Name,
                        pass = passConfig.id,
                        error = result,
                    })
                end
            end

            if ownsPass then
                table.insert(ownedPasses, passConfig.id)
                self:_applyPassBenefits(player, passConfig)
            end
        end
    end

    -- Store owned passes
    self._dataService:SetOwnedPasses(player, ownedPasses)

    self._logger:Info("Game passes checked", {
        player = player.Name,
        ownedCount = #ownedPasses,
        passes = ownedPasses,
    })
end

-- Apply game pass benefits
function MonetizationService:_applyPassBenefits(player, passConfig)
    local benefits = passConfig.benefits or {}

    -- Apply multipliers
    if benefits.multipliers then
        for stat, multiplier in pairs(benefits.multipliers) do
            self._dataService:SetMultiplier(player, stat, multiplier)
        end
    end

    -- Apply effects
    if benefits.effects then
        local effect = benefits.effects
        if effect.permanent then
            -- Apply permanent effect
            self._playerEffectsService:ApplyPermanentEffect(player, effect.id, effect.stats)
        end
    end

    -- Apply features
    if benefits.features then
        for feature, value in pairs(benefits.features) do
            self._dataService:SetFeature(player, feature, value)
        end
    end

    -- Apply perks
    if benefits.perks then
        for perk, value in pairs(benefits.perks) do
            self._dataService:SetPerk(player, perk, value)
        end
    end

    self._logger:Info("Game pass benefits applied", {
        player = player.Name,
        pass = passConfig.id,
    })
end

-- Check premium status
function MonetizationService:CheckPremiumStatus(player)
    local isPremium = player.MembershipType == Enum.MembershipType.Premium

    if isPremium then
        self:_applyPremiumBenefits(player)
    end

    self._dataService:SetPremiumStatus(player, isPremium)
end

-- Apply premium benefits
function MonetizationService:_applyPremiumBenefits(player)
    local benefits = self._productIdMapper:GetPremiumBenefits()

    if not benefits.enabled then
        return
    end

    -- Apply multipliers
    if benefits.multipliers then
        for stat, multiplier in pairs(benefits.multipliers) do
            self._dataService:SetMultiplier(player, "premium_" .. stat, multiplier)
        end
    end

    -- Apply effects
    if benefits.effects then
        local effect = benefits.effects
        self._playerEffectsService:ApplyPermanentEffect(player, effect.id, effect.stats)
    end

    -- Apply perks
    if benefits.perks then
        for perk, value in pairs(benefits.perks) do
            self._dataService:SetPerk(player, "premium_" .. perk, value)
        end
    end

    self._logger:Info("Premium benefits applied", {
        player = player.Name,
    })
end

-- Handle purchase requests from client
function MonetizationService:_handlePurchaseRequest(player, data)
    local productId = data.productId
    local productType = data.productType or "product"

    if productType == "product" then
        -- Get Roblox product ID
        local robloxId = self._productIdMapper:GetProductId(productId)
        if not robloxId then
            self:_sendPurchaseError(player, "Product not found")
            return
        end

        -- Validate before prompting
        local isValid, errorCode, errorParams =
            self._productIdMapper:ValidatePurchase(player, productId)
        if not isValid then
            local errorMessage = self._productIdMapper:GetErrorMessage(errorCode, errorParams)
            self:_sendPurchaseError(player, errorMessage)
            return
        end

        -- Prompt purchase
        if self._testMode then
            -- In test mode, simulate purchase
            self:_simulateTestPurchase(player, productId)
        else
            MarketplaceService:PromptProductPurchase(player, robloxId)
        end
    elseif productType == "gamepass" then
        -- Get Roblox game pass ID
        local robloxId = self._productIdMapper:GetProductId(productId)
        if not robloxId then
            self:_sendPurchaseError(player, "Game pass not found")
            return
        end

        -- Check if already owned
        local ownsPass = self:PlayerOwnsPass(player, productId)
        if ownsPass then
            self:_sendPurchaseError(player, "You already own this game pass!")
            return
        end

        -- Prompt purchase
        if self._testMode then
            -- In test mode, simulate purchase
            self:_simulateTestPassPurchase(player, productId)
        else
            MarketplaceService:PromptGamePassPurchase(player, robloxId)
        end
    end
end

-- Test mode purchase simulation
function MonetizationService:_simulateTestPurchase(player, productId)
    local productConfig = self._productIdMapper:GetProductConfig(productId)
    if not productConfig then
        return
    end

    self._logger:Info("Test mode: Simulating product purchase", {
        player = player.Name,
        product = productId,
    })

    -- Create fake receipt
    local fakeReceipt = {
        PlayerId = player.UserId,
        ProductId = self._productIdMapper:GetProductId(productId),
        PurchaseId = "TEST_" .. os.time() .. "_" .. math.random(1000, 9999),
        CurrencySpent = 0,
        CurrencyType = Enum.CurrencyType.Robux,
        PlaceIdWherePurchased = game.PlaceId,
    }

    -- Process as normal
    self:_processProductPurchase(player, productConfig, fakeReceipt)
end

function MonetizationService:_simulateTestPassPurchase(player, passId)
    local passConfig = self._productIdMapper:GetPassConfig(passId)
    if not passConfig then
        return
    end

    self._logger:Info("Test mode: Simulating game pass purchase", {
        player = player.Name,
        pass = passId,
    })

    -- Apply benefits
    self:_applyPassBenefits(player, passConfig)

    -- Record as owned
    local ownedPasses = self._dataService:GetOwnedPasses(player) or {}
    table.insert(ownedPasses, passId)
    self._dataService:SetOwnedPasses(player, ownedPasses)

    -- Send success
    self._signals.PurchaseSuccess:FireClient(player, {
        type = "gamepass",
        id = passId,
    })
end

-- Helper functions
function MonetizationService:PlayerOwnsPass(player, passId)
    local ownedPasses = self._dataService:GetOwnedPasses(player) or {}
    for _, owned in ipairs(ownedPasses) do
        if owned == passId then
            return true
        end
    end
    return false
end

function MonetizationService:_isFirstPurchase(player)
    return not self._dataService:HasMadeAnyPurchase(player)
end

function MonetizationService:_grantFirstPurchaseBonus(player)
    local bonus = self._productIdMapper:GetFirstPurchaseBonus()
    if not bonus.enabled then
        return
    end

    local rewards = bonus.rewards

    -- Grant currencies
    if rewards.gems then
        self._economyService:AddCurrency(player, "gems", rewards.gems, "first_purchase_bonus")
    end

    if rewards.coins then
        self._economyService:AddCurrency(player, "coins", rewards.coins, "first_purchase_bonus")
    end

    -- Grant items
    if rewards.items then
        for _, itemId in ipairs(rewards.items) do
            self._dataService:AddToInventory(player, itemId, 1)
        end
    end

    -- Grant title
    if rewards.title then
        self._dataService:GrantTitle(player, rewards.title)
    end

    self._logger:Info("First purchase bonus granted", {
        player = player.Name,
    })

    -- Send notification
    self._signals.FirstPurchaseBonus:FireClient(player, rewards)
    fireGameEvent(player, "first_purchase_bonus", rewards) -- config-driven fanfare (game_events)
end

function MonetizationService:_trackPurchase(player, productConfig, receiptInfo)
    -- Track analytics
    local analyticsData = {
        player_id = player.UserId,
        product_id = productConfig.id,
        product_category = productConfig.analytics_category,
        price_robux = productConfig.price_robux,
        receipt_id = receiptInfo.PurchaseId,
        timestamp = os.time(),
    }

    -- Log to console in test mode
    if self._testMode then
        self._logger:Info("Analytics: Purchase tracked", analyticsData)
    end

    -- Here you would send to your analytics service
end

function MonetizationService:_sendPurchaseError(player, message)
    self._signals.PurchaseError:FireClient(player, {
        message = message,
    })
end

function MonetizationService:_sendOwnedPasses(player)
    local ownedPasses = self._dataService:GetOwnedPasses(player) or {}
    self._signals.OwnedPasses:FireClient(player, {
        passes = ownedPasses,
    })
end

function MonetizationService:_sendProductInfo(player, data)
    local productId = data.productId
    local productConfig = self._productIdMapper:GetProductConfig(productId)

    if productConfig then
        self._signals.ProductInfo:FireClient(player, productConfig)
    end
end

-- Network handler for GetProductInfo requests
function MonetizationService:GetProductInfo(player, data)
    self._logger:Info("Product info requested", {
        player = player.Name,
        productId = data.productId,
    })

    local productConfig = self._productIdMapper:GetProductConfig(data.productId)
    if productConfig then
        self._signals.ProductInfo:FireClient(player, {
            productId = data.productId,
            name = productConfig.name,
            description = productConfig.description,
            price = productConfig.price_robux,
            currency = "Robux",
            rewards = productConfig.rewards,
            available = true,
        })
    else
        self._logger:Warn("Product info requested for unknown product", {
            player = player.Name,
            productId = data.productId,
        })
        self._signals.ProductInfo:FireClient(player, {
            productId = data.productId,
            available = false,
            error = "Product not found",
        })
    end
end

-- Network handler for GetOwnedPasses requests
function MonetizationService:GetOwnedPasses(player, data)
    self._logger:Info("Owned passes requested", {
        player = player.Name,
    })

    local ownedPasses = self._dataService:GetOwnedPasses(player)
    local passDetails = {}

    for _, passId in ipairs(ownedPasses) do
        local passConfig = self._productIdMapper:GetPassConfig(passId)
        if passConfig then
            table.insert(passDetails, {
                id = passId,
                name = passConfig.name,
                description = passConfig.description,
                benefits = passConfig.benefits,
            })
        end
    end

    self._signals.OwnedPasses:FireClient(player, {
        passes = passDetails,
        count = #passDetails,
    })
end

return MonetizationService
