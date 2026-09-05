local InternalAccounts = loadModule("src/Shared/Game/InternalAccounts.lua")

return function()
    describe("Week 4 release readiness", function()
        it("uses one DST-aware Mountain calendar day per award round", function()
            local challenge = loadModule("configs/challenge_runs.lua")
            expect(challenge.leaderboard.fixed_rounds).to.equal(true)
            expect(challenge.leaderboard.window_seconds).to.equal(24 * 60 * 60)
            expect(challenge.leaderboard.round_boundary).to.equal("mountain_midnight")
        end)

        it("keeps production leaderboard data out of Studio", function()
            local leaderboards = loadModule("configs/leaderboards.lua")
            expect(leaderboards.publication.studio_read_global).to.equal(false)
            expect(leaderboards.publication.studio_write_global).to.equal(false)
            expect(leaderboards.publication.hide_internal_accounts).to.equal(true)
            for _, board in ipairs(leaderboards.boards) do
                expect(board.global.studio_enabled).to.equal(false)
                if board.awards then
                    expect(board.awards.studio_enabled).to.equal(false)
                end
            end
        end)

        it("ships the complete canonical internal-account exclusion set", function()
            local config = loadModule("configs/internal_accounts.lua")
            local ids = InternalAccounts.userIdSet(config)
            local count = 0
            for userId in pairs(ids) do
                count += 1
                expect(userId > 0).to.equal(true)
            end
            expect(count).to.equal(28)
            expect(count).to.equal(#config.accounts)
            expect(ids[3200870803]).to.equal(true) -- ColoradoPlays
            expect(ids[873359641]).to.equal(true) -- MacrosGodOfMagic
            expect(ids[15921550]).to.equal(true) -- Sploit
            expect(ids[107939353]).to.equal(true) -- Waxillium
            for _, account in ipairs(config.accounts) do
                expect(type(account.name)).to.equal("string")
                expect(account.name ~= "").to.equal(true)
                expect(type(account.family)).to.equal("string")
                expect(account.family ~= "").to.equal(true)
            end
        end)

        it("disables economy and hatch test modes", function()
            local monetization = loadModule("configs/monetization.lua")
            local pets = loadModule("configs/pets.lua")
            expect(monetization.validation_rules.test_mode.enabled).to.equal(false)
            expect(monetization.validation_rules.test_mode.bypass_robux).to.equal(false)
            expect(pets.test_mode.enabled).to.equal(false)
        end)

        it("opens only Week 5 public claims and no Studio claim overrides", function()
            local rewards = loadModule("configs/tester_rewards.lua")
            local enabledCampaign = nil
            for campaignId, campaign in pairs(rewards.campaigns) do
                expect(campaign.claim.studio_enabled).to.equal(false)
                if campaign.claim.enabled then
                    expect(enabledCampaign).to.equal(nil)
                    enabledCampaign = campaignId
                end
            end
            expect(enabledCampaign).to.equal("beta_week_5_2026")

            local weekFive = rewards.campaigns.beta_week_5_2026
            expect(weekFive.egg_id).to.equal("cache_bandit_egg")
            expect(weekFive.pet_id).to.equal("cache_bandit")
            expect(weekFive.claim.starts_at).to.equal(1788588000)
            expect(weekFive.claim.ends_at).to.equal(1789192800)
        end)

        it("keeps the diagnostic promo code Studio-only", function()
            local promos = loadModule("configs/promo_codes.lua")
            expect(promos.codes.studio_smoke.enabled).to.equal(true)
            expect(promos.codes.studio_smoke.studio_only).to.equal(true)
        end)
    end)
end
