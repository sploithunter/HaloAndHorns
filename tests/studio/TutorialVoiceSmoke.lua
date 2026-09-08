-- Client-only presentation test. No tutorial progress, grants, or saved preferences are changed.
local Smoke = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local function settle()
    for _ = 1, 3 do
        RunService.Heartbeat:Wait()
    end
end
function Smoke.run()
    assert(RunService:IsStudio() and RunService:IsClient(), "Run in Studio Client")
    local player = Players.LocalPlayer
    local wasInPrologue = player:GetAttribute("InPrologue")
    player:SetAttribute("InPrologue", false)
    local configs = ReplicatedStorage.Configs
    local Narrator = require(Players.LocalPlayer.PlayerScripts.Client.Systems.TutorialNarrator)
    local config = table.clone(require(configs.tutorial_voice))
    config.audio = table.clone(config.audio)
    config.audio.group_name = "TutorialVoiceSmoke"
    local n = Narrator.new({ config = config })
    local report = { mainSteps = 0 }
    local ok, err = pcall(function()
        n:setStarterChoice(true, false)
        n:setState({ id = "hatch_first_egg", index = 1 })
        assert(n.current == nil, "Egg lesson spoke before starter choice")
        n:setStarterChoice(true, true)
        assert(n.current.cue == "tutorial.choose_companion", "Starter welcome missing")
        local welcome = n.current.sound
        n:setState({ id = "hatch_first_egg", index = 1 })
        n:setStarterChoice(true, true)
        assert(n.current.sound == welcome, "Starter refresh restarted speech")
        n:setStarterChoice(false, false)
        assert(n.current.cue == "tutorial.hatch_first_egg", "Egg lesson did not follow choice")
        n:cancel()
        report.starterChoice = true
        n:setState({ done = true })
        assert(n.current == nil, "Veteran join narrated completion")
        n:setState({ id = "hatch_first_egg", index = 1 })
        local first = n.current.sound
        n:setState({ id = "hatch_first_egg", index = 1, count = 1, body = "localized refresh" })
        assert(n.current.sound == first, "State refresh restarted speech")
        n:setState({ id = "ready", courseId = "basic", index = 1 })
        assert(
            first.Parent == nil and n.current.cue == "combat_tutorial.ready",
            "Track transition left old speech"
        )
        assert(
            n.current.sound.Volume > 2.3 and n.current.sound.Volume < 2.4,
            "Demon tuning changed"
        )
        n:help("combat_tutorial.bind_heal.choose")
        n:setState({ id = "first_fight", courseId = "basic", index = 2 })
        assert(n.helpCue == nil, "Obsolete help survived a lesson transition")
        n:setState({ done = true, courseId = "basic" })
        assert(n.current.cue == "combat_courses.basic.completion", "Wrong course completion")
        local completion = n.current.sound
        n:setState({ done = true, courseId = "basic" })
        assert(n.current.sound == completion, "Repeated done push cut completion")
        n:setState({ id = "rally_call", index = 9 })
        assert(
            n.current.sound == completion and n.nextCue == "tutorial.rally_call",
            "Homeworld cut the demon's exit"
        )
        n.current.resolved = true
        n.current.failed = true
        n:step(0)
        assert(
            n.current.cue == "tutorial.basic_return" and n.nextCue == "tutorial.rally_call",
            "Angel return was lost"
        )
        n:cancel()
        local Flow = require(ReplicatedStorage.Shared.Game.TutorialFlow)
        local Courses = require(ReplicatedStorage.Shared.Game.CombatCourses)
        for index, step in ipairs(require(configs.tutorial).steps) do
            n:setState({ id = step.id, index = index })
            assert(
                n.current.cue == "tutorial." .. step.id,
                "Missing Homeworld performance: " .. step.id
            )
            report.mainSteps += 1
        end
        for _, course in ipairs(require(configs.combat_courses).courses) do
            n:cancel()
            local catalog = Courses.project(require(configs.combat_tutorial), course)
            for index, step in ipairs(catalog.steps) do
                local state = Flow.stateFor(catalog, { step = index, count = 0, done = false })
                state.courseId = course.id
                n:setState(state)
                assert(
                    n.current.cue == "combat_tutorial." .. step.id,
                    "Missing combat performance: " .. step.id
                )
                report.mainSteps += 1
            end
        end
        n:cancel()
        n:setState({ id = "ready", courseId = "basic", index = 1, replay = true })
        assert(n.current.cue == "combat_courses.replay.start", "Replay intro missing")
        n:setState({ done = true, courseId = "basic", replay = true })
        assert(
            n.current.cue == "combat_courses.replay.completion",
            "Replay advertised a new reward"
        )
        n:cancel()
        n:setState({ id = "hatch_first_egg", index = 1 })
        settle()
        assert(n.presentation.head ~= nil, "Angel face did not load")
        n.presentation:step(0.2, 1, 100, true)
        assert(n.presentation.gui.Enabled, "Portrait fallback hidden")
        settle()
        local box = n.presentation.card
        local p, s = box.AbsolutePosition, box.AbsoluteSize
        local origin, extent = n.presentation.gui.AbsolutePosition, n.presentation.gui.AbsoluteSize
        assert(
            p.X >= origin.X
                and p.Y >= origin.Y
                and s.X > 0
                and s.Y > 0
                and p.X + s.X <= origin.X + extent.X
                and p.Y + s.Y <= origin.Y + extent.Y,
            "Portrait geometry invalid"
        )
        assert(n.current.sound.SoundGroup == n.mixer.group, "Narration bypasses Voices mix")
        n:cancel()
        n:setState({ id = "hatch_first_egg", index = 1, count = 0 })
        n:_stop()
        n:step(config.reminder_delay_seconds - 1)
        assert(n.current == nil, "Reminder fired early")
        n:step(1)
        assert(
            n.current and n.current.cue == "tutorial.hatch_first_egg.reminder",
            "Egg reminder missing"
        )
        n:_stop()
        n:step(config.reminder_repeat_seconds - 1)
        assert(n.current == nil, "Reminder repeated early")
        n:step(1)
        assert(n.current and n.current.reminder, "Recurring reminder stopped after one nudge")
        n:setState({ id = "hatch_first_egg", index = 1, count = 1 })
        assert(n.current == nil and n.hasReminded == false, "Progress did not reset reminders")
        n:setState({ done = true })
        n:_stop()
        n:step(config.reminder_repeat_seconds * 2)
        assert(n.current == nil, "Completed tutorial kept reminding")
        n:setState({ id = "hatch_first_egg", index = 1, count = 0 })
        n:_stop()
        local wasMenuOpen = player:GetAttribute("LargeMenuOpen")
        player:SetAttribute("LargeMenuOpen", true)
        n:step(config.reminder_repeat_seconds * 2)
        local remindedDuringMenu = n.current ~= nil
        player:SetAttribute("LargeMenuOpen", wasMenuOpen)
        assert(not remindedDuringMenu, "Reminder interrupted a menu")
        n.presentation:show("demon")
        n.presentation:step(0.1, 2, 100, false)
        local face = n.presentation.worldHead
        assert(
            face.Parent == workspace and not n.presentation.gui.Enabled,
            "Gameplay used a portrait"
        )
        local camera = workspace.CurrentCamera
        local original = camera.CFrame
        local before = face.Position
        camera.CFrame = original * CFrame.Angles(0, math.rad(120), 0)
        n.presentation:step(0.1, 2, 100, false)
        camera.CFrame = original
        local speed = require(configs.merge_egg_prototype).watcher.max_speed
        assert(
            (face.Position - before).Magnitude <= speed * 0.1 + 0.01,
            "Camera pan snapped the face"
        )
        assert(
            face.Parent == workspace and not n.presentation.gui.Enabled,
            "Camera pan switched to portrait"
        )
        report.worldCameraFollow = true
        report.menuReminderPause = true
        report.recurringReminders = true
        report.duplicateSuppression = true
        report.courseHandoff = true
        report.replay = true
        report.portrait = true
    end)
    n:destroy()
    assert(
        not game.SoundService:FindFirstChild("TutorialVoiceSmoke"),
        "Mixer leaked after destruction"
    )
    player:SetAttribute("InPrologue", wasInPrologue)
    assert(ok, tostring(err))
    report.cleanup = true
    return report
end
return Smoke
