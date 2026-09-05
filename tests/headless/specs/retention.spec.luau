local RetentionLogic = loadModule("src/Shared/Game/RetentionLogic.lua")
local retention = loadModule("configs/retention.lua")
local tutorial = loadModule("configs/tutorial.lua")
local combatTutorial = loadModule("configs/combat_tutorial.lua")

return function()
    describe("retention funnel config", function()
        it("keeps stable sequential step numbers and unique ids", function()
            local seen = {}
            for index, step in ipairs(retention.onboarding.steps) do
                expect(type(step.id)).to.equal("string")
                expect(type(step.name)).to.equal("string")
                expect(seen[step.id]).to.equal(nil)
                seen[step.id] = index
            end
            expect(#retention.onboarding.steps <= 100).to.equal(true)
        end)

        it("covers every homeworld tutorial step in tutorial order", function()
            local byStepId = {}
            local combatStartedIndex = nil
            for index, step in ipairs(retention.onboarding.steps) do
                if step.event == "tutorial_step_completed" and step.match then
                    byStepId[step.match.stepId] = index
                end
                if step.id == "combat_started" then
                    combatStartedIndex = index
                end
            end
            local lastHome = 0
            for _, step in ipairs(tutorial.steps) do
                if step.id ~= "first_fight" and step.id ~= "rally_call" then
                    expect(byStepId[step.id]).to.be.ok()
                    expect(byStepId[step.id] > lastHome).to.equal(true)
                    lastHome = byStepId[step.id]
                end
            end
            expect(combatStartedIndex).to.be.ok()
            expect(combatStartedIndex > lastHome).to.equal(true)
            expect(byStepId.first_fight > combatStartedIndex).to.equal(true)
            expect(byStepId.rally_call > byStepId.first_fight).to.equal(true)
            expect(byStepId.combat_ready).to.equal(nil)
        end)

        it("measures room-by-room cave drop-off on Combat Training", function()
            local seen = {}
            local byStepId = {}
            expect(retention.combat_training.enabled).to.equal(false)
            expect(retention.combat_training.name).to.equal("Combat Training")
            expect(retention.combat_training.steps[1].id).to.equal("combat_started")
            for index, step in ipairs(retention.combat_training.steps) do
                expect(type(step.id)).to.equal("string")
                expect(seen[step.id]).to.equal(nil)
                seen[step.id] = index
                if step.event == "tutorial_step_completed" and step.match then
                    byStepId[step.match.stepId] = index
                end
            end
            local lastCombat = 1
            for _, step in ipairs(combatTutorial.steps) do
                local stepId = "combat_" .. step.id
                expect(byStepId[stepId]).to.be.ok()
                expect(byStepId[stepId] > lastCombat).to.equal(true)
                lastCombat = byStepId[stepId]
            end
        end)

        it("ends onboarding at Rally and measures optional goals on Activation", function()
            expect(retention.version).to.equal(9)
            local last = retention.onboarding.steps[#retention.onboarding.steps]
            expect(last.id).to.equal("tutorial_rally_call")
            local seen = {}
            for _, step in ipairs(retention.onboarding.steps) do
                seen[step.id] = true
            end
            expect(seen.first_quest_completed).to.equal(nil)
            expect(seen.first_steps_completed).to.equal(nil)
            expect(seen.first_area_unlocked).to.equal(nil)
            expect(retention.activation.name).to.equal("Activation")
            expect(retention.activation.steps[1].id).to.equal("joined")
            expect(retention.activation.steps[2].id).to.equal("first_quest_completed")
            expect(retention.activation.steps[3].id).to.equal("first_steps_completed")
            expect(retention.activation.steps[4].id).to.equal("first_area_unlocked")
            local service = readFile("src/Server/Services/RetentionService.lua")
            expect(service:find("LogFunnelStepEvent", 1, true)).to.be.ok()
            expect(service:find("_flushActivation", 1, true)).to.be.ok()
        end)
    end)

    describe("RetentionLogic", function()
        it("builds date-partitioned event chunk keys below the Roblox key limit", function()
            local prefix = RetentionLogic.eventKeyPrefix("20260718", 123456789012345, 42)
            local key = RetentionLogic.eventChunkKey(prefix, 7)
            expect(key).to.equal("d20260718/u123456789012345/s42/c00007")
            expect(#key <= 50).to.equal(true)
        end)

        it("sanitizes raw event context to DataStore-safe bounded values", function()
            local cyclic = { keep = "abcdef", nan = 0 / 0, nested = { value = true } }
            cyclic.self = cyclic
            local event = RetentionLogic.rawEvent(2, "test", 100, 1.25, cyclic, {
                max_string_length = 4,
                max_context_depth = 3,
                max_table_items = 10,
            })
            expect(event.sequence).to.equal(2)
            expect(event.name).to.equal("test")
            expect(event.context.keep).to.equal("abcd")
            expect(event.context.nan).to.equal(nil)
            expect(event.context.self).to.equal(nil)
            expect(event.context.nested.value).to.equal(true)
        end)

        it("keeps sanitized arrays contiguous when an element cannot be stored", function()
            local clean = RetentionLogic.sanitize({ "first", 0 / 0, "third" }, {})
            expect(#clean).to.equal(2)
            expect(clean[1]).to.equal("first")
            expect(clean[2]).to.equal("third")
        end)

        it("aggregates new-player tutorial reach, timing, and exit counters once", function()
            local counters = RetentionLogic.newAggregate()
            local seen = {}
            RetentionLogic.aggregateSessionStarted(counters, true)
            RetentionLogic.aggregateEvent(
                counters,
                seen,
                "tutorial_step_completed",
                { stepId = "hatch_first_egg" },
                12.5,
                true
            )
            RetentionLogic.aggregateEvent(
                counters,
                seen,
                "tutorial_step_completed",
                { stepId = "hatch_first_egg" },
                13,
                true
            )
            RetentionLogic.aggregateSessionEnded(counters, {
                durationSeconds = 90,
                firstSession = true,
                earnedLevel = 1,
                claimedLevel = 1,
                tutorialDone = false,
                currentTutorialStep = "equip_pet",
            })

            expect(counters.newPlayers).to.equal(1)
            expect(counters.tutorialSteps.hatch_first_egg.reached).to.equal(1)
            expect(counters.tutorialSteps.hatch_first_egg.totalSecondsToReach).to.equal(12.5)
            expect(counters.tutorialExitBefore.equip_pet).to.equal(1)
            expect(counters.exitedBeforeEarnedLevel2).to.equal(1)
            expect(counters.exitedBeforeClaimedLevel2).to.equal(1)
            expect(counters.newPlayerTotalSessionSeconds).to.equal(90)
        end)

        it("separates any-session tutorial completions from first-session completions", function()
            local counters = RetentionLogic.newAggregate()
            RetentionLogic.aggregateEvent(counters, {}, "tutorial_complete", {}, 120, true)
            RetentionLogic.aggregateEvent(counters, {}, "tutorial_complete", {}, 30, false)
            expect(counters.tutorialCompleted).to.equal(2)
            expect(counters.newPlayerTutorialCompleted).to.equal(1)
        end)

        it("aggregates code redemptions by stable code and campaign", function()
            local counters = RetentionLogic.newAggregate()
            RetentionLogic.aggregateEvent(counters, {}, "promo_link_attributed", {
                codeId = "kade_week_one",
                campaign = "kade_x_week_1",
            }, 2, true)
            RetentionLogic.aggregateEvent(counters, {}, "promo_code_redeemed", {
                codeId = "kade_week_one",
                campaign = "kade_x_week_1",
            }, 20, false)
            RetentionLogic.aggregateEvent(counters, {}, "promo_code_redeemed", {
                codeId = "x_week_one",
                campaign = "official_x_week_1",
            }, 35, false)
            RetentionLogic.aggregateEvent(counters, {}, "promo_code_redeemed", {
                codeId = "kade_week_one",
                campaign = "kade_x_week_1",
            }, 40, false)

            expect(counters.promoCodes.redeemed).to.equal(3)
            expect(counters.promoCodes.attributed).to.equal(1)
            expect(counters.promoCodes.attributedByCampaign.kade_x_week_1).to.equal(1)
            expect(counters.promoCodes.byCode.kade_week_one).to.equal(2)
            expect(counters.promoCodes.byCode.x_week_one).to.equal(1)
            expect(counters.promoCodes.byCampaign.kade_x_week_1).to.equal(2)
            expect(RetentionLogic.dashboardSummary(counters).promoCodesRedeemed).to.equal(3)
            expect(RetentionLogic.dashboardSummary(counters).promoCodeAttributed).to.equal(1)
        end)

        it("aggregates the starter choice microfunnel and selected role once", function()
            local counters = RetentionLogic.newAggregate()
            local seen = {}
            RetentionLogic.aggregateEvent(counters, seen, "starter_pet_choice_shown", {}, 2, true)
            RetentionLogic.aggregateEvent(counters, seen, "starter_pet_choice_shown", {}, 3, true)
            RetentionLogic.aggregateEvent(
                counters,
                seen,
                "starter_pet_selected",
                { petType = "kitty", role = "ranged" },
                8.5,
                true
            )
            RetentionLogic.aggregateEvent(
                counters,
                seen,
                "starter_pet_selected",
                { petType = "kitty" },
                10,
                true
            )
            expect(counters.starterChoice.shown).to.equal(1)
            expect(counters.starterChoice.selected).to.equal(1)
            expect(counters.starterChoice.totalSecondsToSelect).to.equal(8.5)
            expect(counters.starterChoice.byPet.kitty).to.equal(1)
        end)

        it("counts committed power picks in every session and reports share", function()
            local counters = RetentionLogic.newAggregate()
            local first = {}
            local veteran = {}
            RetentionLogic.aggregateEvent(
                counters,
                first,
                "power_selected",
                { power = "rage", level = 2 },
                12,
                true
            )
            RetentionLogic.aggregateEvent(
                counters,
                first,
                "power_selected",
                { power = "rage", level = 4 },
                20,
                true
            )
            RetentionLogic.aggregateEvent(
                counters,
                veteran,
                "power_selected",
                { power = "heal", level = 8 },
                40,
                false
            )
            expect(counters.powerPicks.total).to.equal(3)
            expect(counters.powerPicks.byPower.rage).to.equal(2)
            expect(counters.powerPicks.byPower.heal).to.equal(1)
            expect(counters.powerPicks.byLevel["2"]).to.equal(1)
            expect(counters.powerPicks.byLevel["8"]).to.equal(1)
            expect(RetentionLogic.dashboardSummary(counters).powerPickTotal).to.equal(3)

            local shares = RetentionLogic.powerPickShares(counters)
            expect(shares.total).to.equal(3)
            expect(shares.rows[1].power).to.equal("rage")
            expect(shares.rows[1].count).to.equal(2)
            expect(shares.rows[1].share).to.equal(2 / 3)
            expect(shares.rows[2].power).to.equal("heal")
            expect(shares.rows[2].share).to.equal(1 / 3)
        end)

        it("keeps veteran sessions in general counters but out of the new-player funnel", function()
            local counters = RetentionLogic.newAggregate()
            local seen = {}
            RetentionLogic.aggregateSessionStarted(counters, false)
            RetentionLogic.aggregateEvent(
                counters,
                seen,
                "tutorial_step_completed",
                { stepId = "hatch_first_egg" },
                2,
                false
            )
            RetentionLogic.aggregateSessionEnded(counters, {
                durationSeconds = 30,
                firstSession = false,
                earnedLevel = 10,
                claimedLevel = 9,
            })
            expect(counters.sessionsStarted).to.equal(1)
            expect(counters.sessionsEnded).to.equal(1)
            expect(counters.totalSessionSeconds).to.equal(30)
            expect(counters.newPlayers).to.equal(0)
            expect(counters.tutorialSteps.hatch_first_egg).to.equal(nil)
        end)

        it("builds a bounded daily aggregate shard key", function()
            local key =
                RetentionLogic.aggregateKey("20260718", "12345678-1234-1234-1234-123456789012")
            expect(key).to.equal("a20260718/j12345678123412341234123456789012")
            expect(#key <= 50).to.equal(true)
        end)

        it("excludes internal accounts by ID and safe prefixes, never Colorado*", function()
            local accounts = loadModule("configs/internal_accounts.lua")
            local InternalAccounts = loadModule("src/Shared/Game/InternalAccounts.lua")
            local prefixes = InternalAccounts.namePrefixes(accounts)
            local userIds = InternalAccounts.userIds(accounts)

            expect(RetentionLogic.isExcludedPlayerName("ColoradoPlays", prefixes)).to.equal(false)
            expect(RetentionLogic.isExcludedPlayerName("ColoradoFan", prefixes)).to.equal(false)
            expect(RetentionLogic.isExcludedUserId(3200870803, userIds)).to.equal(true)
            expect(RetentionLogic.isInternalPlayer(3200870803, "ColoradoPlays", userIds, prefixes)).to.equal(
                true
            )
            expect(RetentionLogic.isInternalPlayer(1, "ColoradoFan", userIds, prefixes)).to.equal(
                false
            )
            expect(RetentionLogic.isExcludedPlayerName("WAXILLIUM_alt", prefixes)).to.equal(true)
            expect(RetentionLogic.isExcludedPlayerName("waxiliumLegacy", prefixes)).to.equal(true)
            expect(RetentionLogic.isExcludedPlayerName("sploitdm1", prefixes)).to.equal(true)
            expect(RetentionLogic.isExcludedPlayerName("MacrosTester", prefixes)).to.equal(true)
            expect(RetentionLogic.isExcludedPlayerName("StrangerPlayer", prefixes)).to.equal(false)
            expect(InternalAccounts.isUserId(accounts, 3539984059)).to.equal(true)
            expect(InternalAccounts.isUserId(accounts, 3086045027)).to.equal(true)
            expect(InternalAccounts.isUserId(accounts, 3047771242)).to.equal(true)
        end)

        it("uses a deterministic bounded key for dashboard buckets", function()
            local bucket = RetentionLogic.dashboardBucketIndex("server-job-123", 16)
            expect(bucket >= 0 and bucket < 16).to.equal(true)
            expect(RetentionLogic.dashboardBucketIndex("server-job-123", 16)).to.equal(bucket)
            expect(RetentionLogic.dashboardBucketKey("2026-07-25", bucket)).to.equal(
                string.format("d20260725/b%02d", bucket)
            )
        end)

        it("uses Roblox place version as the authoritative dashboard build key", function()
            expect(RetentionLogic.dashboardBuildKey({
                placeVersion = 42,
                buildCommit = "abc123",
            })).to.equal("place:42")
            expect(RetentionLogic.dashboardBuildKey({ buildCommit = "abc-123" })).to.equal(
                "commit:abc123"
            )
            expect(RetentionLogic.dashboardBuildKey({})).to.equal("unknown")
        end)

        it("replaces one server contribution without double counting", function()
            local first = RetentionLogic.replaceDashboardContribution(nil, {
                jobId = "server-a",
                dateUtc = "20260725",
                bucket = 3,
                bucketCount = 16,
                updatedAt = 10,
                counters = {
                    newPlayers = 2,
                    starterChoice = { selected = 1, byPet = { kitty = 1 } },
                },
            })
            local second = RetentionLogic.replaceDashboardContribution(first, {
                jobId = "server-b",
                dateUtc = "20260725",
                bucket = 3,
                bucketCount = 16,
                updatedAt = 11,
                counters = {
                    newPlayers = 3,
                    starterChoice = { selected = 2, byPet = { doggy = 2 } },
                },
            })
            expect(second.counters.newPlayers).to.equal(5)
            expect(second.counters.starterChoice.selected).to.equal(3)
            expect(second.counters.starterChoice.byPet.kitty).to.equal(1)
            expect(second.counters.starterChoice.byPet.doggy).to.equal(2)

            local replacement = RetentionLogic.replaceDashboardContribution(second, {
                jobId = "server-a",
                dateUtc = "20260725",
                bucket = 3,
                bucketCount = 16,
                updatedAt = 12,
                counters = {
                    newPlayers = 4,
                    starterChoice = { selected = 3, byPet = { bear = 3 } },
                },
            })
            expect(replacement.counters.newPlayers).to.equal(7)
            expect(replacement.counters.starterChoice.selected).to.equal(5)
            expect(replacement.counters.starterChoice.byPet.kitty).to.equal(nil)
            expect(replacement.counters.starterChoice.byPet.bear).to.equal(3)
        end)

        it("derives decision-ready dashboard rates from counters", function()
            local summary = RetentionLogic.dashboardSummary({
                sessionsStarted = 10,
                sessionsEnded = 8,
                totalSessionSeconds = 800,
                newPlayers = 5,
                newPlayerSessionsEnded = 4,
                newPlayerTotalSessionSeconds = 200,
                newPlayerTutorialCompleted = 3,
                exitedBeforeEarnedLevel2 = 2,
                starterChoice = {
                    shown = 5,
                    selected = 4,
                    totalSecondsToSelect = 40,
                },
                distinctReturners = {
                    d1 = 2,
                    d2_7 = 3,
                    d8_30 = 1,
                },
            })
            expect(summary.averageCompletedSessionSeconds).to.equal(100)
            expect(summary.newPlayerTutorialCompletionRate).to.equal(0.6)
            expect(summary.exitedBeforeEarnedLevel2Rate).to.equal(0.5)
            expect(summary.starterChoiceConversionRate).to.equal(0.8)
            expect(summary.averageStarterChoiceSeconds).to.equal(10)
            expect(summary.distinctD1Returners).to.equal(2)
            expect(summary.distinctD1RetentionRate).to.equal(0.4)
            expect(summary.distinctD2To7Returners).to.equal(3)
            expect(summary.distinctD2To7RetentionRate).to.equal(0.6)
            expect(summary.distinctD8To30Returners).to.equal(1)
            expect(summary.distinctD8To30RetentionRate).to.equal(0.2)
        end)

        it("classifies cohort returns by UTC calendar-day window", function()
            local joinedAt = 100 * 86400 + 86300
            expect(select(1, RetentionLogic.returnWindow(joinedAt, joinedAt + 50))).to.equal(nil)
            expect(select(1, RetentionLogic.returnWindow(joinedAt, joinedAt + 100))).to.equal("d1")
            expect(select(2, RetentionLogic.returnWindow(joinedAt, joinedAt + 100))).to.equal(1)
            expect(select(1, RetentionLogic.returnWindow(joinedAt, joinedAt + 2 * 86400))).to.equal(
                "d2_7"
            )
            expect(select(1, RetentionLogic.returnWindow(joinedAt, joinedAt + 8 * 86400))).to.equal(
                "d8_30"
            )
            expect(select(1, RetentionLogic.returnWindow(joinedAt, joinedAt + 31 * 86400))).to.equal(
                nil
            )
        end)

        it("counts each eligible player once per cohort return window", function()
            local joinedAt = 100 * 86400 + 100
            local state = RetentionLogic.ensure(nil, true, joinedAt)

            local firstWindow, cohortDate, dayOffset =
                RetentionLogic.claimReturnWindow(state, joinedAt, joinedAt + 2 * 86400, "19700101")
            expect(firstWindow).to.equal("d2_7")
            expect(type(cohortDate)).to.equal("string")
            expect(dayOffset).to.equal(2)
            expect(
                select(
                    1,
                    RetentionLogic.claimReturnWindow(
                        state,
                        joinedAt,
                        joinedAt + 5 * 86400,
                        "19700101"
                    )
                )
            ).to.equal(nil)
            expect(
                select(
                    1,
                    RetentionLogic.claimReturnWindow(
                        state,
                        joinedAt,
                        joinedAt + 8 * 86400,
                        "19700101"
                    )
                )
            ).to.equal("d8_30")
            expect(state.ReturnTracking.Counted.d2_7 ~= nil).to.equal(true)
            expect(state.ReturnTracking.Counted.d8_30 ~= nil).to.equal(true)
        end)

        it("does not count legacy or ineligible profiles as distinct returners", function()
            local joinedAt = 100 * 86400
            local ineligible = RetentionLogic.ensure(nil, false, joinedAt)
            expect(
                RetentionLogic.claimReturnWindow(ineligible, joinedAt, joinedAt + 86400, "19700101")
            ).to.equal(nil)

            local eligible = RetentionLogic.ensure(nil, true, joinedAt)
            expect(
                RetentionLogic.claimReturnWindow(eligible, joinedAt, joinedAt + 86400, "20260816")
            ).to.equal(nil)
        end)

        it("aggregates only recognized distinct-return windows", function()
            local counters = RetentionLogic.newAggregate()
            expect(RetentionLogic.aggregateDistinctReturner(counters, "d1")).to.equal(true)
            expect(RetentionLogic.aggregateDistinctReturner(counters, "d1")).to.equal(true)
            expect(RetentionLogic.aggregateDistinctReturner(counters, "other")).to.equal(false)
            expect(counters.distinctReturners.d1).to.equal(2)
            expect(counters.distinctReturners.other).to.equal(nil)
        end)

        it(
            "decides first-session eligibility when a reconciled template is still undecided",
            function()
                local state = RetentionLogic.ensure({
                    Eligible = false,
                    EligibilityDecided = false,
                    InstrumentedAt = 0,
                }, true, 100)
                expect(state.Eligible).to.equal(true)
                expect(state.EligibilityDecided).to.equal(true)
                expect(state.InstrumentedAt).to.equal(100)
            end
        )

        it("records a milestone only once with session timing", function()
            local state = RetentionLogic.ensure(nil, true, 100)
            expect(RetentionLogic.record(state, "joined", "onboarding", {
                at = 101,
                session = 1,
                seconds = 4,
            })).to.equal(true)
            expect(RetentionLogic.record(state, "joined", "onboarding", {
                at = 200,
                session = 2,
                seconds = 1,
            })).to.equal(false)
            expect(state.Milestones.joined.at).to.equal(101)
            expect(state.Milestones.joined.seconds).to.equal(4)
        end)

        it("matches events and context fields", function()
            local matches =
                RetentionLogic.matchingSteps(retention, "quest_complete", { quest = "fs_boost" })
            expect(#matches).to.equal(1)
            expect(matches[1].id).to.equal("first_quest_completed")
            expect(
                #RetentionLogic.matchingSteps(
                    retention,
                    "quest_complete",
                    { quest = "mine_break_100" }
                )
            ).to.equal(0)
        end)

        it("queues out-of-order achievements until the contiguous prefix exists", function()
            local state = RetentionLogic.ensure(nil, true, 100)
            RetentionLogic.record(state, "joined", "onboarding", { at = 100 })
            RetentionLogic.record(state, "tutorial_farm_crystals", "onboarding", { at = 102 })
            local pending = RetentionLogic.pendingFunnelSteps(retention, state)
            expect(#pending).to.equal(1)
            expect(pending[1].id).to.equal("joined")

            state.AnalyticsFunnelStep = 1
            RetentionLogic.record(state, "tutorial_hatch_first_egg", "onboarding", { at = 101 })
            pending = RetentionLogic.pendingFunnelSteps(retention, state)
            expect(#pending).to.equal(2)
            expect(pending[1].id).to.equal("tutorial_hatch_first_egg")
            expect(pending[2].id).to.equal("tutorial_farm_crystals")
        end)

        it("does not submit veteran profiles to the onboarding funnel", function()
            local state = RetentionLogic.ensure(nil, false, 100)
            RetentionLogic.record(state, "joined", "onboarding", { at = 100 })
            expect(#RetentionLogic.pendingFunnelSteps(retention, state)).to.equal(0)
        end)

        it("submits activation from join even when onboarding is ineligible", function()
            local state = RetentionLogic.ensure(nil, false, 100)
            RetentionLogic.record(state, "joined", "onboarding", { at = 100 })
            RetentionLogic.record(state, "first_quest_completed", "activation", { at = 140 })
            local pending = RetentionLogic.pendingActivationSteps(retention, state)
            expect(#pending).to.equal(2)
            expect(pending[1].id).to.equal("joined")
            expect(pending[2].id).to.equal("first_quest_completed")
        end)
    end)
end
