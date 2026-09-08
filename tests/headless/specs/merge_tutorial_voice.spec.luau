local Director = loadModule("src/Shared/Game/MergeTutorialVoiceDirector.lua")
local config = loadModule("configs/merge_tutorial_voice.lua")
local tutorial = loadModule("configs/merge_egg_prototype.lua").tutorial
local catalog = loadModule("src/Shared/Game/TutorialVoiceDirector.lua").catalog(
    loadModule("configs/merge_tutorial_voice_lines.lua")
)
local assets = loadModule("configs/merge_tutorial_voice_assets.lua").clips
local function state(overrides)
    local s = {
        observing = true,
        side = "heaven",
        bay = "owned",
        run = 1,
        required = true,
        completed = false,
        rebirths = 0,
        active = true,
        step = "collect_setup",
        created = 0,
        createNeed = 2,
        progress = "0",
    }
    for k, v in pairs(overrides or {}) do
        s[k] = v
    end
    return s
end
return function()
    describe("Merge tutorial narration", function()
        it("binds all 80 performances and both sides of every configured step", function()
            local count = 0
            for cue, line in pairs(catalog) do
                count += 1
                expect(assets[cue].asset_id > 0).to.equal(true)
                expect(assets[cue].seconds > 0).to.equal(true)
                expect(line.speaker == "angel" or line.speaker == "demon").to.equal(true)
            end
            expect(count).to.equal(80)
            for _, side in { "heaven", "hell" } do
                for id in pairs(tutorial.steps) do
                    expect(config.steps[id] ~= nil).to.equal(true)
                    local action =
                        Director.step(Director.new(), state({ side = side, step = id }), config)
                    expect(catalog[action.cue].speaker).to.equal(config.side_speakers[side])
                end
            end
        end)
        it("respects AutoCollector, Deploy Best aliases, and actual upgrade progress", function()
            local function choose(s)
                return Director.step(Director.new(), state(s), config).cue
            end
            expect(choose({ autoCollector = true })).to.equal(
                "merge_tutorial.heaven.collect_setup.auto"
            )
            expect(choose({ step = "combine_once" })).to.equal(choose({ step = "deploy_one" }))
            expect(choose({ step = "upgrade_eggs", created = 2 })).to.equal(
                "merge_tutorial.heaven.upgrade_eggs.deploy"
            )
            expect(choose({ step = "upgrade_eggs", createNeed = 0 })).to.equal(
                "merge_tutorial.heaven.upgrade_eggs"
            )
        end)
        it("skips completed joins, rebirths, foreign bays, and blocked contexts", function()
            for _, overrides in
                {
                    { completed = true },
                    { rebirths = 1 },
                    { observing = false },
                    { blocked = true },
                    { required = false },
                    { side = "unknown" },
                }
            do
                local a = Director.step(Director.new(), state(overrides), config)
                expect(a.cue).to.equal(nil)
                expect(a.cancel).to.equal(true)
            end
        end)
        it("announces live completion once despite split eligibility attribute delivery", function()
            local d = Director.new()
            Director.step(d, state({ step = "talk_quartermaster" }), config)
            Director.step(d, state({ required = false, active = false }), config)
            local a = Director.step(
                d,
                state({ required = false, completed = true, active = false }),
                config
            )
            expect(a.cue).to.equal("merge_tutorial.heaven.completion")
            expect(a.finishCurrent).to.equal(true)
            expect(Director.step(d, state({ completed = true }), config).cue).to.equal(nil)
        end)
        it("resumes only once and resets on side or run changes", function()
            local d = Director.new()
            local s = state({ step = "power_lesson" })
            expect(Director.step(d, s, config).intro).to.equal("merge_tutorial.heaven.resume")
            expect(Director.step(d, s, config).intro).to.equal(nil)
            local a = Director.step(d, state({ side = "hell", step = "power_lesson" }), config)
            expect(a.reset).to.equal(true)
            expect(a.cue).to.equal("merge_tutorial.hell.power_lesson")
            expect(Director.step(d, state({ side = "hell", run = 2 }), config).reset).to.equal(true)
        end)
        it("gives one combat handoff and no combat reminders", function()
            local d = Director.new()
            expect(Director.step(d, state({ active = false }), config).quiet).to.equal(true)
            Director.step(d, state({ step = "deploy_one" }), config)
            local a = Director.step(d, state({ active = false }), config)
            expect(a.cue).to.equal("merge_tutorial.heaven.after_setup")
            expect(a.remind).to.equal(false)
            expect(Director.step(d, state({ active = false }), config).quiet).to.equal(true)
            Director.step(d, state({ step = "deploy_one" }), config)
            expect(Director.step(d, state({ active = false }), config).cue).to.equal(nil)
        end)
        it(
            "scopes contextual help to power lessons and never nags during the timed introduction",
            function()
                local d = Director.new()
                local a = Director.step(
                    d,
                    state({ step = "enhance_lesson", powerHelp = "enhancement" }),
                    config
                )
                expect(a.help).to.equal("merge_tutorial.heaven.help.enhancement")
                expect(Director.step(d, state({ powerHelp = "enhancement" }), config).help).to.equal(
                    nil
                )
                expect(Director.step(d, state({ step = "talk_quartermaster" }), config).remind).to.equal(
                    false
                )
            end
        )
    end)
end
