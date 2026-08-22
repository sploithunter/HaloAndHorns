local AwardDelivery = loadModule("src/Shared/Game/AwardDelivery.lua")
local rewardsConfig = loadModule("configs/rewards.lua")

return function()
    describe("AwardDelivery", function()
        it("builds and validates a versioned durable award message", function()
            local message = AwardDelivery.message({
                id = "leaderboard:range_current:100",
                source = "leaderboard:range_current",
                bundle = { currencies = { gems = 100 } },
            })
            local ok, reason = AwardDelivery.validateMessage(message)
            expect(ok).to.equal(true)
            expect(reason).to.equal(nil)
            expect(message.kind).to.equal("award_delivery")
            expect(message.version).to.equal(1)
        end)

        it("stamps a stable 30-day claim deadline and expires at the boundary", function()
            local seconds = AwardDelivery.DEFAULT_UNCLAIMED_EXPIRY_SECONDS
            expect(rewardsConfig.delivery.unclaimed_expiry_seconds).to.equal(seconds)
            local message = AwardDelivery.message({
                id = "leaderboard:range_current:100",
                created_at = 100,
                bundle = { currencies = { gems = 100 } },
            }, {
                now = 500,
                expiry_seconds = seconds,
            })

            expect(message.award.created_at).to.equal(100)
            expect(message.award.queued_at).to.equal(500)
            expect(message.award.expires_at).to.equal(100 + seconds)
            expect(AwardDelivery.isExpired(message.award, 100 + seconds - 1)).to.equal(false)
            expect(AwardDelivery.isExpired(message.award, 100 + seconds)).to.equal(true)
        end)

        it("does not renew an explicit deadline when a stable award is retried", function()
            local message = AwardDelivery.message({
                id = "leaderboard:range_current:100",
                created_at = 100,
                expires_at = 200,
                bundle = { currencies = { gems = 100 } },
            }, {
                now = 190,
                expiry_seconds = 999,
            })

            expect(message.award.expires_at).to.equal(200)
            expect(message.award.queued_at).to.equal(190)
        end)

        it(
            "keeps legacy timestamp-free messages valid without inventing an expiry on receipt",
            function()
                local message = AwardDelivery.message({
                    id = "legacy",
                    bundle = { currencies = { gems = 1 } },
                })
                local ok = AwardDelivery.validateMessage(message)
                expect(ok).to.equal(true)
                expect(AwardDelivery.isExpired(message.award, 999999)).to.equal(false)
            end
        )

        it("rejects malformed messages without claiming unrelated profile messages", function()
            local ok, reason = AwardDelivery.validateMessage({ kind = "trade_receipt" })
            expect(ok).to.equal(false)
            expect(reason).to.equal("not_award_delivery")

            ok, reason = AwardDelivery.validateMessage({
                kind = "award_delivery",
                version = 1,
                award = { id = "missing_bundle" },
            })
            expect(ok).to.equal(false)
            expect(reason).to.equal("invalid_bundle")
        end)

        it("deduplicates stable ids and caps the persisted claim ledger", function()
            local data = {}
            expect(AwardDelivery.markClaimed(data, "one", 10, 2)).to.equal(true)
            expect(AwardDelivery.markClaimed(data, "one", 11, 2)).to.equal(false)
            expect(AwardDelivery.markClaimed(data, "two", 12, 2)).to.equal(true)
            expect(AwardDelivery.markClaimed(data, "three", 13, 2)).to.equal(true)

            expect(AwardDelivery.isClaimed(data, "one")).to.equal(false)
            expect(AwardDelivery.isClaimed(data, "two")).to.equal(true)
            expect(AwardDelivery.isClaimed(data, "three")).to.equal(true)
            expect(#data.GameData.AwardDelivery.order).to.equal(2)
        end)
    end)
end
