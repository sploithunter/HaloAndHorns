--[[
    Feature 18: Multiplayer / Group Play — [unit] / [integration] scenarios.
    Run: mise run test-headless
]]

local PartyMath = loadModule("src/Shared/Game/PartyMath.lua")
local config = loadModule("configs/party.lua")

return function()
    describe("PartyMath.canJoin", function()
        -- tested RELATIVE to the configured cap (max_size is a live design knob: 2 for the
        -- duo era, 4 when the postponed 4-player UI ships — the math must hold either way)
        it("allows joining below max size", function()
            expect(PartyMath.canJoin(config.max_size - 1, config.max_size)).to.equal(true)
        end)
        it("rejects joining a full party", function()
            expect(PartyMath.canJoin(config.max_size, config.max_size)).to.equal(false)
        end)
    end)

    describe("PartyMath.inviteExpired", function()
        it("keeps a team invitation live before the configured timeout", function()
            expect(PartyMath.inviteExpired({ at = 100 }, 129, config.invite_timeout_seconds)).to.equal(
                false
            )
        end)

        it("expires a team invitation at 30 seconds", function()
            expect(PartyMath.inviteExpired({ at = 100 }, 130, config.invite_timeout_seconds)).to.equal(
                true
            )
        end)
    end)

    describe("team invitation privacy", function()
        it("defaults to Friends Only and supports Everyone or Off", function()
            expect(config.invite_privacy.default).to.equal("friends")
            expect(PartyMath.invitePrivacy(nil, config)).to.equal("friends")
            expect(PartyMath.invitePrivacy(nil, nil)).to.equal("friends")
            expect(PartyMath.invitePrivacy("everyone", config)).to.equal("everyone")
            expect(PartyMath.invitePrivacy("off", config)).to.equal("off")
            expect(PartyMath.invitePrivacyLabel("off", config)).to.equal("Invites off")
        end)

        it("rejects non-friends and rejects everyone when invites are off", function()
            local allowed, reason = PartyMath.canSendInvite({
                targetPrivacy = "friends",
                areFriends = false,
                cfg = config,
            })
            expect(allowed).to.equal(false)
            expect(reason).to.equal("friends_only")

            allowed, reason = PartyMath.canSendInvite({
                targetPrivacy = "off",
                areFriends = true,
                cfg = config,
            })
            expect(allowed).to.equal(false)
            expect(reason).to.equal("invites_off")
        end)

        it("wires all three choices into the Team menu and server gate", function()
            local panel = readFile("src/Client/UI/Menus/TeamPanel.lua")
            local service = readFile("src/Server/Services/PartyService.lua")
            expect(string.find(panel, '{ "everyone", "friends", "off" }', 1, true) ~= nil).to.equal(
                true
            )
            expect(string.find(panel, '"team.set_invite_privacy"', 1, true) ~= nil).to.equal(true)
            expect(string.find(service, "PartyMath.canSendInvite({", 1, true) ~= nil).to.equal(true)
        end)

        it("notifies both players when a Team request expires", function()
            local service = readFile("src/Server/Services/PartyService.lua")
            local panel = readFile("src/Client/UI/Menus/TeamPanel.lua")
            expect(
                string.find(
                    service,
                    'self:_notifyPlayerInviteOutcome(target, "request_expired", invite.from)',
                    1,
                    true
                ) ~= nil
            ).to.equal(true)
            expect(string.find(panel, 'outcome == "request_expired"', 1, true) ~= nil).to.equal(
                true
            )
            expect(string.find(panel, '"team_request_expired"', 1, true) ~= nil).to.equal(true)
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
