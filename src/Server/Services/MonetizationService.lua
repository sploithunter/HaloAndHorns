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
local FoundersChoice = require(ReplicatedStorage.Shared.Game.FoundersChoice)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)

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
    self._inventoryService = self._modules.InventoryService -- capacity refresh after async pass apply
    self._foundersChoiceService = self._modules.FoundersChoiceService
    self._passSources = {}
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

    self._foundersChoiceService.StateChanged:Connect(function(player, reason)
        self:_sendFoundersChoiceState(
            player,
            reason == "eligibility" or reason == "reselection",
            nil
        )
    end)

    -- Track test mode
    self._testMode = self._productIdMapper:IsTestMode()

    self._logger:Info("MonetizationService initialized", {
        testMode = self._testMode,
    })
end

-- Pass benefits write PROFILE state (features, multipliers, owned passes) —
-- checking before the profile loads silently no-ops all of them (live find
-- 2026-07-14: coloradoplays owned +1 Pet Slot, feature never stored; only
-- the attribute-based Auto Collector benefit survived). Await DataLoaded
-- (completion-driven readiness, house rule) before applying.
function MonetizationService:_checkPassesWhenReady(player, includePremium)
    task.spawn(function()
        if not Readiness.awaitAttribute(player, "DataLoaded", true, 30) then
            self._logger:Warn("Pass check skipped — profile never loaded", {
                player = player.Name,
            })
            return
        end
        self:CheckPlayerPasses(player)
        if includePremium then
            self:CheckPremiumStatus(player)
        end
    end)
end

