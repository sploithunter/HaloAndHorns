local Courses = loadModule("src/Shared/Game/CombatCourses.lua")
local Flow = loadModule("src/Shared/Game/TutorialFlow.lua")
local Retention = loadModule("src/Shared/Game/RetentionLogic.lua")
local Hud = loadModule("src/Shared/Game/MergeTutorialHud.lua")
local EffectiveStats = loadModule("src/Shared/Game/EffectiveStats.lua")
local Brew = loadModule("src/Shared/Game/BrewMeter.lua")
local catalog = loadModule("configs/combat_tutorial.lua")
local config = loadModule("configs/combat_courses.lua")
local potions = loadModule("configs/potions.lua")
local buffs = loadModule("configs/buffs.lua")

return function()
    describe("split combat courses", function()
        it(
            "partitions every lesson exactly once and exits each course after its last pillar",
            function()
                local seen, count = {}, 0
                for _, definition in ipairs(config.courses) do
                    local projected = Courses.project(catalog, definition)
                    expect(projected.steps[1].id).to.equal(definition.first)
                    expect(projected.steps[#projected.steps].return_to_exit).to.equal(true)
                    for _, step in ipairs(projected.steps) do
                        expect(seen[step.id]).to.equal(nil)
                        seen[step.id] = true
                        count += 1
                    end
                end
                expect(count).to.equal(#catalog.steps)
                expect(Courses.project(catalog, config.courses[1]).steps[14].id).to.equal(
                    "advance_heal"
                )
                expect(catalog.steps[14].return_to_exit).to.equal(nil)
            end
        )
        it("finishes Basic after Heal without waiting for advanced combat", function()
            local basic = Courses.project(catalog, config.courses[1])
            local progress = Flow.fresh(basic)
            progress.step = #basic.steps
            progress = Flow.advance(basic, progress, "combat_tutorial_advance", {})
            expect(progress.done).to.equal(true)
            expect(#basic.steps).to.equal(14)
        end)
        it("migrates every old lesson index without losing or inventing completions", function()
            for oldStep = 1, #catalog.steps + 1 do
                local data = {
                    CombatTutorial = {
                        version = catalog.version,
                        step = oldStep,
                        count = 2,
                        done = oldStep > #catalog.steps,
                    },
                }
                expect(Courses.migrate(catalog, config, data, Flow)).to.equal(true)
                expect(data.CombatTutorial.done).to.equal(oldStep > 14)
                expect(data.CombatTutorialAdvanced1.done).to.equal(oldStep > 23)
                expect(data.CombatTutorialAdvanced2.done).to.equal(oldStep > 33)
                if oldStep >= 15 and oldStep <= 23 then
                    expect(data.CombatTutorialAdvanced1.step).to.equal(oldStep - 14)
                    expect(data.CombatTutorialAdvanced1.count).to.equal(2)
                elseif oldStep >= 24 and oldStep <= 33 then
                    expect(data.CombatTutorialAdvanced2.step).to.equal(oldStep - 23)
                end
                expect(Courses.migrate(catalog, config, data, Flow)).to.equal(false)
            end
        end)
        it(
            "preserves old reward receipts and does not reward grandfathered advanced completions",
            function()
                local data = {
                    CombatTutorial = {
                        version = 11,
                        step = 34,
                        done = true,
                        completionLevelGranted = true,
                    },
                    CombatTutorialRewardGranted = true,
                }
                Courses.migrate(catalog, config, data, Flow)
                expect(data.CombatTutorialRewardGranted).to.equal(true)
                expect(data.CombatTutorial.completionLevelGranted).to.equal(true)
                expect(data.CombatTutorialAdvanced1RewardGranted).to.equal(true)
                expect(data.CombatTutorialAdvanced2RewardGranted).to.equal(true)
            end
        )
        it("requires Basic before Advanced1 and Advanced1 before Advanced2", function()
            local data = {}
            Courses.migrate(catalog, config, data, Flow)
            expect(Courses.allowed(data, config.courses[2])).to.equal(false)
            data.CombatTutorial.done = true
            expect(Courses.allowed(data, config.courses[2])).to.equal(true)
            expect(Courses.allowed(data, config.courses[3])).to.equal(false)
            data.CombatTutorialAdvanced1.done = true
            expect(Courses.allowed(data, config.courses[3])).to.equal(true)
        end)
        it("grants exactly one earned level from any level but never crosses 50", function()
            for _, definition in ipairs(config.courses) do
                for level = 1, 50 do
                    expect(Courses.levelTarget(definition.completion, level, config.level_cap)).to.equal(
                        math.min(50, level + 1)
                    )
                end
            end
        end)
        it("uses existing one-hour consumable tokens rather than auto-activating boosts", function()
            expect(config.courses[2].completion.grant.items[1].id).to.equal("double_xp_token")
            expect(config.courses[3].completion.grant.items[1].id).to.equal("double_coins_token")
            expect(config.courses[2].completion.grant.items[1].qty).to.equal(1)
        end)
        it("keeps the instruction cover past wave 10 only while Basic is required", function()
            expect(Hud.coversHotbar(true, 100, 10, false, true)).to.equal(true)
            expect(Hud.coversHotbar(true, 3, 10, true, false)).to.equal(false)
            expect(Hud.coversHotbar(false, 100, 10, false, true)).to.equal(false)
        end)
        it("emits three independently named funnels with named, course-scoped steps", function()
            local funnels = Courses.funnels(catalog, config)
            expect(#funnels).to.equal(3)
            expect(#funnels[1].steps).to.equal(15)
            expect(#funnels[2].steps).to.equal(10)
            expect(#funnels[3].steps).to.equal(11)
            local analytics = { course_funnels = funnels }
            local hits = Retention.matchingSteps(
                analytics,
                "combat_tutorial_started",
                { courseId = "advanced_1" }
            )
            expect(#hits).to.equal(1)
            expect(hits[1].funnel).to.equal("advanced_1")
            local state = { Milestones = { [hits[1].id] = {} }, CombatCourseFunnelSteps = {} }
            expect(#Retention.pendingCourseSteps(funnels[2], state)).to.equal(1)
            expect(#Retention.pendingCourseSteps(funnels[1], state)).to.equal(0)
            for _, funnel in ipairs(funnels) do
                for _, step in ipairs(funnel.steps) do
                    expect(type(step.name)).to.equal("string")
                    expect(#step.name > 0).to.equal(true)
                end
            end
        end)
        it("keeps total active native funnels within Roblox's ten-funnel budget", function()
            local retention = loadModule("configs/retention.lua")
            local merge = loadModule("configs/merge_analytics.lua")
            local count = #Courses.funnels(catalog, config)
            for _, key in ipairs({ "onboarding", "activation", "combat_training" }) do
                if retention[key].enabled ~= false then
                    count += 1
                end
            end
            for _, funnel in pairs(merge.funnels) do
                if funnel.enabled ~= false then
                    count += 1
                end
            end
            expect(count).to.equal(10)
        end)
        it(
            "gives the player an 85% first-sip speed boost through the same effective-stat axis",
            function()
                local magnitude = Brew.magnitude(
                    potions.potions.swift_tonic.sip_fraction,
                    potions.meters.speed.cap
                )
                local attrs = { MoveSpeedBuffPotion = magnitude, MoveSpeedBuffPotionUntil = 1060 }
                local mult = EffectiveStats.multiplier("move_speed", function(key)
                    return attrs[key]
                end, 1000, buffs.axes.move_speed)
                expect(math.abs(mult - 1.85) < 0.00001).to.equal(true)
                expect(EffectiveStats.multiplier("move_speed", function(key)
                    return attrs[key]
                end, 1061, buffs.axes.move_speed)).to.equal(1)
            end
        )
    end)
end
