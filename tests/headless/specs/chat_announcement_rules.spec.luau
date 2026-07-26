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
    end)
end
