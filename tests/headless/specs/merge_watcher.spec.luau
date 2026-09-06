local Director = loadModule("src/Shared/Game/MergeWatcherDirector.lua")
local cfg = {
    max_encounters = 4,
    cooldown_seconds = 75,
    quartermaster_delay_seconds = 18,
    quartermaster_reminder_seconds = 180,
    quartermaster_max_reminders = 2,
    milestone_waves = { 1, 5, 10 },
}
local function snapshot(wave)
    return { eligible = true, run = "a", wave = wave or 2, breaches = 0, bulwark = 0 }
end

return function()
    describe("Merge Watcher director", function()
        it(
            "selects each side without leaking palette/asset overrides into shared defaults",
            function()
                local shared = {
                    enabled = true,
                    template_name = "Hell",
                    dialogue = { color = "red", width = 340 },
                    themes = {
                        hell = {},
                        heaven = { template_name = "Heaven", dialogue = { color = "gold" } },
                    },
                }
                local heaven = Director.theme(shared, "heaven")
                expect(heaven.side).to.equal("heaven")
                expect(heaven.template_name).to.equal("Heaven")
                expect(heaven.dialogue.color).to.equal("gold")
                expect(heaven.dialogue.width).to.equal(340)
                expect(Director.theme(shared, "hell").dialogue.color).to.equal("red")
                expect(shared.dialogue.color).to.equal("red")
                expect(Director.theme(shared, "unknown")).to.equal(nil)
                expect(Director.theme(shared, nil)).to.equal(nil)
                shared.enabled = false
                expect(Director.theme(shared, "heaven")).to.equal(nil)
            end
        )
        it("ducks quickly, restores smoothly, clamps long frames and reverses cleanly", function()
            local duck = { fade_in_seconds = 0.15, fade_out_seconds = 0.6 }
            expect(Director.duckAmount(0, true, 0.075, duck)).to.equal(0.5)
            expect(Director.duckAmount(0.5, true, 1, duck)).to.equal(1)
            expect(Director.duckAmount(1, false, 0.3, duck)).to.equal(0.5)
            expect(Director.duckAmount(0.5, false, 1, duck)).to.equal(0)
            expect(Director.duckAmount(0.5, true, 0.075, duck)).to.equal(1)
            expect(Director.duckAmount(0.5, true, -1, duck)).to.equal(0.5)
        end)
        it(
            "extends for spoken clips with room to finish and fade, but bounds late audio",
            function()
                local timing = {
                    duration_seconds = 9,
                    fade_seconds = 1.5,
                    voice = { tail_seconds = 0.35, maximum_encounter_seconds = 13 },
                }
                expect(Director.duration(timing, nil, 0)).to.equal(9)
                expect(Director.duration(timing, { seconds = 3 }, 0.75)).to.equal(9)
                expect(Director.duration(timing, { seconds = 8.25 }, 0.9)).to.equal(11)
                expect(Director.duration(timing, { seconds = 100 }, 2)).to.equal(13)
            end
        )
        it(
            "handles false/nil bays before claim or on the other side without reading attributes",
            function()
                local state = Director.new()
                local s = Director.snapshot(false)
                expect(s.eligible).to.equal(false)
                expect(s.wave).to.equal(0)
                expect(Director.step(state, s, 0, cfg)).to.equal(nil)
                expect(Director.snapshot(nil).eligible).to.equal(false)
            end
        )
        it("reads only the supplied bay's state when it becomes available", function()
            local attributes = {
                CurrentWave = 10,
                EnemiesBreachedBulwark = 2,
                MergeEggTutorialStep = "talk_quartermaster",
            }
            local s = Director.snapshot({
                GetAttribute = function(_, name)
                    return attributes[name]
                end,
            })
            expect(s.eligible).to.equal(true)
            expect(s.wave).to.equal(10)
            expect(s.bulwark).to.equal(2)
            expect(s.tutorialStep).to.equal("talk_quartermaster")
        end)
        it("does not react to old breaches on joining or replay old milestones", function()
            local state = Director.new()
            local s = snapshot(300)
            s.breaches = 5
            expect(Director.step(state, s, 0, cfg)).to.equal(nil)
        end)
        it("reacts to own fresh breaches, with cooldown and no delayed spam", function()
            local state = Director.new()
            Director.step(state, snapshot(), 0, cfg)
            local s = snapshot()
            s.bulwark = 1
            expect(Director.step(state, s, 1, cfg)).to.equal("bulwark")
            local nextState = snapshot()
            nextState.breaches = 1
            expect(Director.step(state, nextState, 2, cfg)).to.equal(nil)
            expect(Director.step(state, nextState, 100, cfg)).to.equal(nil)
        end)
        it("does not count a different run's damage as a breach", function()
            local state = Director.new()
            Director.step(state, snapshot(), 0, cfg)
            local s = snapshot()
            s.run, s.breaches = "b", 20
            expect(Director.step(state, s, 100, cfg)).to.equal(nil)
        end)
        it("suppresses menus/training and reacts to overrun rising edges", function()
            local state = Director.new()
            local s = snapshot()
            s.blocked = true
            expect(Director.step(state, s, 0, cfg)).to.equal(nil)
            s = snapshot()
            s.overrun = true
            expect(Director.step(state, s, 10, cfg)).to.equal("gate")
        end)
        it("nudges after a delay, caps reminders, and stops when no longer relevant", function()
            local state = Director.new()
            local s = snapshot()
            s.quartermaster = true
            expect(Director.step(state, s, 0, cfg)).to.equal(nil)
            expect(Director.step(state, s, 18, cfg)).to.equal("quartermaster")
            expect(Director.step(state, s, 100, cfg)).to.equal(nil)
            expect(Director.step(state, s, 198, cfg)).to.equal("quartermaster")
            expect(Director.step(state, s, 400, cfg)).to.equal(nil)
            expect(Director.step(state, snapshot(), 500, cfg)).to.equal(nil)
        end)
        it("shows each milestone once without stealing input, and ignores other realms", function()
            local state = Director.new()
            local s = snapshot(1)
            s.eligible = false
            expect(Director.step(state, s, 0, cfg)).to.equal(nil)
            s.eligible = true
            expect(Director.step(state, s, 0, cfg)).to.equal("arrival")
            expect(Director.step(state, s, 100, cfg)).to.equal(nil)
            expect(Director.step(state, snapshot(5), 101, cfg)).to.equal("milestone")
        end)
    end)
end
