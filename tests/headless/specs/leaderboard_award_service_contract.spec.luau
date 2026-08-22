return function()
    describe("leaderboard durable award service contract", function()
        it("queues ProfileStore messages and grants only through RewardService", function()
            local delivery = readFile("src/Server/Services/AwardDeliveryService.lua")
            expect(delivery:find("profileStore:MessageAsync", 1, true)).to.be.ok()
            expect(delivery:find("self._rewardService:Grant", 1, true)).to.be.ok()
            expect(delivery:find("AwardDelivery.markClaimed", 1, true)).to.be.ok()
            expect(delivery:find("AwardDelivery.isExpired", 1, true)).to.be.ok()
            expect(delivery:find("award_discard_expired:", 1, true)).to.be.ok()
            expect(delivery:find("processed()", 1, true)).to.be.ok()
            local expiryCheck = delivery:find("if AwardDelivery.isExpired", 1, true)
            local grant = delivery:find("self._rewardService:Grant", 1, true)
            expect(expiryCheck < grant).to.equal(true)
            local queueFunction =
                delivery:find("function AwardDeliveryService:QueueForUser", 1, true)
            local preQueueExpiry = delivery:find(
                "if AwardDelivery.isExpired(messageOrError.award, now)",
                queueFunction,
                true
            )
            local profileMessage = delivery:find("profileStore:MessageAsync", queueFunction, true)
            expect(preQueueExpiry < profileMessage).to.equal(true)
            expect(
                delivery:find(
                    'fireGameEvent(player, notification.event or "award_delivered"',
                    1,
                    true
                )
            ).to.be.ok()
            local events = readFile("configs/game_events.lua")
            local client = readFile("src/Client/Systems/GameEvents.lua")
            local receipt = readFile("src/Client/UI/Components/AwardReceiptModal.lua")
            expect(events:find("award_receipt = {}", 1, true)).to.be.ok()
            expect(client:find("AwardReceiptModal.show(ctx)", 1, true)).to.be.ok()
            expect(receipt:find('confirm.Text = "Got it!"', 1, true)).to.be.ok()
            expect(receipt:find('item.bucket == "eggs"', 1, true)).to.be.ok()
            expect(receipt:find("petsConfig.egg_sources", 1, true)).to.be.ok()
            expect(receipt:find("confirm.SelectionImageObject = selectionImage", 1, true)).to.be.ok()
            expect(receipt:find('player:GetAttribute("InputMode") == "gamepad"', 1, true)).to.be.ok()
            expect(receipt:find("stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border", 1, true)).to.be.ok()
        end)

        it("settles only global public snapshots through the durable delivery boundary", function()
            local settlement = readFile("src/Server/Services/LeaderboardAwardService.lua")
            expect(settlement:find('snapshot.source ~= "global"', 1, true)).to.be.ok()
            expect(settlement:find("self._delivery:QueueForUser", 1, true)).to.be.ok()
            expect(settlement:find("LeaderboardWindowAward.advance", 1, true)).to.be.ok()
            expect(settlement:find("snapshot.roundStartedAt", 1, true)).to.be.ok()
            expect(settlement:find("window_started_at =", 1, true)).to.be.ok()
            expect(settlement:find("created_at = pending.window_ended_at", 1, true)).to.be.ok()
            expect(settlement:find("hide_internal_accounts == true", 1, true)).to.be.ok()
        end)

        it("uses fixed round stores and renders the authoritative round clock", function()
            local service = readFile("src/Server/Services/LeaderboardService.lua")
            local board = readFile("src/Server/Services/LeaderboardBoardService.lua")
            expect(service:find("ChallengeRun.fixedWindowBest", 1, true)).to.be.ok()
            expect(service:find('string.format("%s_r%d"', 1, true)).to.be.ok()
            expect(service:find("self:_rotateChallengeRounds(os.time(), true)", 1, true)).to.be.ok()
            expect(service:find("The datastore read crossed a reset boundary", 1, true)).to.be.ok()
            expect(board:find('"RoundClock"', 1, true)).to.be.ok()
            expect(board:find('"%02d:%02d:%02d"', 1, true)).to.be.ok()
            expect(board:find("countdown.Font = Enum.Font.GothamBlack", 1, true)).to.be.ok()
            expect(board:find('"RESET IN', 1, true)).never.to.be.ok()
        end)

        it("registers delivery unconditionally and settlement with leaderboards", function()
            local bootstrap = readFile("src/Server/init.server.lua")
            expect(bootstrap:find('"AwardDeliveryService"', 1, true)).to.be.ok()
            expect(bootstrap:find('"LeaderboardAwardService"', 1, true)).to.be.ok()
            expect(bootstrap:find('"leaderboards", "LeaderboardAwardService"', 1, true)).to.be.ok()
        end)
    end)
end
