-- Network Bridge Configuration
-- Single source of truth for all client-server communication
return {
    version = 1,

    -- Manifest-driven packets. Signals builds these through SignalRegistry; the
    -- legacy bridge table below remains during the incremental migration.
    packets = {
        PetIndexUpdated = {
            name = "PetIndexUpdated",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "pet_index.updated",
            schema = {
                kind = "tuple",
                arguments = { { name = "snapshot", type = "table" } },
            },
        },
        AchievementCompleted = {
            name = "AchievementCompleted",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "achievements.completed",
            schema = {
                kind = "tuple",
                arguments = { { name = "payload", type = "table" } },
            },
        },
        LeaderboardUpdated = {
            name = "LeaderboardUpdated",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "broadcast",
            topic = "leaderboards.updated",
            schema = {
                kind = "tuple",
                arguments = { { name = "snapshot", type = "table" } },
            },
        },
        UpgradeResult = {
            name = "UpgradeResult",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "upgrades.purchase_result",
            schema = {
                kind = "tuple",
                arguments = { { name = "result", type = "table" } },
            },
        },
        LevelUp_Claimed = {
            name = "LevelUp_Claimed",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "progression.level_claimed",
            schema = {
                kind = "tuple",
                arguments = { { name = "payload", type = "table" } },
            },
        },
        LevelUp_OpenChoice = {
            name = "LevelUp_OpenChoice",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "progression.level_choice_opened",
            schema = { kind = "tuple", arguments = {} },
        },
        ZoneUnlockResult = {
            name = "ZoneUnlockResult",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "zones.unlock_result",
            schema = {
                kind = "tuple",
                arguments = { { name = "result", type = "table" } },
            },
        },
        ZoneTravelResult = {
            name = "ZoneTravelResult",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "zones.travel_result",
            schema = {
                kind = "tuple",
                arguments = { { name = "result", type = "table" } },
            },
        },
        CurrencyUpdate = {
            name = "CurrencyUpdate",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "economy.currency_updated",
            schema = {
                kind = "tuple",
                arguments = { { name = "update", type = "table" } },
            },
        },
        PurchaseSuccess = {
            name = "PurchaseSuccess",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "economy.purchase_succeeded",
            schema = {
                kind = "tuple",
                arguments = { { name = "result", type = "table" } },
            },
        },
        SellSuccess = {
            name = "SellSuccess",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "economy.sale_succeeded",
            schema = {
                kind = "tuple",
                arguments = { { name = "result", type = "table" } },
            },
        },
        EconomyError = {
            name = "EconomyError",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "economy.error",
            schema = {
                kind = "tuple",
                arguments = { { name = "error", type = "table" } },
            },
        },
        RealmTravelOffer = {
            name = "RealmTravelOffer",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "realms.travel_offered",
            schema = {
                kind = "tuple",
                arguments = { { name = "offer", type = "table" } },
            },
        },
        EnchantPetResult = {
            name = "EnchantPetResult",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "enchants.pet_result",
            schema = {
                kind = "tuple",
                arguments = { { name = "result", type = "table" } },
            },
        },
        EnchantStationOpened = {
            name = "EnchantStationOpened",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "enchants.station_opened",
            schema = {
                kind = "tuple",
                arguments = { { name = "station", type = "table" } },
            },
        },
        AdminToolResult = {
            name = "AdminToolResult",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "admin.tool_result",
            schema = {
                kind = "tuple",
                arguments = { { name = "result", type = "table" } },
            },
        },
    },

    bridges = {
        Economy = {
            description = "Economy system for purchases, sales, and shop operations",
            packets = {
                PurchaseItem = {
                    rateLimit = 30,
                    direction = "client_to_server",
                    validation = {
                        itemId = "string",
                        cost = "number",
                        currency = "string",
                    },
                    handler = "EconomyService.PurchaseItem",
                },

                SellItem = {
                    rateLimit = 60,
                    direction = "client_to_server",
                    validation = {
                        itemId = "string",
                        quantity = "number",
                    },
                    handler = "EconomyService.SellItem",
                },

                GetShopItems = {
                    rateLimit = 10,
                    direction = "client_to_server",
                    validation = {},
                    handler = "EconomyService.GetShopItems",
                },

                GetPlayerDebugInfo = {
                    rateLimit = 5,
                    direction = "client_to_server",
                    validation = {},
                    handler = "EconomyService.GetPlayerDebugInfo",
                },

                GiveTestItem = {
                    rateLimit = 5,
                    direction = "client_to_server",
                    validation = {},
                    handler = "EconomyService.GiveTestItem",
                },

                UseItem = {
                    rateLimit = 60,
                    direction = "client_to_server",
                    validation = {
                        itemId = "string",
                    },
                    handler = "EconomyService.UseItem",
                },

                GetActiveEffects = {
                    rateLimit = 10,
                    direction = "client_to_server",
                    validation = {},
                    handler = "EconomyService.GetActiveEffects",
                },

                -- Admin Panel Actions (Self-targeting - existing functionality)
                adjust_currency = {
                    rateLimit = 5,
                    direction = "client_to_server",
                    validation = {
                        currency = "string",
                        amount = "number",
                        targetPlayerId = "number?", -- Optional for backwards compatibility
                    },
                    handler = "EconomyService.AdjustCurrency",
                },

                set_currency = {
                    rateLimit = 5,
                    direction = "client_to_server",
                    validation = {
                        currency = "string",
                        amount = "number",
                        targetPlayerId = "number?", -- Optional for backwards compatibility
                    },
                    handler = "EconomyService.SetCurrency",
                },

                purchase_item = {
                    rateLimit = 100, -- 🔧 INCREASED FOR TESTING
                    direction = "client_to_server",
                    validation = {
                        itemId = "string",
                        cost = "number",
                        currency = "string",
                        targetPlayerId = "number?", -- Optional for backwards compatibility
                    },
                    handler = "EconomyService.AdminPurchaseItem",
                },

                reset_currencies = {
                    rateLimit = 2,
                    direction = "client_to_server",
                    validation = {
                        targetPlayerId = "number?", -- Optional for backwards compatibility
                    },
                    handler = "EconomyService.ResetCurrencies",
                },

                -- Admin Player Management Actions (NEW)
                get_player_list = {
                    rateLimit = 10,
                    direction = "client_to_server",
                    validation = {},
                    handler = "AdminService.GetAllPlayersForAdmin",
                },

                get_player_data = {
                    rateLimit = 10,
                    direction = "client_to_server",
                    validation = {
                        targetPlayerId = "number",
                    },
                    handler = "DataService.GetPlayerData",
                },

                teleport_player = {
                    rateLimit = 5,
                    direction = "client_to_server",
                    validation = {
                        targetPlayerId = "number",
                        position = "table", -- {x, y, z}
                    },
                    handler = "AdminService.TeleportPlayer",
                },

                kick_player = {
                    rateLimit = 2,
                    direction = "client_to_server",
                    validation = {
                        targetPlayerId = "number",
                        reason = "string?",
                    },
                    handler = "AdminService.KickPlayer",
                },

                EconomyError = {
                    rateLimit = 5,
                    direction = "server_to_client",
                    validation = {
                        error = "string",
                        code = "string",
                    },
                    handler = "client.showError",
                },

                PlayerDebugInfo = {
                    rateLimit = 5,
                    direction = "server_to_client",
                    validation = {
                        inventory = "table",
                        currencies = "table",
                    },
                    handler = "client.showDebugInfo",
                },

                ShopItems = {
                    rateLimit = 5,
                    direction = "server_to_client",
                    validation = {
                        items = "table",
                    },
                    handler = "client.showShopItems",
                },

                CurrencyUpdate = {
                    rateLimit = 20,
                    direction = "server_to_client",
                    validation = {
                        currency = "string",
                        amount = "number",
                        change = "number",
                    },
                    handler = "client.updateCurrency",
                },

                PurchaseSuccess = {
                    rateLimit = 20,
                    direction = "server_to_client",
                    validation = {
                        itemId = "string",
                        quantity = "number",
                        price = "table",
                    },
                    handler = "client.showPurchaseSuccess",
                },

                SellSuccess = {
                    rateLimit = 20,
                    direction = "server_to_client",
                    validation = {
                        itemId = "string",
                        quantity = "number",
                        sellPrice = "table",
                    },
                    handler = "client.showSellSuccess",
                },

                ActiveEffects = {
                    rateLimit = 10,
                    direction = "server_to_client",
                    validation = {
                        effects = "table",
                    },
                },

                EconomyUpdate = {
                    rateLimit = 20,
                    direction = "server_to_client",
                    validation = {
                        currency = "string",
                        amount = "number",
                        reason = "string",
                    },
                    handler = "client.updateCurrency",
                },
            },
        },

        PlayerData = {
            description = "Player data synchronization",
            packets = {
                DataLoaded = {
                    rateLimit = 5,
                    direction = "server_to_client",
                    validation = {
                        playerData = "table",
                    },
                    handler = "client.loadPlayerData",
                },

                DataUpdate = {
                    rateLimit = 10,
                    direction = "server_to_client",
                    validation = {
                        field = "string",
                        value = "any",
                    },
                    handler = "client.updatePlayerData",
                },
            },
        },

        Combat = {
            description = "Combat system for PvP and PvE",
            packets = {
                DealDamage = {
                    rateLimit = 20,
                    direction = "client_to_server",
                    validation = {
                        targetId = "string",
                        damage = "number",
                        weaponId = "string",
                    },
                    handler = "CombatService.DealDamage",
                },
            },
        },

        Monetization = {
            description = "Monetization system for Robux purchases and game passes",
            packets = {
                InitiatePurchase = {
                    rateLimit = 10, -- 10 purchase attempts per minute
                    direction = "client_to_server",
                    validation = {
                        productId = "string",
                        productType = "string",
                    },
                    handler = "MonetizationService.InitiatePurchase",
                },
                GetOwnedPasses = {
                    rateLimit = 30, -- 30 checks per minute
                    direction = "client_to_server",
                    validation = {},
                    handler = "MonetizationService.GetOwnedPasses",
                },
                GetProductInfo = {
                    rateLimit = 60, -- 60 info requests per minute
                    direction = "client_to_server",
                    validation = {
                        productId = "string",
                    },
                    handler = "MonetizationService.GetProductInfo",
                },
                PurchaseSuccess = {
                    rateLimit = 20,
                    direction = "server_to_client",
                    validation = {
                        type = "string",
                        id = "string",
                        rewards = "table",
                    },
                    handler = "client.showPurchaseSuccess",
                },
                PurchaseError = {
                    rateLimit = 20,
                    direction = "server_to_client",
                    validation = {
                        message = "string",
                    },
                    handler = "client.showPurchaseError",
                },
                OwnedPasses = {
                    rateLimit = 10,
                    direction = "server_to_client",
                    validation = {
                        passes = "table",
                    },
                    handler = "client.updateOwnedPasses",
                },
                ProductInfo = {
                    rateLimit = 10,
                    direction = "server_to_client",
                    validation = {
                        id = "string",
                        name = "string",
                        price_robux = "number",
                    },
                    handler = "client.showProductInfo",
                },
                FirstPurchaseBonus = {
                    rateLimit = 5,
                    direction = "server_to_client",
                    validation = {
                        gems = "number",
                        coins = "number",
                    },
                    handler = "client.showFirstPurchaseBonus",
                },
            },
        },
    },

    validators = {
        -- Basic validation for packets with no required data
        basicValidator = function(data)
            return true
        end,

        -- Validation for item purchases
        itemPurchaseValidator = function(data)
            return type(data.itemId) == "string"
                and data.itemId:match("^[a-z_]+$")
                and #data.itemId <= 50
                and type(data.cost) == "number"
                and data.cost > 0
                and type(data.currency) == "string"
        end,

        -- Validation for item sales
        itemSellValidator = function(data)
            return type(data.itemId) == "string"
                and type(data.quantity) == "number"
                and data.quantity > 0
                and data.quantity <= 100
        end,

        -- Validation for Robux purchases
        purchaseValidator = function(data)
            return type(data.productId) == "string"
                and data.productId:match("^[a-z_]+$")
                and #data.productId <= 50
                and (data.productType == "product" or data.productType == "gamepass")
        end,

        -- Validation for product info requests
        productInfoValidator = function(data)
            return type(data.productId) == "string"
                and data.productId:match("^[a-z_]+$")
                and #data.productId <= 50
        end,
    },
}
