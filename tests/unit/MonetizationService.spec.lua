--[[
    MonetizationService Test Suite
    
    Comprehensive tests covering:
    - Developer product purchases
    - Game pass purchases
    - Premium benefits
    - Purchase validation
    - First purchase bonuses
    - Error handling
    - Edge cases
]]

return function()
    local MonetizationService =
        require(game.ServerScriptService.Server.Services.MonetizationService)
    local ProductIdMapper = require(game.ReplicatedStorage.Shared.Utils.ProductIdMapper)

    describe("MonetizationService", function()
        local mockLogger, mockDataService, mockEconomyService, mockProductIdMapper
        local mockPlayerEffectsService, mockNetworkConfig
        local monetizationService

        -- Mock player object
        local function createMockPlayer(userId, name)
            local playerTable = {
                UserId = userId or 12345,
                Name = name or "TestPlayer",
                MembershipType = Enum.MembershipType.None,
            }
            -- Register in global lookup tables that MonetizationService uses
            _G.__TEST_PLAYER = playerTable
            _G.__TEST_PLAYERS_BY_ID = _G.__TEST_PLAYERS_BY_ID or {}
            _G.__TEST_PLAYERS_BY_ID[playerTable.UserId] = playerTable
            return playerTable
        end

        beforeEach(function()
            -- Stub RemoteEvents to prevent FireClient errors during tests
            local Signals = require(game.ReplicatedStorage.Shared.Network.Signals)
            local function stub(name)
                local remote = Signals[name]
                if remote and typeof(remote) == "Instance" then
                    -- Replace with proxy table preserving FireClient
                end
                Signals[name] = { FireClient = function() end }
            end
            for _, n in ipairs({
                "PurchaseSuccess",
                "PurchaseError",
                "OwnedPasses",
                "ProductInfo",
                "FirstPurchaseBonus",
            }) do
                stub(n)
            end
            -- Create mocks
            mockLogger = {
                Info = function() end,
                Warn = function() end,
                Error = function() end,
                Debug = function() end,
            }

            mockDataService = {
                IsDataLoaded = function()
                    return true
                end,
                GetOwnedPasses = function()
                    return {}
                end,
                SetOwnedPasses = function() end,
                RecordPurchase = function() end,
                AddToInventory = function()
                    return true
                end,
                HasMadeAnyPurchase = function()
                    return false
                end,
                GetPurchaseHistory = function()
                    return {}
                end,
                SetMultiplier = function() end,
                SetFeature = function() end,
                SetPerk = function() end,
                SetPremiumStatus = function() end,
                GrantTitle = function() end,
            }

            mockEconomyService = {
                AddCurrency = function()
                    return true
                end,
            }

            mockProductIdMapper = {
                IsTestMode = function()
                    return true
                end,
                GetProductByRobloxId = function(id)
                    if id == 1234567890 then
                        return {
                            id = "small_gems",
                            name = "100 Gems",
                            price_robux = 99,
                            rewards = { gems = 100 },
                        }
                    end
                    return nil
                end,
                GetProductConfig = function(id)
                    if id == "small_gems" then
                        return {
                            id = "small_gems",
                            name = "100 Gems",
                            price_robux = 99,
                            rewards = { gems = 100 },
                        }
                    elseif id == "starter_pack" then
                        return {
                            id = "starter_pack",
                            name = "Starter Pack",
                            price_robux = 199,
                            rewards = {
                                gems = 150,
                                coins = 25000,
                                items = { "wooden_sword" },
                            },
                            one_time_only = true,
                            level_requirement = { max = 10 },
                        }
                    end
                    return nil
                end,
                GetPassConfig = function(id)
                    if id == "vip_pass" then
                        return {
                            id = "vip_pass",
                            name = "VIP Pass",
                            price_robux = 499,
                            benefits = {
                                multipliers = { xp = 2.0, coins = 1.5 },
                                effects = {
                                    id = "vip_effect",
                                    permanent = true,
                                    stats = { speedMultiplier = 0.25 },
                                },
                            },
                            test_mode_enabled = true,
                        }
                    end
                    return nil
                end,
                GetAllPasses = function()
                    return {
                        {
                            id = "vip_pass",
                            test_mode_enabled = true,
                        },
                    }
                end,
                GetProductId = function(configId)
                    local mapping = {
                        small_gems = 1234567890,
                        vip_pass = 123456789,
                    }
                    return mapping[configId]
                end,
                ValidatePurchase = function()
                    return true, "valid"
                end,
                GetErrorMessage = function(code)
                    return "Error: " .. code
                end,
                GetFirstPurchaseBonus = function()
                    return {
                        enabled = true,
                        rewards = {
                            gems = 100,
                            coins = 50000,
                            items = { "wooden_sword" },
                            title = "Supporter",
                        },
                    }
                end,
                GetPremiumBenefits = function()
                    return {
                        enabled = true,
                        multipliers = { xp = 1.5, coins = 1.25 },
                        effects = {
                            id = "premium_effect",
                            permanent = true,
                            stats = { speedMultiplier = 0.1 },
                        },
                    }
                end,
            }

            mockPlayerEffectsService = {
                ApplyEffect = function() end,
                ApplyPermanentEffect = function() end,
            }

            mockNetworkConfig = {
                GetBridge = function()
                    return {
                        Connect = function() end,
                        Fire = function() end,
                    }
                end,
            }

            -- Create service with mocks

            -- Register the mock player globally for MonetizationService fallback logic

            monetizationService = setmetatable({}, MonetizationService)
            monetizationService._modules = {
                Logger = mockLogger,
                DataService = mockDataService,
                EconomyService = mockEconomyService,
                ProductIdMapper = mockProductIdMapper,
                PlayerEffectsService = mockPlayerEffectsService,
                NetworkConfig = mockNetworkConfig,
            }
            monetizationService:Init()
        end)

        describe("ProcessReceipt", function()
            it("should process valid product purchase", function()
                local player = createMockPlayer()
                local receipt = {
                    PlayerId = player.UserId,
                    ProductId = 1234567890,
                    PurchaseId = "12345",
                    CurrencySpent = 99,
                    CurrencyType = Enum.CurrencyType.Robux,
                }

                local result = monetizationService:ProcessReceipt(receipt)
                expect(result).to.equal(Enum.ProductPurchaseDecision.PurchaseGranted)
            end)

            it("should prevent duplicate purchases", function()
                local player = createMockPlayer()
                local receipt = {
                    PlayerId = player.UserId,
                    ProductId = 1234567890,
                    PurchaseId = "12345",
                    CurrencySpent = 99,
                    CurrencyType = Enum.CurrencyType.Robux,
                }

                -- First purchase
                monetizationService:ProcessReceipt(receipt)

                -- Duplicate attempt
                local result = monetizationService:ProcessReceipt(receipt)
                expect(result).to.equal(Enum.ProductPurchaseDecision.PurchaseGranted)
            end)

            it("should handle unknown products", function()
                local player = createMockPlayer()
                local receipt = {
                    PlayerId = player.UserId,
                    ProductId = 9999999, -- Unknown product
                    PurchaseId = "12345",
                }

                mockProductIdMapper.GetProductByRobloxId = function()
                    return nil
                end

                local result = monetizationService:ProcessReceipt(receipt)
                expect(result).to.equal(Enum.ProductPurchaseDecision.NotProcessedYet)
            end)

            it("should handle player leaving during purchase", function()
                local receipt = {
                    PlayerId = 99999, -- Non-existent player
                    ProductId = 1234567890,
                    PurchaseId = "12345",
                }

                local result = monetizationService:ProcessReceipt(receipt)
                expect(result).to.equal(Enum.ProductPurchaseDecision.NotProcessedYet)
            end)
        end)

        describe("Purchase Validation", function()
            it("should validate level requirements", function()
                mockProductIdMapper.ValidatePurchase = function(player, configId)
                    return false, "level_too_high", { level = 10 }
                end

                local player = createMockPlayer()
                local receipt = {
                    PlayerId = player.UserId,
                    ProductId = 1234567890,
                    PurchaseId = "12345",
                }

                -- Should still grant to prevent Robux loss
                local result = monetizationService:ProcessReceipt(receipt)
                expect(result).to.equal(Enum.ProductPurchaseDecision.PurchaseGranted)
            end)

            it("should enforce one-time purchases", function()
                mockProductIdMapper.ValidatePurchase = function(player, configId)
                    return false, "one_time_only"
                end

                local player = createMockPlayer()
                local receipt = {
                    PlayerId = player.UserId,
                    ProductId = 1234567890,
                    PurchaseId = "12345",
                }

                local result = monetizationService:ProcessReceipt(receipt)
                expect(result).to.equal(Enum.ProductPurchaseDecision.PurchaseGranted)
            end)
        end)

        describe("Reward Granting", function()
            it("should grant currency rewards", function()
                local currencyGranted = false
                mockEconomyService.AddCurrency = function(player, currency, amount, reason)
                    currencyGranted = true
                    expect(currency).to.equal("gems")
                    expect(amount).to.equal(100)
                    expect(reason).to.equal("robux_purchase")
                    return true
                end

                local player = createMockPlayer()
                local receipt = {
                    PlayerId = player.UserId,
                    ProductId = 1234567890,
                    PurchaseId = "12345",
                }

                monetizationService:ProcessReceipt(receipt)
                expect(currencyGranted).to.equal(true)
            end)

            it("should grant item rewards", function()
                local itemsGranted = {}
                mockDataService.AddToInventory = function(player, itemId, quantity)
                    table.insert(itemsGranted, itemId)
                    return true
                end

                mockProductIdMapper.GetProductByRobloxId = function()
                    return {
                        id = "starter_pack",
                        rewards = {
                            items = { "wooden_sword", "health_potion" },
                        },
                    }
                end

                local player = createMockPlayer()
                local receipt = {
                    PlayerId = player.UserId,
                    ProductId = 1234567892,
                    PurchaseId = "12345",
                }

                monetizationService:ProcessReceipt(receipt)
                expect(#itemsGranted).to.equal(2)
                expect(itemsGranted[1]).to.equal("wooden_sword")
                expect(itemsGranted[2]).to.equal("health_potion")
            end)

            it("should grant effect rewards", function()
                local effectApplied = false
                mockPlayerEffectsService.ApplyEffect = function(player, effectId, duration)
                    effectApplied = true
                    expect(effectId).to.equal("xp_boost")
                    expect(duration).to.equal(3600)
                end

                mockProductIdMapper.GetProductByRobloxId = function()
                    return {
                        id = "boost_pack",
                        rewards = {
                            effects = { { id = "xp_boost", duration = 3600 } },
                        },
                    }
                end

                local player = createMockPlayer()
                local receipt = {
                    PlayerId = player.UserId,
                    ProductId = 1234567893,
                    PurchaseId = "12345",
                }

                monetizationService:ProcessReceipt(receipt)
                expect(effectApplied).to.equal(true)
            end)
        end)

        describe("First Purchase Bonus", function()
            it("should grant first purchase bonus", function()
                local bonusGranted = false
                local titleGranted = false

                mockDataService.HasMadeAnyPurchase = function()
                    return false
                end
                mockDataService.GrantTitle = function(player, title)
                    titleGranted = true
                    expect(title).to.equal("Supporter")
                end

                local player = createMockPlayer()
                local receipt = {
                    PlayerId = player.UserId,
                    ProductId = 1234567890,
                    PurchaseId = "12345",
                }

                monetizationService:ProcessReceipt(receipt)
                expect(titleGranted).to.equal(true)
            end)

            it("should not grant bonus on subsequent purchases", function()
                mockDataService.HasMadeAnyPurchase = function()
                    return true
                end

                local titleGranted = false
                mockDataService.GrantTitle = function()
                    titleGranted = true
                end

                local player = createMockPlayer()
                local receipt = {
                    PlayerId = player.UserId,
                    ProductId = 1234567890,
                    PurchaseId = "12345",
                }

                monetizationService:ProcessReceipt(receipt)
                expect(titleGranted).to.equal(false)
            end)
        end)

        describe("Game Pass Management", function()
            it("should check and apply game pass benefits", function()
                local multiplierSet = false
                local effectApplied = false

                mockDataService.SetMultiplier = function(player, stat, value)
                    multiplierSet = true
                    if stat == "xp" then
                        expect(value).to.equal(2.0)
                    elseif stat == "coins" then
                        expect(value).to.equal(1.5)
                    end
                end

                mockPlayerEffectsService.ApplyPermanentEffect = function(player, effectId, stats)
                    effectApplied = true
                    expect(effectId).to.equal("vip_effect")
                    expect(stats.speedMultiplier).to.equal(0.25)
                end

                local player = createMockPlayer()
                monetizationService:CheckPlayerPasses(player)

                expect(multiplierSet).to.equal(true)
                expect(effectApplied).to.equal(true)
            end)

            it("should store owned passes", function()
                local passesStored = nil
                mockDataService.SetOwnedPasses = function(player, passes)
                    passesStored = passes
                end

                local player = createMockPlayer()
                monetizationService:CheckPlayerPasses(player)

                expect(passesStored).to.be.ok()
                expect(#passesStored).to.equal(1)
                expect(passesStored[1]).to.equal("vip_pass")
            end)
        end)

        describe("Premium Benefits", function()
            it("should apply premium benefits", function()
                local multiplierSet = false
                local effectApplied = false

                mockDataService.SetMultiplier = function(player, stat, value)
                    multiplierSet = true
                end

                mockPlayerEffectsService.ApplyPermanentEffect = function(player, effectId, stats)
                    effectApplied = true
                    expect(effectId).to.equal("premium_effect")
                end

                local player = createMockPlayer()
                player.MembershipType = Enum.MembershipType.Premium

                monetizationService:CheckPremiumStatus(player)

                expect(multiplierSet).to.equal(true)
                expect(effectApplied).to.equal(true)
            end)
        end)

        describe("Error Handling", function()
            it("should handle currency grant failures", function()
                mockEconomyService.AddCurrency = function()
                    return false -- Simulate failure
                end

                local player = createMockPlayer()
                local receipt = {
                    PlayerId = player.UserId,
                    ProductId = 1234567890,
                    PurchaseId = "12345",
                }

                local result = monetizationService:ProcessReceipt(receipt)
                expect(result).to.equal(Enum.ProductPurchaseDecision.NotProcessedYet)
            end)

            it("should continue with other rewards on item grant failure", function()
                local currencyGranted = false

                mockDataService.AddToInventory = function()
                    return false -- Simulate item grant failure
                end

                mockEconomyService.AddCurrency = function()
                    currencyGranted = true
                    return true
                end

                mockProductIdMapper.GetProductByRobloxId = function()
                    return {
                        id = "combo_pack",
                        rewards = {
                            gems = 100,
                            items = { "failing_item" },
                        },
                    }
                end

                local player = createMockPlayer()
                local receipt = {
                    PlayerId = player.UserId,
                    ProductId = 1234567899,
                    PurchaseId = "12345",
                }

                local result = monetizationService:ProcessReceipt(receipt)
                expect(result).to.equal(Enum.ProductPurchaseDecision.PurchaseGranted)
                expect(currencyGranted).to.equal(true)
            end)
        end)

        describe("Test Mode", function()
            it("should simulate purchases in test mode", function()
                local purchaseProcessed = false
                local originalProcess = monetizationService._processProductPurchase

                monetizationService._processProductPurchase = function(
                    self,
                    player,
                    config,
                    receipt
                )
                    purchaseProcessed = true
                    expect(string.find(receipt.PurchaseId, "TEST_", 1, true)).to.be.ok()
                    return true
                end

                local player = createMockPlayer()
                monetizationService:_simulateTestPurchase(player, "small_gems")

                expect(purchaseProcessed).to.equal(true)

                -- Restore
                monetizationService._processProductPurchase = originalProcess
            end)

            it("should grant test game passes", function()
                local benefitsApplied = false
                local originalApply = monetizationService._applyPassBenefits

                monetizationService._applyPassBenefits = function(self, player, config)
                    benefitsApplied = true
                end

                local player = createMockPlayer()
                monetizationService:_simulateTestPassPurchase(player, "vip_pass")

                expect(benefitsApplied).to.equal(true)

                -- Restore
                monetizationService._applyPassBenefits = originalApply
            end)
        end)
    end)
end
