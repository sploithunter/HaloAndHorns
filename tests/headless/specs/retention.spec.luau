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
            RetentionLogic.record(state, "tutorial_equip_pet", "onboarding", { at = 102 })
            local pending = RetentionLogic.pendingFunnelSteps(retention, state)
            expect(#pending).to.equal(1)
            expect(pending[1].id).to.equal("joined")

            state.AnalyticsFunnelStep = 1
            RetentionLogic.record(state, "tutorial_hatch_first_egg", "onboarding", { at = 101 })
            pending = RetentionLogic.pendingFunnelSteps(retention, state)
            expect(#pending).to.equal(2)
            expect(pending[1].id).to.equal("tutorial_hatch_first_egg")
            expect(pending[2].id).to.equal("tutorial_equip_pet")
        end)

        it("does not submit veteran profiles to the onboarding funnel", function()
            local state = RetentionLogic.ensure(nil, false, 100)
            RetentionLogic.record(state, "joined", "onboarding", { at = 100 })
            expect(#RetentionLogic.pendingFunnelSteps(retention, state)).to.equal(0)
        end)
    end)
end
