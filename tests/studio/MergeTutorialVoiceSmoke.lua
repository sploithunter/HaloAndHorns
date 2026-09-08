-- Read-only tutorial snapshots; never changes a profile, tutorial progress, or bay ownership.
local Smoke = {}
function Smoke.run()
    local RunService = game:GetService("RunService")
    assert(RunService:IsStudio() and RunService:IsClient(), "Run in Studio Client")
    local player = game.Players.LocalPlayer
    local systems = player.PlayerScripts.Client.Systems
    local Controller = require(systems.MergeTutorialNarrator)
    local Narrator = require(systems.TutorialNarrator)
    local configs = game.ReplicatedStorage.Configs
    local config = require(configs.merge_tutorial_voice)
    local c = Controller.new()
    local other = Narrator.new()
    local savedPrologue = player:GetAttribute("InPrologue")
    player:SetAttribute("InPrologue", false)
    local report = { mainSteps = 0 }
    local function state(overrides)
        local s = {
            observing = true,
            bay = "fixture",
            run = 1,
            side = "heaven",
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
    local ok, err = pcall(function()
        for _, side in { "heaven", "hell" } do
            for step, suffix in pairs(config.steps) do
                c:apply(state({ side = side, step = step }))
                if c.voice.nextCue then
                    c.voice.current.resolved, c.voice.current.failed = true, true
                    c.voice:step(0)
                end
                assert(
                    c.voice.current.cue == "merge_tutorial." .. side .. "." .. suffix,
                    "Wrong step " .. step
                )
                local sound = c.voice.current.sound
                c:apply(state({ side = side, step = step, progress = "1" }))
                assert(c.voice.current.sound == sound, "Count refresh restarted speech")
                assert(sound.SoundGroup == c.voice.mixer.group, "Voice bypasses volume control")
                report.mainSteps += 1
            end
        end
        c:apply(state())
        local angel = c.voice.current.sound
        c:apply(state({ side = "hell" }))
        assert(
            angel.Parent == nil and c.voice.current.sound.Volume > 2.3,
            "Side swap or demon gain broken"
        )
        other:setCue("tutorial.hatch_first_egg")
        c.voice:cancel()
        assert(
            player:GetAttribute("TutorialNarrationActive"),
            "One idle narrator silenced another's priority"
        )
        other:cancel()
        c.key = nil
        c:apply(state({ step = "enhance_lesson", powerHelp = "enhancement" }))
        assert(
            c.voice.helpCue == "merge_tutorial.heaven.help.enhancement",
            "Contextual help missing"
        )
        c:apply(state({ step = "deploy_one" }))
        assert(c.voice.helpCue == nil, "Stale power help survived")
        c:apply(state({ active = false }))
        assert(c.voice.current.cue == "merge_tutorial.heaven.after_setup", "Defense advice missing")
        c.voice:_stop()
        c:apply(state({ active = false }))
        c.voice:_stepReminders(120, false)
        assert(c.voice.current == nil, "Combat interval nagged")
        c:apply(state())
        c.voice:_stop()
        c.voice:_stepReminders(c.voice.config.reminder_delay_seconds, false)
        assert(c.voice.current.reminder, "Idle reminder missing")
        c.voice:_stop()
        c.voice:_stepReminders(c.voice.config.reminder_repeat_seconds, false)
        assert(c.voice.current.reminder, "Second reminder missing")
        c:apply(state({ progress = "2" }))
        assert(c.voice.current == nil and not c.voice.hasReminded, "Progress did not stop reminder")
        c:apply(state({ step = "talk_quartermaster" }))
        local intro = c.voice.current.sound
        c:apply(
            state({
                step = "talk_quartermaster",
                completed = true,
                required = false,
                active = false,
            })
        )
        assert(
            c.voice.current.sound == intro and c.voice.nextCue == "merge_tutorial.heaven.completion",
            "Timed introduction was cut short"
        )
        c:apply(state({ completed = true, required = false }))
        assert(c.voice.current.sound == intro, "Repeated completion interrupted exit")
        c.voice.current.resolved, c.voice.current.failed = true, true
        c.voice:step(0)
        assert(c.voice.current.cue == "merge_tutorial.heaven.completion", "Completion not played")
        c:apply(state({ run = 2, completed = true }))
        assert(c.voice.current == nil, "Veteran join celebrated again")
        c:apply(state({ run = 3, rebirths = 1 }))
        assert(c.voice.current == nil, "Reborn player was tutored")
        c:apply(state({ run = 4 }))
        for _ = 1, 3 do
            RunService.Heartbeat:Wait()
        end
        c.voice.presentation:step(0.1, 1, 100, false)
        assert(
            c.voice.presentation.worldHead.Parent == workspace
                and not c.voice.presentation.gui.Enabled,
            "Gameplay face is not in world"
        )
        c.voice.presentation:step(0.1, 1, 100, true)
        assert(c.voice.presentation.gui.Enabled, "Menu portrait missing")
        c:apply(state({ observing = false }))
        assert(c.voice.current == nil, "Leaving owned bay left speech playing")
        report.contextTransitions = true
        report.reminders = true
        report.menuPortrait = true
        report.worldFace = true
        report.sharedPriority = true
        report.completionHandoff = true
    end)
    c:destroy()
    other:destroy()
    player:SetAttribute("InPrologue", savedPrologue)
    assert(ok, tostring(err))
    report.cleanup = true
    return report
end
return Smoke
