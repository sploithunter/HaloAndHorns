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
