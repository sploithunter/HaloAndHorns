local RetentionLogic = loadModule("src/Shared/Game/RetentionLogic.lua")
local retention = loadModule("configs/retention.lua")
local tutorial = loadModule("configs/tutorial.lua")

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

        it("covers every tutorial step in tutorial order", function()
            for index, step in ipairs(tutorial.steps) do
                local funnelStep = retention.onboarding.steps[index + 1]
                expect(funnelStep.event).to.equal("tutorial_step_completed")
                expect(funnelStep.match.stepId).to.equal(step.id)
            end
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

        it("excludes configured internal username prefixes case-insensitively", function()
            local prefixes = retention.dashboard.excluded_name_prefixes
            expect(RetentionLogic.isExcludedPlayerName("ColoradoPlays", prefixes)).to.equal(true)
            expect(RetentionLogic.isExcludedPlayerName("WAXILLIUM_alt", prefixes)).to.equal(true)
            expect(RetentionLogic.isExcludedPlayerName("waxiliumLegacy", prefixes)).to.equal(true)
            expect(RetentionLogic.isExcludedPlayerName("sploitdm1", prefixes)).to.equal(true)
            expect(RetentionLogic.isExcludedPlayerName("MacrosTester", prefixes)).to.equal(true)
            expect(RetentionLogic.isExcludedPlayerName("StrangerPlayer", prefixes)).to.equal(false)
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
            })
            expect(summary.averageCompletedSessionSeconds).to.equal(100)
            expect(summary.newPlayerTutorialCompletionRate).to.equal(0.6)
            expect(summary.exitedBeforeEarnedLevel2Rate).to.equal(0.5)
            expect(summary.starterChoiceConversionRate).to.equal(0.8)
            expect(summary.averageStarterChoiceSeconds).to.equal(10)
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
    end)
end
