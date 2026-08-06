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

        it("can open a closed public campaign in Studio only", function()
            local studioDefinition = {
                claim = {
                    enabled = false,
                    studio_enabled = true,
                },
            }
            expect(Campaign.isClaimWindowOpen(studioDefinition, 150, false)).to.equal(false)
            expect(Campaign.isClaimWindowOpen(studioDefinition, 150, true)).to.equal(true)
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

        it("upgrades a Huge award in place without replacing its identity or serial", function()
            local record = {
                id = "beta_pet",
                awarded_to_user_id = 42,
                award_tier = "basic",
                variant = "basic",
                huge = true,
                serial = 17,
                serial_key = "huge:beta_pet:basic",
            }

            local changed, tier = Campaign.reconcileTier(record, 42, 5, definition)

            expect(changed).to.equal(true)
            expect(tier).to.equal("golden")
            expect(record.id).to.equal("beta_pet")
            expect(record.variant).to.equal("golden")
            expect(record.huge).to.equal(true)
            expect(record.serial).to.equal(17)
            expect(record.serial_key).to.equal("huge:beta_pet:basic")
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

        it("ships the authored week-one campaign with public claiming disabled", function()
            local config = loadModule("configs/tester_rewards.lua")
            local pets = loadModule("configs/pets.lua")
            local roles = loadModule("configs/pet_roles.lua")
            local weekOne = config.campaigns.beta_week_1_2026
            local betaByte = pets.pets.beta_tester_bot
            local testerEgg = pets.egg_sources.beta_tester_egg
            expect(weekOne.egg_id).to.equal("beta_tester_egg")
            expect(weekOne.pet_id).to.equal("beta_tester_bot")
            expect(weekOne.claim.enabled).to.equal(false)
            expect(weekOne.claim.studio_enabled).to.equal(true)
            expect(weekOne.claim_limit).to.equal(1)
            expect(weekOne.minimum_claim_level).to.equal(2)
            expect(weekOne.golden_level).to.equal(5)
            expect(weekOne.rainbow_level).to.equal(10)
            expect(weekOne.huge_chance).to.equal(0.01)
            expect(config.defaults.minimum_claim_level).to.equal(2)
            expect(config.defaults.golden_level).to.equal(5)
            expect(config.defaults.rainbow_level).to.equal(10)
            expect(config.defaults.huge_chance).to.equal(0.01)
            expect(betaByte.display_name).to.equal("Beta Byte")
            expect(betaByte.category).to.equal("exclusive")
            expect(betaByte.origin).to.equal("grass")
            expect(roles.by_type.beta_tester_bot).to.equal("melee")
            expect(testerEgg.huge.chance).to.equal(0.01)
            expect(testerEgg.huge.pets.beta_tester_bot).to.equal(1)
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

        it("provides deterministic admin egg variants without opening public claims", function()
            local service = readFile("src/Server/Services/TesterRewardService.lua")
            local admin = readFile("src/Server/Services/AdminToolsService.lua")
            expect(service:find("AdminGrantTestEgg", 1, true)).to.be.ok()
            expect(service:find("tester_force_huge", 1, true)).to.be.ok()
            expect(admin:find("GameData.TesterRewards = { campaigns = {} }", 1, true)).to.be.ok()
            expect(admin:find("rec.award_id == nil", 1, true)).to.be.ok()
        end)

        it("celebrates the egg grant with the standard floating reward banner", function()
            local events = loadModule("configs/game_events.lua")
            local award = events.tester_reward_awarded
            expect(award.sound).to.equal("celebratory_jingle")
            expect(award.banner.seconds).to.equal(9)
            expect(award.vfx.kind).to.equal("burst")
        end)
    end)
end
