-- One current performance and one replaceable next cue. Never advances tutorial progress.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Director = require(ReplicatedStorage.Shared.Game.TutorialVoiceDirector)
local VoiceLocale = require(ReplicatedStorage.Shared.Game.TutorialVoiceLocale)
local TutorialLocalization = require(ReplicatedStorage.Shared.Game.TutorialLocalization)
local Mixer = require(script.Parent.MergeWatcherAudio)
local Presentation = require(script.Parent.TutorialVoicePresentation)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local Narrator = {}
local Player = {}
Player.__index = Player
local singleton
local speakingOwners = {}
local exclusiveOwner
function Narrator.isSpeaking(except)
    if exclusiveOwner and exclusiveOwner ~= except then
        return true
    end
    for owner in pairs(speakingOwners) do
        if owner ~= except then
            return true
        end
    end
    return false
end
function Narrator.new(options)
    options = options or {}
    local config = options.config or require(ReplicatedStorage.Configs.tutorial_voice)
    local lines = options.lines or require(ReplicatedStorage.Configs.tutorial_voice_lines)
    local watcher = require(ReplicatedStorage.Configs.merge_egg_prototype).watcher
    local audioConfig = table.clone(watcher.voice)
    audioConfig.group_name = config.audio.group_name
    local self = setmetatable({
        config = config,
        catalog = Director.catalog(lines),
        assets = options.assets or require(ReplicatedStorage.Configs.tutorial_voice_assets).clips,
        locales = options.locales
            or require(ReplicatedStorage.Configs.tutorial_voice_locales).locales,
        language = TutorialLocalization.languageFor(
            options.localeId or Players.LocalPlayer:GetAttribute("TutorialLocaleId")
        ),
        unavailable = {},
        watcher = watcher,
        volumes = lines.playbackVolumeSource,
        mixer = Mixer.new(audioConfig),
        presentation = Presentation.new(config),
        seen = {},
        eventTimes = {},
        connections = {},
    }, Player)
    if options.localeId == nil then
        table.insert(
            self.connections,
            Players.LocalPlayer:GetAttributeChangedSignal("TutorialLocaleId"):Connect(function()
                self:setLocale(Players.LocalPlayer:GetAttribute("TutorialLocaleId"))
            end)
        )
    end
    table.insert(
        self.connections,
        RunService.Heartbeat:Connect(function(dt)
            self:step(dt)
        end)
    )
    return self
end
function Player:_stop()
    self.deferredCue = nil
    if self.current then
        self.current.sound:Destroy()
    end
    self.current = nil
    self.mixer:setSpeaking(false)
    self.presentation:hide()
    speakingOwners[self] = nil
    Players.LocalPlayer:SetAttribute(
        "TutorialNarrationActive",
        exclusiveOwner ~= nil or next(speakingOwners) ~= nil
    )
end
function Player:cancel()
    self:_stop()
    self.deferredCue = nil
    self.nextCue, self.helpCue, self.identity, self.state = nil, nil, nil, nil
    table.clear(self.seen)
end
function Player:setLocale(localeId)
    local language = TutorialLocalization.languageFor(localeId)
    if language == self.language then
        return
    end
    self.language = language
    -- Translate an active performance without reviving completed lessons or losing its queue.
    local current = self.current
    if current then
        local idleSeconds = self.idleSeconds
        if self:_play(current.cue, current.completion) then
            self.current.reminder = current.reminder
        end
        self.idleSeconds = idleSeconds
    end
