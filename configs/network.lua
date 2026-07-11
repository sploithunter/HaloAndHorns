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
        PurchaseItem = {
            name = "PurchaseItem",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 30,
            handler = "EconomyService.PurchaseItem",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        SellItem = {
            name = "SellItem",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 60,
            handler = "EconomyService.SellItem",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        AdjustCurrency = {
            name = "AdjustCurrency",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "admin",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 20,
            handler = "EconomyService.AdjustCurrency",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        ConvertCurrency = {
            name = "ConvertCurrency",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 20,
            handler = "EconomyService.ConvertCurrency",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        PurchaseUpgrade = {
            name = "PurchaseUpgrade",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 10,
            handler = "UpgradeService.PurchaseUpgrade",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        PurchaseResult = {
            name = "PurchaseResult",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "economy.request_result",
            schema = {
                kind = "tuple",
                arguments = { { name = "result", type = "table" } },
            },
        },
        GiveItemSuccess = {
            name = "GiveItemSuccess",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "economy.test_item_granted",
            schema = {
                kind = "tuple",
                arguments = { { name = "result", type = "table" } },
            },
        },
        DeleteInventoryItem = {
            name = "DeleteInventoryItem",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 30,
            handler = "InventoryService.DeleteInventoryItem",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        CleanupInventory = {
            name = "CleanupInventory",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "admin",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 5,
            handler = "InventoryService.CleanupInventory",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        FixItemCategories = {
            name = "FixItemCategories",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "admin",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 5,
            handler = "InventoryService.FixItemCategories",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        CleanOrphanedBuckets = {
            name = "CleanOrphanedBuckets",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "admin",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 5,
            handler = "InventoryService.CleanOrphanedBuckets",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        TogglePetEquipped = {
            name = "TogglePetEquipped",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 30,
            handler = "InventoryService.TogglePetEquipped",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        SetEquippedPets = {
            name = "SetEquippedPets",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 20,
            handler = "InventoryService.SetEquippedPets",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        ToggleToolEquipped = {
            name = "ToggleToolEquipped",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 20,
            handler = "InventoryService.ToggleToolEquipped",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        EnchantPetRequest = {
            name = "EnchantPetRequest",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 10,
            handler = "EnchantService.RerollPetEnchant",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        SaveDisplayPreferences = {
            name = "SaveDisplayPreferences",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 30,
            handler = "SettingsService.SaveDisplayPreferences",
            schema = {
                kind = "tuple",
                arguments = { { name = "preferences", type = "table" } },
            },
        },
        ForceRegenerateAssets = {
            name = "ForceRegenerateAssets",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "admin",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 2,
            handler = "AssetPreloadService.ForceRegenerateAssets",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        UnlockZoneRequest = {
            name = "UnlockZoneRequest",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 10,
            handler = "ZoneService.UnlockZone",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        AutoTarget_ToggleFree = {
            name = "AutoTarget_ToggleFree",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 20,
            handler = "AutoTargetService.ToggleFree",
            schema = { kind = "tuple", arguments = {} },
        },
        AutoTarget_TogglePaid = {
            name = "AutoTarget_TogglePaid",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 20,
            handler = "AutoTargetService.TogglePaid",
            schema = { kind = "tuple", arguments = {} },
        },
        AutoTarget_SetMode = {
            name = "AutoTarget_SetMode",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 20,
            handler = "AutoTargetService.SetAutoTargetMode",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        AutoTarget_RequestAttack = {
            name = "AutoTarget_RequestAttack",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 120,
            handler = "AutoTargetService.RequestAutoTargetAttack",
            schema = { kind = "tuple", arguments = {} },
        },
        AutoDelete_SetFilters = {
            name = "AutoDelete_SetFilters",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 20,
            handler = "AutoTargetService.SetAutoDeleteFilters",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        HatchSettings_SetCount = {
            name = "HatchSettings_SetCount",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 20,
            handler = "SettingsService.SetHatchSelectedCount",
            schema = {
                kind = "tuple",
                arguments = { { name = "count", type = "number" } },
            },
        },
        HatchSettings_SetActionMode = {
            name = "HatchSettings_SetActionMode",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 20,
            handler = "SettingsService.SetHatchActionMode",
            schema = {
                kind = "tuple",
                arguments = { { name = "actionMode", type = "string" } },
            },
        },
        HatchSettings_SetModes = {
            name = "HatchSettings_SetModes",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 20,
            handler = "SettingsService.SetHatchModes",
            schema = {
                kind = "tuple",
                arguments = { { name = "modes", type = "table" } },
            },
        },
        Settings_SetPetFormation = {
            name = "Settings_SetPetFormation",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 20,
            handler = "SettingsService.SetPetFormation",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        Settings_SetPetAttackStyle = {
            name = "Settings_SetPetAttackStyle",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 20,
            handler = "SettingsService.SetPetAttackStyle",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        Settings_SetInventoryCardScale = {
            name = "Settings_SetInventoryCardScale",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 20,
            handler = "SettingsService.SetInventoryCardScale",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        Settings_SetEnemyLevelOffset = {
            name = "Settings_SetEnemyLevelOffset",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 20,
            handler = "SettingsService.SetEnemyLevelOffset",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        PetReportPositions = {
            name = "PetReportPositions",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 900,
            handler = "PetFollowService.ReportPositions",
            schema = {
                kind = "tuple",
                arguments = { { name = "positions", type = "table" } },
            },
        },
        InitiatePurchase = {
            name = "InitiatePurchase",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 10,
            handler = "MonetizationService.InitiatePurchase",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        GetOwnedPasses = {
            name = "GetOwnedPasses",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 30,
            handler = "MonetizationService.GetOwnedPasses",
            schema = { kind = "tuple", arguments = {} },
        },
        GetProductInfo = {
            name = "GetProductInfo",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 60,
            handler = "MonetizationService.GetProductInfo",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
            },
        },
        PurchaseError = {
            name = "PurchaseError",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "monetization.purchase_error",
            schema = {
                kind = "tuple",
                arguments = { { name = "error", type = "table" } },
            },
        },
        OwnedPasses = {
            name = "OwnedPasses",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "monetization.owned_passes",
            schema = {
                kind = "tuple",
                arguments = { { name = "snapshot", type = "table" } },
            },
        },
        ProductInfo = {
            name = "ProductInfo",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "monetization.product_info",
            schema = {
                kind = "tuple",
                arguments = { { name = "product", type = "table" } },
            },
        },
        FirstPurchaseBonus = {
            name = "FirstPurchaseBonus",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "monetization.first_purchase_bonus",
            schema = {
                kind = "tuple",
                arguments = { { name = "rewards", type = "table" } },
            },
        },
        Breakables_Attack = {
            name = "Breakables_Attack",
            transport = "reliable_event",
            direction = "client_to_server",
            authorization = "player",
            environments = { production = true, studio = true, test = true },
            delivery = "request",
            rate_limit = 120,
            handler = "BreakableService.Attack",
            schema = {
                kind = "tuple",
                arguments = { { name = "request", type = "table" } },
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
        Combat_PetHit = {
            name = "Combat_PetHit",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "combat.pet_hit",
            schema = {
                kind = "tuple",
                arguments = { { name = "hit", type = "table" } },
            },
        },
        Combat_Heal = {
            name = "Combat_Heal",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "broadcast",
            topic = "combat.heal",
            schema = {
                kind = "tuple",
                arguments = { { name = "heal", type = "table" } },
            },
        },
        Combat_EnemyHit = {
            name = "Combat_EnemyHit",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "broadcast",
            topic = "combat.enemy_hit",
            schema = {
                kind = "tuple",
                arguments = { { name = "hit", type = "table" } },
            },
        },
        Power_AreaFx = {
            name = "Power_AreaFx",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "broadcast",
            topic = "powers.area_fx",
            schema = {
                kind = "tuple",
                arguments = { { name = "effect", type = "table" } },
            },
        },
        Hotbar_State = {
            name = "Hotbar_State",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "hotbar.state",
            schema = {
                kind = "tuple",
                arguments = { { name = "state", type = "table" } },
            },
        },
        Power_Cooldown = {
            name = "Power_Cooldown",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "powers.cooldown",
            schema = {
                kind = "tuple",
                arguments = { { name = "cooldown", type = "table" } },
            },
        },
        AutoTarget_Status = {
            name = "AutoTarget_Status",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "auto_target.status",
            schema = {
                kind = "tuple",
                arguments = { { name = "status", type = "table" } },
            },
        },
        PetPositionsRelay = {
            name = "PetPositionsRelay",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "pets.positions_relayed",
            schema = {
                kind = "tuple",
                arguments = { { name = "positions", type = "table" } },
            },
        },
        GameEvent = {
            name = "GameEvent",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "game_events.fired",
            schema = {
                kind = "tuple",
                arguments = {
                    { name = "name", type = "string" },
                    { name = "context", type = "table" },
                },
            },
        },
        PlayerDebugInfo = {
            name = "PlayerDebugInfo",
            transport = "reliable_event",
            direction = "server_to_client",
            authorization = "server",
            environments = { production = true, studio = true, test = true },
            delivery = "player",
            topic = "debug.player_info",
            schema = {
                kind = "tuple",
                arguments = { { name = "snapshot", type = "table" } },
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
