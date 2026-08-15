--[[
    Compact native player-list presentation.
    Run: mise run test-headless
]]

local PlayerListStatus = loadModule("src/Shared/Game/PlayerListStatus.lua")

return function()
    describe("PlayerListStatus.rank", function()
        it("shows ordinary levels without extra words", function()
            expect(PlayerListStatus.rank(19, 0)).to.equal("19")
        end)

        it("replaces the capped level with crossed-swords veteran rank", function()
            expect(PlayerListStatus.rank(50, 72)).to.equal("⚔️ 72")
        end)
    end)

    describe("PlayerListStatus.status", function()
        it("uses compact entitlement icons", function()
            expect(PlayerListStatus.status({ vip = true, founder = true })).to.equal("👑 ⭐")
            expect(PlayerListStatus.status({})).to.equal("")
        end)
    end)

    describe("PlayerListStatus.location", function()
        it("formats Home and its origins", function()
            expect(PlayerListStatus.location({ layer = "base", area = "Spawn" })).to.equal("Home")
            expect(PlayerListStatus.location({ layer = "base", area = "Home_Ice" })).to.equal(
                "Home Ice"
            )
        end)

        it("formats deep realms compactly and unambiguously", function()
            expect(PlayerListStatus.location({
                layer = "heaven_2",
                realm = "heaven",
                area = "Heaven_2_Ice",
            })).to.equal("😇2 Ice")
            expect(PlayerListStatus.location({
                layer = "hell_2",
                realm = "hell",
                area = "Hell_2_Ice",
            })).to.equal("😈2 Ice")
        end)

        it("shows trial realm without exposing an instance id", function()
            expect(PlayerListStatus.location({ inMission = true, realm = "heaven" })).to.equal(
                "😇 Trial"
            )
            expect(PlayerListStatus.location({ inMission = true, realm = "hell" })).to.equal(
                "😈 Trial"
            )
        end)
    end)
end
