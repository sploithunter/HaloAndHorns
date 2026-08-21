return function()
    describe("leaderboard durable award service contract", function()
        it("queues ProfileStore messages and grants only through RewardService", function()
            local delivery = readFile("src/Server/Services/AwardDeliveryService.lua")
            expect(delivery:find("profileStore:MessageAsync", 1, true)).to.be.ok()
            expect(delivery:find("self._rewardService:Grant", 1, true)).to.be.ok()
            expect(delivery:find("AwardDelivery.markClaimed", 1, true)).to.be.ok()
            expect(delivery:find("processed()", 1, true)).to.be.ok()
            expect(
                delivery:find(
                    'fireGameEvent(player, notification.event or "award_delivered"',
                    1,
                    true
                )
            ).to.be.ok()
        end)

        it("settles only global public snapshots through the durable delivery boundary", function()
            local settlement = readFile("src/Server/Services/LeaderboardAwardService.lua")
            expect(settlement:find('snapshot.source ~= "global"', 1, true)).to.be.ok()
            expect(settlement:find("self._delivery:QueueForUser", 1, true)).to.be.ok()
            expect(settlement:find("LeaderboardWindowAward.advance", 1, true)).to.be.ok()
            expect(settlement:find("hide_internal_accounts == true", 1, true)).to.be.ok()
        end)

        it("registers delivery unconditionally and settlement with leaderboards", function()
            local bootstrap = readFile("src/Server/init.server.lua")
            expect(bootstrap:find('"AwardDeliveryService"', 1, true)).to.be.ok()
            expect(bootstrap:find('"LeaderboardAwardService"', 1, true)).to.be.ok()
            expect(bootstrap:find('"leaderboards", "LeaderboardAwardService"', 1, true)).to.be.ok()
        end)
    end)
end
