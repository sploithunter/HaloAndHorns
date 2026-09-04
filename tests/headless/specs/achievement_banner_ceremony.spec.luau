local config = loadModule("configs/achievement_banners.lua")
local network = loadModule("configs/network.lua")

return function()
    describe("achievement banner checkpoint ceremony", function()
        it("keeps the owner camera beat inside the configured checkpoint pause", function()
            local ceremony = config.ceremony
            local cameraSeconds = ceremony.camera_in_seconds
                + ceremony.hold_seconds
                + ceremony.camera_out_seconds
            expect(cameraSeconds <= ceremony.checkpoint_minimum_seconds).to.equal(true)
            expect(ceremony.safety_timeout_seconds <= ceremony.checkpoint_minimum_seconds).to.equal(
                true
            )
            expect(config.display.maximum <= #config.display.slots).to.equal(true)
            expect(config.display.slot_anchor).to.equal("top_center")
        end)

        it("fits every configured award across both mall-facing stair walls", function()
            local awardCount = 0
            for _ in pairs(config.awards) do
                awardCount += 1
            end
            expect(config.display.maximum >= awardCount).to.equal(true)
            expect(#config.display.slots).to.equal(8)
            for index, slot in ipairs(config.display.slots) do
                expect(slot.z > 0).to.equal(true)
                if index % 2 == 1 then
                    expect(slot.x < 0).to.equal(true)
                else
                    expect(slot.x > 0).to.equal(true)
                end
            end
        end)

        it("defines every award with a spawnable model and printable style", function()
            for _, award in pairs(config.awards) do
                expect(config.model.variants[award.variant]).to.be.ok()
                expect(config.styles[award.style]).to.be.ok()
                expect(type(award.trigger.fact)).to.equal("string")
                expect(type(award.trigger.at_least)).to.equal("number")
            end
        end)

        it("uses a server-only reliable owner presentation packet", function()
            local packet = network.packets.AchievementBannerCeremony
            expect(packet.direction).to.equal("server_to_client")
            expect(packet.delivery).to.equal("player")
            expect(packet.authorization).to.equal("server")
            expect(packet.transport).to.equal("reliable_event")
        end)

        it("persists awards and wires only the Merge checkpoint seam", function()
            local dataService = readFile("src/Server/Services/DataService.lua")
            local server = readFile("src/Server/init.server.lua")
            local merge = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            local client = readFile("src/Client/Systems/AchievementBannerController.lua")
            expect(dataService:find("AchievementBanners = {", 1, true)).to.be.ok()
            expect(server:find('"AchievementBannerService"', 1, true)).to.be.ok()
            expect(client:find("AchievementBannerCeremony).start()", 1, true)).to.be.ok()

            local checkpoint = merge:find("local reachedCheckpoint", 1, true)
            local presentation = merge:find("PresentCheckpoint(", checkpoint, true)
            local timer = merge:find("record.nextWaveAt = os.clock() + waveGap", checkpoint, true)
            expect(checkpoint).to.be.ok()
            expect(presentation > checkpoint).to.equal(true)
            expect(timer > presentation).to.equal(true)
            expect(merge:find('level = record.player:GetAttribute("Level")', checkpoint, true)).to.be.ok()
            expect(
                merge:find(
                    'veteran_level = record.player:GetAttribute("VetLevel")',
                    checkpoint,
                    true
                )
            ).to.be.ok()
            expect(merge:find("merge_wave = record.waveIndex", checkpoint, true)).to.be.ok()
            expect(merge:find("merge_egg_tier = record.maximumEggTier", checkpoint, true)).to.be.ok()
        end)

        it("never waits for a client acknowledgement before the next wave", function()
            local service = readFile("src/Server/Services/AchievementBannerService.lua")
            expect(service:find("FireClient(player", 1, true)).to.be.ok()
            expect(service:find("OnServerEvent", 1, true)).never.to.be.ok()
            expect(service:find("InvokeClient", 1, true)).never.to.be.ok()
        end)
    end)
end
