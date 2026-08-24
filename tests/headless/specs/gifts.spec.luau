local GiftDelivery = loadModule("src/Shared/Game/GiftDelivery.lua")
local GiftLogic = loadModule("src/Shared/Game/GiftLogic.lua")

local RARITIES = {
    "common",
    "uncommon",
    "rare",
    "epic",
    "legendary",
    "mythic",
    "secret",
    "exclusive",
    "huge",
}

local function gift(overrides)
    local value = {
        id = "gift-one",
        sender_user_id = 11,
        sender_name = "Giver",
        receiver_user_id = 22,
        sent_at = 100,
        rarity_id = "secret",
        record_key = "secret-uid",
        pet_record = {
            id = "abyssal_wyrm",
            variant = "rainbow",
            level = 17,
            enchantments = { { id = "power", level = 3 } },
            serial = 42,
        },
    }
    for key, child in pairs(overrides or {}) do
        value[key] = child
    end
    return value
end

return function()
    describe("GiftLogic receiver preferences", function()
        it("defaults malformed values to accept any", function()
            expect(GiftLogic.sanitizePreference(nil)).to.equal("any")
            expect(GiftLogic.sanitizePreference("broken")).to.equal("any")
            expect(GiftLogic.preferenceLabel(nil)).to.equal("Any gift")
        end)

        it("enforces every rarity threshold using the supplied order", function()
            expect(GiftLogic.accepts("any", "common", RARITIES)).to.equal(true)
            expect(GiftLogic.accepts("off", "huge", RARITIES)).to.equal(false)
            expect(GiftLogic.accepts("uncommon_plus", "common", RARITIES)).to.equal(false)
            expect(GiftLogic.accepts("uncommon_plus", "uncommon", RARITIES)).to.equal(true)
            expect(GiftLogic.accepts("rare_plus", "uncommon", RARITIES)).to.equal(false)
            expect(GiftLogic.accepts("rare_plus", "rare", RARITIES)).to.equal(true)
            expect(GiftLogic.accepts("mythic_plus", "legendary", RARITIES)).to.equal(false)
            expect(GiftLogic.accepts("mythic_plus", "mythic", RARITIES)).to.equal(true)
            expect(GiftLogic.accepts("mythic_plus", "secret", RARITIES)).to.equal(true)
            expect(GiftLogic.accepts("mythic_plus", "exclusive", RARITIES)).to.equal(true)
            expect(GiftLogic.accepts("mythic_plus", "huge", RARITIES)).to.equal(true)
        end)

        it("fails closed for a rarity absent from the configured order", function()
            expect(GiftLogic.accepts("any", "creator", RARITIES)).to.equal(false)
            local accepted, reason = GiftLogic.accepts("rare_plus", "creator", RARITIES)
            expect(accepted).to.equal(false)
            expect(reason).to.equal("unknown_rarity")
        end)

        it("resolves Huge and record overrides before compact-stack config fallback", function()
            local config = {
                getPet = function()
                    return { rarity_id = "rare" }
                end,
            }
            expect(GiftLogic.resolveRarity({ id = "a", huge = true }, config)).to.equal("huge")
            expect(GiftLogic.resolveRarity({ id = "a", rarity_id = "secret" }, config)).to.equal(
                "secret"
            )
            expect(GiftLogic.resolveRarity({ id = "a" }, config)).to.equal("rare")
        end)

        it("maps Huge explicitly into the Exclusive giver ranking", function()
            expect(GiftLogic.leaderboardCounter("huge")).to.equal("exclusive_gift_points")
            expect(GiftLogic.leaderboardCounter("exclusive")).to.equal("exclusive_gift_points")
            expect(GiftLogic.leaderboardCounter("secret")).to.equal("secret_gift_points")
            expect(GiftLogic.leaderboardCounter("mythic")).to.equal("mythical_gift_points")
            expect(GiftLogic.leaderboardCounter("legendary")).to.equal(nil)
        end)

        it("weights Basic, Golden, and Rainbow gifts at 1, 5, and 25 points", function()
            expect(GiftLogic.leaderboardPoints({ variant = "basic" })).to.equal(1)
            expect(GiftLogic.leaderboardPoints({ variant = "golden" })).to.equal(5)
            expect(GiftLogic.leaderboardPoints({ variant = "rainbow" })).to.equal(25)
            expect(GiftLogic.leaderboardPoints({})).to.equal(1)
            expect(GiftLogic.leaderboardPoints({ variant = "invented" })).to.equal(1)
        end)

        it("maps wrapper colors without revealing pets below their rarity band", function()
            expect(GiftLogic.presentationTier("legendary")).to.equal("standard")
            expect(GiftLogic.presentationTier("mythic")).to.equal("mythical")
            expect(GiftLogic.presentationTier("secret")).to.equal("secret")
            expect(GiftLogic.presentationTier("exclusive")).to.equal("exclusive")
            expect(GiftLogic.presentationTier("huge")).to.equal("exclusive")

            local tier, presentation = GiftLogic.resolvePresentation("secret", {
                presentations = {
                    secret = { replicated_model_name = "Crimson" },
                },
            })
            expect(tier).to.equal("secret")
            expect(presentation.replicated_model_name).to.equal("Crimson")
        end)

        it("tracks every weighted gift plus any qualifying category", function()
            local standard = GiftLogic.giverScores({
                rarity_id = "legendary",
                pet_record = { variant = "golden" },
            })
            expect(#standard).to.equal(1)
            expect(standard[1].counter_id).to.equal("all_gift_points")
            expect(standard[1].points).to.equal(5)

            local secret = GiftLogic.giverScores({
                rarity_id = "secret",
                pet_record = { variant = "rainbow" },
            })
            expect(#secret).to.equal(2)
            expect(secret[1].counter_id).to.equal("all_gift_points")
            expect(secret[1].points).to.equal(25)
            expect(secret[2].counter_id).to.equal("secret_gift_points")
            expect(secret[2].points).to.equal(25)
        end)

        it(
            "reconstructs point scoring for an outbox written before weights were persisted",
            function()
                local counter, points = GiftLogic.leaderboardScore({
                    rarity_id = "secret",
                    pet_record = { id = "a", variant = "rainbow" },
                })
                expect(counter).to.equal("secret_gift_points")
                expect(points).to.equal(25)

                local storedCounter, storedPoints = GiftLogic.leaderboardScore({
                    rarity_id = "mythic",
                    pet_record = { id = "b", variant = "basic" },
                }, 5)
                expect(storedCounter).to.equal("mythical_gift_points")
                expect(storedPoints).to.equal(5)
            end
        )
    end)

    describe("GiftDelivery durable contract", function()
        it("versions and deep-copies the exact pet message", function()
            local source = gift()
            local message = GiftDelivery.message(source)
            source.pet_record.level = 99
            source.pet_record.enchantments[1].level = 9

            expect(message.kind).to.equal("gift_delivery")
            expect(message.version).to.equal(1)
            expect(message.gift.pet_record.level).to.equal(17)
            expect(message.gift.pet_record.enchantments[1].level).to.equal(3)
            expect(GiftDelivery.validateMessage(message)).to.equal(true)
        end)

        it("rejects malformed identities, rarities, and pet records", function()
            local message = GiftDelivery.message(gift())
            message.gift.receiver_user_id = 0
            expect(GiftDelivery.validateMessage(message)).to.equal(false)
            message.gift.receiver_user_id = 22
            message.gift.rarity_id = "invented"
            expect(GiftDelivery.validateMessage(message)).to.equal(false)
            message.gift.rarity_id = "secret"
            message.gift.pet_record = {}
            expect(GiftDelivery.validateMessage(message)).to.equal(false)
        end)

        it("accepts negative Studio test identities only when explicitly enabled", function()
            local studioGift = gift({
                sender_user_id = -2,
                receiver_user_id = -1,
            })
            local message = GiftDelivery.message(studioGift, {
                allow_studio_user_ids = true,
            })

            expect(GiftDelivery.validateMessage(message)).to.equal(false)
            expect(GiftDelivery.validateMessage(message, {
                allow_studio_user_ids = true,
            })).to.equal(true)
            expect(GiftDelivery.isValidUserId(-1, {
                allow_studio_user_ids = true,
            })).to.equal(true)
            expect(GiftDelivery.isValidUserId(-1)).to.equal(false)
            expect(GiftDelivery.isValidUserId(0, {
                allow_studio_user_ids = true,
            })).to.equal(false)
            expect(GiftDelivery.isValidUserId(-1.5, {
                allow_studio_user_ids = true,
            })).to.equal(false)
        end)

        it("builds an unopened record without dropping the embedded pet", function()
            local source = gift()
            local wrapped = GiftDelivery.wrappedRecord(source)
            source.pet_record.serial = 1000

            expect(wrapped.id).to.equal("wrapped_pet_gift")
            expect(wrapped.gift_id).to.equal("gift-one")
            expect(wrapped.sender_name).to.equal("Giver")
            expect(wrapped.pet_id).to.equal("abyssal_wyrm")
            expect(wrapped.pet_record.serial).to.equal(42)
        end)

        it("keeps sender and receiver idempotency ledgers permanent", function()
            local data = {}
            expect(GiftDelivery.markReceived(data, "one")).to.equal(true)
            expect(GiftDelivery.markReceived(data, "one")).to.equal(false)
            expect(GiftDelivery.isReceived(data, "one")).to.equal(true)
            expect(GiftDelivery.markSent(data, "one")).to.equal(true)
            expect(GiftDelivery.markSent(data, "one")).to.equal(false)
            expect(GiftDelivery.isSent(data, "one")).to.equal(true)
        end)
    end)

    describe("gift feature wiring", function()
        it("persists sender escrow before queuing the receiver message", function()
            local service = readFile("src/Server/Services/GiftService.lua")
            local sendStart = service:find("function GiftService:Send", 1, true)
            local save = service:find("gift_outbox_before_message:", sendStart, true)
            local queue = service:find("self:_queueOutboxEntry(player, giftId)", save, true)
            expect(sendStart ~= nil).to.equal(true)
            expect(save ~= nil).to.equal(true)
            expect(queue ~= nil).to.equal(true)
            expect(save < queue).to.equal(true)

            local data = readFile("src/Server/Services/DataService.lua")
            expect(data:find("function DataService:SaveAndConfirm", 1, true) ~= nil).to.equal(true)
            expect(data:find("lastConfirmedRequestId", 1, true) ~= nil).to.equal(true)
        end)

        it("allows Studio test-player IDs without weakening live delivery validation", function()
            local service = readFile("src/Server/Services/GiftDeliveryService.lua")
            expect(service:find("allow_studio_user_ids = RunService:IsStudio()", 1, true) ~= nil).to.equal(
                true
            )
            expect(
                service:find("GiftDelivery.isValidUserId(id, MESSAGE_VALIDATION_OPTIONS)", 1, true)
                    ~= nil
            ).to.equal(true)
            expect(
                service:find(
                    "GiftDelivery.validateMessage(message, MESSAGE_VALIDATION_OPTIONS)",
                    1,
                    true
                ) ~= nil
            ).to.equal(true)
        end)

        it("opens the exact pet before consuming the wrapped record", function()
            local service = readFile("src/Server/Services/GiftService.lua")
            local openStart = service:find("function GiftService:OpenGift", 1, true)
            local grant = service:find("self._petTransferService:GrantRecord", openStart, true)
            local remove = service:find("GIFTS_BUCKET,", grant, true)
            expect(grant ~= nil).to.equal(true)
            expect(remove ~= nil).to.equal(true)
            expect(grant < remove).to.equal(true)
        end)

        it(
            "wires preferences, gift commands, inventory presentation, and opening reveal",
            function()
                local settings = readFile("src/Server/Services/SettingsService.lua")
                local api = readFile("src/Server/Services/GameAPIService.lua")
                local tradePanel = readFile("src/Client/UI/Menus/TradePanel.lua")
                local inventoryPanel = readFile("src/Client/UI/Menus/InventoryPanel.lua")
                local inventoryConfig = readFile("configs/inventory.lua")

                expect(settings:find('GiftAcceptance = "any"', 1, true) ~= nil).to.equal(true)
                expect(settings:find("SetGiftAcceptance", 1, true) ~= nil).to.equal(true)
                expect(api:find('bus:register("gift.set_preference"', 1, true) ~= nil).to.equal(
                    true
                )
                expect(api:find('bus:register("gift.send"', 1, true) ~= nil).to.equal(true)
                expect(api:find('bus:register("gift.open"', 1, true) ~= nil).to.equal(true)
                expect(tradePanel:find('"uncommon_plus", "Uncommon+"', 1, true) ~= nil).to.equal(
                    true
                )
                expect(tradePanel:find('self:_callBus("gift.send"', 1, true) ~= nil).to.equal(true)
                expect(inventoryConfig:find('name = "Gifts"', 1, true) ~= nil).to.equal(true)
                expect(inventoryPanel:find("_loadGiftsFromFolder", 1, true) ~= nil).to.equal(true)
                expect(inventoryPanel:find('InvokeServer("gift.open"', 1, true) ~= nil).to.equal(
                    true
                )
                expect(
                    inventoryPanel:find("StartPetRevealAnimation({ result.pet })", 1, true) ~= nil
                ).to.equal(true)
            end
        )

        it("publishes three top-three giver rankings from idempotent point counters", function()
            local stats = readFile("configs/stats.lua")
            local boards = readFile("configs/leaderboards.lua")
            for _, counter in ipairs({
                "mythical_gift_points",
                "secret_gift_points",
                "exclusive_gift_points",
            }) do
                expect(stats:find(counter, 1, true) ~= nil).to.equal(true)
                expect(boards:find('counter = "' .. counter .. '"', 1, true) ~= nil).to.equal(true)
            end
            expect(boards:find('id = "gift_exclusives"', 1, true) ~= nil).to.equal(true)
            expect(boards:find('id = "gift_secrets"', 1, true) ~= nil).to.equal(true)
            expect(boards:find('id = "gift_mythicals"', 1, true) ~= nil).to.equal(true)
            expect(boards:find("max_entries = 3", 1, true) ~= nil).to.equal(true)
            expect(boards:find("Basic 1 · Golden 5 · Rainbow 25", 1, true) ~= nil).to.equal(true)
            expect(boards:find("LB_GiftExclusives_v2", 1, true) ~= nil).to.equal(true)

            local service = readFile("src/Server/Services/GiftService.lua")
            expect(service:find("counter_points = GiftLogic.leaderboardPoints", 1, true) ~= nil).to.equal(
                true
            )
            expect(service:find("GiftLogic.giverScores", 1, true) ~= nil).to.equal(true)
            expect(stats:find("all_gift_points", 1, true) ~= nil).to.equal(true)
            expect(boards:find('counter = "all_gift_points"', 1, true) == nil).to.equal(true)
        end)

        it("traces every supplied icon and model through uploaded asset manifests", function()
            local gifts = readFile("configs/gifts.lua")
            local iconManifest = readFile("scripts/gift_icon_ids.json")
            local modelManifest = readFile("scripts/gift_model_ids.json")
            for _, assetId in ipairs({
                "74519461902415",
                "100900758738930",
                "131574195765765",
                "110223776207323",
            }) do
                expect(gifts:find(assetId, 1, true) ~= nil).to.equal(true)
                expect(iconManifest:find(assetId, 1, true) ~= nil).to.equal(true)
            end
            for _, assetId in ipairs({
                "75928057436522",
                "117665017287463",
                "138682808296676",
                "125462665041651",
            }) do
                expect(gifts:find(assetId, 1, true) ~= nil).to.equal(true)
                expect(modelManifest:find(assetId, 1, true) ~= nil).to.equal(true)
            end
        end)
    end)
end
