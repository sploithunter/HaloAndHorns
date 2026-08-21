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

        it("closes week one and ships the authored week-two Signal Seal campaign", function()
            local config = loadModule("configs/tester_rewards.lua")
            local pets = loadModule("configs/pets.lua")
            local roles = loadModule("configs/pet_roles.lua")
            local weekOne = config.campaigns.beta_week_1_2026
            local weekTwo = config.campaigns.beta_week_2_2026
            local signalSeal = pets.pets.signal_seal
            local signalSealEgg = pets.egg_sources.signal_seal_egg
            expect(weekOne.claim.enabled).to.equal(false)
            expect(weekOne.claim.studio_enabled).to.equal(true)
            expect(weekOne.claim.starts_at).to.equal(1786168800)
            expect(weekOne.claim.ends_at).to.equal(1786773600)
            expect(weekTwo.egg_id).to.equal("signal_seal_egg")
            expect(weekTwo.pet_id).to.equal("signal_seal")
            expect(weekTwo.claim.enabled).to.equal(true)
            expect(weekTwo.claim.studio_enabled).to.equal(true)
            expect(weekTwo.claim.starts_at).to.equal(1786773600)
            expect(weekTwo.claim.ends_at).to.equal(1787378400)
            expect(weekTwo.claim_limit).to.equal(1)
            expect(weekTwo.minimum_claim_level).to.equal(2)
            expect(weekTwo.golden_level).to.equal(5)
            expect(weekTwo.rainbow_level).to.equal(10)
            expect(weekTwo.huge_chance).to.equal(0.01)
            expect(config.defaults.minimum_claim_level).to.equal(2)
            expect(config.defaults.golden_level).to.equal(5)
            expect(config.defaults.rainbow_level).to.equal(10)
            expect(config.defaults.huge_chance).to.equal(0.01)
            expect(signalSeal.display_name).to.equal("Signal Seal")
            expect(signalSeal.category).to.equal("exclusive")
            expect(signalSeal.origin).to.equal("ice")
            expect(roles.by_type.signal_seal).to.equal("support")
            expect(roles.support_auras.signal_seal.kind).to.equal("luck")
            expect(signalSealEgg.huge.chance).to.equal(0.01)
            expect(signalSealEgg.huge.pets.signal_seal).to.equal(1)
        end)

        it(
            "authors the remaining three tester weeks without opening future public claims",
            function()
                local config = loadModule("configs/tester_rewards.lua")
                local pets = loadModule("configs/pets.lua")
                local roles = loadModule("configs/pet_roles.lua")
                local expected = {
                    {
                        campaign = "beta_week_3_2026",
                        pet = "patch_phoenix",
                        egg = "patch_phoenix_egg",
                        role = "ranged",
                        aura = "drop_rate",
                        starts_at = 1787378400,
                        ends_at = 1787983200,
                    },
                    {
                        campaign = "beta_week_4_2026",
                        pet = "core_digger",
                        egg = "core_digger_egg",
                        role = "tank",
                        aura = "yield",
                        starts_at = 1787983200,
                        ends_at = 1788588000,
                    },
                    {
                        campaign = "beta_week_5_2026",
                        pet = "cache_bandit",
                        egg = "cache_bandit_egg",
                        role = "melee",
                        aura = "xp",
                        starts_at = 1788588000,
                        ends_at = 1789192800,
                    },
                }

                for _, row in ipairs(expected) do
                    local campaign = config.campaigns[row.campaign]
                    local pet = pets.pets[row.pet]
                    local egg = pets.egg_sources[row.egg]
                    expect(campaign.pet_id).to.equal(row.pet)
                    expect(campaign.egg_id).to.equal(row.egg)
                    expect(campaign.claim.enabled).to.equal(false)
                    expect(campaign.claim.studio_enabled).to.equal(false)
                    expect(campaign.claim.starts_at).to.equal(row.starts_at)
                    expect(campaign.claim.ends_at).to.equal(row.ends_at)
                    expect(pet.category).to.equal("exclusive")
                    expect(roles.by_type[row.pet]).to.equal(row.role)
                    expect(roles.support_auras[row.pet].kind).to.equal(row.aura)
                    expect(egg.fixed_odds).to.equal(true)
                    expect(egg.huge.chance).to.equal(0.01)
                    expect(egg.huge.pets[row.pet]).to.equal(1)
                    expect(egg.pet_weights[row.pet]).to.equal(1)
                end
            end
        )

        it(
            "shows the public campaign in Events for the same Saturday-to-Saturday window",
            function()
                local events = loadModule("configs/events.lua")
                local event = events.global_events.beta_test_week_two
                local schedule = events.scheduled_global_events.beta_test_week_two
                local eventService = readFile("src/Server/Services/EventService.lua")

                expect(event.display_name).to.equal("Beta Test Week Two")
                expect(next(event.modifiers)).to.equal(nil)
                expect(schedule.event_id).to.equal("beta_test_week_two")
                expect(schedule.starts_at).to.equal(1786773600)
                expect(schedule.ends_at).to.equal(1787378400)
                expect(eventService:find("now < startsAt", 1, true)).to.be.ok()
                expect(eventService:find("now >= endsAt", 1, true)).to.be.ok()
            end
        )

        it("schedules the remaining tester campaign cards for their authored weeks", function()
            local events = loadModule("configs/events.lua")
            local expected = {
                beta_test_week_three = { 1787378400, 1787983200 },
                beta_test_week_four = { 1787983200, 1788588000 },
                beta_test_week_five = { 1788588000, 1789192800 },
            }

            for eventId, window in pairs(expected) do
                local event = events.global_events[eventId]
                local schedule = events.scheduled_global_events[eventId]
                expect(event).to.be.ok()
                expect(next(event.modifiers)).to.equal(nil)
                expect(schedule.event_id).to.equal(eventId)
                expect(schedule.starts_at).to.equal(window[1])
                expect(schedule.ends_at).to.equal(window[2])
            end
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

        it("provides deterministic admin egg variants independently of public claims", function()
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
