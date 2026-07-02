--[[
    Feature 18: Multiplayer / Group Play — [unit] / [integration] scenarios.
    Run: mise run test-headless
]]

local PartyMath = loadModule("src/Shared/Game/PartyMath.lua")
local config = loadModule("configs/party.lua")

return function()
    describe("PartyMath.canJoin", function()
        it("allows joining below max size", function()
            expect(PartyMath.canJoin(3, config.max_size)).to.equal(true)
        end)
        it("rejects joining a full party", function()
            expect(PartyMath.canJoin(4, config.max_size)).to.equal(false)
        end)
    end)

    describe("PartyMath.scaledHp", function()
        it("solo HP is unscaled", function()
            expect(PartyMath.scaledHp(1000, 1, 0.5)).to.equal(1000)
        end)
        it("4-player scaling: 1000 * (1 + 0.5*3) = 2500", function()
            expect(PartyMath.scaledHp(1000, 4, 0.5)).to.equal(2500)
        end)
    end)

    describe("PartyMath.splitLoot", function()
        it("splits a boss drop equally (100 lava / 4 = 25 each)", function()
            local share = PartyMath.splitLoot({ lava_coins = 100 }, 4)
            expect(share.lava_coins).to.equal(25)
        end)
    end)

    describe("PartyMath.attribution", function()
        it("credits each player proportionally and names the MVP", function()
            local a = PartyMath.attribution({ p1 = 300, p2 = 100 })
            expect(a.total).to.equal(400)
            expect(a.fractions.p1).to.near(0.75, 1e-6)
            expect(a.fractions.p2).to.near(0.25, 1e-6)
            expect(a.mvp).to.equal("p1")
        end)
    end)
end
