-- Network manifest validation and registry construction stay pure for CI.

local NetworkManifest = loadModule("src/Shared/Network/NetworkManifest.lua")
local SignalRegistry = loadModule("src/Shared/Network/SignalRegistry.lua")
local networkConfig = loadModule("configs/network.lua")

local function validClientPacket()
    return {
        name = "RequestSnapshot",
        transport = "reliable_event",
        direction = "client_to_server",
        authorization = "player",
        environments = { production = true, studio = true, test = true },
        delivery = "request",
        rate_limit = 10,
        handler = "LeaderboardService.GetSnapshot",
        schema = { kind = "tuple", arguments = {} },
    }
end

return function()
    describe("NetworkManifest", function()
        it("validates the live migrated packet declarations", function()
            local ok, err = NetworkManifest.validate(networkConfig)
            if not ok then
                error("network config invalid: " .. tostring(err))
            end
            expect(ok).to.equal(true)
            expect(networkConfig.packets.PetIndexUpdated.name).to.equal("PetIndexUpdated")
            expect(networkConfig.packets.AchievementCompleted.name).to.equal("AchievementCompleted")
            expect(networkConfig.packets.LeaderboardUpdated.name).to.equal("LeaderboardUpdated")
            expect(networkConfig.packets.UpgradeResult.name).to.equal("UpgradeResult")
            expect(networkConfig.packets.LevelUp_Claimed.name).to.equal("LevelUp_Claimed")
            expect(networkConfig.packets.LevelUp_OpenChoice.name).to.equal("LevelUp_OpenChoice")
            expect(networkConfig.packets.ZoneUnlockResult.name).to.equal("ZoneUnlockResult")
            expect(networkConfig.packets.ZoneTravelResult.name).to.equal("ZoneTravelResult")
            expect(networkConfig.packets.PurchaseItem.handler).to.equal(
                "EconomyService.PurchaseItem"
            )
            expect(networkConfig.packets.SellItem.rate_limit).to.equal(60)
            expect(networkConfig.packets.AdjustCurrency.authorization).to.equal("admin")
            expect(networkConfig.packets.ConvertCurrency.delivery).to.equal("request")
            expect(networkConfig.packets.PurchaseUpgrade.handler).to.equal(
                "UpgradeService.PurchaseUpgrade"
            )
            expect(networkConfig.packets.PurchaseResult.name).to.equal("PurchaseResult")
            expect(networkConfig.packets.GiveItemSuccess.name).to.equal("GiveItemSuccess")
            expect(networkConfig.packets.DeleteInventoryItem.authorization).to.equal("player")
            expect(networkConfig.packets.CleanupInventory.authorization).to.equal("admin")
            expect(networkConfig.packets.FixItemCategories.authorization).to.equal("admin")
            expect(networkConfig.packets.CleanOrphanedBuckets.authorization).to.equal("admin")
            expect(networkConfig.packets.TogglePetEquipped.rate_limit).to.equal(30)
            expect(networkConfig.packets.SetEquippedPets.handler).to.equal(
                "InventoryService.SetEquippedPets"
            )
            expect(networkConfig.packets.ToggleToolEquipped.delivery).to.equal("request")
            expect(networkConfig.packets.EnchantPetRequest.handler).to.equal(
                "EnchantService.RerollPetEnchant"
            )
            expect(networkConfig.packets.SaveDisplayPreferences.authorization).to.equal("player")
            expect(networkConfig.packets.ForceRegenerateAssets.authorization).to.equal("admin")
            expect(networkConfig.packets.UnlockZoneRequest.handler).to.equal(
                "ZoneService.UnlockZone"
            )
            expect(#networkConfig.packets.AutoTarget_ToggleFree.schema.arguments).to.equal(0)
            expect(networkConfig.packets.AutoTarget_RequestAttack.rate_limit).to.equal(120)
            expect(networkConfig.packets.HatchSettings_SetCount.schema.arguments[1].type).to.equal(
                "number"
            )
            expect(networkConfig.packets.HatchSettings_SetActionMode.schema.arguments[1].type).to.equal(
                "string"
            )
            expect(networkConfig.packets.Settings_SetPetFormation.delivery).to.equal("request")
            expect(networkConfig.packets.PetReportPositions.rate_limit).to.equal(900)
            expect(networkConfig.packets.InitiatePurchase.handler).to.equal(
                "MonetizationService.InitiatePurchase"
            )
            expect(#networkConfig.packets.GetOwnedPasses.schema.arguments).to.equal(0)
            expect(networkConfig.packets.GetProductInfo.rate_limit).to.equal(60)
            expect(networkConfig.packets.PurchaseError.topic).to.equal(
                "monetization.purchase_error"
            )
            expect(networkConfig.packets.OwnedPasses.delivery).to.equal("player")
            expect(networkConfig.packets.ProductInfo.name).to.equal("ProductInfo")
            expect(networkConfig.packets.FirstPurchaseBonus.name).to.equal("FirstPurchaseBonus")
            expect(networkConfig.packets.Breakables_Attack.rate_limit).to.equal(120)
            expect(networkConfig.packets.Squad_Recall.handler).to.equal("EnemyService.RecallPet")
            expect(networkConfig.packets.Squad_Summon.handler).to.equal("EnemyService.SummonPet")
            expect(networkConfig.packets.Power_ToggleActive.authorization).to.equal("player")
            expect(networkConfig.packets.Combat_SetAssist.rate_limit).to.equal(60)
            expect(networkConfig.packets.Combat_SelectPetTarget.delivery).to.equal("request")
            expect(networkConfig.packets.Hotbar_Activate.rate_limit).to.equal(180)
            expect(networkConfig.packets.Hotbar_Rebind.name).to.equal("Hotbar_Rebind")
            expect(#networkConfig.packets.Hotbar_RequestState.schema.arguments).to.equal(0)
            expect(networkConfig.packets.CurrencyUpdate.name).to.equal("CurrencyUpdate")
            expect(networkConfig.packets.PurchaseSuccess.name).to.equal("PurchaseSuccess")
            expect(networkConfig.packets.SellSuccess.name).to.equal("SellSuccess")
            expect(networkConfig.packets.EconomyError.name).to.equal("EconomyError")
            expect(networkConfig.packets.RealmTravelOffer.name).to.equal("RealmTravelOffer")
            expect(networkConfig.packets.EnchantPetResult.name).to.equal("EnchantPetResult")
            expect(networkConfig.packets.EnchantStationOpened.name).to.equal("EnchantStationOpened")
            expect(networkConfig.packets.AdminToolResult.name).to.equal("AdminToolResult")
            expect(networkConfig.packets.Combat_PetHit.name).to.equal("Combat_PetHit")
            expect(networkConfig.packets.Combat_Heal.name).to.equal("Combat_Heal")
            expect(networkConfig.packets.Combat_EnemyHit.name).to.equal("Combat_EnemyHit")
            expect(networkConfig.packets.Power_AreaFx.name).to.equal("Power_AreaFx")
            expect(networkConfig.packets.Hotbar_State.name).to.equal("Hotbar_State")
            expect(networkConfig.packets.Power_Cooldown.name).to.equal("Power_Cooldown")
            expect(networkConfig.packets.AutoTarget_Status.name).to.equal("AutoTarget_Status")
            expect(networkConfig.packets.PetPositionsRelay.name).to.equal("PetPositionsRelay")
            expect(networkConfig.packets.GameEvent.name).to.equal("GameEvent")
            expect(#networkConfig.packets.GameEvent.schema.arguments).to.equal(2)
            expect(networkConfig.packets.PlayerDebugInfo.name).to.equal("PlayerDebugInfo")
        end)

        it("builds the exact wire names through one registry", function()
            local created = {}
            local transport = {
                RemoteEvent = function(_, name)
                    table.insert(created, "event:" .. name)
                    return { name = name, kind = "event" }
                end,
                RemoteFunction = function(_, name)
                    table.insert(created, "function:" .. name)
                    return { name = name, kind = "function" }
                end,
            }
            local signals = SignalRegistry.build(networkConfig, transport)
            expect(signals.PetIndexUpdated.name).to.equal("PetIndexUpdated")
            expect(signals.AchievementCompleted.name).to.equal("AchievementCompleted")
            expect(signals.LeaderboardUpdated.name).to.equal("LeaderboardUpdated")
            expect(signals.UpgradeResult.name).to.equal("UpgradeResult")
            expect(signals.LevelUp_Claimed.name).to.equal("LevelUp_Claimed")
            expect(signals.LevelUp_OpenChoice.name).to.equal("LevelUp_OpenChoice")
            expect(signals.ZoneUnlockResult.name).to.equal("ZoneUnlockResult")
            expect(signals.ZoneTravelResult.name).to.equal("ZoneTravelResult")
            expect(signals.PurchaseItem.name).to.equal("PurchaseItem")
            expect(signals.SellItem.name).to.equal("SellItem")
            expect(signals.AdjustCurrency.name).to.equal("AdjustCurrency")
            expect(signals.ConvertCurrency.name).to.equal("ConvertCurrency")
            expect(signals.PurchaseUpgrade.name).to.equal("PurchaseUpgrade")
            expect(signals.PurchaseResult.name).to.equal("PurchaseResult")
            expect(signals.GiveItemSuccess.name).to.equal("GiveItemSuccess")
            expect(signals.DeleteInventoryItem.name).to.equal("DeleteInventoryItem")
            expect(signals.CleanupInventory.name).to.equal("CleanupInventory")
            expect(signals.FixItemCategories.name).to.equal("FixItemCategories")
            expect(signals.CleanOrphanedBuckets.name).to.equal("CleanOrphanedBuckets")
            expect(signals.TogglePetEquipped.name).to.equal("TogglePetEquipped")
            expect(signals.SetEquippedPets.name).to.equal("SetEquippedPets")
            expect(signals.ToggleToolEquipped.name).to.equal("ToggleToolEquipped")
            expect(signals.EnchantPetRequest.name).to.equal("EnchantPetRequest")
            expect(signals.SaveDisplayPreferences.name).to.equal("SaveDisplayPreferences")
            expect(signals.ForceRegenerateAssets.name).to.equal("ForceRegenerateAssets")
            expect(signals.UnlockZoneRequest.name).to.equal("UnlockZoneRequest")
            expect(signals.AutoTarget_ToggleFree.name).to.equal("AutoTarget_ToggleFree")
            expect(signals.AutoTarget_TogglePaid.name).to.equal("AutoTarget_TogglePaid")
            expect(signals.AutoTarget_SetMode.name).to.equal("AutoTarget_SetMode")
            expect(signals.AutoTarget_RequestAttack.name).to.equal("AutoTarget_RequestAttack")
            expect(signals.AutoDelete_SetFilters.name).to.equal("AutoDelete_SetFilters")
            expect(signals.HatchSettings_SetCount.name).to.equal("HatchSettings_SetCount")
            expect(signals.HatchSettings_SetActionMode.name).to.equal("HatchSettings_SetActionMode")
            expect(signals.HatchSettings_SetModes.name).to.equal("HatchSettings_SetModes")
            expect(signals.Settings_SetPetFormation.name).to.equal("Settings_SetPetFormation")
            expect(signals.Settings_SetPetAttackStyle.name).to.equal("Settings_SetPetAttackStyle")
            expect(signals.Settings_SetInventoryCardScale.name).to.equal(
                "Settings_SetInventoryCardScale"
            )
            expect(signals.Settings_SetEnemyLevelOffset.name).to.equal(
                "Settings_SetEnemyLevelOffset"
            )
            expect(signals.PetReportPositions.name).to.equal("PetReportPositions")
            expect(signals.InitiatePurchase.name).to.equal("InitiatePurchase")
            expect(signals.GetOwnedPasses.name).to.equal("GetOwnedPasses")
            expect(signals.GetProductInfo.name).to.equal("GetProductInfo")
            expect(signals.PurchaseError.name).to.equal("PurchaseError")
            expect(signals.OwnedPasses.name).to.equal("OwnedPasses")
            expect(signals.ProductInfo.name).to.equal("ProductInfo")
            expect(signals.FirstPurchaseBonus.name).to.equal("FirstPurchaseBonus")
            expect(signals.Breakables_Attack.name).to.equal("Breakables_Attack")
            expect(signals.Squad_Recall.name).to.equal("Squad_Recall")
            expect(signals.Squad_Summon.name).to.equal("Squad_Summon")
            expect(signals.Power_ToggleActive.name).to.equal("Power_ToggleActive")
            expect(signals.Combat_SetAssist.name).to.equal("Combat_SetAssist")
            expect(signals.Combat_SelectPetTarget.name).to.equal("Combat_SelectPetTarget")
            expect(signals.Hotbar_Activate.name).to.equal("Hotbar_Activate")
            expect(signals.Hotbar_Rebind.name).to.equal("Hotbar_Rebind")
            expect(signals.Hotbar_RequestState.name).to.equal("Hotbar_RequestState")
            expect(signals.CurrencyUpdate.name).to.equal("CurrencyUpdate")
            expect(signals.PurchaseSuccess.name).to.equal("PurchaseSuccess")
            expect(signals.SellSuccess.name).to.equal("SellSuccess")
            expect(signals.EconomyError.name).to.equal("EconomyError")
            expect(signals.RealmTravelOffer.name).to.equal("RealmTravelOffer")
            expect(signals.EnchantPetResult.name).to.equal("EnchantPetResult")
            expect(signals.EnchantStationOpened.name).to.equal("EnchantStationOpened")
            expect(signals.AdminToolResult.name).to.equal("AdminToolResult")
            expect(signals.Combat_PetHit.name).to.equal("Combat_PetHit")
            expect(signals.Combat_Heal.name).to.equal("Combat_Heal")
            expect(signals.Combat_EnemyHit.name).to.equal("Combat_EnemyHit")
            expect(signals.Power_AreaFx.name).to.equal("Power_AreaFx")
            expect(signals.Hotbar_State.name).to.equal("Hotbar_State")
            expect(signals.Power_Cooldown.name).to.equal("Power_Cooldown")
            expect(signals.AutoTarget_Status.name).to.equal("AutoTarget_Status")
            expect(signals.PetPositionsRelay.name).to.equal("PetPositionsRelay")
            expect(signals.GameEvent.name).to.equal("GameEvent")
            expect(signals.PlayerDebugInfo.name).to.equal("PlayerDebugInfo")
            expect(#created).to.equal(73)
        end)

        it("requires rate limits and handlers on client-origin packets", function()
            local packet = validClientPacket()
            packet.rate_limit = nil
            local ok =
                NetworkManifest.validate({ version = 1, packets = { RequestSnapshot = packet } })
            expect(ok).to.equal(false)

            packet.rate_limit = 10
            packet.handler = nil
            ok = NetworkManifest.validate({ version = 1, packets = { RequestSnapshot = packet } })
            expect(ok).to.equal(false)
        end)

        it("rejects key/name drift and unknown schema types", function()
            local packet = validClientPacket()
            packet.name = "DifferentName"
            local ok =
                NetworkManifest.validate({ version = 1, packets = { RequestSnapshot = packet } })
            expect(ok).to.equal(false)

            packet.name = "RequestSnapshot"
            packet.schema.arguments = { { name = "boardId", type = "mystery" } }
            ok = NetworkManifest.validate({ version = 1, packets = { RequestSnapshot = packet } })
            expect(ok).to.equal(false)
        end)

        it("keeps direction, authorization, and delivery internally consistent", function()
            local packet = validClientPacket()
            packet.authorization = "server"
            local ok =
                NetworkManifest.validate({ version = 1, packets = { RequestSnapshot = packet } })
            expect(ok).to.equal(false)

            packet.authorization = "player"
            packet.delivery = "broadcast"
            ok = NetworkManifest.validate({ version = 1, packets = { RequestSnapshot = packet } })
            expect(ok).to.equal(false)
        end)
    end)
end
