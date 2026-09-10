-- One optional comment per client session, after server-confirmed manual pickups and non-ownership.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local Policy = require(ReplicatedStorage.Shared.Game.CollectorCommentPolicy)
local Narrator = require(script.Parent.TutorialNarrator)
local config = require(ReplicatedStorage.Configs.collector_voice)
local collectorAttribute =
    require(ReplicatedStorage.Configs.drops).auto_collector.entitlement_attribute
local Comments = {}
Comments.__index = Comments
local singleton

function Comments.new(options)
    options = options or {}
    return setmetatable({ voice = options.voice, connections = {}, elapsed = 0 }, Comments)
end

function Comments:receive(snapshot, now)
    if not self.played and snapshot.eligible == true and snapshot.collector ~= true then
        self.pendingUntil = now + config.pending_seconds
    end
end

function Comments:step(snapshot, now)
    if snapshot.eligible ~= true or snapshot.collector == true then
        self.pendingUntil = nil
        if self.voice then
            self.voice:cancel()
        end
        return
    end
    if self.voice and self.voice.current and (snapshot.blocked or snapshot.side ~= self.side) then
        self.voice:cancel()
    end
    if self.pendingUntil and now > self.pendingUntil then
        self.pendingUntil = nil
    end
    if self.played or not self.pendingUntil or not Policy.canPlay(snapshot) then
        return
    end
    if not self.voice then
        local playback = table.clone(require(ReplicatedStorage.Configs.tutorial_voice))
        playback.audio = table.clone(playback.audio)
        playback.audio.group_name = config.group_name
        self.voice = Narrator.new({
            config = playback,
            lines = {
                sections = config.sections,
                playbackVolumeSource = require(ReplicatedStorage.Configs.tutorial_voice_lines).playbackVolumeSource,
            },
            assets = config.clips,
            locales = config.locales,
        })
    end
    local cue = config.cues[snapshot.side == "hell" and "demon" or "angel"]
    if self.voice:_play(cue) then
        self.side, self.played, self.pendingUntil = snapshot.side, true, nil
    end
end

function Comments:snapshot()
    local p = Players.LocalPlayer
    local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
    local camera = Workspace.CurrentCamera
    local gui = p:FindFirstChildOfClass("PlayerGui")
    local modeNotice = gui and gui:FindFirstChild("MergeDefenseModeNotice")
    return {
        eligible = p:GetAttribute(config.eligibility_attribute),
        collector = p:GetAttribute(collectorAttribute),
        side = p:GetAttribute("InCrossroads") == true
                and (p:GetAttribute("CrossroadsGuide") == "demon" and "hell" or "heaven")
            or (p:GetAttribute("InMergeEggPrototype") == true and p:GetAttribute("MergeEggBaySide"))
            or p:GetAttribute("CurrentRealm"),
        blocked = (
            p:GetAttribute("InMergeEggPrototype") == true
            and p:GetAttribute("MergeEggBaySide") == nil
        )
            or not humanoid
            or humanoid.Health <= 0
            or not camera
            or camera.CameraType == Enum.CameraType.Scriptable
            or GuiService.MenuIsOpen
            or Narrator.isSpeaking(self.voice)
            or p:GetAttribute("InCombat") == true
            or p:GetAttribute("InCombatTutorial") == true
            or p:GetAttribute("InPrologue") == true
            or p:GetAttribute("LargeMenuOpen") == true
            or p:GetAttribute("StarterPetChoiceOpen") == true
            or p:GetAttribute("TutorialHandoffOpen") == true
            or p:GetAttribute("CombatTutorialPromptOpen") == true
            or p:GetAttribute("MergeTutorialMenuOpen") == true
            or p:GetAttribute("MergePortalTransitActive") == true
            or p:GetAttribute("TutorialStepId") ~= nil
            or p:GetAttribute("MergeTutorialVoiceLessonActive") == true
            or (modeNotice ~= nil and modeNotice.Enabled)
            or Workspace:FindFirstChild("MergeWatcherApparition") ~= nil,
    }
end

function Comments:destroy()
    for _, connection in ipairs(self.connections) do
        connection:Disconnect()
    end
    if self.voice then
        self.voice:destroy()
    end
end

function Comments.start()
    if singleton or not config.enabled then
        return singleton
    end
    singleton = Comments.new()
    local self = singleton
    table.insert(
        self.connections,
        Signals.GameEvent.OnClientEvent:Connect(function(event)
            if event == config.event then
                self:receive(self:snapshot(), os.clock())
            end
        end)
    )
    local function changed()
        self:step(self:snapshot(), os.clock())
    end
    for _, attribute in { config.eligibility_attribute, collectorAttribute } do
        table.insert(
            self.connections,
            Players.LocalPlayer:GetAttributeChangedSignal(attribute):Connect(changed)
        )
    end
    table.insert(
        self.connections,
        RunService.Heartbeat:Connect(function(dt)
            self.elapsed += dt
            if self.elapsed >= config.scan_seconds then
                self.elapsed = 0
                if self.pendingUntil or (self.voice and self.voice.current) then
                    changed()
                end
            end
        end)
    )
    return self
end
return Comments