end
function Player:_play(cue, completion, forceEnglish)
    if exclusiveOwner and exclusiveOwner ~= self then
        self.deferredCue = { cue = cue, completion = completion, forceEnglish = forceEnglish }
        return true
    end
    local line = self.catalog[cue]
    local asset, language = VoiceLocale.resolve(
        forceEnglish and "en" or self.language,
        cue,
        self.assets,
        self.locales,
        self.unavailable
    )
    if not self.config.enabled or not line or not asset then
        return false
    end
    self:_stop()
    local sound = Instance.new("Sound")
    sound.Name = "TutorialNarrationClip"
    sound.SoundId = "rbxassetid://" .. tostring(asset.asset_id)
    local gain = require(ReplicatedStorage.Configs[self.volumes.config])
    for _, key in ipairs(self.volumes[line.speaker]) do
        gain = gain[key]
    end
    sound.Volume = gain
    sound.SoundGroup = self.mixer.group
    sound.Parent = SoundService
    local now = os.clock()
    self.current = {
        cue = cue,
        sound = sound,
        startedAt = now,
        seconds = asset.seconds,
        completion = completion,
        language = language,
        assetId = asset.asset_id,
    }
    self.idleSeconds = 0
    self.seen[cue] = true
    self.presentation:show(line.speaker)
    self.presentation.gui:SetAttribute("Cue", cue)
    self.presentation.gui:SetAttribute("VoiceLanguage", language)
    speakingOwners[self] = true
    Players.LocalPlayer:SetAttribute("TutorialNarrationActive", true)
    task.spawn(function()
        local ok = pcall(function()
            ContentProvider:PreloadAsync({ sound }, function(_, status)
                if self.current and self.current.sound == sound then
                    self.current.loadFailed = status == Enum.AssetFetchStatus.Failure
                end
            end)
        end)
        if not ok and self.current and self.current.sound == sound then
            self.current.loadFailed = true
        end
    end)
    return true
end
function Player:_fallback(current)
    if current.language == "en" then
        return false
    end
    -- A rejected/unavailable recording is tried only once per player instance, not every reminder.
    self.unavailable[current.assetId] = true
    if self:_play(current.cue, current.completion, true) then
        self.current.reminder = current.reminder
        return true
    end
    return false
end
-- External tutorial tracks share playback, queue bounds, presentation and reminders.
function Player:updateCueProgress(progress)
    if self.cueProgress ~= progress then
        self.cueProgress = progress
        self.idleSeconds, self.hasReminded = 0, false
        if self.current and self.current.reminder then
            self:_stop()
        end
    end
end
function Player:setCue(cue, progress, options)
    options = options or {}
    self.helpCue, self.nextCue = nil, nil
    table.clear(self.seen)
    self.identity = options.remind and cue or nil
    self.cueProgress = progress
    self.idleSeconds, self.hasReminded = 0, false
    if options.finishCurrent and self.current then
        self.nextCue = cue
    elseif options.intro then
        self:_play(options.intro)
        self.nextCue = cue
    else
        self:_play(cue)
    end
end
function Player:setStarterChoice(pending, visible)
    self.starterPending = pending == true
    if self.starterPending then
        if self.state and not self.state.courseId then
            self.parkedStarterState = self.state
            self:cancel()
        end
        if visible and not self.starterVisible then
            self:_play("tutorial.choose_companion")
        end
        self.starterVisible = visible == true
    else
        local wasVisible = self.starterVisible
        self.starterVisible = false
        if wasVisible then
            self:_stop()
        end
        local state = self.parkedStarterState
        self.parkedStarterState = nil
        if state then
            self:setState(state)
        end
    end
end
function Player:setState(state)
    if self.starterPending and type(state) == "table" and not state.courseId then
        self.parkedStarterState = state
        return
    end
    local previous = self.state
    local key = Director.key(state)
    if key and key == self.identity then
        if previous and previous.count ~= state.count then
            self.idleSeconds, self.hasReminded = 0, false
            if self.current and self.current.reminder then
                self:_stop()
            end
        end
        self.state = state
        if state.id == "stack_brew" then
            local remaining = (tonumber(state.need) or 5) - (tonumber(state.count) or 0)
            self:help(Director.doorCue(self.config, nil, state.id, remaining))
        end
        return
    end
    local completion = Director.completion(previous, state)
    self.state, self.identity = state, key
    self.helpCue, self.nextCue = nil, nil
    table.clear(self.seen)
    if completion then
        self.lastCompleted = previous.courseId
        self:_play(completion, true)
        return
    end
    if not key then
        -- Repeated done pushes must not cut off the completion performance.
        if
            not (self.current and self.current.completion and type(state) == "table" and state.done)
        then
            self:_stop()
        end
        return
    end
    self.idleSeconds, self.hasReminded = 0, false
    if self.current and self.current.completion then
        self.nextCue = key
        return
    end
    local intro = Director.introduction(previous, state)
    if self.lastCompleted == "basic" and not state.courseId then
        intro = "tutorial.basic_return"
        self.lastCompleted = nil
    end
    if intro and self:_play(intro) then
        self.nextCue = key
    else
        self:_play(key)
    end
