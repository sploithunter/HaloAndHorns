--[[
    RealmTokens — [unit] World S3 token-earning loop.
    Run: mise run test-headless
]]

local RealmTokens = loadModule("src/Shared/Game/RealmTokens.lua")
local layersConfig = loadModule("configs/layers.lua")

return function()
    describe("RealmTokens.currencyForLayer", function()
        it("base / neutral earns no token", function()
            expect(RealmTokens.currencyForLayer("base", layersConfig)).to.equal(nil)
            expect(RealmTokens.currencyForLayer(nil, layersConfig)).to.equal(nil)
        end)
        it("heaven earns light, hell earns shadow", function()
            expect(RealmTokens.currencyForLayer("heaven_2", layersConfig)).to.equal("light_tokens")
            expect(RealmTokens.currencyForLayer("hell_4", layersConfig)).to.equal("shadow_tokens")
        end)
    end)

    describe("RealmTokens.fromIncome", function()
        it("base earns nothing", function()
            expect(RealmTokens.fromIncome(1000, "base", layersConfig)).to.equal(nil)
        end)
        it("cuts the configured fraction of income in a realm", function()
            -- income_cut 0.1 -> 100 of 1000
            local g = RealmTokens.fromIncome(1000, "heaven_1", layersConfig)
            expect(g.currency).to.equal("light_tokens")
            expect(g.amount).to.equal(100)
        end)
        it("floors a small positive trickle to income_min (1)", function()
            -- 5 * 0.1 = 0.5 -> floor 0 -> raised to income_min 1
            local g = RealmTokens.fromIncome(5, "hell_1", layersConfig)
            expect(g.currency).to.equal("shadow_tokens")
            expect(g.amount).to.equal(1)
        end)
        it("zero / negative income earns nothing", function()
            expect(RealmTokens.fromIncome(0, "heaven_1", layersConfig)).to.equal(nil)
            expect(RealmTokens.fromIncome(-50, "heaven_1", layersConfig)).to.equal(nil)
        end)
    end)

    describe("RealmTokens.flat (conquest / hatch)", function()
        it("grants the configured flat amount in the player's realm", function()
            expect(RealmTokens.flat("conquest", "heaven_3", layersConfig).amount).to.equal(25)
            expect(RealmTokens.flat("hatch", "hell_2", layersConfig).amount).to.equal(2)
            expect(RealmTokens.flat("hatch", "hell_2", layersConfig).currency).to.equal(
                "shadow_tokens"
            )
        end)
        it("base earns nothing; unknown kind earns nothing", function()
            expect(RealmTokens.flat("conquest", "base", layersConfig)).to.equal(nil)
            expect(RealmTokens.flat("mystery", "heaven_1", layersConfig)).to.equal(nil)
        end)
    end)

    describe("RealmTokens.hatchLuck (depth = desirability)", function()
        it("base has no luck bonus", function()
            expect(RealmTokens.hatchLuck("base", layersConfig)).to.equal(0)
            expect(RealmTokens.hatchLuck(nil, layersConfig)).to.equal(0)
        end)
        it("scales with depth (0.1 per layer)", function()
            expect(RealmTokens.hatchLuck("heaven_3", layersConfig)).to.near(0.3, 1e-9)
            expect(RealmTokens.hatchLuck("hell_5", layersConfig)).to.near(0.5, 1e-9)
        end)
    end)
end
