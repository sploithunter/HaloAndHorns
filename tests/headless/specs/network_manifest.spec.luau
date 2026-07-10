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
            expect(#created).to.equal(26)
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