end
function Player:help(cue)
    if cue == self.helpCue then
        return
    end
    if self.current and self.current.cue == self.helpCue then
        self:_stop()
    end
    self.helpCue = self.catalog[cue] and cue or nil
    self.helpAt = os.clock() + self.config.help_delay_seconds
end
function Player:say(cue)
    if not self.catalog[cue] then
        return
    end
    local now = os.clock()
    if now - (self.eventTimes[cue] or -math.huge) < self.config.event_cooldown_seconds then
        return
    end
    self.eventTimes[cue] = now
    self.nextCue, self.helpCue = nil, nil
    self:_play(cue)
end
function Player:step(dt)
    self.mixer:step(dt)
    if exclusiveOwner and exclusiveOwner ~= self then
        return
    end
    if self.deferredCue then
        local deferred = self.deferredCue
        self.deferredCue = nil
        self:_play(deferred.cue, deferred.completion, deferred.forceEnglish)
    end
    local current = self.current
    local player = Players.LocalPlayer
    if current then
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if player:GetAttribute("InPrologue") or (humanoid and humanoid.Health <= 0) then
            self:cancel()
            return
        end
        if GuiService.MenuIsOpen then
            if current.sound.IsPlaying then
                current.sound:Pause()
                current.paused = true
            end
            current.startedAt += dt
            self.presentation.gui.Enabled = false
            if self.presentation.worldHead then
                self.presentation.worldHead.Parent = nil
            end
            self.mixer:setSpeaking(false)
            return
        elseif current.paused then
            current.paused = false
            current.sound:Resume()
        end
        local age = os.clock() - current.startedAt
        if not current.resolved then
            if current.sound.IsLoaded then
                current.resolved = true
                current.audioStarted = age
                current.sound:Play()
            elseif current.loadFailed or age >= self.config.audio.load_deadline_seconds then
                if self:_fallback(current) then
                    return
                end
                current.resolved = true
                current.failed = true
                warn("Tutorial voice unavailable: " .. current.cue)
            end
        end
        local finished = current.failed
            or (
                current.audioStarted
                and not current.sound.IsPlaying
                and age > current.audioStarted + self.config.audio.tail_seconds
            )
        local expired = age
            > (current.audioStarted or self.config.audio.load_deadline_seconds)
                + current.seconds
                + self.config.audio.tail_seconds
        if finished or expired then
            self:_stop()
            self.finishedAt = os.clock()
            local nextCue = self.nextCue
            self.nextCue = nil
            if nextCue then
                if self.lastCompleted == "basic" and nextCue:sub(1, 9) == "tutorial." then
                    self.lastCompleted = nil
                    self:_play("tutorial.basic_return")
                    self.nextCue = nextCue
                else
                    self:_play(nextCue)
                end
            end
            return
        end
        self.mixer:setSpeaking(current.sound.IsPlaying)
        self.presentation:step(
            dt,
            age,
            current.sound.PlaybackLoudness,
            self.starterVisible == true
                or player:GetAttribute("LargeMenuOpen") == true
                or player:GetAttribute("TutorialHandoffOpen") == true
                or player:GetAttribute("CombatTutorialPromptOpen") == true
                or player:GetAttribute("MergeTutorialMenuOpen") == true
        )
    elseif self.identity then
        local now = os.clock()
        if self.helpCue and not self.seen[self.helpCue] and now >= self.helpAt then
            self:_play(self.helpCue)
        else
            self:_stepReminders(
                dt,
                GuiService.MenuIsOpen
                    or player:GetAttribute("LargeMenuOpen") == true
                    or player:GetAttribute("TutorialHandoffOpen") == true
                    or player:GetAttribute("StarterPetChoiceOpen") == true
                    or player:GetAttribute("CombatTutorialPromptOpen") == true
                    or player:GetAttribute("MergeTutorialMenuOpen") == true
                    or player:GetAttribute("InPrologue") == true
                    or player:GetAttribute("InCombat") == true
            )
        end
    end
