-- Optional spoken orientation; no movement lock, rewards, or saved tutorial advancement.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local Flow = require(ReplicatedStorage.Shared.Game.CrossroadsIntroFlow)
local Narrator = require(script.Parent.TutorialNarrator)
local config = require(ReplicatedStorage.Configs.crossroads_tutorial)
local hostConfig = require(ReplicatedStorage.Configs.crossroads_hosts)
local HostClient = require(script.Parent.CrossroadsHostClient)
local HostPresentation = require(script.Parent.CrossroadsHostPresentation)
local Hatch = require(ReplicatedStorage.Shared.Services.EggHatchingService)
local Tutorial = {}
local started = false
local function rgb(value)
    return Color3.fromRGB(value[1], value[2], value[3])
end
function Tutorial.start()
    if
        started
        or not config.enabled
        or not PlaceRuntime.isRole(game.PlaceId, require(ReplicatedStorage.Configs.places), "main")
    then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local voiceConfig = table.clone(require(ReplicatedStorage.Configs.tutorial_voice))
    voiceConfig.audio = table.clone(voiceConfig.audio)
    voiceConfig.audio.group_name = config.group_name
    local hosts = HostClient.new()
    local lines = table.clone(config)
    lines.sections = table.clone(config.sections)
    for _, section in ipairs(require(ReplicatedStorage.Configs.crossroads_host_lines).sections) do
        table.insert(lines.sections, section)
    end
    local assets = table.clone(require(ReplicatedStorage.Configs.crossroads_voice_assets).clips)
    for cue, asset in pairs(require(ReplicatedStorage.Configs.crossroads_host_voice_assets).clips) do
        assets[cue] = asset
    end
    local voice = Narrator.new({
        config = voiceConfig,
        lines = lines,
        assets = assets,
        locales = {},
        presentation = hostConfig.enabled and HostPresentation.new() or nil,
        soundParent = hostConfig.enabled and function(speaker)
            return hosts:face(speaker)
        end or nil,
        soundRange = hostConfig.enabled and {
            minimum = hostConfig.minimum_hearing_distance,
            maximum = hostConfig.hearing_radius,
        } or nil,
    })
    local flow = Flow.new(config)
    local gui = Instance.new("ScreenGui")
    gui.Name, gui.ResetOnSpawn, gui.DisplayOrder =
        "CrossroadsIntroduction", false, config.ui.display_order
    gui.Enabled = false
    local panel = Instance.new("Frame")
    panel.Name = "Caption"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(config.ui.position[1], config.ui.position[2])
    panel.Size = UDim2.fromScale(config.ui.size[1], config.ui.size[2])
    panel.BackgroundColor3 = rgb(config.ui.background)
    panel.BorderSizePixel = 0
    panel.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(config.ui.corner_scale, 0)
    corner.Parent = panel
    local function label(name, position, size)
        local item = Instance.new("TextLabel")
        item.Name = name
        item.BackgroundTransparency = 1
        item.Position, item.Size = position, size
        item.Font = Enum.Font.GothamMedium
        item.TextColor3 = rgb(config.ui.text)
        item.TextScaled, item.TextWrapped = true, true
        item.Parent = panel
        return item
    end
    local function configuredLabel(name, slot)
        local position, size = config.ui[slot .. "_position"], config.ui[slot .. "_size"]
        return label(
            name,
            UDim2.fromScale(position[1], position[2]),
            UDim2.fromScale(size[1], size[2])
        )
    end
    local title = configuredLabel("Speaker", "speaker")
    local body = configuredLabel("Line", "line")
    local footer = configuredLabel("Explore", "footer")
    footer.Text = config.ui.explore
    gui.Parent = player:WaitForChild("PlayerGui")
    local sequence, index, elapsed, minimum, busy, hostRequest
    local function release()
        if busy then
            busy = false
            Narrator.release(voice)
            Signals.CrossroadsDialogueActive:FireServer(false)
        end
        gui.Enabled = false
        player:SetAttribute("CrossroadsNarrationBusy", false)
    end
    local function nextLine()
        index += 1
        local cue = sequence[index]
        if not cue then
            sequence = nil
            return
        end
        local line = voice.catalog[cue]
        elapsed = 0
        minimum = math.clamp(
            #line.text / config.caption_characters_per_second,
            config.caption_min_seconds,
            config.caption_max_seconds
        )
        body.Text = line.text
        title.Text = config.ui.title .. " • " .. voiceConfig.faces[line.speaker].label
        title.TextColor3 = rgb(config.ui[line.speaker])
        gui:SetAttribute("Cue", cue)
        player:SetAttribute("CrossroadsGuide", line.speaker)
        voice:setCue(cue)
    end
    RunService.Heartbeat:Connect(function(dt)
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local alive = humanoid and humanoid.Health > 0
        if not alive or player:GetAttribute("InCrossroads") ~= true then
            voice:cancel()
            sequence, hostRequest = nil, nil
            release()
            return
        end
        flow:observe(player:GetAttribute("CrossroadsAtmosphereZone"))
        local blocked = GuiService.MenuIsOpen
            or player:GetAttribute("LargeMenuOpen") == true
            or not Hatch:IsHatchReady()
        if hostConfig.enabled then
            hosts:nextRequest(os.clock(), true) -- Observe reactions even while a hatch/menu owns the screen.
        end
        if
            sequence
            and hostRequest
            and (
                not hosts:valid(hostRequest)
                or (hostRequest.activity ~= "gate" and hosts:gatePriority())
            )
        then
            voice:cancel()
            sequence, hostRequest = nil, nil
        end
        if not sequence then
            if
                not busy
                and (
                    GuiService.MenuIsOpen
                    or player:GetAttribute("LargeMenuOpen") == true
                    or player:GetAttribute("ClientUIReady") ~= true
                )
            then
                return
            end
            sequence = flow:nextSequence()
            hostRequest = nil
            if not sequence and hostConfig.enabled then
                hostRequest = hosts:nextRequest(os.clock(), blocked)
                sequence = hostRequest and hostRequest.cues
            end
            if not sequence then
                player:SetAttribute("CrossroadsGuide", flow.owner)
                release()
                return
            end
            if not busy then
                if not Narrator.acquire(voice) then
                    sequence = nil
                    return
                end
                busy = true
                Signals.CrossroadsDialogueActive:FireServer(true)
                player:SetAttribute("CrossroadsNarrationBusy", true)
            end
            index = 0
            nextLine()
        end
        gui.Enabled = not blocked
        if not GuiService.MenuIsOpen then
            elapsed += dt
        end
        if not voice.current and elapsed >= minimum then
            nextLine()
        end
    end)
end
return Tutorial
