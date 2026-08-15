local EarlyBoostSampler = loadModule("src/Shared/Game/EarlyBoostSampler.lua")
local progression = loadModule("configs/player_progression.lua")
local config = progression.early_boost_sampler

return function()
    describe("EarlyBoostSampler", function()
        it("grants one distinct token at claimed levels 2, 3, and 4", function()
            expect(#config.grants).to.equal(3)
            expect(config.grants[1].claimed_level).to.equal(2)
            expect(config.grants[1].item_id).to.equal("double_coins_token")
            expect(config.grants[1].quantity).to.equal(1)
            expect(config.grants[2].claimed_level).to.equal(3)
            expect(config.grants[2].item_id).to.equal("titan_team_token")
            expect(config.grants[2].quantity).to.equal(1)
            expect(config.grants[3].claimed_level).to.equal(4)
            expect(config.grants[3].item_id).to.equal("double_xp_token")
            expect(config.grants[3].quantity).to.equal(1)
        end)

        it("references usable token definitions from the shared item catalog", function()
            local items = loadModule("configs/items.lua")
            local byId = {}
            for _, item in ipairs(items) do
                byId[item.id] = item
            end
            for _, grant in ipairs(config.grants) do
                local item = byId[grant.item_id]
                expect(item).never.to.equal(nil)
                expect(item.consumable).to.equal(true)
                expect(item.hotbar_type).to.equal("token")
            end
        end)

        it("waits for each claimed-level threshold", function()
            expect(#EarlyBoostSampler.pendingGrants({}, 1, config)).to.equal(0)
            expect(#EarlyBoostSampler.pendingGrants({}, 2, config)).to.equal(1)
            expect(#EarlyBoostSampler.pendingGrants({}, 3, config)).to.equal(2)
            expect(#EarlyBoostSampler.pendingGrants({}, 4, config)).to.equal(3)
        end)

        it("reconciles an existing player only once", function()
            local gameData = {}
            local pending = EarlyBoostSampler.pendingGrants(gameData, 20, config)
            expect(#pending).to.equal(3)
            for _, grant in ipairs(pending) do
                EarlyBoostSampler.markGrant(gameData, grant)
            end
            expect(#EarlyBoostSampler.pendingGrants(gameData, 20, config)).to.equal(0)
        end)

        it("restores only a failed grant marker", function()
            local gameData = {}
            local pending = EarlyBoostSampler.pendingGrants(gameData, 4, config)
            EarlyBoostSampler.markGrant(gameData, pending[1])
            EarlyBoostSampler.markGrant(gameData, pending[2])
            EarlyBoostSampler.restoreGrant(gameData, pending[2])
            local retry = EarlyBoostSampler.pendingGrants(gameData, 4, config)
            expect(#retry).to.equal(2)
            expect(retry[1].itemId).to.equal("titan_team_token")
            expect(retry[2].itemId).to.equal("double_xp_token")
        end)

        it("wires hotbar binding, banner feedback, and admin reset re-arming", function()
            local progressionSource = readFile("src/Server/Services/PlayerProgressionService.lua")
            local adminSource = readFile("src/Server/Services/AdminToolsService.lua")
            local gameEvents = loadModule("configs/game_events.lua")

            expect(progressionSource:find("EarlyBoostSampler.pendingGrants", 1, true)).to.be.ok()
            expect(progressionSource:find("AutoBindToken(player, grant.itemId)", 1, true)).to.be.ok()
            expect(progressionSource:find('fireGameEvent(player, "early_boost_awarded"', 1, true)).to.be.ok()
            expect(adminSource:find("prog:ResetEarlyBoostSampler(targetPlayer)", 1, true)).to.be.ok()
            expect(type(gameEvents.early_boost_awarded.banner)).to.equal("table")
        end)
    end)
end
