local Rules = loadModule("src/Shared/Game/ChatAnnouncementRules.lua")
local livePets = loadModule("configs/pets.lua")
local liveConfig = loadModule("configs/chat_announcements.lua")

local pets = {
    rarity_order = {
        "common",
        "uncommon",
        "rare",
        "epic",
        "legendary",
        "mythic",
        "secret",
        "exclusive",
        "huge",
    },
    rarities = {
        legendary = { name = "Legendary", color = { R = 1, G = 0.84, B = 0 } },
        mythic = { name = "Mythical", color = { R = 1, G = 0, B = 1 } },
        secret = { name = "Secret", color = { R = 1, G = 0.55, B = 0 } },
        exclusive = { name = "Exclusive", color = { R = 0, G = 1, B = 1 } },
        huge = { name = "Huge", color = { R = 1, G = 0.35, B = 0.82 } },
    },
    variants = {
        basic = { name = "Basic" },
        golden = { name = "Golden" },
        rainbow = { name = "Rainbow" },
    },
    pets = {
        dragon = { display_name = "Dragon" },
    },
}

local config = {
    hatch = { minimum_rarity = "mythic", global_rarity = "huge" },
    team = { color_hex = "#62D8FF" },
    level_up = {
        color_hex = "#FFD95A",
        prefixes = { "Grats", "Congratulations", "GG" },
    },
    creator_luck = { color_hex = "#AA5AFF" },
    founders_legacy = { color_hex = "#FFC637" },
}

