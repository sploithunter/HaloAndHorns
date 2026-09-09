-- Reuses the tutorial voice player; driven by the existing owned-bay HUD update, not another scan.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Director = require(ReplicatedStorage.Shared.Game.MergeTutorialVoiceDirector)
local Narrator = require(script.Parent.TutorialNarrator)
local config = require(ReplicatedStorage.Configs.merge_tutorial_voice)
local transitConfig = require(ReplicatedStorage.Configs.merge_egg_prototype).gate.transit_feedback
local Controller = {}
Controller.__index = Controller
local singleton
function Controller.new(options)
    options = options or {}
    local playback = table.clone(require(ReplicatedStorage.Configs.tutorial_voice))
    playback.audio = table.clone(playback.audio)
    playback.audio.group_name = config.group_name
    playback.reminders = {}
    playback.reminder_fallback = {}
    for side, speaker in pairs(config.side_speakers) do
        playback.reminder_fallback[speaker] = Director.cue(side, config.reminder_cue)
    end
    return setmetatable({
        director = Director.new(),
        voice = options.voice or Narrator.new({
            config = playback,
            lines = require(ReplicatedStorage.Configs.merge_tutorial_voice_lines),
            assets = require(ReplicatedStorage.Configs.merge_tutorial_voice_assets).clips,
        }),
    }, Controller)
end
function Controller:apply(snapshot)
    local action = Director.step(self.director, snapshot, config)
    if action.cancel or action.reset then
        self.voice:cancel()
        self.key = nil
    end
    if action.cue then
        if action.cue ~= self.key then
            self.key = action.cue
            self.voice:setCue(action.cue, action.progress, action)
        else
            self.voice:updateCueProgress(action.progress)
        end
        self.voice:help(action.help)
    elseif action.quiet then
        -- Let a short combat handoff finish, but never run an idle reminder during waves.
        self.voice.identity, self.voice.helpCue = nil, nil
    end
    return action
end
function Controller:destroy()
    self.voice:destroy()
end
function Controller.update(world, observing, menuOpen)
    local player = Players.LocalPlayer
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    local modeNotice = playerGui and playerGui:FindFirstChild("MergeDefenseModeNotice")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    player:SetAttribute("MergeTutorialMenuOpen", observing == true and menuOpen == true)
    player:SetAttribute(
        "MergeTutorialVoiceLessonActive",
        observing == true
            and world ~= nil
            and world:GetAttribute("ActivePlayer") == player.Name
            and world:GetAttribute("MergeEggTutorialActive") == true
    )
    if not config.enabled then
        return
    end
    if not singleton then
        if not observing or not world then
            return
        end
        singleton = Controller.new()
    end
    local function attr(name)
        return world and world:GetAttribute(name)
    end
    local function count(name)
        -- Replicated counters can be absent while a bay's initial attributes arrive.
        return tonumber(attr(name)) or 0
    end
    local snapshot = {
        observing = observing == true and world ~= nil and attr("ActivePlayer") == player.Name,
        blocked = player:GetAttribute("InCombatTutorial") == true
            or player:GetAttribute("InPrologue") == true
            or player:GetAttribute(transitConfig.active_attribute) == true
            or not humanoid
            or humanoid.Health <= 0
            or (modeNotice ~= nil and modeNotice.Enabled),
        bay = world,
        run = attr("ActiveRunId"),
        side = attr("MergeEggBaySide"),
        required = attr("MergeEggTutorialRequired") == true,
        completed = attr("MergeEggTutorialCompleted") == true,
        rebirths = count("MergeDefenseRebirthCount"),
        active = attr("MergeEggTutorialActive") == true,
        step = attr("MergeEggTutorialStep"),
        autoCollector = attr("MergeEggTutorialUsesAutoCollector") == true,
        created = count("MergeEggTutorialUpgradeCreated"),
        createNeed = count("MergeEggTutorialUpgradeCreateNeed"),
        powerHelp = player:GetAttribute("MergeTutorialPowerGuideAction"),
    }
    snapshot.progress = table.concat({
        tostring(attr("MergeEggTutorialEggsCreated")),
        tostring(attr("MergeEggTutorialPositionsFilled")),
        tostring(attr("MergeEggTutorialUpgradeCreated")),
        tostring(attr("MergeEggTutorialUpgradeWallet")),
        tostring(snapshot.powerHelp),
    }, ":")
    singleton:apply(snapshot)
end
return Controller
