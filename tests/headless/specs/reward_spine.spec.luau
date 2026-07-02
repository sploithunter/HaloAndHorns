--[[
    Phase 7: Reward spine — RewardBundle / Condition / ClaimLogic / DailyStreak /
    ShopLogic. The unified core behind Quests, Daily, and Shop.
    Run: mise run test-headless
]]

local RewardBundle = loadModule("src/Shared/Game/RewardBundle.lua")
local Condition = loadModule("src/Shared/Game/Condition.lua")
local ClaimLogic = loadModule("src/Shared/Game/ClaimLogic.lua")
local DailyStreak = loadModule("src/Shared/Game/DailyStreak.lua")
local ShopLogic = loadModule("src/Shared/Game/ShopLogic.lua")

return function()
    describe("RewardBundle", function()
        it("normalizes every section so consumers never nil-check", function()
            local b = RewardBundle.normalize({ currencies = { coins = 100 } })
            expect(b.currencies.coins).to.equal(100)
            expect(#b.pets).to.equal(0)
            expect(next(b.slots)).to.equal(nil)
        end)
        it("merges: currencies/slots sum, lists concatenate", function()
            local m = RewardBundle.merge(
                { currencies = { coins = 100 }, items = { { id = "a" } } },
                { currencies = { coins = 50, gems = 2 }, items = { { id = "b" } } }
            )
            expect(m.currencies.coins).to.equal(150)
            expect(m.currencies.gems).to.equal(2)
            expect(#m.items).to.equal(2)
        end)
        it("detects an empty bundle", function()
            expect(RewardBundle.isEmpty({})).to.equal(true)
            expect(RewardBundle.isEmpty({ currencies = { coins = 1 } })).to.equal(false)
        end)
        it("carries and sums experience", function()
            expect(RewardBundle.normalize({ experience = 250 }).experience).to.equal(250)
            expect(RewardBundle.isEmpty({ experience = 50 })).to.equal(false)
            local m = RewardBundle.merge({ experience = 100 }, { experience = 150 })
            expect(m.experience).to.equal(250)
        end)
    end)

    describe("Condition", function()
        local snap =
            { counters = { breakables_broken = 37 }, level = 8, currencies = { coins = 1200 } }
        it("counter_at_least is met when the counter reaches the target", function()
            expect(
                Condition.isMet(
                    { type = "counter_at_least", counter = "breakables_broken", value = 50 },
                    snap
                )
            ).to.equal(false)
            expect(
                Condition.isMet(
                    { type = "counter_at_least", counter = "breakables_broken", value = 30 },
                    snap
                )
            ).to.equal(true)
        end)
        it("level_at_least reads the snapshot level", function()
            expect(Condition.isMet({ type = "level_at_least", value = 10 }, snap)).to.equal(false)
            expect(Condition.isMet({ type = "level_at_least", value = 8 }, snap)).to.equal(true)
        end)
        it("progress reports current/target/fraction for the UI", function()
            local p = Condition.progress(
                { type = "counter_at_least", counter = "breakables_broken", value = 50 },
                snap
            )
            expect(p.current).to.equal(37)
            expect(p.target).to.equal(50)
            expect(p.met).to.equal(false)
            expect(p.fraction > 0.73 and p.fraction < 0.75).to.equal(true)
        end)
        it("all_of requires every sub-condition", function()
            local c = {
                type = "all_of",
                of = {
                    { type = "level_at_least", value = 5 },
                    { type = "counter_at_least", counter = "breakables_broken", value = 100 },
                },
            }
            expect(Condition.isMet(c, snap)).to.equal(false)
        end)
        it("a nil condition is always met (gate handled elsewhere)", function()
            expect(Condition.isMet(nil, snap)).to.equal(true)
        end)
    end)

    describe("ClaimLogic", function()
        it("blocks an unmet gate", function()
            expect(ClaimLogic.canClaim(false, 0, {}).reason).to.equal("not_met")
        end)
        it("claim-once rejects a second claim", function()
            expect(ClaimLogic.canClaim(true, 0, {}).ok).to.equal(true)
            expect(ClaimLogic.canClaim(true, 1, {}).reason).to.equal("already_claimed")
        end)
        it("repeatable allows many claims", function()
            expect(ClaimLogic.canClaim(true, 5, { repeatable = true }).ok).to.equal(true)
        end)
        it("limit enforces a maximum", function()
            expect(ClaimLogic.canClaim(true, 0, { limit = 1 }).ok).to.equal(true)
            expect(ClaimLogic.canClaim(true, 1, { limit = 1 }).reason).to.equal("out_of_stock")
        end)
    end)

    describe("DailyStreak", function()
        local cfg = { max_gap_days = 1, cycle_length = 7 }
        it("first-ever claim starts the streak at day 1", function()
            local r = DailyStreak.resolve(nil, 100, 0, cfg)
            expect(r.claimable).to.equal(true)
            expect(r.newStreak).to.equal(1)
            expect(r.claimDay).to.equal(1)
        end)
        it("a consecutive day advances the streak", function()
            local r = DailyStreak.resolve(100, 101, 1, cfg)
            expect(r.newStreak).to.equal(2)
            expect(r.reset).to.equal(false)
        end)
        it("the same day cannot be claimed twice", function()
            local r = DailyStreak.resolve(100, 100, 1, cfg)
            expect(r.claimable).to.equal(false)
            expect(r.reason).to.equal("already_claimed_today")
        end)
        it("a missed day beyond the gap resets the streak", function()
            local r = DailyStreak.resolve(100, 105, 4, cfg)
            expect(r.newStreak).to.equal(1)
            expect(r.reset).to.equal(true)
        end)
        it("the calendar wraps at cycle_length", function()
            local r = DailyStreak.resolve(106, 107, 7, cfg)
            expect(r.newStreak).to.equal(8)
            expect(r.claimDay).to.equal(1) -- (8-1)%7 + 1
        end)
    end)

    describe("ShopLogic", function()
        local offer = { cost = { currencies = { coins = 1000 } }, limit = 1 }
        it("affordable checks balances", function()
            expect(ShopLogic.affordable(offer.cost, { coins = 1000 })).to.equal(true)
            expect(ShopLogic.affordable(offer.cost, { coins = 999 })).to.equal(false)
        end)
        it("rejects an unaffordable purchase with the missing currency", function()
            local r = ShopLogic.canPurchase(offer, { coins = 500 }, 0)
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("insufficient_funds")
            expect(r.currency).to.equal("coins")
        end)
        it("allows an affordable purchase", function()
            expect(ShopLogic.canPurchase(offer, { coins = 1000 }, 0).ok).to.equal(true)
        end)
        it("enforces the purchase limit", function()
            expect(ShopLogic.canPurchase(offer, { coins = 1000 }, 1).reason).to.equal(
                "out_of_stock"
            )
        end)
    end)
end