return function()
    describe("live chat announcement config", function()
        it("uses the pets rarity order as its threshold source of truth", function()
            local ranks = {}
            for rank, rarityId in ipairs(livePets.rarity_order) do
                ranks[rarityId] = rank
            end
            expect(ranks[liveConfig.hatch.minimum_rarity]).to.equal(ranks.mythic)
            expect(ranks[liveConfig.hatch.global_rarity]).to.equal(ranks.huge)
            expect(ranks[liveConfig.hatch.global_rarity] > ranks[liveConfig.hatch.minimum_rarity]).to.equal(
                true
            )
        end)
    end)

    describe("ChatAnnouncementRules hatch threshold", function()
        it("does not announce below Mythical", function()
            local payload = Rules.hatch(
                "Colorado Plays",
                { Pet = "dragon", RarityId = "legendary" },
                pets,
                config
            )
            expect(payload).to.equal(nil)
        end)

        it("announces Mythical through Exclusive in the current server", function()
            for _, rarityId in ipairs({ "mythic", "secret", "exclusive" }) do
                local payload = Rules.hatch(
                    "Colorado Plays",
                    { Pet = "dragon", RarityId = rarityId },
                    pets,
                    config
                )
                expect(payload.scope).to.equal("server")
                expect(payload.rarityId).to.equal(rarityId)
            end
        end)

        it("announces Huge globally with variant and family names", function()
            local payload = Rules.hatch(
                "Colorado Plays",
                { Pet = "dragon", Type = "rainbow", RarityId = "huge" },
                pets,
                config
            )
            expect(payload.scope).to.equal("global")
            expect(payload.text).to.equal(
                "🌎 HUGE HATCH! Colorado Plays hatched a Huge Rainbow Dragon!"
            )
        end)
    end)

    describe("ChatAnnouncementRules team sidekick", function()
        it("announces only when joining raises the player's combat level", function()
            local payload = Rules.teamSidekick("Sploit Hunter", "Colorado Plays", 19, 49, config)
            expect(payload.text).to.equal(
                "🤝 Sploit Hunter joined Colorado Plays — playing at level 49."
            )
            expect(Rules.teamSidekick("Peer", "Lead", 49, 49, config)).to.equal(nil)
            expect(Rules.teamSidekick("Exemplar", "Lead", 50, 49, config)).to.equal(nil)
        end)
    end)

    describe("ChatAnnouncementRules level up", function()
        it("uses the display name, claimed level, and configured congratulations", function()
            expect(Rules.levelUp("Sploit Hunter", 8, config, 1).text).to.equal(
                "🎉 Grats to Sploit Hunter on making level 8!"
            )
            expect(Rules.levelUp("Colorado Plays", 50, config, 2).text).to.equal(
                "🎉 Congratulations to Colorado Plays on making level 50!"
            )
            expect(Rules.levelUp("Waxillium", 4, config, 3).text).to.equal(
                "🎉 GG to Waxillium on making level 4!"
            )
        end)
    end)

    describe("ChatAnnouncementRules creator luck", function()
        it("uses the activating creator and exact 2x launch copy", function()
            local payload = Rules.creatorLuck("Colorado Plays", 2, config)
            expect(payload.kind).to.equal("creator_luck")
            expect(payload.scope).to.equal("server")
            expect(payload.colorHex).to.equal("#AA5AFF")
            expect(payload.text).to.equal("🍀 Colorado Plays joined! Hatch luck is now 2x!!!")
        end)
    end)

    describe("ChatAnnouncementRules Founder’s Legacy", function()
        it("announces the rare founder and exact server aura", function()
            local payload = Rules.foundersLegacy("Colorado Plays", 1.5, config)
            expect(payload.kind).to.equal("founders_legacy")
            expect(payload.scope).to.equal("server")
            expect(payload.colorHex).to.equal("#FFC637")
            expect(payload.text).to.equal(
                "👑 Colorado Plays entered with Founder's Legacy! A 1.5x hatch-luck aura is active!"
            )
        end)
    end)

    describe("runtime wiring", function()
        it("connects hatch, team, global relay, and TextChatService presentation", function()
            expect(
                string.find(
                    readFile("src/Server/Services/EggService.lua"),
                    "self._chatAnnouncementService:AnnounceHatches",
                    1,
                    true
                ) ~= nil
            ).to.equal(true)
            expect(
                string.find(
                    readFile("src/Server/Services/PartyService.lua"),
                    "self._chatAnnouncementService:AnnounceSidekick",
                    1,
                    true
                ) ~= nil
            ).to.equal(true)
            expect(
                string.find(
                    readFile("src/Server/Services/PlayerProgressionService.lua"),
                    "self._chatAnnouncementService:AnnounceLevel",
                    1,
                    true
                ) ~= nil
            ).to.equal(true)
            expect(
                string.find(
                    readFile("src/Server/Services/MeetCreatorService.lua"),
                    "self._chatAnnouncementService:AnnounceCreatorLuck",
                    1,
                    true
                ) ~= nil
            ).to.equal(true)
            local server = readFile("src/Server/Services/ChatAnnouncementService.lua")
            expect(string.find(server, "MessagingService:SubscribeAsync", 1, true) ~= nil).to.equal(
                true
            )
            expect(string.find(server, "MessagingService.PublishAsync", 1, true) ~= nil).to.equal(
                true
            )
            expect(
                string.find(
                    readFile("src/Client/Systems/ChatAnnouncements.lua"),
                    "DisplaySystemMessage",
                    1,
                    true
                ) ~= nil
            ).to.equal(true)
            expect(
                string.find(
                    readFile("src/Client/Systems/ChatAnnouncements.lua"),
                    "ChatMakeSystemMessage",
                    1,
                    true
                ) ~= nil
            ).to.equal(true)
        end)

        it("prefers a live TextChannel even when ChatVersion claims legacy", function()
            local client = readFile("src/Client/Systems/ChatAnnouncements.lua")
            expect(string.find(client, "ChatVersion ~=", 1, true)).to.equal(nil)
            expect(
                string.find(client, "if displayTextChannel(payload, colorHex) then", 1, true) ~= nil
            ).to.equal(true)
            expect(string.find(client, "displayLegacy(payload.text, colorHex)", 1, true) ~= nil).to.equal(
                true
            )
        end)

        it("persists a default-on client opt-out and exposes it in Settings", function()
            local client = readFile("src/Client/Systems/ChatAnnouncements.lua")
            local gameApi = readFile("src/Server/Services/GameAPIService.lua")
            local settingsPanel = readFile("src/Client/UI/Menus/SettingsPanel.lua")

            expect(string.find(client, "result.displayChatAnnouncements ~= false", 1, true) ~= nil).to.equal(
                true
            )
            expect(
                string.find(
                    client,
                    'callBus("settings.set", { displayChatAnnouncements = enabled })',
                    1,
                    true
                ) ~= nil
            ).to.equal(true)
            expect(string.find(client, "if enabled then", 1, true) ~= nil).to.equal(true)
            expect(string.find(gameApi, "prefs.displayChatAnnouncements ~= false", 1, true) ~= nil).to.equal(
                true
            )
            expect(
                string.find(gameApi, "data.Settings.ClientPrefs.displayChatAnnouncements", 1, true)
                    ~= nil
            ).to.equal(true)
            expect(string.find(settingsPanel, '"Chat Announcements"', 1, true) ~= nil).to.equal(
                true
            )
            expect(
                string.find(settingsPanel, "ChatAnnouncements.setEnabled(value)", 1, true) ~= nil
            ).to.equal(true)
        end)
    end)
end