end
-- Explicit blocked input keeps timer tests independent of a live player's menus/combat.
function Player:_stepReminders(dt, blocked)
    if blocked or not self.identity or self.current then
        return
    end
    self.idleSeconds = (self.idleSeconds or 0) + dt
    local delay = self.hasReminded and self.config.reminder_repeat_seconds
        or self.config.reminder_delay_seconds
    if self.idleSeconds >= delay then
        local speaker = self.catalog[self.identity].speaker
        local reminder = self.config.reminders[self.identity]
            or self.config.reminder_fallback[speaker]
        if self:_play(reminder) then
            self.current.reminder = true
            self.hasReminded = true
        end
    end
end
function Player:destroy()
    Narrator.release(self)
    self:cancel()
    for _, connection in ipairs(self.connections) do
        connection:Disconnect()
    end
    self.presentation:destroy()
    self.mixer:destroy()
end
-- An authored exchange owns the voice channel until every participant has finished.
function Narrator.acquire(owner)
    if exclusiveOwner and exclusiveOwner ~= owner then
        return false
    end
    exclusiveOwner = owner
    local interrupted = {}
    for other in pairs(speakingOwners) do
        if other ~= owner then
            table.insert(interrupted, other)
        end
    end
    for _, other in ipairs(interrupted) do
        local current = other.current
        other:_stop()
        other.deferredCue = current and { cue = current.cue, completion = current.completion }
    end
    Players.LocalPlayer:SetAttribute("TutorialNarrationActive", true)
    return true
end
function Narrator.release(owner)
    if exclusiveOwner == owner then
        exclusiveOwner = nil
        Players.LocalPlayer:SetAttribute("TutorialNarrationActive", next(speakingOwners) ~= nil)
    end
end
function Narrator.start()
    if singleton then
        return singleton
    end
    singleton = Narrator.new()
    local player = Players.LocalPlayer
    local starterEnabled = require(ReplicatedStorage.Configs.starter_pets).enabled
        and require(ReplicatedStorage.Shared.Game.PlaceRuntime).isRole(
            game.PlaceId,
            require(ReplicatedStorage.Configs.places),
            "main"
        )
    if starterEnabled then
        singleton:setStarterChoice(player:GetAttribute("StarterPetChosen") ~= true, false)
        player:GetAttributeChangedSignal("StarterPetChosen"):Connect(function()
            if player:GetAttribute("StarterPetChosen") == false then
                singleton:setStarterChoice(
                    true,
                    player:GetAttribute("StarterPetChoiceOpen") == true
                )
            end
        end)
    end
    Signals.GameEvent.OnClientEvent:Connect(function(name, context)
        if name == "combat_tutorial_door_blocked" and type(context) == "table" then
            singleton:say(context.voiceCue)
        end
    end)
    Players.LocalPlayer.CharacterAdded:Connect(function()
        singleton:cancel()
        Signals.TutorialStateRequest:FireServer()
    end)
    return singleton
end
function Narrator.setStarterChoice(pending, visible)
    Narrator.start():setStarterChoice(pending, visible)
end
function Narrator.setState(state)
    Narrator.start():setState(state)
end
function Narrator.help(cue)
    Narrator.start():help(cue)
end
function Narrator.say(cue)
    Narrator.start():say(cue)
end
function Narrator.stopEvent()
    if singleton then
        singleton:_stop()
        singleton.nextCue, singleton.helpCue = nil, nil
    end
end
function Narrator.suspend()
    if not singleton then
        return
    end
    if singleton.current and singleton.current.completion then
        singleton.state, singleton.identity, singleton.nextCue, singleton.helpCue =
            nil, nil, nil, nil
    else
        singleton:cancel()
    end
end
function Narrator.cancel()
    if singleton then
        singleton:cancel()
    end
end
return Narrator
