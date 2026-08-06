local Campaign = loadModule("src/Shared/Game/TesterRewardCampaign.lua")

return function()
    local definition = {
        claim_limit = 1,
        minimum_claim_level = 2,
        golden_level = 5,
        rainbow_level = 10,
        huge_chance = 0.01,
        egg_id = "beta_egg",
        pet_id = "beta_pet",
        claim = { enabled = true, starts_at = 100, ends_at = 200 },
    }

    describe("TesterRewardCampaign", function()
        it("uses one stable award record and the configured level tiers", function()
            expect(Campaign.recordKey("week_1", 42)).to.equal("tester_reward|week_1|42")
            expect(Campaign.tierForLevel(2, definition)).to.equal("basic")
            expect(Campaign.tierForLevel(5, definition)).to.equal("golden")
            expect(Campaign.tierForLevel(10, definition)).to.equal("rainbow")
        end)

        it("grants only after active-window eligibility and claimed level two", function()
            expect(Campaign.isClaimWindowOpen(definition, 99)).to.equal(false)
            expect(Campaign.isClaimWindowOpen(definition, 150)).to.equal(true)
            expect(Campaign.canGrant(definition, { eligible_at = 150 }, 1)).to.equal(false)
            expect(Campaign.canGrant(definition, { eligible_at = 150 }, 2)).to.equal(true)
            expect(Campaign.canGrant(definition, { eligible_at = 150, granted_count = 1 }, 50)).to.equal(
                false
            )
        end)

        it("freezes with another owner and catches up when returned", function()
            local record = {
                awarded_to_user_id = 42,
                award_tier = "basic",
                variant = "basic",
            }
            local changed = Campaign.reconcileTier(record, 99, 10, definition)
            expect(changed).to.equal(false)
            expect(record.variant).to.equal("basic")

            changed = Campaign.reconcileTier(record, 42, 10, definition)
            expect(changed).to.equal(true)
            expect(record.variant).to.equal("rainbow")
        end)

        it(
            "validates a same-species 1-percent huge campaign without hardcoding a huge id",
            function()
                local config = { version = 1, defaults = {}, campaigns = { week_1 = definition } }
                local pets = {
                    egg_sources = { beta_egg = { fixed_odds = true } },
                    pets = { beta_pet = {} },
                }
                local ok = Campaign.validate(config, pets)
                expect(ok).to.equal(true)
            end
        )

        it("ships disabled until authored week-one assets are supplied", function()
            local config = loadModule("configs/tester_rewards.lua")
            expect(next(config.campaigns)).to.equal(nil)
            expect(config.defaults.minimum_claim_level).to.equal(2)
            expect(config.defaults.golden_level).to.equal(5)
            expect(config.defaults.rainbow_level).to.equal(10)
            expect(config.defaults.huge_chance).to.equal(0.01)
        end)

        it("preserves provenance through hatching and trade escrow", function()
            local grant = readFile("src/Server/Services/PetGrantService.lua")
            local hatch = readFile("src/Server/Services/MeetCreatorService.lua")
            local trade = readFile("src/Server/Services/TradeService.lua")
            expect(grant:find("awarded_to_user_id", 1, true)).to.be.ok()
            expect(hatch:find("ResolveHatch", 1, true)).to.be.ok()
            expect(hatch:find("_eggHatchLocks", 1, true)).to.be.ok()
            expect(trade:find('category = "eggs"', 1, true)).to.be.ok()
            expect(trade:find("ReconcileRecordBeforeTrade", 1, true)).to.be.ok()
        end)
    end)
end