function MonetizationService:Start()
    -- Check game passes for all current players
    for _, player in ipairs(Players:GetPlayers()) do
        self:_checkPassesWhenReady(player, true)
    end

    -- Set up player connections
    Players.PlayerAdded:Connect(function(player)
        self:_checkPassesWhenReady(player, true)
    end)
    Players.PlayerRemoving:Connect(function(player)
        if self._speedPassApplied then
            self._speedPassApplied[player.UserId] = nil
        end
        self._passSources[player.UserId] = nil
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

    Signals.FoundersChoiceStateRequest.OnServerEvent:Connect(function(player, request)
        self:GetFoundersChoiceState(player, request)
    end)

    Signals.FoundersChoiceSelect.OnServerEvent:Connect(function(player, request)
        self:SelectFoundersChoice(player, request)
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

-- Complete a Marketplace game-pass purchase. Roblox's finished callback carries
-- the numeric pass ID only; map that back to config, apply the permanent benefit,
-- persist ownership/purchase history, and refresh the shop snapshot immediately.
function MonetizationService:_handleGamePassPurchase(player, gamePassId)
    local passConfig = self._productIdMapper:GetPassByRobloxId(gamePassId)
    if not passConfig then
        self._logger:Error("Unknown game pass purchased", {
            player = player.Name,
            gamePassId = gamePassId,
        })
        self:_sendPurchaseError(player, "Game pass not found")
        return false
    end

    local passSources = self._passSources[player.UserId] or {}
    local existingSources = passSources[passConfig.id] or {}
    if existingSources.marketplace == true then
        self:_sendOwnedPasses(player)
        return true
    end

    -- A real purchase supersedes the promotional source, but never removes the
    -- benefit. Return the Founder's Choice immediately so it can be spent on a
    -- different pass, and mark this pass as Marketplace-owned for this session.
    self._foundersChoiceService:ReleaseForMarketplaceOwnership(player, passConfig.id)
    existingSources.marketplace = true
    passSources[passConfig.id] = existingSources
    self._passSources[player.UserId] = passSources

    local firstPurchase = self:_isFirstPurchase(player)
    local ownedPasses = self._dataService:GetOwnedPasses(player) or {}
    if not table.find(ownedPasses, passConfig.id) then
        self:_applyPassBenefits(player, passConfig)
        table.insert(ownedPasses, passConfig.id)
    end
    if not self._dataService:SetOwnedPasses(player, ownedPasses) then
        self._logger:Error("Failed to persist purchased game pass", {
            player = player.Name,
            pass = passConfig.id,
        })
        self:_sendPurchaseError(player, "Purchase completed, but saving is delayed. Please rejoin.")
        return false
    end

    if self._inventoryService and self._inventoryService.RefreshEquipCapacity then
        pcall(function()
            self._inventoryService:RefreshEquipCapacity(player)
        end)
    end

    if firstPurchase then
        self:_grantFirstPurchaseBonus(player)
    end

    local purchaseId = "GAMEPASS_" .. tostring(gamePassId) .. "_" .. tostring(os.time())
    self._dataService:RecordPurchase(player, {
        type = "gamepass",
        id = passConfig.id,
        gamePassId = gamePassId,
        purchaseId = purchaseId,
        robuxSpent = passConfig.price_robux,
        timestamp = os.time(),
    })
    self:_trackPurchase(player, passConfig, { PurchaseId = purchaseId })

    self.PassPurchased:Fire(player, passConfig)
    self._signals.PurchaseSuccess:FireClient(player, {
        type = "gamepass",
        id = passConfig.id,
    })
    self:_sendOwnedPasses(player)
    self:_sendFoundersChoiceState(player, true, nil)

    self._logger:Info("Game pass purchase processed", {
        player = player.Name,
        pass = passConfig.id,
        gamePassId = gamePassId,
    })
    return true
end

-- Check game passes for a player
function MonetizationService:GetCreatorPassGateState(player)
    local data = self._dataService:GetData(player)
    local settings = data and data.Settings or nil
    local state = self._productIdMapper:GetCreatorPassGateState(player.UserId, settings)
    state.active = state.eligible and state.enabled
    return state
end

-- Pass ownership is recomputed, so clear every authored pass channel first. This makes the creator
-- balance gate immediate and also prevents stale pass benefits when Marketplace ownership changes.
-- Premium keys are separately prefixed and earned/timed effects are not touched.
function MonetizationService:_clearPassBenefits(player, passes)
    for _, passConfig in ipairs(passes or {}) do
        local benefits = passConfig.benefits or {}

        for stat in pairs(benefits.multipliers or {}) do
            self._dataService:SetMultiplier(player, stat, nil)
        end
        for feature in pairs(benefits.features or {}) do
            self._dataService:SetFeature(player, feature, nil)
        end
        for perk in pairs(benefits.perks or {}) do
            self._dataService:SetPerk(player, perk, nil)
        end

        local effect = benefits.effects
        if effect and effect.permanent and self._playerEffectsService.RemovePermanentEffect then
            self._playerEffectsService:RemovePermanentEffect(player, effect.id, effect.stats)
        end
    end

    self._speedPassApplied = self._speedPassApplied or {}
    self._speedPassApplied[player.UserId] = {}
    player:SetAttribute("MoveSpeedBuffPass", 0)
    player:SetAttribute("AutoCollectRange", nil)
end

-- Persisted creator-only switch used for production balancing. Disabled means a true no-pass state:
-- even real Marketplace ownership is ignored until the listed creator turns the gate back on.
function MonetizationService:SetCreatorPassBenefitsEnabled(player, enabled)
    local state = self:GetCreatorPassGateState(player)
    if not state.eligible then
        return false, "Only listed creator accounts can use the game-pass test gate", state
    end

    local data = self._dataService:GetData(player)
    if not data then
        return false, "Player profile is not loaded", state
    end

    data.Settings = data.Settings or {}
    data.Settings.CreatorGamePassesEnabled = enabled == true
    self._dataService:RequestSave(player, "creator_game_pass_gate", { critical = true })

    self:CheckPlayerPasses(player)
    self:CheckPremiumStatus(player)
    self:_sendOwnedPasses(player)

    state = self:GetCreatorPassGateState(player)
    self._logger:Info("Creator game-pass benefits toggled", {
        player = player.Name,
        userId = player.UserId,
        enabled = state.enabled,
    })
    return true,
        state.enabled and "Creator game-pass benefits ON" or "Creator game-pass benefits OFF",
        state
end

function MonetizationService:CheckPlayerPasses(player)
    local passes = self._productIdMapper:GetAllPasses()
    local creatorGate = self:GetCreatorPassGateState(player)
    local creatorOwnsAll = creatorGate.active
    -- OFF suppresses automatic Marketplace/creator/Studio sources. A deliberately selected
    -- Founder benefit remains, allowing test accounts to evaluate exactly one choice at a time;
    -- Admin Reset clears that choice and restores a true no-pass baseline.
    local forceNoPasses = creatorGate.eligible and not creatorGate.enabled
    local sourceSets = {
        marketplace = {},
        creator = {},
        test = {},
    }

    if not forceNoPasses then
        for _, passConfig in ipairs(passes) do
            local passId = self._productIdMapper:GetProductId(passConfig.id)
            if passId then
                -- Marketplace is the only source that can displace an identical Founder benefit.
                -- Studio test grants and creator ownership are runtime privileges, not purchases.
                if not self._testMode then
                    local success, result = pcall(function()
                        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
                    end)
                    if success and result == true then
                        sourceSets.marketplace[passConfig.id] = true
                    else
                        if not success then
                            self._logger:Error("Failed to check game pass ownership", {
                                player = player.Name,
                                pass = passConfig.id,
                                error = result,
                            })
                        end
                    end
                end
                if creatorOwnsAll then
                    sourceSets.creator[passConfig.id] = true
                elseif self._testMode and passConfig.test_mode_enabled then
                    sourceSets.test[passConfig.id] = true
                end
            end
        end
    end

    local founderState = self._foundersChoiceService:GetState(player)
    local founderPassId = founderState and founderState.selectedPassId or ""
    if sourceSets.marketplace[founderPassId] then
        self._foundersChoiceService:ReleaseForMarketplaceOwnership(player, founderPassId)
        founderPassId = ""
    end
    if not self._foundersChoiceService:IsEligiblePass(founderPassId) then
        founderPassId = ""
    end

    local ownedPasses, passSources =
        FoundersChoice.effectivePasses(passes, sourceSets, founderPassId, forceNoPasses)

    self:_clearPassBenefits(player, passes)
    for _, passId in ipairs(ownedPasses) do
        local passConfig = self._productIdMapper:GetPassConfig(passId)
        if passConfig then
            self:_applyPassBenefits(player, passConfig)
        end
    end

    self._passSources[player.UserId] = passSources
    self._dataService:SetOwnedPasses(player, ownedPasses)

    -- Pass benefits land AFTER the join-time equip restore (ownership checks
    -- are async) — recompute equip capacity so a paid slot is visible the
    -- moment benefits apply, not on the player's next equip action.
    if self._inventoryService and self._inventoryService.RefreshEquipCapacity then
        pcall(function()
            self._inventoryService:RefreshEquipCapacity(player)
        end)
    end

    self._logger:Info("Game passes checked", {
        player = player.Name,
        ownedCount = #ownedPasses,
        passes = ownedPasses,
        creatorEntitlement = creatorOwnsAll == true,
        creatorGateEnabled = creatorGate.enabled,
        forcedNoPasses = forceNoPasses,
        foundersPass = founderPassId ~= "" and founderPassId or nil,
    })
    self:_sendOwnedPasses(player)
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
        -- SPEED reaches the character via the move_speed axis (MoveSpeedBuff*
        -- attrs -> Eff_Speed -> client WalkSpeed), NOT PlayerEffectsService —
        -- publish pass speed on the axis' permanent pass source. Guarded per
        -- pass per session so a test-mode re-purchase can't double-stack.
        local speedFrac = effect.stats and tonumber(effect.stats.speedMultiplier)
        if speedFrac and speedFrac ~= 0 then
            self._speedPassApplied = self._speedPassApplied or {}
            local applied = self._speedPassApplied[player.UserId] or {}
            self._speedPassApplied[player.UserId] = applied
            if not applied[passConfig.id] then
                applied[passConfig.id] = true
                local current = tonumber(player:GetAttribute("MoveSpeedBuffPass")) or 0
                player:SetAttribute("MoveSpeedBuffPass", current + speedFrac)
            end
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

    -- AUTO COLLECTOR (2026-07-14, Jason: "extend Magnet — they get the same
    -- benefit immediately"): mirror the range as a player attribute so
    -- DropService's collect loop adds it beside MagnetBuff (pass 30 + magnet
    -- power 30 = the 60-stud bubble). Bespoke visuals can come later.
    if benefits.features and benefits.features.auto_collect_enabled then
        player:SetAttribute(
            "AutoCollectRange",
            tonumber(benefits.features.auto_collect_range) or 30
        )
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

    local robloxId = self._productIdMapper:GetProductId(passId)
    self:_handleGamePassPurchase(player, robloxId)
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
    local sources = self._passSources[player.UserId] or {}
    local passDetails = {}
    for _, passId in ipairs(ownedPasses) do
        local passConfig = self._productIdMapper:GetPassConfig(passId)
        passDetails[#passDetails + 1] = {
            id = passId,
            name = passConfig and passConfig.name or passId,
            description = passConfig and passConfig.description or "",
            benefits = passConfig and passConfig.benefits or {},
            sources = sources[passId] or {},
        }
    end
    self._signals.OwnedPasses:FireClient(player, {
        passes = passDetails,
        count = #passDetails,
    })
end

function MonetizationService:_foundersClientState(player, show, errorMessage)
    local state = self._foundersChoiceService:GetState(player) or FoundersChoice.normalizeState(nil)
    local unavailable = {}
    for passId, sources in pairs(self._passSources[player.UserId] or {}) do
        -- Creator/Studio grants are testing sources, not purchases. They must not
        -- consume or visually disable a player's one promotional selection.
        if type(sources) == "table" and sources.marketplace == true then
            unavailable[passId] = true
        end
    end

    local choices = {}
    for _, passId in ipairs(self._foundersChoiceService:GetEligiblePassIds()) do
        local config = self._productIdMapper:GetPassConfig(passId)
        if config then
            choices[#choices + 1] = {
                id = passId,
                name = config.name,
                description = config.description,
                icon = config.icon,
                unavailable = unavailable[passId] == true,
            }
        end
    end

    return {
        eligible = state.eligible == true,
        eligibilityDecided = state.eligibilityDecided == true,
        claimNumber = state.claimNumber,
        testReservation = self._foundersChoiceService:IsTestUser(player.UserId),
        selectedPassId = state.selectedPassId,
        canChoose = FoundersChoice.canChoose(state),
        show = show == true,
        error = errorMessage,
        choices = choices,
    }
end

function MonetizationService:_sendFoundersChoiceState(player, show, errorMessage)
    self._signals.FoundersChoiceState:FireClient(
        player,
        self:_foundersClientState(player, show, errorMessage)
    )
end

function MonetizationService:GetFoundersChoiceState(player, request)
    -- The client UI becomes ready before profile persistence necessarily does. On a first-time
    -- reservation, FoundersChoiceService later emits StateChanged; on a rejoin with an already
    -- decided (but still unclaimed) choice there is no new eligibility transition to emit. Reading
    -- before DataLoaded therefore hid the chooser for the whole session. Always answer from the
    -- loaded profile so dismissing/rejoining never forfeits or strands an unclaimed choice.
    if not Readiness.awaitAttribute(player, "DataLoaded", true, 30) then
        if player.Parent then
            self:_sendFoundersChoiceState(
                player,
                type(request) == "table" and request.open == true,
                "Your profile is still loading. Please try again."
            )
        end
        return
    end
    if not player.Parent then
        return
    end
    self._foundersChoiceService:QueueEligibility(player, false)
    local state = self._foundersChoiceService:GetState(player)
    local wantsOpen = type(request) == "table" and request.open == true
    self:_sendFoundersChoiceState(player, wantsOpen or FoundersChoice.canChoose(state), nil)
end

function MonetizationService:SelectFoundersChoice(player, request)
    local passId = type(request) == "table" and request.passId or nil
    if type(passId) ~= "string" then
        self:_sendFoundersChoiceState(player, true, "Choose a benefit first.")
        return
    end

    if not self._passSources[player.UserId] then
        self:CheckPlayerPasses(player)
    end
    local unavailable = {}
    for ownedId, sources in pairs(self._passSources[player.UserId] or {}) do
        if type(sources) == "table" and sources.marketplace == true then
            unavailable[ownedId] = true
        end
    end
    local ok, reason = self._foundersChoiceService:Select(player, passId, unavailable)
    if not ok then
        self:_sendFoundersChoiceState(player, true, reason)
        return
    end

    self:CheckPlayerPasses(player)
    self:_sendFoundersChoiceState(player, false, nil)
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

    self:_sendOwnedPasses(player)
end

return MonetizationService
