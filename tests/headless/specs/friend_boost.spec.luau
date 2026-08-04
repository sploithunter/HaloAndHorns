local FriendBoost = loadModule("src/Shared/Game/FriendBoost.lua")
local config = loadModule("configs/friend_boost.lua")

local function near(value, expected)
    return math.abs(value - expected) < 0.0001
end

return function()
    describe("FriendBoost launch tuning", function()
        it("grants 20% luck and 10% XP/coins per friend", function()
            local one = FriendBoost.bonuses(config, 1)
            expect(near(one.hatchLuck, 0.20)).to.equal(true)
            expect(near(one.xp, 0.10)).to.equal(true)
            expect(near(one.coins, 0.10)).to.equal(true)
        end)

        it("scales linearly through four friends", function()
            local four = FriendBoost.bonuses(config, 4)
            expect(four.friendCount).to.equal(4)
            expect(near(four.hatchLuck, 0.80)).to.equal(true)
            expect(near(four.xp, 0.40)).to.equal(true)
            expect(near(four.coins, 0.40)).to.equal(true)
        end)

        it("counts only the first four friends", function()
            local many = FriendBoost.bonuses(config, 20)
            expect(many.friendCount).to.equal(4)
            expect(near(many.hatchLuck, 0.80)).to.equal(true)
        end)

        it("reserves smaller post-launch values as a single phase switch", function()
            local later = table.clone(config)
            later.active_phase = "post_launch"
            local four = FriendBoost.bonuses(later, 4)
            expect(near(four.hatchLuck, 0.10)).to.equal(true)
            expect(near(four.xp, 0.20)).to.equal(true)
            expect(near(four.coins, 0.20)).to.equal(true)
        end)

        it("only recognizes gameplay coin currencies", function()
            expect(FriendBoost.isCoinCurrency("grass_coins")).to.equal(true)
            expect(FriendBoost.isCoinCurrency("coins")).to.equal(true)
            expect(FriendBoost.isCoinCurrency("gems")).to.equal(false)
            expect(FriendBoost.isCoinCurrency("hell_tokens")).to.equal(false)
        end)
    end)
end
